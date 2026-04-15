// lib/services/analytics_service.dart
import 'package:finadvise/api_client.dart';

// ─── MODELS ───────────────────────────────────────────────────────────────────

class TicketGraphData {
  final int count;
  final String label;

  TicketGraphData({required this.count, required this.label});

  factory TicketGraphData.fromJson(Map<String, dynamic> json) => TicketGraphData(
        count: json['count'] ?? 0,
        label: json['label'] ?? '',
      );
}

/// Consolidated analytics model built from real API endpoints:
/// - GET /api/dashboard/summaries?period=WEEKLY
///   → Map<String, List<TicketGraphData>>
///   → keys: "byStatus", "byPriority", "trend" (actual keys depend on backend)
/// - GET /api/dashboard/analytics?period=WEEKLY
///   → Map<String, Object>
///   → keys: totalTickets, resolvedTickets, avgResponseTime, avgResolutionTime, etc.
class DashboardAnalytics {
  // From /api/dashboard/analytics
  final int totalTickets;
  final int resolvedTickets;
  final int openTickets;
  final int slaBreaches;
  final double avgResponseTime; // hours
  final double avgResolutionTime; // hours
  final double avgRating;

  // From /api/dashboard/summaries
  final Map<String, int> ticketsByStatus;
  final Map<String, int> ticketsByPriority;
  final List<TicketGraphData> weeklyTrend;

  DashboardAnalytics({
    required this.totalTickets,
    required this.resolvedTickets,
    required this.openTickets,
    required this.slaBreaches,
    required this.avgResponseTime,
    required this.avgResolutionTime,
    required this.avgRating,
    required this.ticketsByStatus,
    required this.ticketsByPriority,
    required this.weeklyTrend,
  });

  static DashboardAnalytics empty() => DashboardAnalytics(
        totalTickets: 0,
        resolvedTickets: 0,
        openTickets: 0,
        slaBreaches: 0,
        avgResponseTime: 0,
        avgResolutionTime: 0,
        avgRating: 0,
        ticketsByStatus: {},
        ticketsByPriority: {},
        weeklyTrend: [],
      );
}

// ─── SERVICE ──────────────────────────────────────────────────────────────────

class AnalyticsService {
  final ApiClient _apiClient = ApiClient();

  /// GET /api/dashboard/summaries?period=WEEKLY
  /// Returns Map<String, List<TicketGraphData>>
  /// period: WEEKLY | MONTHLY
  Future<Map<String, List<TicketGraphData>>> getDashboardSummaries({
    String period = 'WEEKLY',
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/dashboard/summaries',
        queryParameters: {'period': period},
      );
      final raw = response.data as Map<String, dynamic>;
      return raw.map((key, value) => MapEntry(
            key,
            (value as List).map((e) => TicketGraphData.fromJson(e)).toList(),
          ));
    } catch (_) {
      return {};
    }
  }

  /// GET /api/dashboard/analytics?period=WEEKLY
  /// Returns Map<String, Object>
  Future<Map<String, dynamic>> getResolutionAnalytics({
    String period = 'WEEKLY',
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/dashboard/analytics',
        queryParameters: {'period': period},
      );
      return Map<String, dynamic>.from(response.data);
    } catch (_) {
      return {};
    }
  }

  /// Fetches BOTH endpoints and merges into DashboardAnalytics
  Future<DashboardAnalytics> getFullDashboard({String period = 'WEEKLY'}) async {
    try {
      final results = await Future.wait([
        getDashboardSummaries(period: period),
        getResolutionAnalytics(period: period),
      ]);

      final summaries = results[0] as Map<String, List<TicketGraphData>>;
      final analytics = results[1] as Map<String, dynamic>;

      // Build status map from summaries (key "byStatus" or first matching list)
      final Map<String, int> statusMap = {};
      final Map<String, int> priorityMap = {};
      List<TicketGraphData> trend = [];

      summaries.forEach((key, graphList) {
        final k = key.toLowerCase();
        if (k.contains('status')) {
          for (final g in graphList) {
            statusMap[g.label] = g.count;
          }
        } else if (k.contains('priority')) {
          for (final g in graphList) {
            priorityMap[g.label] = g.count;
          }
        } else if (k.contains('trend') || k.contains('daily') || k.contains('weekly')) {
          trend = graphList;
        }
      });

      // Parse analytics map — keys depend on backend implementation
      final int totalTickets = _parseInt(analytics['totalTickets']) ??
          _parseInt(analytics['total']) ?? 0;
      final int resolvedTickets = _parseInt(analytics['resolvedTickets']) ??
          _parseInt(analytics['resolved']) ?? 0;
      final int openTickets = _parseInt(analytics['openTickets']) ??
          _parseInt(analytics['open']) ?? 0;
      final int slaBreaches = _parseInt(analytics['slaBreaches']) ??
          _parseInt(analytics['breached']) ?? 0;
      final double avgResponse = _parseDouble(analytics['avgResponseTime']) ??
          _parseDouble(analytics['avgFirstResponseTime']) ?? 0.0;
      final double avgResolution = _parseDouble(analytics['avgResolutionTime']) ?? 0.0;
      final double avgRating = _parseDouble(analytics['avgRating']) ??
          _parseDouble(analytics['averageRating']) ?? 0.0;

      return DashboardAnalytics(
        totalTickets: totalTickets,
        resolvedTickets: resolvedTickets,
        openTickets: openTickets,
        slaBreaches: slaBreaches,
        avgResponseTime: avgResponse,
        avgResolutionTime: avgResolution,
        avgRating: avgRating,
        ticketsByStatus: statusMap,
        ticketsByPriority: priorityMap,
        weeklyTrend: trend,
      );
    } catch (_) {
      return DashboardAnalytics.empty();
    }
  }

  int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}

