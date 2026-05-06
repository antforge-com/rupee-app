// lib/services/consultant_service_ext.dart
import 'package:dio/dio.dart';
import 'package:finadvise/api_client.dart';
import '../models/all_models.dart';
import '../models/models.dart';
class ConsultantServiceExtended {
  final ApiClient _apiClient = ApiClient();
  Future<List<ConsultantModel>> getAllConsultants() async {
    try {
      final response = await _apiClient.dio.get('/api/consultants');
      final list = response.data is List ? response.data : response.data['content'] ?? [];
      return (list as List).map((c) => ConsultantModel.fromJson(c as Map<String, dynamic>)).toList();
    } catch (e) { return []; }
  }
  Future<ConsultantModel?> getConsultantById(int id) async {
    try {
      final response = await _apiClient.dio.get('/api/consultants/$id');
      return ConsultantModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) { return null; }
  }
  Future<List<ConsultantModel>> searchConsultants(String query) async {
    try {
      final response = await _apiClient.dio.get('/api/consultants/search', queryParameters: {'q': query});
      final list = response.data is List ? response.data : response.data['content'] ?? [];
      return (list as List).map((c) => ConsultantModel.fromJson(c as Map<String, dynamic>)).toList();
    } catch (e) { return []; }
  }
  Future<List<ConsultantModel>> getConsultantsBySkill(String skill) async {
    try {
      final response = await _apiClient.dio.get('/api/consultants', queryParameters: {'skill': skill});
      final list = response.data is List ? response.data : response.data['content'] ?? [];
      return (list as List).map((c) => ConsultantModel.fromJson(c as Map<String, dynamic>)).toList();
    } catch (e) { return []; }
  }
  Future<bool> updateConsultantProfile(int id, Map<String, dynamic> data) async {
    try {
      await _apiClient.dio.put('/api/consultants/$id', data: data);
      return true;
    } catch (e) { return false; }
  }
}
