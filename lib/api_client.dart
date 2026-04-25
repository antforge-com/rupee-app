// lib/core/api/api_client.dart
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://52.55.178.31:8081',
  );

  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Callback for global 401 handling (set from main.dart)
  Function()? onUnauthorized;

  static String _stripTrailingSlashes(String value) =>
      value.replaceAll(RegExp(r'/+$'), '');

  static String _normalizeBaseUrl(String raw) {
    final candidate = _stripTrailingSlashes(raw.trim());
    if (candidate.isEmpty) return baseUrl;

    try {
      final parsed = Uri.parse(candidate);
      final origin = parsed.origin;
      final path = _stripTrailingSlashes(parsed.path);

      // Match web's resolveApiBaseUrl behavior: allow inputs like:
      //   http://host:port
      //   http://host:port/api
      //   http://host:port/swagger-ui/index.html
      //   http://host:port/v3/api-docs
      if (path.isEmpty || path == '/') return origin;
      if (RegExp(r'/swagger-ui(?:/|$)', caseSensitive: false).hasMatch(path)) {
        return origin;
      }
      if (RegExp(r'/v3/api-docs(?:/|$)', caseSensitive: false).hasMatch(path)) {
        return origin;
      }
      if (path.toLowerCase().endsWith('/api')) {
        final withoutApi = path.substring(0, path.length - 4);
        return withoutApi.isEmpty ? origin : '$origin$withoutApi';
      }

      return '$origin$path';
    } catch (_) {
      return baseUrl;
    }
  }

  static String get normalizedBaseUrl => _normalizeBaseUrl(baseUrl);

  static String get apiOrigin {
    try {
      return Uri.parse(normalizedBaseUrl).origin;
    } catch (_) {
      return normalizedBaseUrl;
    }
  }

  /// Mirrors web `buildBackendAssetUrl`: converts a backend-returned path into a usable URL.
  /// - If `path` is already absolute (http/https/blob/data), returns it as-is.
  /// - Otherwise prefixes with the API origin (no forced `/api`).
  static String buildBackendAssetUrl(String? path) {
    if (path == null) return '';
    final p = path.trim();
    if (p.isEmpty) return '';
    if (RegExp(r'^(?:https?:|blob:|data:)', caseSensitive: false).hasMatch(p)) {
      return p;
    }
    final normalizedPath = p.startsWith('/') ? p : '/$p';
    return '$apiOrigin$normalizedPath';
  }

  ApiClient._internal() {
    dio = Dio(BaseOptions(
      baseUrl: normalizedBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: {
        // Keep this flexible so multipart requests can set their own boundary/content type.
        'Accept': 'application/json',
      },
    ));

    // ── Request Interceptor: inject JWT ──
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Prefer SharedPreferences (used by AuthService) but fallback to FlutterSecureStorage (legacy)
        final prefs = await SharedPreferences.getInstance();
        String? token = prefs.getString('fin_token');
        
        if (token == null || token.isEmpty) {
          token = await _storage.read(key: 'jwt_token') ??
              await _storage.read(key: 'fin_token');
        }

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
