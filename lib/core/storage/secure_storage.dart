import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/user.dart';

class SecureStorage {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';
  static const _deviceKey = 'device_id';

  static Future<String> getDeviceId() async {
    final curId = await _storage.read(key: _deviceKey);
    if (curId != null && curId.isNotEmpty) {
      return curId;
    }
    // Generate new UUID
    final uuid = const Uuid().v4();
    await _storage.write(key: _deviceKey, value: uuid);
    return uuid;
  }

  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  static Future<void> saveUser(User user) async {
    final Map<String, dynamic> json = {
      'id': user.id,
      'name': user.name,
      'email': user.email,
      'isGuest': user.isGuest,
      'loginAt': user.loginAt?.toIso8601String(),
    };
    await _storage.write(key: _userKey, value: jsonEncode(json));
  }

  static Future<User?> getUser() async {
    final userStr = await _storage.read(key: _userKey);
    if (userStr == null) return null;

    final map = jsonDecode(userStr);
    return User()
      ..id = map['id']
      ..name = map['name']
      ..email = map['email']
      ..isGuest = map['isGuest'] ?? false
      ..loginAt = map['loginAt'] != null
          ? DateTime.parse(map['loginAt'])
          : null;
  }

  static Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
    // CRITICAL: We DO NOT delete the device_id here.
    // This allows guest tasks to persist for this device.
  }

  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
