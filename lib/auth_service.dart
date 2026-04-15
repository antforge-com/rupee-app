// lib/core/services/auth_service.dart
import 'package:dio/dio.dart';
import 'package:finadvise/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/models.dart';

class AuthService {
  final ApiClient _apiClient = ApiClient();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Login with email and password
  Future<AuthResult> login(String email, String password) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/users/authenticate',
        data: {
          'identifier': email, // Backend API expects 'identifier' field
          'password': password
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final token = data['token'];
        final role = data['role'] ?? 'USER';
        final userId = data['userId']?.toString() ?? '';
        final consultantId = data['consultantId']?.toString() ?? '';

        await _storage.write(key: 'fin_token', value: token);
        await _storage.write(key: 'user_role', value: role);
        await _storage.write(key: 'user_id', value: userId);
        if (consultantId.isNotEmpty) {
          await _storage.write(key: 'consultant_id', value: consultantId);
        }

        return AuthResult(
          success: true,
          role: role,
          userId: userId,
          consultantId: consultantId,
          message: 'Login successful',
        );
      }
      return AuthResult(success: false, message: 'Invalid response from server.');
    } on DioException catch (e) {
      String errorMessage = 'Could not connect to server. Please try again.';
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        errorMessage = 'Incorrect email or password.';
      } else if (e.response?.data?['message'] != null) {
        errorMessage = e.response!.data['message'];
      } else if (e.type == DioExceptionType.connectionTimeout) {
        errorMessage = 'Connection timed out. Please check your internet.';
      }
      return AuthResult(success: false, message: errorMessage);
    } catch (e) {
      return AuthResult(success: false, message: 'Something went wrong. Please try again.');
    }
  }

  // Google Sign-In flow
  Future<AuthResult> googleSignIn(String idToken) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/users/oauth/google',
        data: {'idToken': idToken},
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final token = data['token'];
        final role = data['role'] ?? 'USER';
        final userId = data['userId']?.toString() ?? '';
        final consultantId = data['consultantId']?.toString() ?? '';

        await _storage.write(key: 'fin_token', value: token);
        await _storage.write(key: 'user_role', value: role);
        await _storage.write(key: 'user_id', value: userId);
        if (consultantId.isNotEmpty) {
          await _storage.write(key: 'consultant_id', value: consultantId);
        }

        return AuthResult(
          success: true, 
          role: role, 
          userId: userId, 
          consultantId: consultantId, 
          message: 'Google Sign-In successful'
        );
      }
      return AuthResult(success: false, message: 'Invalid response from server.');
    } catch (e) {
      return AuthResult(success: false, message: 'Google Sign-In failed. Please try again.');
    }
  }

  // Send OTP for forgot password
  Future<bool> sendForgotPasswordOtp(String email) async {
    try {
      await _apiClient.dio.post('/api/users/forgot-password', data: {'email': email});
      return true;
    } catch (e) {
      return false;
    }
  }

  // Set new password
  Future<bool> resetPassword(String email, String otp, String newPassword) async {
    try {
      await _apiClient.dio.post('/api/users/reset-password', data: {
        'email': email,
        'otp': otp,
        'newPassword': newPassword,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // Clear storage on logout
  Future<void> logout() async {
    await _storage.deleteAll();
  }

  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: 'fin_token');
    return token != null && token.isNotEmpty;
  }

  Future<String?> getUserRole() => _storage.read(key: 'user_role');
  Future<String?> getUserId() => _storage.read(key: 'user_id');
  Future<String?> getConsultantId() => _storage.read(key: 'consultant_id');
}