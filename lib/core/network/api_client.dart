import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dio/dio.dart';
import '../storage/secure_storage.dart';

class ApiClient {
  static String get baseUrl => dotenv.env['API_URL'] ?? 'http://localhost/api';
  late final Dio dio;

  ApiClient() {
    dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    dio.interceptors.add(_AuthInterceptor());
  }

  Future<Response> get(String path) => dio.get(path);
  
  Future<Response> post(String path, {dynamic data}) => dio.post(path, data: data);
}

class _AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
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
      SecureStorage.clearAll();
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
    if (error.response?.data is Map<String, dynamic>) {
      final msg = error.response?.data['message'];
      if (msg != null) return ApiException(msg.toString(), error.response?.statusCode);
    }
    return ApiException(error.message ?? 'Unknown error occurred', error.response?.statusCode);
  }

  @override
  String toString() => message;
}
