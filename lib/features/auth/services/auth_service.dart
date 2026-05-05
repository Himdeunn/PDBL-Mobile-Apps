// lib/features/auth/services/auth_service.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/local_database.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/models/user.dart';
import '../../task/services/task_repository.dart';

class AuthService {
  final ApiClient _api = ApiClient();
  User? _cachedUser;

  /// Single in-flight background refresh future — prevents multiple pages
  /// from each triggering their own parallel background refresh.
  Future<void>? _backgroundRefreshFuture;

  /// Retrieves the current user. Uses in-memory cache first, then SecureStorage.
  /// If [forceRefresh] is true, it will wait for the API to return.
  /// Otherwise, it performs a background refresh if it's been a while.
  Future<User?> getCurrentUser({bool forceRefresh = false}) async {
    // 1. Check in-memory cache
    if (_cachedUser != null && !forceRefresh) {
      // If we have a user, trigger a background refresh just in case
      if (!_cachedUser!.isGuest) {
        _backgroundRefresh();
      }
      return _cachedUser;
    }

    // 2. Check SecureStorage if cache is empty
    _cachedUser ??= await SecureStorage.getUser();

    // 3. If force refresh or no user at all, fetch from API
    if (forceRefresh || (_cachedUser != null && !_cachedUser!.isGuest && _cachedUser!.loginAt == null)) {
      await refreshUser();
    } else if (_cachedUser != null && !_cachedUser!.isGuest) {
      // Just background sync if we have a basic user object
      _backgroundRefresh();
    }

    return _cachedUser;
  }

  /// Deduplicates background refresh: if one is already in-flight, reuses it.
  /// Only calls refreshUser() — the Dio interceptor handles token refresh
  /// automatically on 401, so we don't need a separate refreshToken() call here.
  void _backgroundRefresh() {
    if (_backgroundRefreshFuture != null) return;
    _backgroundRefreshFuture = refreshUser().whenComplete(() {
      _backgroundRefreshFuture = null;
    });
  }

  Future<void> refreshUser() async {
    try {
      final token = await SecureStorage.getToken();
      if (token == null || token.isEmpty) return;

      final response = await _api.get('user');
      final userData = response.data;
      if (userData != null && userData['id'] != null) {
        final existingUser = _cachedUser ?? User();
        existingUser.id = userData['id'] as int?;
        existingUser.name = userData['name'] as String? ?? existingUser.name;
        existingUser.email = userData['email'] as String? ?? existingUser.email;
        existingUser.avatar = userData['avatar_url'] as String? ?? existingUser.avatar;
        existingUser.avatarUrl = (userData['avatar_url'] as String?) ?? existingUser.avatarUrl;
        existingUser.todayTarget = (userData['today_target'] as num?)?.toInt() ?? existingUser.todayTarget;
        existingUser.emailVerifiedAt = userData['email_verified_at'] != null
            ? DateTime.tryParse(userData['email_verified_at'] as String)
            : null;
        existingUser.googleId = userData['google_id'] as String?;
        existingUser.isGuest = false;
        
        _cachedUser = existingUser;
        await SecureStorage.saveUser(existingUser);
        
        // Background sync-up FCM Token if logged in
        syncFcmToken();
      }
    } catch (e) {
      // Silently fail, could be network or session issues
    }
  }

  /// Synchronously returns the current cached user if available,
  /// otherwise returns null. Fast for UI initialization.
  User? get currentCachedUser => _cachedUser;

  /// Retrieves from local storage without network sync. Fast.
  Future<User?> getCachedUser() async {
    if (_cachedUser != null) return _cachedUser;
    _cachedUser = await SecureStorage.getUser();
    return _cachedUser;
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    // Ensure no stale session exists before registration
    await SecureStorage.clearAll();
    _cachedUser = null;

    final deviceId = await SecureStorage.getDeviceId();

    await _api.post(
      'register',
      data: {
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
        'device_id': deviceId,
      },
    );
    // Registration only creates the account — no token issued until email is verified.
  }

  Future<User?> login({required String email, required String password}) async {
    final deviceId = await SecureStorage.getDeviceId();
    final response = await _api.post(
      'login',
      data: {'email': email, 'password': password, 'device_id': deviceId},
    );

    return await _handleAuthSuccess(response.data);
  }

  Future<User> _handleAuthSuccess(Map<String, dynamic> data) async {
    final token = data['token'] as String?;
    final userData = data['user'] as Map<String, dynamic>?;

    // Detect if we were previously in Guest Mode to trigger migration
    final wasGuest = _cachedUser?.isGuest ?? (await SecureStorage.getUser())?.isGuest ?? false;

    final user = User()
      ..id = userData?['id'] as int?
      ..name = userData?['name'] as String? ?? ''
      ..email = userData?['email'] as String? ?? ''
      ..avatar = userData?['avatar_url'] as String?
      ..avatarUrl = userData?['avatar_url'] as String?
      ..googleId = userData?['google_id'] as String?
      ..emailVerifiedAt = userData?['email_verified_at'] != null
          ? DateTime.tryParse(userData!['email_verified_at'] as String)
          : null
      ..isGuest = false
      ..loginAt = DateTime.now();

    // Save token first so migration sync can use it
    if (token == null || token.isEmpty) {
      throw Exception('Failed to obtain access session from server. (Token is empty)');
    }
    
    await SecureStorage.saveToken(token);
    
    _cachedUser = user;
    await SecureStorage.saveUser(user);

    // Sync FCM Token with the backend
    await syncFcmToken();
    
    // Check if we need to sync local tasks to server
    if (wasGuest && user.email != null) {
      try {
        final taskRepo = TaskRepository();
        await taskRepo.migrateGuestTasksToUser(user.email!);
      } catch (e) {
        // Migration failed
      }
    }

    return user;
  }

