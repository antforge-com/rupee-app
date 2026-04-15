// lib/core/services/user_service.dart  ← NEW FILE
// ════════════════════════════════════════════════════════════════════════════
// Swagger spec ke exact endpoints:
//   GET /api/users/me
//   GET /api/users/{id}
//   PUT /api/users/{id}  body: { identifier, password, role, consultantId }
//   DELETE /api/users/{id}
//   GET /api/users  (admin)
//   GET /api/users/role/{role}
// ════════════════════════════════════════════════════════════════════════════
import 'package:finadvise/api_client.dart';

import '../models/models.dart';

class UserService {
  final ApiClient _apiClient = ApiClient();

  /// GET /api/users/me — Apna profile
  Future<UserModel?> getMe() async {
    try {
      final response = await _apiClient.dio.get('/api/users/me');
      return UserModel.fromJson(response.data);
    } catch (e) {
      return null;
    }
  }

  /// GET /api/users/{id}
  Future<UserModel?> getUserById(int userId) async {
    try {
      final response = await _apiClient.dio.get('/api/users/$userId');
      return UserModel.fromJson(response.data);
    } catch (e) {
      return null;
    }
  }

  /// PUT /api/users/{id}
  /// UpdateUserRequest: { identifier?, password?, role?, consultantId? }
  Future<bool> updateUser(int userId, {
    String? identifier,
    String? password,
    String? role,
    int? consultantId,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (identifier != null) body['identifier'] = identifier;
      if (password != null) body['password'] = password;
      if (role != null) body['role'] = role;
      if (consultantId != null) body['consultantId'] = consultantId;
      if (body.isEmpty) return true;

      await _apiClient.dio.put('/api/users/$userId', data: body);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// DELETE /api/users/{id}
  Future<bool> deleteUser(int userId) async {
    try {
      await _apiClient.dio.delete('/api/users/$userId');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// GET /api/users — All users (Admin only)
  Future<List<UserModel>> getAllUsers({int page = 0, int size = 50}) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/users',
        queryParameters: {'page': page, 'size': size},
      );
      final data = response.data;
      final list = data is Map ? (data['content'] ?? data['data'] ?? []) : data;
      return (list as List).map((e) => UserModel.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// GET /api/users/role/{role}
  Future<List<UserModel>> getUsersByRole(String role) async {
    try {
      final response = await _apiClient.dio.get('/api/users/role/$role');
      final data = response.data;
      final list = data is Map ? (data['content'] ?? data['data'] ?? []) : data;
      return (list as List).map((e) => UserModel.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }
}
