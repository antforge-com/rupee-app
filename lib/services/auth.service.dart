// lib/core/services/auth_service.dart
// ════════════════════════════════════════════════════════════════════════════
// Swagger spec ke exact endpoints:
//   POST /api/users/authenticate        → login
//   POST /api/users/send-otp            → OTP bhejo (registration se pehle)
//   POST /api/users/forgot-password     → forgot password OTP
//   POST /api/users/reset-password      → OTP se password reset
//   PUT  /api/users/change-password     → logged-in user password change
//
// Registration ke liye OnboardingService.register() use karo
// ════════════════════════════════════════════════════════════════════════════

import 'package:finadvise/api_client.dart';

// ─── Response Models ─────────────────────────────────────────────────────────

class AuthResult {
  final bool success;
  final String? token;
  final int? userId;
  final String? identifier;
  final String? role;
  final int? consultantId;
  final bool requiresPasswordChange;
  final String? error;

  const AuthResult({
    required this.success,
    this.token,
    this.userId,
    this.identifier,
    this.role,
    this.consultantId,
    this.requiresPasswordChange = false,
    this.error,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
        success: true,
        token: json['token'] as String?,
        userId: (json['userId'] as num?)?.toInt(),
        identifier: json['identifier'] as String?,
        role: json['role'] as String?,
        consultantId: (json['consultantId'] as num?)?.toInt(),
        requiresPasswordChange: json['requiresPasswordChange'] as bool? ?? false,
      );

  factory AuthResult.failure(String message) =>
      AuthResult(success: false, error: message);
}

class OtpResult {
  final bool success;
  final String? message;
  final String? error;

  const OtpResult({required this.success, this.message, this.error});
}

// ─── Service ─────────────────────────────────────────────────────────────────

class AuthService {
  final ApiClient _apiClient = ApiClient();

  // ── LOGIN ─────────────────────────────────────────────────────────────────

  /// POST /api/users/authenticate
  /// body: { identifier, password }
  /// identifier = email ya phone number
  /// Returns AuthResult with JWT token + user info
  Future<AuthResult> login({
    required String identifier,
    required String password,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/users/authenticate',
        data: {
          'identifier': identifier.trim(),
          'password': password,
        },
      );
      return AuthResult.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      return AuthResult.failure(_extractError(e));
    }
  }

  // ── OTP (Registration se pehle) ───────────────────────────────────────────

  /// POST /api/users/send-otp
  /// body: { email, phoneNumber? }
  /// Registration shuru karne se pehle OTP bhejta hai
  Future<OtpResult> sendRegistrationOtp({
    required String email,
    String? phoneNumber,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/users/send-otp',
        data: {
          'email': email.trim(),
          if (phoneNumber != null && phoneNumber.isNotEmpty)
            'phoneNumber': phoneNumber.trim(),
        },
      );
      final msg = (response.data as Map<String, dynamic>?)?['message'] as String?;
      return OtpResult(success: true, message: msg ?? 'OTP bheja gaya');
    } catch (e) {
      return OtpResult(success: false, error: _extractError(e));
    }
  }

  // ── FORGOT PASSWORD ───────────────────────────────────────────────────────

  /// POST /api/users/forgot-password
  /// body: { email }
  /// Registered email pe password reset OTP bhejta hai
  Future<OtpResult> forgotPassword({required String email}) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/users/forgot-password',
        data: {'email': email.trim()},
      );
      final msg = (response.data as Map<String, dynamic>?)?['message'] as String?;
      return OtpResult(success: true, message: msg ?? 'OTP bheja gaya');
    } catch (e) {
      return OtpResult(success: false, error: _extractError(e));
    }
  }

  // ── RESET PASSWORD ────────────────────────────────────────────────────────

  /// POST /api/users/reset-password
  /// body: { email, otp, newPassword }
  /// OTP verify karke password reset karta hai
  Future<OtpResult> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/users/reset-password',
        data: {
          'email': email.trim(),
          'otp': otp.trim(),
          'newPassword': newPassword,
        },
      );
      final msg = (response.data as Map<String, dynamic>?)?['message'] as String?;
      return OtpResult(success: true, message: msg ?? 'Password reset ho gaya');
    } catch (e) {
      return OtpResult(success: false, error: _extractError(e));
    }
  }

  // ── CHANGE PASSWORD (logged-in user) ──────────────────────────────────────

  /// PUT /api/users/change-password
  /// body: { newPassword (min 8 chars), confirmPassword }
  /// Requires valid JWT — logged-in user ke liye
  Future<OtpResult> changePassword({
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      final response = await _apiClient.dio.put(
        '/api/users/change-password',
        data: {
          'newPassword': newPassword,
          'confirmPassword': confirmPassword,
        },
      );
      final msg = (response.data as Map<String, dynamic>?)?['message'] as String?;
      return OtpResult(success: true, message: msg ?? 'Password change ho gaya');
    } catch (e) {
      return OtpResult(success: false, error: _extractError(e));
    }
  }

  // ── ERROR HELPER ──────────────────────────────────────────────────────────

  String _extractError(dynamic e) {
    try {
      // Dio error → server message nikalo
      final dynamic response = (e as dynamic).response;
      if (response != null) {
        final data = response.data;
        if (data is Map) {
          return (data['message'] ?? data['error'] ?? 'Kuch gadbad ho gayi')
              .toString();
        }
      }
    } catch (_) {}
    return e.toString();
  }
}