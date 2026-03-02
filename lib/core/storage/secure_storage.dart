import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/models/user.dart';

class SecureStorage {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  static Future<void> saveUser(User user) async {
    final Map<String, dynamic> json = {
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
      ..name = map['name']
      ..email = map['email']
      ..isGuest = map['isGuest'] ?? false
      ..loginAt = map['loginAt'] != null ? DateTime.parse(map['loginAt']) : null;
  }

  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
