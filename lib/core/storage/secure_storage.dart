import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/user.dart';

class SecureStorage {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: false),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';
  static const _deviceKey = 'device_id';
  static const _lastFcmTokenKey = 'last_fcm_token';
  static const _lastFcmSyncTimeKey = 'last_fcm_sync_time';

  static Future<String> getDeviceId() async {
    try {
      final curId = await _storage.read(key: _deviceKey);
      if (curId != null && curId.isNotEmpty) {
        return curId;
      }
    } catch (_) {}
    final uuid = const Uuid().v4();
    try {
      await _storage.write(key: _deviceKey, value: uuid);
    } catch (_) {}
    return uuid;
  }

  static Future<void> saveToken(String token) async {
    try {
      await _storage.write(key: _tokenKey, value: token);
    } catch (_) {}
  }

  static Future<String?> getToken() async {
    try {
      return await _storage.read(key: _tokenKey);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveUser(User user) async {
    final Map<String, dynamic> json = {
      'id': user.id,
      'name': user.name,
      'email': user.email,
      'avatar': user.avatar,
      'avatar_url': user.avatarUrl,
      'isGuest': user.isGuest,
      'today_target': user.todayTarget,
      'loginAt': user.loginAt?.toIso8601String(),
    };
    try {
      await _storage.write(key: _userKey, value: jsonEncode(json));
    } catch (_) {}
  }

  static Future<User?> getUser() async {
    try {
      final userStr = await _storage.read(key: _userKey);
      if (userStr == null) return null;

      final map = jsonDecode(userStr) as Map<String, dynamic>;
      return User()
        ..id = map['id'] as int?
        ..name = map['name'] as String?
        ..email = map['email'] as String?
        ..avatar = map['avatar'] as String?
        ..avatarUrl = (map['avatar_url'] ?? map['avatar']) as String?
        ..isGuest = (map['isGuest'] as bool?) ?? false
        ..todayTarget = (map['today_target'] as num?)?.toInt() ?? 0
        ..loginAt = map['loginAt'] != null
            ? DateTime.tryParse(map['loginAt'] as String)
            : null;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> getEmail() async {
    final user = await getUser();
    return user?.email;
  }

  static Future<void> logout() async {
    try {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _userKey);
      await _storage.delete(key: _lastFcmTokenKey);
      await _storage.delete(key: _lastFcmSyncTimeKey);
      // CRITICAL: We DO NOT delete the device_id here.
      // This allows guest tasks to persist for this device.
    } catch (_) {}
  }

  static Future<void> saveLastFcmToken(String? token) async {
    try {
      if (token == null) {
        await _storage.delete(key: _lastFcmTokenKey);
      } else {
        await _storage.write(key: _lastFcmTokenKey, value: token);
      }
    } catch (_) {}
  }

  static Future<String?> getLastFcmToken() async {
    try {
      return await _storage.read(key: _lastFcmTokenKey);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveLastFcmSyncTime(DateTime time) async {
    try {
      await _storage.write(key: _lastFcmSyncTimeKey, value: time.toIso8601String());
    } catch (_) {}
  }

  static Future<DateTime?> getLastFcmSyncTime() async {
    try {
      final str = await _storage.read(key: _lastFcmSyncTimeKey);
      return str != null ? DateTime.tryParse(str) : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
    } catch (_) {}
  }
}