  Future<User> enterGuestMode() async {
    final user = User()
      ..name = 'Guest'
      ..email = null
      ..isGuest = true
      ..loginAt = DateTime.now();

    _cachedUser = user;
    await SecureStorage.saveUser(user);
    return user;
  }

  Future<void> logout() async {
    await SecureStorage.clearAll();
    try {
      await GoogleSignIn().signOut();
    } catch (_) {
      // Ignore if google sign in fails or was not used
    }
  }

  Future<bool> isLoggedIn() async {
    // Use cached user if possible to speed this up significantly
    final user = _cachedUser ?? await getCachedUser();
    if (user == null) return false;
    if (user.isGuest) return true;
    if (user.loginAt == null) return false;

    final token = await SecureStorage.getToken();
    if (token == null || token.isEmpty) return false;

    final now = DateTime.now();
    final difference = now.difference(user.loginAt!);

    if (difference.inDays >= 14) {
      // Proactive refresh — well before the 21-day TTL expires.
      // With JWT_REFRESH_IAT=true, each successful refresh resets the window.
      try {
        await refreshToken();
        return true;
      } catch (_) {
        if (difference.inDays >= 21) {
          await logout();
          return false;
        }
        // Token still valid (< 21 days), just couldn't refresh — continue
      }
    }
    
    return true;
  }

  Future<bool> isGuest() async {
    final user = await getCurrentUser();
    return user?.isGuest ?? true;
  }

  /// Refresh the current token with a new one from the server.
  /// Throws on failure so callers (e.g. isLoggedIn) can react.
  Future<void> refreshToken() async {
    final response = await _api.post('refresh');
    final newToken = response.data['token'] as String?;
    if (newToken != null && newToken.isNotEmpty) {
      await SecureStorage.saveToken(newToken);
      
      // Update loginAt to reset the day counter
      if (_cachedUser != null) {
        _cachedUser!.loginAt = DateTime.now();
        await SecureStorage.saveUser(_cachedUser!);
      }
    }
  }

  /// Syncs the FCM token for the currently authenticated user with deduplication.
  Future<void> syncFcmToken({String? fcmToken}) async {
    try {
      final user = _cachedUser;
      if (user == null || user.isGuest) return;

      final token = fcmToken ?? await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      // Deduplication check
      final lastToken = await SecureStorage.getLastFcmToken();
      final lastSync = await SecureStorage.getLastFcmSyncTime();
      final now = DateTime.now();

      if (token == lastToken && lastSync != null && now.difference(lastSync).inHours < 4) {
        // Already synced recently with the same token
        return;
      }

      final response = await _api.post('auth/register-fcm-token', data: {'token': token});
      if (response.statusCode == 200) {
        await SecureStorage.saveLastFcmToken(token);
        await SecureStorage.saveLastFcmSyncTime(now);
      }
    } catch (e) {
      // Failed to sync, will retry on next check
    }
  }

  /// Manually updates the in-memory cache and SecureStorage with a new user object.
  /// Useful for immediate UI updates after profile changes.
  Future<void> updateUserCache(User user) async {
    _cachedUser = user;
    await SecureStorage.saveUser(user);
  }
  /// True if the last googleLogin call converted a regular account to Google-only.
  bool _lastGoogleLoginConverted = false;
  bool get lastGoogleLoginConverted => _lastGoogleLoginConverted;

  Future<User?> googleLogin({
    required String googleId,
    required String email,
    required String name,
    String? avatarUrl,
  }) async {
    final deviceId = await SecureStorage.getDeviceId();
    final response = await _api.post(
      'auth/google',
      data: {
        'google_id': googleId,
        'email': email,
        'name': name,
        'avatar_url': avatarUrl,
        'device_id': deviceId,
      },
    );
    _lastGoogleLoginConverted = response.data['account_converted'] == true;
    return await _handleAuthSuccess(response.data);
  }

  Future<void> verifyEmail(String email, String otp) async {
    final response = await _api.post(
      'auth/verify-email',
      data: {'email': email, 'otp': otp},
    );
    await _handleAuthSuccess(response.data);
  }

  Future<void> resendVerification(String email) async {
    await _api.post('auth/resend-verification', data: {'email': email});
  }

  /// Returns response data including `retry_after` seconds.
  Future<Map<String, dynamic>> resendVerificationWithCooldown(String email) async {
    final response = await _api.post('auth/resend-verification', data: {'email': email});
    return response.data as Map<String, dynamic>;
  }

  Future<void> forgotPassword(String email) async {
    await _api.post('auth/forgot-password', data: {'email': email});
  }

  Future<void> verifyOtp(String email, String otp) async {
    await _api.post('auth/verify-otp', data: {'email': email, 'otp': otp});
  }

  Future<void> resetPassword({
    required String email,
    required String otp,
    required String password,
  }) async {
    await _api.post('auth/reset-password', data: {
      'email': email,
      'otp': otp,
      'password': password,
      'password_confirmation': password,
    });
  }

  /// Clears the in-memory cache.
  void clearUserCache() {
    _cachedUser = null;
  }
}
