import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dio/dio.dart';
import '../storage/secure_storage.dart';

class ApiClient {
  static String get baseUrl => dotenv.env['API_URL'] ?? 'http://localhost/api';
  late final Dio dio;

  ApiClient() {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(_AuthInterceptor());
  }

  Future<Response> get(String path) => dio.get(path);

  Future<Response> post(String path, {dynamic data}) =>
      dio.post(path, data: data);
}

class _AuthInterceptor extends Interceptor {
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // 1. Always attach device ID
    final deviceId = await SecureStorage.getDeviceId();
    options.headers['X-Device-ID'] = deviceId;

    // 2. Attach auth token if available
    final token = await SecureStorage.getToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    return handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // If the error is 401 Unauthorized, we could trigger a refresh flow here if needed
    // or log the user out directly depending on the backend implementation
    if (err.response?.statusCode == 401) {
      SecureStorage.logout();
      // Optionally emit a session expired event to UI
    }
    return handler.next(err);
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  factory ApiException.fromDioError(DioException error) {
    String message = 'An unexpected error occurred. Please try again.';
    int? statusCode = error.response?.statusCode;

    // 1. Try to get message from server response first
    if (error.response?.data is Map<String, dynamic>) {
      final msg = error.response?.data['message'];
      if (msg != null) return ApiException(msg.toString(), statusCode);
    }

    // 2. Map DioException types to user-friendly messages
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        message =
            'Connection timed out. Please check your internet and try again.';
        break;
      case DioExceptionType.badResponse:
        if (statusCode != null) {
          if (statusCode >= 500) {
            message =
                'The server is currently unavailable. Please try again later.';
          } else if (statusCode == 404) {
            message = 'The requested resource was not found.';
          } else if (statusCode == 403) {
            message = 'You do not have permission to perform this action.';
          } else if (statusCode == 401) {
            message = 'Your session has expired. Please log in again.';
          } else {
            message =
                'Something went wrong with your request. Please try again.';
          }
        }
        break;
      case DioExceptionType.cancel:
        message = 'The request was cancelled.';
        break;
      case DioExceptionType.connectionError:
        message =
            'Cannot connect to the server. Please check your internet connection.';
        break;
      case DioExceptionType.badCertificate:
        message = 'An insecure connection was detected. Please try again.';
        break;
      default:
        // Handle specific technical messages like "Failed host lookup" even in 'unknown' type
        final technicalMsg = error.message?.toLowerCase() ?? '';
        if (technicalMsg.contains('failed host lookup') ||
            technicalMsg.contains('socketexception')) {
          message =
              'Cannot connect to the server. Please check your internet connection.';
        }
    }

    return ApiException(message, statusCode);
  }

  @override
  String toString() => message;
}
