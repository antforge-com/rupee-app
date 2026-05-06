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

  static const List<String> _listKeys = [
    'content', 'data', 'items', 'tickets', 'bookings', 'rows', 'records',
    'messages', 'submissions', 'results',
  ];

  static const List<String> _mapKeys = [
    'data', 'payload', 'result', 'analytics', 'summary', 'summaries',
    'response', 'page',
  ];

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return null;
  }

  List<Map<String, dynamic>> _asMapList(dynamic value,
      {List<String> keys = _listKeys}) {
    List<Map<String, dynamic>> toMapList(List<dynamic> list) => list
        .map(_asMap)
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);

    dynamic findList(dynamic raw, int depth) {
      if (depth > 6 || raw == null) return null;
      if (raw is List) return raw;
      final map = _asMap(raw);
      if (map == null) return null;
      for (final key in keys) {
        final candidate = map[key];
        if (candidate is List) return candidate;
      }
      for (final entry in map.entries) {
        if (keys.contains(entry.key)) continue;
        final nested = findList(entry.value, depth + 1);
        if (nested is List) return nested;
      }
      return null;
    }

    final list = findList(value, 0);
    if (list is List) return toMapList(list.cast<dynamic>());
    return const [];
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? 0;
  }

  Future<List<Map<String, dynamic>>> _getAllFeedbacks() async {
    try {
      final response = await _apiClient.dio.get('/api/feedbacks');
      return _asMapList(response.data);
    } catch (_) {
      return [];
    }
  }

  /// GET /api/analytics/tickets/all or /api/tickets — Fetch all tickets for analytics
  Future<List<Map<String, dynamic>>> getAnalyticsTicketsAll({
    int fallbackSize = 500,
  }) async {
    final requests = [
      () => _apiClient.dio.get('/api/analytics/tickets/all'),
      () => _apiClient.dio.get('/analytics/tickets/all'),
      () => _apiClient.dio.get(
            '/api/tickets',
            queryParameters: {
              'page': 0,
              'size': fallbackSize,
              'sortBy': 'createdAt'
            },
          ),
      () => _apiClient.dio.get(
            '/api/tickets',
            queryParameters: {'size': fallbackSize},
          ),
    ];

    for (var i = 0; i < requests.length; i++) {
      final request = requests[i];
      try {
        final response = await request();
        final items = _asMapList(response.data);
        if (items.isEmpty) continue;

        // If paginated ticket API is used, fetch remaining pages as well.
        if (i >= 2) {
          final root = _asMap(response.data) ?? const <String, dynamic>{};
          final totalPages = _toInt(root['totalPages'] ?? root['pages']);
          if (totalPages > 1) {
            final size = _toInt(root['size'] ?? root['pageSize']);
            final pageSize = size > 0 ? size : fallbackSize;
            final all = <Map<String, dynamic>>[...items];
            for (var page = 1; page < totalPages; page++) {
              try {
                final next = await _apiClient.dio.get(
                  '/api/tickets',
                  queryParameters: {
                    'page': page,
                    'size': pageSize,
                    'sortBy': 'createdAt',
                  },
                );
                all.addAll(_asMapList(next.data));
              } catch (_) {
                // Best effort: keep rows fetched so far.
              }
            }

            final seen = <String>{};
            final deduped = all.where((row) {
              final key = '${row['id'] ?? row['ticketId'] ?? ''}'.trim();
              if (key.isEmpty) return true;
              if (seen.contains(key)) return false;
              seen.add(key);
              return true;
            }).toList(growable: false);
            if (deduped.isNotEmpty) return deduped;
          }
        }

        return items;
      } catch (_) {
        // Try next endpoint variant.
      }
    }

    return [];
  }

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

  /// Compatibility alias for dashboard
  Future<DashboardAnalytics> getAnalyticsLegacy({String period = 'WEEKLY'}) async {
    final res = await getAnalytics(period: period);
    return DashboardAnalytics.fromJson(res ?? {});
  }
}
