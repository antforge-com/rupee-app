// lib/services/skill_master_service_ext.dart
import 'package:dio/dio.dart';
import 'package:finadvise/api_client.dart';
import '../models/all_models.dart';
class SkillMasterServiceExtended {
  final ApiClient _apiClient = ApiClient();
  Future<List<SkillMasterModel>> getAllSkills() async {
    try {
      final response = await _apiClient.dio.get('/api/skills');
      final list = response.data is List ? response.data : response.data['content'] ?? [];
      return (list as List).map((s) => SkillMasterModel.fromJson(s as Map<String, dynamic>)).toList();
    } catch (e) { return []; }
  }
  Future<SkillMasterModel?> createSkill(SkillMasterModel skill) async {
    try {
      final response = await _apiClient.dio.post('/api/skills', data: skill.toJson());
      return SkillMasterModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) { return null; }
  }
  Future<SkillMasterModel?> getSkillById(int id) async {
    try {
      final response = await _apiClient.dio.get('/api/skills/$id');
      return SkillMasterModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) { return null; }
  }
  Future<bool> updateSkill(int id, SkillMasterModel skill) async {
    try {
      await _apiClient.dio.put('/api/skills/$id', data: skill.toJson());
      return true;
    } catch (e) { return false; }
  }
  Future<bool> deleteSkill(int id) async {
    try {
      await _apiClient.dio.delete('/api/skills/$id');
      return true;
    } catch (e) { return false; }
  }
}
