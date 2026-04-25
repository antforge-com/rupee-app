// lib/core/services/analytics_service.dart
// ════════════════════════════════════════════════════════════════════════════
// Swagger spec ke ALL dashboard endpoints:
//   GET /api/dashboard/analytics?period=WEEKLY      ← resolution analytics
//   GET /api/dashboard/summaries?period=WEEKLY       ← graph data
//   GET /api/dashboard/ticket-volume?days=14
//   GET /api/dashboard/sla-breach?days=14
//   GET /api/dashboard/revenue?days=14
//   GET /api/dashboard/response-times?days=14
//   GET /api/dashboard/reports?days=14&groupBy=CATEGORY
//   GET /api/dashboard/customer-satisfaction?days=14
//   GET /api/dashboard/agent-performance?days=14
// ════════════════════════════════════════════════════════════════════════════

import 'package:finadvise/api_client.dart';
import '../models/models.dart';

class AnalyticsPeriod {
  static const String weekly = 'WEEKLY';
  static const String monthly = 'MONTHLY';
  static const String yearly = 'YEARLY';
}

class AnalyticsService {
  final ApiClient _apiClient = ApiClient();

  // ── PERIOD-BASED ──────────────────────────────────────────────────────────

  /// GET /api/dashboard/analytics?period=WEEKLY
  Future<Map<String, dynamic>?> getAnalytics({
    String period = AnalyticsPeriod.weekly,
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/dashboard/analytics',
        queryParameters: {'period': period},
      );
      return response.data is Map
          ? Map<String, dynamic>.from(response.data)
          : null;
    } catch (e) {
      return null;
    }
  }

  /// GET /api/dashboard/summaries?period=WEEKLY
  /// Returns: Map<String, List<{count, label}>>
  Future<Map<String, dynamic>?> getSummaries({
    String period = AnalyticsPeriod.weekly,
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/dashboard/summaries',
        queryParameters: {'period': period},
      );
      return response.data is Map
          ? Map<String, dynamic>.from(response.data)
          : null;
    } catch (e) {
      return null;
    }
  }

  // ── DAYS-BASED ────────────────────────────────────────────────────────────

  /// GET /api/dashboard/ticket-volume?days=14
  Future<Map<String, dynamic>?> getTicketVolume({int days = 14}) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/dashboard/ticket-volume',
        queryParameters: {'days': days},
      );
      return response.data is Map
          ? Map<String, dynamic>.from(response.data)
          : null;
    } catch (e) {
      return null;
    }
  }

  /// GET /api/dashboard/sla-breach?days=14
  Future<Map<String, dynamic>?> getSlaBreach({int days = 14}) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/dashboard/sla-breach',
        queryParameters: {'days': days},
      );
      return response.data is Map
          ? Map<String, dynamic>.from(response.data)
          : null;
    } catch (e) {
      return null;
    }
  }

  /// GET /api/dashboard/revenue?days=14
  Future<Map<String, dynamic>?> getRevenue({int days = 14}) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/dashboard/revenue',
        queryParameters: {'days': days},
      );
      return response.data is Map
          ? Map<String, dynamic>.from(response.data)
          : null;
    } catch (e) {
      return null;
    }
  }

  /// GET /api/dashboard/response-times?days=14
  Future<Map<String, dynamic>?> getResponseTimes({int days = 14}) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/dashboard/response-times',
        queryParameters: {'days': days},
      );
      return response.data is Map
          ? Map<String, dynamic>.from(response.data)
          : null;
    } catch (e) {
      return null;
    }
  }

  /// GET /api/dashboard/reports?days=14&groupBy=CATEGORY
  /// groupBy: CATEGORY | PRIORITY | STATUS | CONSULTANT (server-side values)
  Future<Map<String, dynamic>?> getReports({
    int days = 14,
    String groupBy = 'CATEGORY',
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/dashboard/reports',
        queryParameters: {'days': days, 'groupBy': groupBy},
      );
      return response.data is Map
          ? Map<String, dynamic>.from(response.data)
          : null;
    } catch (e) {
      return null;
    }
  }

  /// GET /api/dashboard/customer-satisfaction?days=14
  Future<Map<String, dynamic>?> getCustomerSatisfaction({int days = 14}) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/dashboard/customer-satisfaction',
        queryParameters: {'days': days},
      );
      return response.data is Map
          ? Map<String, dynamic>.from(response.data)
          : null;
    } catch (e) {
      return null;
    }
  }

  /// GET /api/dashboard/agent-performance?days=14
  Future<Map<String, dynamic>?> getAgentPerformance({int days = 14}) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/dashboard/agent-performance',
        queryParameters: {'days': days},
      );
      return response.data is Map
          ? Map<String, dynamic>.from(response.data)
          : null;
    } catch (e) {
      return null;
    }
  }

  // ── FULL DASHBOARD (parallel fetch) ──────────────────────────────────────

  /// Sab period-based data ek saath fetch karo
  Future<({Map<String, dynamic>? analytics, Map<String, dynamic>? summaries})>
  getFullDashboard({String period = AnalyticsPeriod.weekly}) async {
    final results = await Future.wait([
      getAnalytics(period: period),
      getSummaries(period: period),
    ]);
    return (
    analytics: results[0],
    summaries: results[1],
    );
  }

  /// Alias for getFullDashboard to support legacy dashboard code
  Future<({Map<String, dynamic>? analytics, Map<String, dynamic>? summaries})>
  getAnalyticsAlias({String period = AnalyticsPeriod.weekly}) => getFullDashboard(period: period);
}
