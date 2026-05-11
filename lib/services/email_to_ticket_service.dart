import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:finadvise/api_client.dart';

class EmailToTicketActionResult {
  final bool ok;
  final String message;

  /// Raw response body from the health endpoint (null for non-health calls).
  final Map<String, dynamic>? rawData;

  const EmailToTicketActionResult({
    required this.ok,
    required this.message,
    this.rawData,
  });
}

class EmailToTicketService {
  final ApiClient _apiClient = ApiClient();

  /// GET /api/email-to-ticket/health
  ///
  /// The backend returns a PLAIN TEXT response ("Email-to-Ticket service is running"),
  /// NOT JSON. We use ResponseType.plain so Dio never tries to JSON-decode it,
  /// which previously caused a parse exception and made result.ok = false every time.
  Future<EmailToTicketActionResult> getHealthStatus() async {
    try {
      final response = await _apiClient.dio.get(
        '/api/email-to-ticket/health',
        options: Options(
          sendTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 30),
          // CRITICAL: plain text — do not JSON-decode the response
          responseType: ResponseType.plain,
          validateStatus: (s) => s != null && s >= 200 && s < 300,
        ),
      );

      final rawString = (response.data ?? '').toString().trim();

      // Try to parse as JSON in case the backend later returns a JSON body
      Map<String, dynamic>? raw;
      if (rawString.startsWith('{')) {
        try {
          raw = jsonDecode(rawString) as Map<String, dynamic>;
        } catch (_) {}
      }

      return EmailToTicketActionResult(
        ok: true,
        message: rawString.isNotEmpty
            ? rawString
            : 'Email-to-ticket service is running',
        rawData: raw,
      );
    } catch (error) {
      return EmailToTicketActionResult(
        ok: false,
        message: _messageFromError(
          error,
          fallback: 'Unable to reach email-to-ticket health endpoint',
        ),
      );
    }
  }

  /// POST /api/email-to-ticket/poll
  ///
  /// Backend returns plain text immediately ("Email polling initiated successfully
  /// in the background.") because the service is @Async. Use ResponseType.plain
  /// for the same reason as health — prevents Dio JSON-parse exception on plain text.
  Future<EmailToTicketActionResult> triggerPolling() async {
    try {
      final response = await _apiClient.dio.post(
        '/api/email-to-ticket/poll',
        options: Options(
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 90),
          // CRITICAL: plain text response from backend
          responseType: ResponseType.plain,
          validateStatus: (s) => s != null && s >= 200 && s < 300,
        ),
      );

      final rawString = (response.data ?? '').toString().trim();
      return EmailToTicketActionResult(
        ok: true,
        message: rawString.isNotEmpty
            ? rawString
            : 'Email polling initiated successfully',
      );
    } catch (error) {
      if (error is DioException) {
        final isTimeout = error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout ||
            error.type == DioExceptionType.sendTimeout;
        if (isTimeout) {
          // @Async poll: backend returns instantly, so a timeout here means
          // the server itself is unreachable, not that polling is slow.
          return const EmailToTicketActionResult(
            ok: false,
            message:
                'Email-to-ticket backend timed out. Check server connectivity.',
          );
        }
        // 403 = admin role required; show a clear message
        if (error.response?.statusCode == 403) {
          return const EmailToTicketActionResult(
            ok: false,
            message:
                'Poll Inbox requires admin privileges. Ensure your account has the ADMIN role.',
          );
        }
      }
      return EmailToTicketActionResult(
        ok: false,
        message: _messageFromError(
          error,
          fallback: 'Email polling request failed',
        ),
      );
    }
  }

  String _messageFromError(Object error, {required String fallback}) {
    if (error is DioException) {
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        return 'Request timed out. Check server connectivity.';
      }
      final status = error.response?.statusCode;
      if (status == 403) {
        return 'Access denied (403). Admin role required.';
      }
      if (status == 401) {
        return 'Unauthorized (401). Please log in again.';
      }
      final data = error.response?.data;
      if (data != null) {
        final s = data.toString().trim();
        if (s.isNotEmpty && s.length < 200) return s;
      }
      final msg = error.message?.trim() ?? '';
      if (msg.isNotEmpty) return msg;
    }
    return fallback;
  }
}