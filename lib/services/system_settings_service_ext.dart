// lib/services/system_settings_service_ext.dart
import 'package:dio/dio.dart';
import 'package:finadvise/api_client.dart';
import '../models/all_models.dart';
class SystemSettingsServiceExtended {
  final ApiClient _apiClient = ApiClient();
  Future<List<SystemSettingsModel>> getAllSettings() async {
    try {
      final response = await _apiClient.dio.get('/api/system-settings');
      final list = response.data is List ? response.data : response.data['content'] ?? [];
      return (list as List).map((s) => SystemSettingsModel.fromJson(s as Map<String, dynamic>)).toList();
    } catch (e) { return []; }
  }
  Future<SystemSettingsModel?> getSettingByKey(String key) async {
    try {
      final response = await _apiClient.dio.get('/api/system-settings/$key');
      return SystemSettingsModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) { return null; }
  }
  Future<bool> updateSetting(String key, SystemSettingsModel setting) async {
    try {
      await _apiClient.dio.put('/api/system-settings/$key', data: setting.toJson());
      return true;
    } catch (e) { return false; }
  }
  Future<Map<String, dynamic>?> getAllSettingsMap() async {
    try {
      final response = await _apiClient.dio.get('/api/system-settings/all');
      return response.data is Map ? Map<String, dynamic>.from(response.data) : null;
    } catch (e) { return null; }
  }
}
