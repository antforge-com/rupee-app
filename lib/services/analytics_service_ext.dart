// lib/services/analytics_service_ext.dart
import 'package:dio/dio.dart';
import 'package:finadvise/api_client.dart';
import '../models/all_models.dart';
class AnalyticsServiceExtended {
  final ApiClient _apiClient = ApiClient();
  Future<AnalyticsModel?> getDashboardAnalytics() async {
    try {
      final response = await _apiClient.dio.get('/api/analytics/dashboard');
      return AnalyticsModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) { return null; }
  }
  Future<Map<String, dynamic>?> getBookingStats() async {
    try {
      final response = await _apiClient.dio.get('/api/analytics/bookings');
      return response.data is Map ? Map<String, dynamic>.from(response.data) : null;
    } catch (e) { return null; }
  }
  Future<Map<String, dynamic>?> getRevenueStats() async {
    try {
      final response = await _apiClient.dio.get('/api/analytics/revenue');
      return response.data is Map ? Map<String, dynamic>.from(response.data) : null;
    } catch (e) { return null; }
  }
  Future<Map<String, dynamic>?> getTicketStats() async {
    try {
      final response = await _apiClient.dio.get('/api/analytics/tickets');
      return response.data is Map ? Map<String, dynamic>.from(response.data) : null;
    } catch (e) { return null; }
  }
  Future<Map<String, dynamic>?> getConsultantStats() async {
    try {
      final response = await _apiClient.dio.get('/api/analytics/consultants');
      return response.data is Map ? Map<String, dynamic>.from(response.data) : null;
    } catch (e) { return null; }
  }
  Future<Map<String, dynamic>?> getReportData(String reportType) async {
    try {
      final response = await _apiClient.dio.get('/api/analytics/reports/$reportType');
      return response.data is Map ? Map<String, dynamic>.from(response.data) : null;
    } catch (e) { return null; }
  }
}
