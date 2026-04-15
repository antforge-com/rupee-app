// lib/core/api/api_client.dart
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  static const String baseUrl = 'http://52.55.178.31:8081';

  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Callback for global 401 handling (set from main.dart)
  Function()? onUnauthorized;

  ApiClient._internal() {
    dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // ── Request Interceptor: inject JWT ──
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // FIXED: Changed 'fin_token' to 'jwt_token' to match the login_screen.dart storage key
        final token = await _storage.read(key: 'jwt_token');
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        return handler.next(response);
      },
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401) {
          onUnauthorized?.call();
        }
        return handler.next(e);
      },
    ));

    // ── Logging Interceptor (dev only) ──
    dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: false,
      logPrint: (o) => debugPrint(o.toString()),
    ));
  }

  // ignore: avoid_print
  void debugPrint(String msg) => print('[ApiClient] $msg');
}