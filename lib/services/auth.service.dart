// lib/core/services/auth_service.dart
// ════════════════════════════════════════════════════════════════════════════
// Matches api.ts exactly:
//   POST /api/users/authenticate        → login (clears token first)
//   POST /api/users/send-otp            → sendRegistrationOtp
//   POST /api/users/check-otp           → checkOtp (validates without consuming)
//   POST /api/users/forgot-password     → forgotPassword
//   POST /api/users/reset-password      → resetPassword
//   PUT  /api/users/change-password     → changePassword
//   Role normalization: strips ROLE_ prefix, maps ADVISOR → CONSULTANT
//   requiresPasswordChange detection + local flag management
// ════════════════════════════════════════════════════════════════════════════

import 'package:finadvise/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

// ─── Key constants (match web's localStorage keys) ──────────────────────────
const _kToken = 'fin_token';
const _kRole = 'fin_role';
const _kUserId = 'fin_user_id';
const _kConsultantId = 'fin_consultant_id';
const _kRequiresPwChange = 'fin_requires_pw_change';

String _normalizeRole(dynamic rawRole) {
  final normalized = (rawRole ?? 'USER')
      .toString()
      .toUpperCase()
      .replaceFirst(RegExp(r'^ROLE_'), '');
  if (normalized == 'ADVISOR' || normalized == 'AGENT') return 'CONSULTANT';
  return normalized;
}

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

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    // Robustly extract role from any response shape (matches web logic)
    String rawRole = '';
    if (json['role'] is String && (json['role'] as String).isNotEmpty) {
      rawRole = json['role'];
    } else if (json['userRole'] is String) {
      rawRole = json['userRole'];
    } else if (json['roles'] is List && (json['roles'] as List).isNotEmpty) {
      final r = (json['roles'] as List)[0];
      rawRole = r is String ? r : (r['authority'] ?? r['name'] ?? '');
    } else if (json['authorities'] is List &&
        (json['authorities'] as List).isNotEmpty) {
      final a = (json['authorities'] as List)[0];
      rawRole = a is String ? a : (a['authority'] ?? a['name'] ?? '');
    }

    // Extract userId from multiple possible keys
    final userId = (json['userId'] ?? json['id'] ?? json['user_id'] as num?)
        ?.toInt();

    return AuthResult(
      success: true,
      token: json['token'] ?? json['accessToken'] ?? json['access_token'] ?? json['jwt'],
      userId: userId,
      identifier: json['identifier'] as String?,
      role: _normalizeRole(rawRole.isNotEmpty ? rawRole : 'GUEST'),
      consultantId: (json['consultantId'] as num?)?.toInt(),
      requiresPasswordChange: json['requiresPasswordChange'] as bool? ?? false,
    );
  }

  factory AuthResult.failure(String message) =>
      AuthResult(success: false, error: message);
}

class OtpResult {
  final bool success;
  final String? message;
  final String? error;

  const OtpResult({required this.success, this.message, this.error});
}

class PasswordChangeResult {
  final bool success;
  final String? error;
  const PasswordChangeResult({required this.success, this.error});
}

// ─── Service ─────────────────────────────────────────────────────────────────

class AuthService {
  final ApiClient _apiClient = ApiClient();

  // ── TOKEN/SESSION HELPERS ─────────────────────────────────────────────────

