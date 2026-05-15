import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/utils/error_handler.dart';
import '../../auth/services/auth_service.dart';

class ProfileService {
  final ApiClient _api = ApiClient();
  final AuthService? _authService;

  ProfileService({AuthService? authService}) : _authService = authService;

  Future<String?> updateAvatar(String filePath, {String? oldAvatarUrl}) async {
    try {
      final filename = filePath.split(Platform.pathSeparator).last;
      final extension = filename.split('.').last.toLowerCase();
      final contentType = switch (extension) {
        'png' => MediaType('image', 'png'),
        'gif' => MediaType('image', 'gif'),
        _ => MediaType('image', 'jpeg'),
      };

      final formData = FormData.fromMap({
        'avatar': await MultipartFile.fromFile(
          filePath,
          filename: filename,
          contentType: contentType,
        ),
        if (oldAvatarUrl != null && oldAvatarUrl.isNotEmpty)
          'old_avatar': oldAvatarUrl,
      });

      final response = await _api.post('profile/avatar', data: formData);

      if (response.statusCode == 200) {
        final avatarUrl = response.data['avatar_url'] as String?;
        if (avatarUrl == null || avatarUrl.isEmpty) {
          throw Exception(
            'Avatar upload succeeded but no avatar URL was returned.',
          );
        }

        final currentUser = await SecureStorage.getUser();
        if (currentUser != null) {
          currentUser.avatar = avatarUrl;
          currentUser.avatarUrl = avatarUrl;
          await SecureStorage.saveUser(currentUser);
          if (_authService != null) {
            await _authService.updateUserCache(currentUser);
          }
        }
        return avatarUrl;
      }

      return null;
    } catch (e) {
      if (e is DioException) {
        final statusCode = e.response?.statusCode;
        final data = e.response?.data;
        final message = data is Map
            ? data['message']?.toString().toLowerCase() ?? ''
            : '';
        final errors = data is Map ? data['errors'] : null;
        final avatarErrors = errors is Map
            ? errors['avatar']?.toString().toLowerCase() ?? ''
            : '';

        if (statusCode == 413 ||
            message.contains('too large') ||
            message.contains('maximum') ||
            avatarErrors.contains('too large') ||
            avatarErrors.contains('greater than')) {
          ErrorHandler.showErrorPopup(
            'The file is too large. Please use a smaller image.',
            title: 'File Too Large',
          );
          rethrow;
        }
      }
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
      final response = await _api.post('profile/update', data: {'name': name});

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