// ─── ADMIN SERVICE (merged) ───────────────────────────────────────────────────

class AdminService {
  final ApiClient _apiClient = ApiClient();

  // ── USERS ──

  /// GET /api/users
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final response = await _apiClient.dio.get('/api/users');
      return List<Map<String, dynamic>>.from(response.data);
    } catch (_) {
      return [];
    }
  }

  /// GET /api/users/role/{role}
  /// role: USER | SUBSCRIBER | CONSULTANT | ADMIN
  Future<List<Map<String, dynamic>>> getUsersByRole(String role) async {
    try {
      final response = await _apiClient.dio.get('/api/users/role/$role');
      return List<Map<String, dynamic>>.from(response.data);
    } catch (_) {
      return [];
    }
  }

  /// PUT /api/users/{id}
  /// Body: { identifier?, password?, role?, consultantId? }
  Future<bool> updateUser(int userId, Map<String, dynamic> data) async {
    try {
      await _apiClient.dio.put('/api/users/$userId', data: data);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// DELETE /api/users/{id}
  Future<bool> deleteUser(int userId) async {
    try {
      await _apiClient.dio.delete('/api/users/$userId');
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── SYSTEM SETTINGS ──

  /// GET /api/admin/settings/holidays
  Future<List<Map<String, dynamic>>> getHolidays() async {
    try {
      final response = await _apiClient.dio.get('/api/admin/settings/holidays');
      return List<Map<String, dynamic>>.from(response.data);
    } catch (_) {
      return [];
    }
  }

  /// POST /api/admin/settings/holidays
  /// Body: { holidayDate, name }
  Future<bool> addHoliday(String date, String name) async {
    try {
      await _apiClient.dio.post('/api/admin/settings/holidays', data: {
        'holidayDate': date,
        'name': name,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// DELETE /api/admin/settings/holidays/{id}
  Future<bool> deleteHoliday(int id) async {
    try {
      await _apiClient.dio.delete('/api/admin/settings/holidays/$id');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// GET /api/admin/settings/business-hours
  Future<List<Map<String, dynamic>>> getBusinessHours() async {
    try {
      final response = await _apiClient.dio.get('/api/admin/settings/business-hours');
      return List<Map<String, dynamic>>.from(response.data);
    } catch (_) {
      return [];
    }
  }

  /// POST /api/admin/settings/business-hours
  /// Body: List of { dayOfWeek, startTime, endTime, workingDay }
  Future<bool> updateBusinessHours(List<Map<String, dynamic>> hours) async {
    try {
      await _apiClient.dio.post('/api/admin/settings/business-hours', data: hours);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// GET /api/admin/settings/auto-responder
  Future<Map<String, dynamic>?> getAutoResponder() async {
    try {
      final response = await _apiClient.dio.get('/api/admin/settings/auto-responder');
      return Map<String, dynamic>.from(response.data);
    } catch (_) {
      return null;
    }
  }

  /// POST /api/admin/settings/auto-responder
  /// Body: { enabled, message }
  Future<bool> updateAutoResponder(bool enabled, String message) async {
    try {
      await _apiClient.dio.post('/api/admin/settings/auto-responder', data: {
        'enabled': enabled,
        'message': message,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── SUBSCRIPTION PLANS ──

  /// GET /api/subscription-plans
  Future<List<Map<String, dynamic>>> getAllPlans() async {
    try {
      final response = await _apiClient.dio.get('/api/subscription-plans');
      return List<Map<String, dynamic>>.from(response.data);
    } catch (_) {
      return [];
    }
  }

  /// POST /api/subscription-plans
  /// Body: { name, originalPrice, discountPrice, features?, tag? }
  Future<bool> createPlan(Map<String, dynamic> data) async {
    try {
      await _apiClient.dio.post('/api/subscription-plans', data: data);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// PUT /api/subscription-plans/{id}
  Future<bool> updatePlan(int id, Map<String, dynamic> data) async {
    try {
      await _apiClient.dio.put('/api/subscription-plans/$id', data: data);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// DELETE /api/subscription-plans/{id}
  Future<bool> deletePlan(int id) async {
    try {
      await _apiClient.dio.delete('/api/subscription-plans/$id');
      return true;
    } catch (_) {
      return false;
    }
  }
}
