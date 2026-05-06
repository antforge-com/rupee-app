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
    'content',
    'data',
    'items',
    'tickets',
    'bookings',
    'rows',
    'records',
    'messages',
    'submissions',
    'results',
  ];

  static const List<String> _mapKeys = [
    'data',
    'payload',
    'result',
    'analytics',
    'summary',
    'summaries',
    'response',
    'page',
  ];

  static const Set<String> _resolvedStatuses = {'RESOLVED', 'CLOSED'};
  static const Set<String> _openStatuses = {
    'NEW',
    'OPEN',
    'IN_PROGRESS',
    'PENDING',
  };

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map(
        (key, val) => MapEntry(key.toString(), val),
      );
    }
    return null;
  }

  List<Map<String, dynamic>> _asMapList(
    dynamic value, {
    List<String> keys = _listKeys,
  }) {
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

  Map<String, dynamic>? _unwrapMap(
    dynamic raw, {
    List<String> preferredKeys = const [],
  }) {
    Map<String, dynamic>? findMap(dynamic value, int depth) {
      if (depth > 6) return null;
      final map = _asMap(value);
      if (map == null) return null;

      for (final key in preferredKeys) {
        final nested = _asMap(map[key]);
        if (nested != null && nested.isNotEmpty) return nested;
      }
      for (final key in _mapKeys) {
        final nested = _asMap(map[key]);
        if (nested != null && nested.isNotEmpty) return nested;
      }
      for (final entry in map.entries) {
        if (preferredKeys.contains(entry.key) || _mapKeys.contains(entry.key)) {
          continue;
        }
        final nested = findMap(entry.value, depth + 1);
        if (nested != null && nested.isNotEmpty) return nested;
      }
      return map;
    }

    return findMap(raw, 0);
  }

  bool _looksLikeDashboard(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return false;
    return json.containsKey('totalTickets') ||
        json.containsKey('resolvedTickets') ||
        json.containsKey('ticketsByStatus') ||
        json.containsKey('ticketsByPriority');
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? 0;
  }

  double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}') ?? 0.0;
  }

  String _toUpperString(dynamic value, {String fallback = 'UNKNOWN'}) {
    final raw = '${value ?? ''}'.trim();
    if (raw.isEmpty) return fallback;
    return raw.toUpperCase();
  }

  DateTime? _parseDate(dynamic value) {
    final raw = '${value ?? ''}'.trim();
    if (raw.isEmpty) return null;

    try {
      final normalized =
          (raw.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(raw))
              ? raw
              : '${raw}Z';
      return DateTime.tryParse(normalized)?.toLocal();
    } catch (_) {
      return null;
    }
  }

  bool _isWithinPeriod(DateTime? createdAt, String period) {
    if (createdAt == null) return true;
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final upper = period.toUpperCase();
    int days = 7;
    if (upper == AnalyticsPeriod.monthly) {
      days = 30;
    } else if (upper == AnalyticsPeriod.yearly) {
      days = 365;
    }
    final cutoff = startOfToday.subtract(Duration(days: days - 1));
    return !createdAt.isBefore(cutoff);
  }

  Map<String, int> _sortedCountMap(Map<String, int> source) {
    final entries = source.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return {for (final entry in entries) entry.key: entry.value};
  }

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

  Future<List<Map<String, dynamic>>> _getAllFeedbacks() async {
    try {
      final response = await _apiClient.dio.get('/api/feedbacks');
      return _asMapList(response.data);
    } catch (_) {
      return [];
    }
  }

  DashboardAnalytics _buildFromTicketDataset({
    required List<Map<String, dynamic>> tickets,
    required List<Map<String, dynamic>> feedbacks,
    required String period,
  }) {
    final scoped = tickets
        .where((t) => _isWithinPeriod(_parseDate(t['createdAt']), period))
        .toList(growable: false);

    final byStatus = <String, int>{};
    final byPriority = <String, int>{};
    final byCategory = <String, int>{};

    final responseHours = <double>[];
    final resolutionHours = <double>[];
    final ratings = <double>[];

    var resolvedCount = 0;
    var openCount = 0;
    var slaBreaches = 0;

    for (final ticket in scoped) {
      final status = _toUpperString(ticket['status']);
      final priority = _toUpperString(ticket['priority'], fallback: 'LOW');
      final category =
          '${ticket['category'] ?? ticket['categoryName'] ?? 'General'}'
              .trim()
              .replaceAll(RegExp(r'\s+'), ' ');

      byStatus[status] = (byStatus[status] ?? 0) + 1;
      byPriority[priority] = (byPriority[priority] ?? 0) + 1;
      byCategory[category.isEmpty ? 'General' : category] =
          (byCategory[category.isEmpty ? 'General' : category] ?? 0) + 1;

      if (_resolvedStatuses.contains(status)) {
        resolvedCount++;
      } else if (_openStatuses.contains(status)) {
        openCount++;
      }

      final breached = ticket['isSlaBreached'] == true ||
          ticket['slaBreached'] == true ||
          ticket['breached'] == true;
      if (breached) slaBreaches++;

      final createdAt = _parseDate(ticket['createdAt']);
      final firstResponseAt = _parseDate(ticket['firstResponseAt']);
      if (createdAt != null &&
          firstResponseAt != null &&
          !firstResponseAt.isBefore(createdAt)) {
        responseHours.add(
          firstResponseAt.difference(createdAt).inMinutes / 60.0,
        );
      }

      final resolvedAt = _parseDate(
        ticket['resolvedAt'] ??
            ticket['closedAt'] ??
            (_resolvedStatuses.contains(status) ? ticket['updatedAt'] : null),
      );
      if (createdAt != null &&
          resolvedAt != null &&
          !resolvedAt.isBefore(createdAt)) {
        resolutionHours.add(
          resolvedAt.difference(createdAt).inMinutes / 60.0,
        );
      }

      final ticketRating =
          _toDouble(ticket['feedbackRating'] ?? ticket['rating']);
      if (ticketRating > 0) ratings.add(ticketRating);
    }

    if (ratings.isEmpty) {
      for (final feedback in feedbacks) {
        if (!_isWithinPeriod(_parseDate(feedback['createdAt']), period))
          continue;
        final rating = _toDouble(feedback['rating']);
        if (rating > 0) ratings.add(rating);
      }
    }

    final totalTickets = scoped.length;
    if (openCount == 0 && totalTickets >= resolvedCount) {
      openCount = totalTickets - resolvedCount;
    }

    final avgResponse = responseHours.isEmpty
        ? 0.0
        : responseHours.reduce((a, b) => a + b) / responseHours.length;
    final avgResolution = resolutionHours.isEmpty
        ? 0.0
        : resolutionHours.reduce((a, b) => a + b) / resolutionHours.length;
    final avgRating = ratings.isEmpty
        ? 0.0
        : ratings.reduce((a, b) => a + b) / ratings.length;

    return DashboardAnalytics(
      totalTickets: totalTickets,
      openTickets: openCount,
      resolvedTickets: resolvedCount,
      slaBreaches: slaBreaches,
      avgResponseTime: avgResponse,
      avgResolutionTime: avgResolution,
      avgRating: avgRating,
      ticketsByStatus: _sortedCountMap(byStatus),
      ticketsByPriority: _sortedCountMap(byPriority),
      ticketsByCategory: _sortedCountMap(byCategory),
    );
  }

  // PERIOD-BASED

  /// GET /api/dashboard/analytics?period=WEEKLY
  Future<Map<String, dynamic>?> getAnalytics({
    String period = AnalyticsPeriod.weekly,
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/dashboard/analytics',
        queryParameters: {'period': period},
      );
      return _unwrapMap(response.data, preferredKeys: const ['analytics']);
    } catch (_) {
      return null;
    }
  }

  /// GET /api/dashboard/summaries?period=WEEKLY
  Future<Map<String, dynamic>?> getSummaries({
    String period = AnalyticsPeriod.weekly,
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/dashboard/summaries',
        queryParameters: {'period': period},
      );
      return _unwrapMap(response.data,
          preferredKeys: const ['summaries', 'summary']);
    } catch (_) {
      return null;
    }
  }

  // DAYS-BASED

  Future<Map<String, dynamic>?> getTicketVolume({int days = 14}) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/dashboard/ticket-volume',
        queryParameters: {'days': days},
      );
      return _unwrapMap(response.data);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getSlaBreach({int days = 14}) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/dashboard/sla-breach',
        queryParameters: {'days': days},
      );
      return _unwrapMap(response.data);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getRevenue({int days = 14}) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/dashboard/revenue',
        queryParameters: {'days': days},
      );
      return _unwrapMap(response.data);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getResponseTimes({int days = 14}) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/dashboard/response-times',
        queryParameters: {'days': days},
      );
      return _unwrapMap(response.data);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getReports({
    int days = 14,
    String groupBy = 'CATEGORY',
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/dashboard/reports',
        queryParameters: {'days': days, 'groupBy': groupBy},
      );
      return _unwrapMap(response.data);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getCustomerSatisfaction({int days = 14}) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/dashboard/customer-satisfaction',
        queryParameters: {'days': days},
      );
      return _unwrapMap(response.data);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getAgentPerformance({int days = 14}) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/dashboard/agent-performance',
        queryParameters: {'days': days},
      );
      return _unwrapMap(response.data);
    } catch (_) {
      return null;
    }
  }

  // FULL DASHBOARD

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

  /// Compatibility method used by older dashboard implementations.
  /// Falls back to the same full-ticket dataset strategy used by web analytics.
  Future<DashboardAnalytics> getAnalyticsLegacy({
    String period = AnalyticsPeriod.weekly,
  }) async {
    final map = await getAnalytics(period: period);
    if (_looksLikeDashboard(map)) {
      return DashboardAnalytics.fromJson(map!);
    }

    final tickets = await getAnalyticsTicketsAll();
    if (tickets.isEmpty) {
      return DashboardAnalytics.fromJson(map ?? const {});
    }

    final feedbacks = await _getAllFeedbacks();
    return _buildFromTicketDataset(
      tickets: tickets,
      feedbacks: feedbacks,
      period: period,
    );
  }
}
