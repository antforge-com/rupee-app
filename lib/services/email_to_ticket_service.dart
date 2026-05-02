import 'package:dio/dio.dart';
import 'package:finadvise/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmailToTicketActionResult {
  final bool ok;
  final String message;

  const EmailToTicketActionResult({
    required this.ok,
    required this.message,
  });
}

class EmailToTicketService {
  final ApiClient _apiClient = ApiClient();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// GET /api/email-to-ticket/health
  Future<EmailToTicketActionResult> getHealthStatus() async {
    Dio? dio;
    try {
      dio = await _buildDio(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
      );
      final response = await dio.get('/api/email-to-ticket/health');
      return EmailToTicketActionResult(
        ok: true,
        message: _messageFromData(
          response.data,
          fallback: 'Email-to-ticket service is running',
        ),
      );
    } catch (error) {
      return EmailToTicketActionResult(
        ok: false,
        message: _messageFromError(
          error,
          fallback: 'Unable to reach email-to-ticket health endpoint',
        ),
      );
    } finally {
      dio?.close(force: true);
    }
  }

  /// POST /api/email-to-ticket/poll
  Future<EmailToTicketActionResult> triggerPolling() async {
    Dio? dio;
    try {
      dio = await _buildDio(
        connectTimeout: const Duration(seconds: 45),
        receiveTimeout: const Duration(minutes: 2),
      );
      final response = await dio.post('/api/email-to-ticket/poll');
      return EmailToTicketActionResult(
        ok: true,
        message: _messageFromData(
          response.data,
          fallback: 'Email polling initiated successfully',
        ),
      );
    } catch (error) {
      return EmailToTicketActionResult(
        ok: false,
        message: _messageFromError(
          error,
          fallback: 'Email polling request failed',
        ),
      );
    } finally {
      dio?.close(force: true);
    }
  }

  Future<Dio> _buildDio({
    required Duration connectTimeout,
    required Duration receiveTimeout,
  }) async {
    final dio = Dio(
      BaseOptions(
        baseUrl: _apiClient.dio.options.baseUrl,
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
        sendTimeout: receiveTimeout,
        headers: {
          ..._apiClient.dio.options.headers,
          'Accept': 'application/json',
        },
      ),
    );

    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('fin_token');
    if (token == null || token.isEmpty) {
      token = await _storage.read(key: 'jwt_token') ??
          await _storage.read(key: 'fin_token');
    }
    if (token != null && token.isNotEmpty) {
      dio.options.headers['Authorization'] = 'Bearer $token';
    }
    return dio;
  }

  String _messageFromData(dynamic data, {required String fallback}) {
    if (data is Map) {
      final msg = data['message'] ?? data['status'] ?? data['detail'];
      if (msg != null && '$msg'.trim().isNotEmpty) {
        return '$msg'.trim();
      }
    }
    if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }
    final text = data?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _messageFromError(Object error, {required String fallback}) {
    if (error is DioException) {
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        return 'Email-to-ticket backend timed out. Check the mailbox service and server response time.';
      }
      final data = error.response?.data;
      final fromData = _messageFromData(data, fallback: '');
      if (fromData.isNotEmpty) {
        return fromData;
      }
      final message = error.message?.trim() ?? '';
      if (message.isNotEmpty) {
        return message;
      }
    }
    return fallback;
  }
}
