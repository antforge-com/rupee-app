// lib/services/dashboard_service_ext.dart
import 'package:dio/dio.dart';
import 'package:finadvise/api_client.dart';
import '../models/all_models.dart';
class DashboardServiceExtended {
  final ApiClient _apiClient = ApiClient();
  Future<DashboardStatsModel?> getDashboardStats() async {
    try {
      final response = await _apiClient.dio.get('/api/dashboard/stats');
      return DashboardStatsModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) { return null; }
  }
  Future<Map<String, dynamic>?> getUserDashboard(int userId) async {
    try {
      final response = await _apiClient.dio.get('/api/dashboard/user/$userId');
      return response.data is Map ? Map<String, dynamic>.from(response.data) : null;
    } catch (e) { return null; }
  }
  Future<Map<String, dynamic>?> getAdminDashboard() async {
    try {
      final response = await _apiClient.dio.get('/api/dashboard/admin');
      return response.data is Map ? Map<String, dynamic>.from(response.data) : null;
    } catch (e) { return null; }
  }
  Future<Map<String, dynamic>?> getConsultantDashboard(int consultantId) async {
    try {
      final response = await _apiClient.dio.get('/api/dashboard/consultant/$consultantId');
      return response.data is Map ? Map<String, dynamic>.from(response.data) : null;
    } catch (e) { return null; }
  }
  Future<List<Map<dynamic, dynamic>>?> getRecentActivity() async {
    try {
      final response = await _apiClient.dio.get('/api/dashboard/activity/recent');
      final list = response.data is List ? response.data : [];
      return (list as List).map((item) => item is Map ? Map<String, dynamic>.from(item) : {}).toList();
    } catch (e) { return null; }
  }
}
