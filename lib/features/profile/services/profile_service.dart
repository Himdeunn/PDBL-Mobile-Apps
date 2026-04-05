import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/utils/error_handler.dart';
import '../../auth/services/auth_service.dart';

class ProfileService {
  final ApiClient _api = ApiClient();
  final AuthService? _authService;

  ProfileService({AuthService? authService}) : _authService = authService;

  Future<void> updateAvatar(String filePath) async {
    try {
      final formData = FormData.fromMap({
        'avatar': await MultipartFile.fromFile(filePath),
      });

      final response = await _api.post('profile/avatar', data: formData);

      if (response.statusCode == 200) {
        final avatarUrl = response.data['avatar_url'] as String?;
        final currentUser = await SecureStorage.getUser();
        if (currentUser != null && avatarUrl != null) {
          currentUser.avatarUrl = avatarUrl;
          await SecureStorage.saveUser(currentUser);
          if (_authService != null) {
            await _authService.updateUserCache(currentUser);
          }
        }
      }
    } catch (e) {
      ErrorHandler.handleApiError(e);
      rethrow;
    }
  }

  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    try {
      await _api.post(
        'profile/password',
        data: {
          'current_password': currentPassword,
          'password': newPassword,
          'password_confirmation': newPasswordConfirmation,
        },
      );
    } catch (e) {
      ErrorHandler.handleApiError(e);
      rethrow;
    }
  }

  Future<void> updateEmail({
    required String email,
    required String currentPassword,
  }) async {
    try {
      final response = await _api.post(
        'profile/email',
        data: {'email': email, 'current_password': currentPassword},
      );

      if (response.statusCode == 200) {
        final userData = response.data['user'];
        final currentUser = await SecureStorage.getUser();
        if (currentUser != null) {
          currentUser.email = userData['email'];
          await SecureStorage.saveUser(currentUser);
          if (_authService != null) {
            await _authService.updateUserCache(currentUser);
          }
        }
      }
    } catch (e) {
      ErrorHandler.handleApiError(e);
      rethrow;
    }
  }

  Future<void> updateProfile({required String name}) async {
    try {
      final response = await _api.post(
        'profile/update',
        data: {'name': name},
      );

      if (response.statusCode == 200) {
        final userData = response.data['user'];
        final currentUser = await SecureStorage.getUser();
        if (currentUser != null) {
          currentUser.name = userData['name'];
          await SecureStorage.saveUser(currentUser);
          if (_authService != null) {
            await _authService.updateUserCache(currentUser);
          }
        }
      }
    } catch (e) {
      ErrorHandler.handleApiError(e);
      rethrow;
    }
  }
}
