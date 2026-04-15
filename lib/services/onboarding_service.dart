// lib/core/services/onboarding_service.dart
// ════════════════════════════════════════════════════════════════════════════
// Swagger spec ke exact endpoints:
//   POST /api/onboarding              → JSON body (multipart NAHI!)
//   GET  /api/onboarding/{id}
//   PUT  /api/onboarding/{id}         → multipart/form-data
//   DELETE /api/onboarding/{id}
//   POST /api/onboarding/admin/member → multipart/form-data (admin use)
//
// POST /api/onboarding fields (UserRegistrationRequest):
//   name* (2-100 chars), email*, phoneNumber* (10 digits), otp* (6 digits),
//   location?, profileImageUrl?, subscribed?, subscriptionPlanId?
//   NOTE: dob/identifier/incomeItems/expenseItems → sirf PUT mein hain
//
// PUT /api/onboarding/{id} fields (UpdateUserRegistrationRequest):
//   name?, dob?, identifier? (PAN/Aadhaar), location?, email?,
//   phoneNumber*, profileImageUrl?, subscriptionPlanId?,
//   incomeItems:[{label,amount}], expenseItems:[{label,amount}]
// ════════════════════════════════════════════════════════════════════════════

import 'package:dio/dio.dart';
import 'package:finadvise/api_client.dart';
import '../models/models.dart';

class OnboardingService {
  final ApiClient _apiClient = ApiClient();

  // ── REGISTER (Step 1: OTP bhejna, Step 2: yahan call karo) ───────────────

  /// POST /api/onboarding — Naya user register karo
  /// IMPORTANT: JSON body hai, multipart NAHI
  /// OTP pehle POST /api/users/send-otp se lo, phir yahan bhejo
  ///
  /// Required: name, email, phoneNumber, otp
  /// Optional: location, profileImageUrl, subscribed, subscriptionPlanId
  Future<OnboardingProfile?> register({
    required String name,
    required String email,
    required String phoneNumber, // 10 digits
    required String otp,         // 6 digits
    String? location,
    String? profileImageUrl,
    bool subscribed = false,
    int? subscriptionPlanId,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/onboarding',
        data: {
          'name': name.trim(),
          'email': email.trim(),
          'phoneNumber': phoneNumber.trim(),
          'otp': otp.trim(),
          if (location != null && location.isNotEmpty) 'location': location.trim(),
          if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
          'subscribed': subscribed,
          if (subscriptionPlanId != null) 'subscriptionPlanId': subscriptionPlanId,
        },
      );
      return OnboardingProfile.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  // ── ADMIN: Member create karna ────────────────────────────────────────────

  /// POST /api/onboarding/admin/member — Admin member banaye (multipart)
  /// body fields: name*, email*, phoneNumber*, location?
  Future<OnboardingProfile?> createMemberByAdmin({
    required String name,
    required String email,
    required String phoneNumber,
    String? location,
    MultipartFile? profilePhoto,
  }) async {
    try {
      final dataMap = <String, dynamic>{
        'name': name.trim(),
        'email': email.trim(),
        'phoneNumber': phoneNumber.trim(),
        if (location != null && location.isNotEmpty) 'location': location.trim(),
      };
      final formData = FormData.fromMap({
        'data': dataMap,
        if (profilePhoto != null) 'file': profilePhoto,
      });
      final response = await _apiClient.dio.post(
        '/api/onboarding/admin/member',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      return OnboardingProfile.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  // ── READ ─────────────────────────────────────────────────────────────────

  /// GET /api/onboarding/{id}
  Future<OnboardingProfile?> getProfile(int onboardingId) async {
    try {
      final response = await _apiClient.dio.get('/api/onboarding/$onboardingId');
      return OnboardingProfile.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  // ── UPDATE (multipart) ────────────────────────────────────────────────────

  /// PUT /api/onboarding/{id} — Profile update (multipart/form-data)
  /// UpdateUserRegistrationRequest fields:
  ///   name?, dob? (date), identifier? (PAN/Aadhaar), location?,
  ///   email?, phoneNumber* (required), profileImageUrl?,
  ///   subscriptionPlanId?, incomeItems?, expenseItems?
  Future<bool> updateProfile(
    int onboardingId, Map<String, String> map, {
    String? name,
    String? dob,           // "YYYY-MM-DD"
    String? identifier,    // PAN: ABCDE1234F ya Aadhaar: 12-digit
    String? location,
    String? email,
    String? phoneNumber,   // Required by API if updating
    String? profileImageUrl,
    int? subscriptionPlanId,
    List<Map<String, dynamic>> incomeItems = const [],
    List<Map<String, dynamic>> expenseItems = const [],
    MultipartFile? profilePhoto,
  }) async {
    try {
      final dataMap = <String, dynamic>{
        if (name != null) 'name': name,
        if (dob != null) 'dob': dob,
        if (identifier != null) 'identifier': identifier,
        if (location != null) 'location': location,
        if (email != null) 'email': email,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
        if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
        if (subscriptionPlanId != null) 'subscriptionPlanId': subscriptionPlanId,
        if (incomeItems.isNotEmpty) 'incomeItems': incomeItems,
        if (expenseItems.isNotEmpty) 'expenseItems': expenseItems,
      };

      final formData = FormData.fromMap({
        'data': dataMap,
        if (profilePhoto != null) 'file': profilePhoto,
      });

      await _apiClient.dio.put(
        '/api/onboarding/$onboardingId',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── DELETE ────────────────────────────────────────────────────────────────

  /// DELETE /api/onboarding/{id}
  Future<bool> deleteProfile(int onboardingId) async {
    try {
      await _apiClient.dio.delete('/api/onboarding/$onboardingId');
      return true;
    } catch (e) {
      return false;
    }
  }
}
