// lib/services/user_service_ext.dart
import 'package:dio/dio.dart';
import 'package:finadvise/api_client.dart';
import '../models/all_models.dart';
import '../models/models.dart';
class UserServiceExtended {
  final ApiClient _apiClient = ApiClient();
  Future<UserModel?> getCurrentUser() async {
    try {
      final response = await _apiClient.dio.get('/api/users/profile');
      return UserModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) { return null; }
  }
  Future<UserModel?> getUserById(int id) async {
    try {
      final response = await _apiClient.dio.get('/api/users/$id');
      return UserModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) { return null; }
  }
  Future<bool> updateUserProfile(Map<String, dynamic> data) async {
    try {
      await _apiClient.dio.put('/api/users/profile', data: data);
      return true;
    } catch (e) { return false; }
  }
  Future<bool> uploadProfilePicture(String filePath) async {
    try {
      final formData = FormData.fromMap({'file': await MultipartFile.fromFile(filePath)});
      await _apiClient.dio.post('/api/users/profile/picture', data: formData);
      return true;
    } catch (e) { return false; }
  }
  Future<List<UserModel>> searchUsers(String query) async {
    try {
      final response = await _apiClient.dio.get('/api/users/search', queryParameters: {'q': query});
      final list = response.data is List ? response.data : response.data['content'] ?? [];
      return (list as List).map((u) => UserModel.fromJson(u as Map<String, dynamic>)).toList();
    } catch (e) { return []; }
  }
  Future<bool> updateUserStatus(int userId, String status) async {
    try {
      await _apiClient.dio.put('/api/users/$userId/status', data: {'status': status});
      return true;
    } catch (e) { return false; }
  }
}
