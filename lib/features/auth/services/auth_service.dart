import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/local_database.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../../core/models/user.dart';

class AuthService {
  final ApiClient _api = ApiClient();

  Future<User?> getCurrentUser() async {
    final user = await SecureStorage.getUser();
    if (user != null && user.id == null && !user.isGuest) {
      try {
        final response = await _api.get('/user');
        final userData = response.data;
        if (userData != null && userData['id'] != null) {
          user.id = userData['id'] as int?;
          await SecureStorage.saveUser(user);
        }
      } catch (e) {
        // Silently fail, might be offline or session expired
      }
    }
    return user;
  }

  Future<User> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      final deviceId = await SecureStorage.getDeviceId();
      final response = await _api.post(
        '/register',
        data: {
          'name': name,
          'email': email,
          'password': password,
          'password_confirmation': passwordConfirmation,
          'device_id': deviceId,
        },
      );

      return _handleAuthSuccess(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<User> login({required String email, required String password}) async {
    try {
      final deviceId = await SecureStorage.getDeviceId();
      final response = await _api.post(
        '/login',
        data: {'email': email, 'password': password, 'device_id': deviceId},
      );

      return _handleAuthSuccess(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<User> _handleAuthSuccess(Map<String, dynamic> data) async {
    final token = data['token'] as String?;
    final userData = data['user'] as Map<String, dynamic>?;

    final user = User()
      ..id = userData?['id'] as int?
      ..name = userData?['name'] as String? ?? ''
      ..email = userData?['email'] as String? ?? ''
      ..isGuest = false
      ..loginAt = DateTime.now();

    if (token != null) {
      await SecureStorage.saveToken(token);
    }
    await SecureStorage.saveUser(user);

    return user;
  }

  Future<User> enterGuestMode() async {
    final user = User()
      ..name = 'Guest'
      ..email = null
      ..isGuest = true
      ..loginAt = DateTime.now();

    await SecureStorage.saveUser(user);
    return user;
  }

  Future<void> logout() async {
    try {
      // API expects the token to log out. The AuthInterceptor handles attaching it.
      await _api.post('/logout');
    } catch (_) {
      // Ignore network errors on logout
    } finally {
      await LocalDatabase.clearAll();
      await SecureStorage.logout();
    }
  }

  Future<bool> isLoggedIn() async {
    final user = await getCurrentUser();
    if (user == null) return false;
    if (user.isGuest) return true;
    if (user.loginAt == null) return false;

    final token = await SecureStorage.getToken();
    if (token == null || token.isEmpty) return false;

    final now = DateTime.now();
    final difference = now.difference(user.loginAt!);

    if (difference.inDays >= 7) {
      await logout();
      return false;
    }
    return true;
  }
}
