// lib/core/network/api_client.dart
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import '../storage/secure_storage.dart';
import '../utils/error_handler.dart';

class ApiClient {
  static String get baseUrl {
    var url = dotenv.env['API_URL'] ?? '';
    
    if (url.isEmpty) {
      // Return a dummy but valid looking URL to avoid crashes before env is loaded, 
      // but it will fail network calls predictably.
      return 'http://invalid-url-check-env-file/';
    }
    
    // 1. Ensure it has /api prefix
    if (!url.contains('/api')) {
      url = url.endsWith('/') ? '${url}api' : '$url/api';
    }

    // 2. Ensure it EXACTLY ends with /api/ (with trailing slash)
    // Dio joins baseUrl + path. If baseUrl is .../api and path is user, result is .../apiuser (ERROR 404)
    if (!url.endsWith('/')) {
      url = '$url/';
    }

    // 3. Adaptive Security & Environment
    final bool isLocal = url.contains('localhost') || url.contains('10.0.2.2') || url.contains('127.0.0.1');
    if (!isLocal && !url.startsWith('https://')) {
      url = url.replaceFirst('http://', 'https://');
    }

    return url;
  }

  late Dio _dio;
  Dio get dio => _dio;

  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(_RetryInterceptor(_dio));
    _dio.interceptors.add(_AuthInterceptor());
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    return await _dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(String path, {dynamic data, Options? options}) async {
    return await _dio.post(path, data: data, options: options);
  }

  Future<Response> put(String path, {dynamic data}) async {
    return await _dio.put(path, data: data);
  }

  Future<Response> delete(String path) async {
    return await _dio.delete(path);
  }
}

class _AuthInterceptor extends Interceptor {
  /// Completer-based mutex: the FIRST 401 triggers a refresh, all others
  /// await the same Completer. When refresh completes (success or failure),
  /// every waiter gets the result simultaneously — no duplicate refresh calls.
  static Completer<String?>? _refreshCompleter;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final deviceId = await SecureStorage.getDeviceId();
      options.headers['X-Device-ID'] = deviceId;

      final timezone = await FlutterTimezone.getLocalTimezone();
      options.headers['X-Timezone'] = timezone;
    } catch (_) {}

    final token = await SecureStorage.getToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer ${token.trim()}';
    }
    return handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final statusCode = err.response?.statusCode;
    final path = err.requestOptions.path;

    // Handle 401 Unauthorized
    if (statusCode == 401) {
      // If we're already trying to refresh/login/register, just logout
      if (path == 'refresh' || path == 'login' || path == 'register') {
        return _handleLogout(err, handler);
      }

      try {
        String? newTokenValue;

        if (_refreshCompleter != null) {
          // Another request already started refresh — just wait for it
          newTokenValue = await _refreshCompleter!.future;
        } else {
          // We are the first — create a Completer and run refresh
          final completer = Completer<String?>();
          _refreshCompleter = completer;

          try {
            newTokenValue = await _performRefresh();
            completer.complete(newTokenValue);
          } catch (e) {
            ErrorHandler.handleApiError(e);
            completer.completeError(e);
            rethrow;
          } finally {
            _refreshCompleter = null;
          }
        }

        // Refresh succeeded — retry original request with the new token
        if (newTokenValue != null && newTokenValue.isNotEmpty) {
          final options = err.requestOptions;
          options.headers['Authorization'] = 'Bearer ${newTokenValue.trim()}';
          options.headers['Accept'] = 'application/json';
          options.headers['Content-Type'] = 'application/json';

          // Use a fresh Dio instance to avoid interceptor recursion/loops
          final retryDio = Dio(BaseOptions(
            baseUrl: ApiClient.baseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
          ));
          
          try {
            final response = await retryDio.fetch(options);
            
            // Verify status code of retried request
            if (response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300) {
              return handler.resolve(response);
            } else {
              // Re-reject with the same error but updated response if needed
              return handler.reject(DioException(
                requestOptions: options,
                response: response,
                type: DioExceptionType.badResponse,
                error: 'Request failed after token refresh',
              ));
            }
          } catch (e) {
             // If the retry itself throws (e.g. network error), reject original
             return handler.reject(DioException(
                requestOptions: options,
                error: e,
                type: DioExceptionType.unknown,
             ));
          }
        }
      } catch (e) {
        // Refresh failed — logout
        return _handleLogout(err, handler);
      }
    }

    return handler.next(err);
  }

  Future<String?> _performRefresh() async {
    final token = await SecureStorage.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('No token available to refresh');
    }

    try {
      final dio = Dio(BaseOptions(
        baseUrl: ApiClient.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer ${token.trim()}',
        },
      ));

      final response = await dio.post('refresh');
      final newToken = response.data['token'] as String?;

      if (newToken != null && newToken.isNotEmpty) {
        final tokenStr = newToken.trim();
        await SecureStorage.saveToken(tokenStr);

        final user = await SecureStorage.getUser();
        if (user != null) {
          user.loginAt = DateTime.now();
          await SecureStorage.saveUser(user);
        }

        return tokenStr;
      } else {
        throw Exception('Server returned empty refresh token');
      }
    } catch (e) {
      rethrow;
    }
  }

  void _handleLogout(DioException err, ErrorInterceptorHandler handler) {
    final isRefreshError = err.requestOptions.path == 'refresh';
    final is401 = err.response?.statusCode == 401;

    // Only force logout if the REFRESH call itself failed with 401
    if (isRefreshError && is401) {
      SecureStorage.logout();
      ErrorHandler.showErrorPopup('Your session has expired. Please log in again.');
    }

    handler.reject(err);
  }
}

class _RetryInterceptor extends Interceptor {
  final Dio dio;
  final int maxRetries = 3;
  final List<int> retryStatusCodes = [
    408, // Request Timeout
    502, // Bad Gateway
    503, // Service Unavailable
    504, // Gateway Timeout
  ];

  _RetryInterceptor(this.dio);

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final path = options.path;

    // Logic: Retrieve the current retry count
    int retryCount = 0;
    if (options.extra.containsKey('retry_count')) {
      retryCount = options.extra['retry_count'] as int;
    }

    // Only retry if:
    // 1. It's a network error OR a retryable status code
    // 2. We haven't exceeded max retries
    // 3. It's NOT a login/refresh request (to avoid duplication or infinite loops)
    final isTimeout = err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError;

    final isRetryableStatus = err.response != null && retryStatusCodes.contains(err.response!.statusCode);
    final isNotCriticalPath = !path.contains('login') && !path.contains('refresh') && !path.contains('register');

    if ((isTimeout || isRetryableStatus) && retryCount < maxRetries && isNotCriticalPath) {
      retryCount++;
      options.extra['retry_count'] = retryCount;

      // Exponential backoff: 1s, 2s, 4s...
      final delaySeconds = 1 << (retryCount - 1);
      await Future.delayed(Duration(seconds: delaySeconds));

      try {
        final response = await dio.fetch(options);
        
        // Verify status code of retried request
        if (response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300) {
          return handler.resolve(response);
        } else {
          return handler.reject(DioException(
            requestOptions: options,
            response: response,
            type: DioExceptionType.badResponse,
            error: response.statusMessage,
          ));
        }
      } catch (e) {
        // If the retry itself fails, the error will bubble back into this interceptor 
        // with the updated 'retry_count' in 'options.extra'.
        return super.onError(err, handler);
      }
    }

    return super.onError(err, handler);
  }
}