  Future<void> persistSession(AuthResult result) async {
    final prefs = await SharedPreferences.getInstance();
    if (result.token != null) await prefs.setString(_kToken, result.token!);
    if (result.role != null) await prefs.setString(_kRole, result.role!);
    if (result.userId != null) {
      await prefs.setString(_kUserId, result.userId.toString());
    }
    if (result.consultantId != null) {
      await prefs.setString(_kConsultantId, result.consultantId.toString());
    }
    if (result.requiresPasswordChange) {
      await prefs.setBool(_kRequiresPwChange, true);
    } else {
      await prefs.remove(_kRequiresPwChange);
    }
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kToken);
    return token != null && token.isNotEmpty;
  }

  Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kRole);
  }

  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kUserId);
  }

  Future<String?> getConsultantId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kConsultantId);
  }

  Future<bool> requiresPasswordChange() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kRequiresPwChange) ?? false;
  }

  Future<void> clearRequiresPasswordChange() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRequiresPwChange);
    // Also mark as done per-user (matches web's fin_pw_changed_{uid})
    final uid = prefs.getString(_kUserId);
    if (uid != null) await prefs.setBool('fin_pw_changed_$uid', true);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kRole);
    await prefs.remove(_kUserId);
    await prefs.remove(_kConsultantId);
    await prefs.remove(_kRequiresPwChange);
  }

  // ── LOGIN ─────────────────────────────────────────────────────────────────

  /// POST /api/users/authenticate
  /// Clears existing token first (matches web clearToken())
  Future<AuthResult> login({
    required String identifier,
    required String password,
  }) async {
    // Clear existing session (matches web clearToken())
    await logout();
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

  // ── SEND REGISTRATION OTP ─────────────────────────────────────────────────

  /// POST /api/users/send-otp
  /// phoneNumber is optional — pass if user filled mobile field
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
      final msg =
      (response.data as Map<String, dynamic>?)?['message'] as String?;
      return OtpResult(success: true, message: msg ?? 'OTP sent');
    } catch (e) {
      return OtpResult(success: false, error: _extractError(e));
    }
  }

  // ── CHECK OTP (validate without consuming) ────────────────────────────────

  /// POST /api/users/check-otp
  /// Validates OTP without marking as used — RegisterPage.tsx calls this
  /// before /onboarding to give immediate feedback
  Future<OtpResult> checkOtp({
    required String email,
    required String otp,
  }) async {
    try {
      await _apiClient.dio.post(
        '/api/users/check-otp',
        data: {
          'email': email.trim(),
          'otp': otp.trim(),
        },
      );
      return const OtpResult(success: true, message: 'OTP verified');
    } catch (e) {
      return OtpResult(success: false, error: _extractError(e));
    }
  }

  // ── FORGOT PASSWORD ───────────────────────────────────────────────────────

  /// POST /api/users/forgot-password
  Future<OtpResult> forgotPassword({required String email}) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/users/forgot-password',
        data: {'email': email.trim()},
      );
      final msg =
      (response.data as Map<String, dynamic>?)?['message'] as String?;
      return OtpResult(success: true, message: msg ?? 'OTP sent');
    } catch (e) {
      return OtpResult(success: false, error: _extractError(e));
    }
  }

  // ── RESET PASSWORD ────────────────────────────────────────────────────────

  /// POST /api/users/reset-password
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
      final msg =
      (response.data as Map<String, dynamic>?)?['message'] as String?;
      return OtpResult(success: true, message: msg ?? 'Password reset successful');
    } catch (e) {
      return OtpResult(success: false, error: _extractError(e));
    }
  }

  // ── CHANGE PASSWORD (logged-in user) ──────────────────────────────────────

  /// PUT /api/users/change-password
  Future<PasswordChangeResult> changePassword({
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      await _apiClient.dio.put(
        '/api/users/change-password',
        data: {
          'newPassword': newPassword,
          'confirmPassword': confirmPassword,
        },
      );
      return const PasswordChangeResult(success: true);
    } catch (e) {
      return PasswordChangeResult(success: false, error: _extractError(e));
    }
  }

  // ── TERMS & CONDITIONS ────────────────────────────────────────────────────

  /// GET /api/admin/config/terms  — returns list of term records
  Future<String> getTermsAndConditions() async {
    try {
      final response =
      await _apiClient.dio.get('/api/admin/config/terms');
      final data = response.data;
      final list = data is List
          ? data
          : (data is Map ? (data['content'] ?? data['data'] ?? []) : []);
      return (list as List)
          .map((r) =>
          (r['content'] ?? r['text'] ?? '').toString().trim())
          .where((s) => s.isNotEmpty)
          .join('\n\n');
    } catch (_) {
      return '';
    }
  }

  // ── ERROR HELPER ──────────────────────────────────────────────────────────

  String _extractError(dynamic e) {
    try {
      final dynamic response = (e as dynamic).response;
      if (response != null) {
        final data = response.data;
        if (data is Map) {
          return (data['message'] ?? data['error'] ?? 'Something went wrong')
              .toString();
        }
      }
    } catch (_) {}
    return e.toString();
  }
}