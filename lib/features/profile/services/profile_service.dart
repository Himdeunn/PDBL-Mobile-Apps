import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';

class ProfileService {
  final ApiClient _api = ApiClient();

  Future<void> updateAvatar(String filePath) async {
    try {
      final formData = FormData.fromMap({
        'avatar': await MultipartFile.fromFile(filePath),
      });

      final response = await _api.post('/profile/avatar', data: formData);

      if (response.statusCode == 200) {
        final userData = response.data['user'] as Map<String, dynamic>?;
        if (userData != null) {
          final currentUser = await SecureStorage.getUser();
          if (currentUser != null) {
            // Updated user model would include avatar URL if stored there
            // For now let's just refresh local user info if needed
            // SecureStorage.saveUser(currentUser);
          }
        }
      }
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    try {
      await _api.post(
        '/profile/password',
        data: {
          'current_password': currentPassword,
          'password': newPassword,
          'password_confirmation': newPasswordConfirmation,
        },
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> updateEmail({
    required String email,
    required String currentPassword,
  }) async {
    try {
      final response = await _api.post(
        '/profile/email',
        data: {'email': email, 'current_password': currentPassword},
      );

      if (response.statusCode == 200) {
        final userData = response.data['user'];
        final currentUser = await SecureStorage.getUser();
        if (currentUser != null) {
          currentUser.email = userData['email'];
          await SecureStorage.saveUser(currentUser);
        }
      }
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> updateProfile({required String name}) async {
    try {
      final response = await _api.post(
        '/profile/update',
        data: {'name': name},
      );

      if (response.statusCode == 200) {
        final userData = response.data['user'];
        final currentUser = await SecureStorage.getUser();
        if (currentUser != null) {
          currentUser.name = userData['name'];
          await SecureStorage.saveUser(currentUser);
        }
      }
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}

