import 'dart:async';
import 'dart:math';

import 'package:finadvise/api_client.dart';
import 'package:finadvise/app_theme.dart';
import 'package:finadvise/models/models.dart';
import 'package:finadvise/services/analytics_service.dart';
import 'package:finadvise/services/booking_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

DateTime? _analyticsDate(dynamic value) {
  if (value == null) return null;
  if (value is int) {
    if (value > 1000000000000) return DateTime.fromMillisecondsSinceEpoch(value).toLocal();
    if (value > 1000000000) return DateTime.fromMillisecondsSinceEpoch(value * 1000).toLocal();
    return null;
  }
  final raw = value.toString().trim();
  if (raw.isEmpty || raw == 'null') return null;
  final epoch = int.tryParse(raw);
  if (epoch != null && epoch > 1000000000) {
    final ms = epoch > 1000000000000 ? epoch : epoch * 1000;
    return DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
  }
  final isoDate = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw);
  if (isoDate != null) {
    final y = int.tryParse(isoDate.group(1)!);
    final m = int.tryParse(isoDate.group(2)!);
    final d = int.tryParse(isoDate.group(3)!);
    if (y != null && m != null && d != null) return DateTime(y, m, d);
  }
  final ddMm = RegExp(r'^(\d{1,2})[-/](\d{1,2})[-/](\d{4})$').firstMatch(raw);
  if (ddMm != null) {
    final d = int.tryParse(ddMm.group(1)!);
    final m = int.tryParse(ddMm.group(2)!);
    final y = int.tryParse(ddMm.group(3)!);
    if (y != null && m != null && d != null) return DateTime(y, m, d);
  }
  final hasZone = raw.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(raw);
  if (hasZone) return DateTime.tryParse(raw)?.toLocal();
  if (raw.contains('T')) return DateTime.tryParse(raw + 'Z')?.toLocal();
  if (raw.contains(' ') && raw.contains('-')) {
    return DateTime.tryParse(raw.replaceFirst(' ', 'T') + 'Z')?.toLocal();
  }
  return DateTime.tryParse(raw + 'Z')?.toLocal();
}

bool _isResolvedStatus(String status) =>
    const {'RESOLVED', 'CLOSED'}.contains(status.toUpperCase());

bool _isOpenStatus(String status) => const {
      'NEW',
      'OPEN',
      'IN_PROGRESS',
      'PENDING'
    }.contains(status.toUpperCase());

int _daysForRange(String range) {
  switch (range) {
    case 'DAILY_14':
      return 14;
    case 'WEEKLY_60':
      return 60;
    case 'MONTHLY_180':
      return 180;
    default:
      return 14;
  }
}

bool _inSelectedRange(Map<String, dynamic> ticket, String range) {
  final dateFields = [
    'createdAt', 'created_at', 'createdDate', 'timestamp', 'updatedAt', 'date',
  ];
  DateTime? createdAt;
  for (final field in dateFields) {
    createdAt = _analyticsDate(ticket[field]);
    if (createdAt != null) break;
  }
  if (createdAt == null) return true;
  if (createdAt.isAfter(DateTime.now())) return true;
  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day);
  final cutoff = startOfToday.subtract(Duration(days: _daysForRange(range)));
  return !createdAt.isBefore(cutoff);
}

const _slaByPriority = {
  'LOW': 72,
  'MEDIUM': 24,
  'HIGH': 8,
  'URGENT': 4,
  'CRITICAL': 2,
};

bool _isSlaBreached(Map<String, dynamic> ticket) {
  final status = (ticket['status'] ?? '').toString().toUpperCase();
  if (_isResolvedStatus(status)) return false;

  if (ticket['slaBreached'] == true ||
      ticket['isSlaBreached'] == true ||
      ticket['breached'] == true) {
    return true;
  }

  final created = _analyticsDate(ticket['createdAt']);
  if (created == null) return false;

  final priority = (ticket['priority'] ?? 'MEDIUM').toString().toUpperCase();
  final windowHours = _slaByPriority[priority] ?? 24;
  return DateTime.now().difference(created).inHours >= windowHours;
}

String _ticketAgentName(Map<String, dynamic> ticket) {
  final candidates = [
    ticket['agentName'],
    ticket['consultantName'],
    ticket['assignedToName'],
  ];
  for (final raw in candidates) {
    final name = '${raw ?? ''}'.trim();
    if (name.isNotEmpty) return name;
  }
  return '';
}

class _VolumePoint {
  final String label;
  final int created;
  final int resolved;
  const _VolumePoint(this.label, this.created, this.resolved);
}

class _AgentRollup {
  final String name;
  final int assigned;
  final int resolved;
  final int totalResolutionMinutes;
  final int resolvedWithDuration;

  const _AgentRollup({
    required this.name,
    required this.assigned,
    required this.resolved,
    required this.totalResolutionMinutes,
    required this.resolvedWithDuration,
  });

  double get resolutionRate => assigned == 0 ? 0 : resolved * 100 / assigned;

  int get avgResolutionMinutes => resolvedWithDuration == 0
      ? 0
      : (totalResolutionMinutes / resolvedWithDuration).round();
}

class _MetricTab {
  final String key;
  final String label;
  final IconData icon;
  const _MetricTab(this.key, this.label, this.icon);
}

class _BookingConsultantRollup {
  final String name;
  final int total;
  final int pending;
  final int completed;
  final double revenue;

  const _BookingConsultantRollup({
    required this.name,
    required this.total,
    required this.pending,
    required this.completed,
    required this.revenue,
  });
}

class AdminAnalyticsWebTab extends StatefulWidget {
  const AdminAnalyticsWebTab({super.key});

  @override
  State<AdminAnalyticsWebTab> createState() => _AdminAnalyticsWebTabState();
}

class _AdminAnalyticsWebTabState extends State<AdminAnalyticsWebTab> {
  final AnalyticsService _analyticsService = AnalyticsService();
  final BookingService _bookingService = BookingService();

  bool _loading = true;
  List<Map<String, dynamic>> _tickets = const [];
  List<Booking> _bookings = const [];
  String _metric = 'ticket_volume';
  String _range = 'DAILY_14';
  Timer? _pollTimer;

  static const _metricTabs = [
    _MetricTab('ticket_volume', 'Ticket Volume', Icons.show_chart_rounded),
    _MetricTab(
        'agent_performance', 'Agent Performance', Icons.person_search_rounded),
    _MetricTab('customer_satisfaction', 'Customer Satisfaction',
        Icons.sentiment_satisfied_alt_rounded),
    _MetricTab('sla_breach', 'SLA Breach', Icons.warning_amber_rounded),
    _MetricTab(
        'bookings_revenue', 'Bookings & Revenue', Icons.payments_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _load();
    _pollTimer =
        Timer.periodic(const Duration(seconds: 25), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final results = await Future.wait<dynamic>([
        _fetchAllTicketsForAnalytics().catchError((_) => <Map<String, dynamic>>[]),
        _fetchAllBookings().catchError((_) => <Booking>[]),
      ]);
      final rows = (results[0] as List)
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
      final bookings = results[1] as List<Booking>;
      if (!mounted) return;
      setState(() {
        _tickets = rows;
        _bookings = bookings;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchAllTicketsForAnalytics() async {
    final client = ApiClient().dio;
    final endpoints = <Future<dynamic> Function()>[
      () => client.get('/api/tickets',
          queryParameters: {'page': 0, 'size': 500, 'sort': 'createdAt,DESC'}),
      () => client.get('/api/tickets',
          queryParameters: {'page': 0, 'size': 200}),
      () => client.get('/api/analytics/tickets/all'),
      () => client.get('/api/analytics/tickets',
          queryParameters: {'size': 500}),
    ];
    for (final ep in endpoints) {
      try {
        final response = await ep();
        final data = response.data;
        List<dynamic> items = [];
        if (data is List) {
          items = data;
        } else if (data is Map) {
          items = (data['content'] ?? data['data'] ?? data['items'] ??
              data['tickets'] ?? data['rows'] ?? []) as List;
        }
        if (items.isEmpty) continue;
        final maps = items
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        if (data is Map) {
          final totalPages = (data['totalPages'] as num?)?.toInt() ?? 1;
          if (totalPages > 1) {
            final size = (data['size'] as num?)?.toInt() ?? 200;
            for (var page = 1; page < totalPages && page < 10; page++) {
              try {
                final next = await client.get('/api/tickets',
                    queryParameters: {'page': page, 'size': size});
                if (next.data is Map) {
                  final nd = next.data as Map;
                  final ni = (nd['content'] ?? nd['data'] ?? nd['items'] ?? []) as List;
                  maps.addAll(ni.whereType<Map>()
                      .map((e) => Map<String, dynamic>.from(e as Map)));
                }
              } catch (_) {}
            }
          }
        }
        if (maps.isNotEmpty) return maps;
      } catch (_) {}
    }
    return [];

  }
  Future<List<Booking>> _fetchAllBookings() async {
    final regular = <Booking>[];
    try {
      final first =
          await _bookingService.getAllBookingsPaginated(page: 0, size: 200);
      regular.addAll(first['bookings'] as List<Booking>? ?? const <Booking>[]);

      final totalPages = (first['totalPages'] as int?) ?? 1;
      for (var page = 1; page < totalPages; page++) {
        final next =
            await _bookingService.getAllBookingsPaginated(page: page, size: 200);
        regular.addAll(next['bookings'] as List<Booking>? ?? const <Booking>[]);
      }

      if (regular.isEmpty) {
        regular.addAll(await _bookingService.getAllBookings(page: 0, size: 200));
      }
    } catch (_) {}

    final specialRows = await _bookingService.getAllSpecialBookings();
    final special = specialRows
        .map(_specialBookingToBooking)
        .whereType<Booking>()
        .toList(growable: false);

    final merged = <String, Booking>{};
    for (final booking in regular) {
      merged['REG-${booking.id}'] = booking;
    }
    for (final booking in special) {
      merged['SPL-${booking.id}'] = booking;
    }
    return merged.values.toList(growable: false);
  }

  String _firstBookingText(List<dynamic> values) {
    for (final value in values) {
      final text = (value ?? '').toString().trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return '';
  }

  String _normalizeSpecialStatus(dynamic raw) {
    final status = (raw ?? '').toString().trim().toUpperCase();
    if (status == 'COMPLETED') return 'COMPLETED';
    if (status == 'CANCELLED' || status == 'CANCELED' || status == 'REJECTED') {
      return 'CANCELLED';
    }
    if (status == 'CONFIRMED' || status == 'SCHEDULED') return 'CONFIRMED';
    return 'PENDING';
  }

  Booking? _specialBookingToBooking(Map<String, dynamic> row) {
    final id = (row['id'] as num?)?.toInt();
    if (id == null || id <= 0) return null;

    final status = _normalizeSpecialStatus(row['status']);
    final consultantName = _firstBookingText([
      row['consultantName'],
      row['consultant'] is Map ? row['consultant']['name'] : null,
      row['consultant'] is Map ? row['consultant']['fullName'] : null,
    ]);
    final clientName = _firstBookingText([
      row['clientName'],
      row['userName'],
      row['user'] is Map ? row['user']['name'] : null,
      row['user'] is Map ? row['user']['fullName'] : null,
      row['userEmail'],
    ]);
    final slotDate = _firstBookingText([
      row['scheduledDate'],
      row['scheduled_date'],
      row['slotDate'],
      row['bookingDate'],
      row['date'],
    ]);
    final timeRange = _firstBookingText([
      row['scheduledTimeRange'],
      row['scheduled_time_range'],
      row['timeRange'],
      row['scheduledTime'],
      row['slotTime'],
      row['time'],
    ]);

    final data = <String, dynamic>{
      'id': id,
      'bookingStatus': status,
      'status': status,
      'consultantId': row['consultantId'] ?? row['consultant_id'],
      'consultantName': consultantName,
      'userId': row['userId'] ?? row['user_id'],
      'clientName': clientName,
      'slotDate': slotDate,
      'timeRange': timeRange,
      'meetingMode': row['meetingMode'] ?? row['meeting_mode'],
      'paymentStatus': row['paymentStatus'] ?? row['payment_status'],
      'totalAmount': row['totalAmount'] ??
          row['sessionAmount'] ??
          row['amount'] ??
          row['baseAmount'],
      'createdAt': row['createdAt'] ?? row['created_at'],
    };
    return Booking.fromJson(data);
  }

  List<Map<String, dynamic>> get _scopedTickets => _tickets
      .where((t) => _inSelectedRange(t, _range))
      .toList(growable: false);

  int get _resolvedCount {
    var count = 0;
    for (final t in _scopedTickets) {
      final status = (t['status'] ?? '').toString().toUpperCase();
      if (_isResolvedStatus(status)) count++;
    }
    return count;
  }

  int get _openCount {
    var count = 0;
    for (final t in _scopedTickets) {
      final status = (t['status'] ?? '').toString().toUpperCase();
      if (_isOpenStatus(status)) count++;
    }
    return count;
  }

  int get _slaBreachedCount {
    var count = 0;
    for (final t in _scopedTickets) {
      if (_isSlaBreached(t)) count++;
    }
    return count;
  }

  DateTime? _bookingDate(Booking booking) =>
      _analyticsDate(booking.slotDate ?? booking.createdAt);

  bool _inBookingRange(Booking booking) {
    final date = _bookingDate(booking);
    if (date == null) return true;
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final cutoff =
        startOfToday.subtract(Duration(days: _daysForRange(_range) - 1));
    return !date.isBefore(cutoff);
  }

  List<Booking> get _scopedBookings =>
      _bookings.where(_inBookingRange).toList(growable: false);

  String _bookingStatus(Booking booking) => booking.status.toUpperCase();

  bool _isCompletedBooking(Booking booking) {
    final status = _bookingStatus(booking);
    return status == 'COMPLETED';
  }

  bool _isPendingBooking(Booking booking) {
    final status = _bookingStatus(booking);
    return status == 'PENDING' ||
        status == 'CONFIRMED' ||
        status == 'NEW' ||
        status == 'OPEN' ||
        status == 'IN_PROGRESS';
  }

  String _money(num amount) =>
      'Rs ${NumberFormat.decimalPattern('en_IN').format(amount.round())}';

  List<_BookingConsultantRollup> _buildConsultantBookingRows() {
    final map = <String, _BookingConsultantRollup>{};
    for (final booking in _scopedBookings) {
      final name = (booking.consultantName ?? '').trim().isEmpty
          ? 'Unassigned'
          : booking.consultantName!.trim();
      final current = map[name] ??
          _BookingConsultantRollup(
            name: name,
            total: 0,
            pending: 0,
            completed: 0,
            revenue: 0,
          );
      final completed = _isCompletedBooking(booking);
      final pending = _isPendingBooking(booking);
      final next = _BookingConsultantRollup(
        name: name,
        total: current.total + 1,
        pending: current.pending + (pending ? 1 : 0),
        completed: current.completed + (completed ? 1 : 0),
        revenue: current.revenue + (completed ? (booking.amount ?? 0) : 0),
      );
      map[name] = next;
    }
    final rows = map.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    return rows;
  }

  List<_VolumePoint> _buildVolumeSeries() {
    final now = DateTime.now();
    final points = <_VolumePoint>[];

    if (_range == 'DAILY_14') {
      for (var i = 13; i >= 0; i--) {
        final day =
            DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
        final created = _scopedTickets.where((ticket) {
          final createdAt = _analyticsDate(ticket['createdAt']);
          if (createdAt == null) return false;
          return createdAt.year == day.year &&
              createdAt.month == day.month &&
              createdAt.day == day.day;
        }).length;

        final resolved = _scopedTickets.where((ticket) {
          final status = (ticket['status'] ?? '').toString().toUpperCase();
          if (!_isResolvedStatus(status)) return false;
          final closedAt = _analyticsDate(ticket['resolvedAt'] ??
              ticket['closedAt'] ??
              ticket['updatedAt']);
          if (closedAt == null) return false;
          return closedAt.year == day.year &&
              closedAt.month == day.month &&
              closedAt.day == day.day;
        }).length;

        points.add(
            _VolumePoint(DateFormat('d MMM').format(day), created, resolved));
      }
      return points;
    }

    if (_range == 'WEEKLY_60') {
      const weeks = 9;
      for (var i = weeks - 1; i >= 0; i--) {
        final end = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: i * 7));
        final start = end.subtract(const Duration(days: 6));
        final created = _scopedTickets.where((ticket) {
          final createdAt = _analyticsDate(ticket['createdAt']);
          if (createdAt == null) return false;
          return !createdAt.isBefore(start) &&
              !createdAt
                  .isAfter(DateTime(end.year, end.month, end.day, 23, 59, 59));
        }).length;
        final resolved = _scopedTickets.where((ticket) {
          final status = (ticket['status'] ?? '').toString().toUpperCase();
          if (!_isResolvedStatus(status)) return false;
          final closedAt = _analyticsDate(ticket['resolvedAt'] ??
              ticket['closedAt'] ??
              ticket['updatedAt']);
          if (closedAt == null) return false;
          return !closedAt.isBefore(start) &&
              !closedAt
                  .isAfter(DateTime(end.year, end.month, end.day, 23, 59, 59));
        }).length;
        points.add(_VolumePoint(
          '${DateFormat('d MMM').format(start)}-${DateFormat('d MMM').format(end)}',
          created,
          resolved,
        ));
      }
      return points;
    }

    for (var i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final created = _scopedTickets.where((ticket) {
        final createdAt = _analyticsDate(ticket['createdAt']);
        if (createdAt == null) return false;
        return createdAt.year == month.year && createdAt.month == month.month;
      }).length;
      final resolved = _scopedTickets.where((ticket) {
        final status = (ticket['status'] ?? '').toString().toUpperCase();
        if (!_isResolvedStatus(status)) return false;
        final closedAt = _analyticsDate(
            ticket['resolvedAt'] ?? ticket['closedAt'] ?? ticket['updatedAt']);
        if (closedAt == null) return false;
        return closedAt.year == month.year && closedAt.month == month.month;
      }).length;
      points.add(
          _VolumePoint(DateFormat('MMM').format(month), created, resolved));
    }
    return points;
  }

  List<_AgentRollup> _buildAgentRows() {
    final map = <String, _AgentRollup>{};
    for (final ticket in _scopedTickets) {
      final agent = _ticketAgentName(ticket);
      if (agent.isEmpty) continue;

      final current = map[agent] ??
          _AgentRollup(
            name: agent,
            assigned: 0,
            resolved: 0,
            totalResolutionMinutes: 0,
            resolvedWithDuration: 0,
          );

      final status = (ticket['status'] ?? '').toString().toUpperCase();
      var resolved = current.resolved;
      var totalMinutes = current.totalResolutionMinutes;
      var resolvedWithDuration = current.resolvedWithDuration;

      if (_isResolvedStatus(status)) {
        resolved++;
        final start = _analyticsDate(ticket['createdAt']);
        final end = _analyticsDate(
            ticket['resolvedAt'] ?? ticket['closedAt'] ?? ticket['updatedAt']);
        if (start != null && end != null && !end.isBefore(start)) {
          totalMinutes += end.difference(start).inMinutes;
          resolvedWithDuration++;
        }
      }

      map[agent] = _AgentRollup(
        name: agent,
        assigned: current.assigned + 1,
        resolved: resolved,
        totalResolutionMinutes: totalMinutes,
        resolvedWithDuration: resolvedWithDuration,
      );
    }
    final rows = map.values.toList()
      ..sort((a, b) => b.assigned.compareTo(a.assigned));
    return rows;
  }

  Widget _buildMetricTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _metricTabs.map((tab) {
            final active = _metric == tab.key;
            return GestureDetector(
              onTap: () => setState(() => _metric = tab.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 170),
                margin: const EdgeInsets.only(right: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: active ? const Color(0xFFF8FAFC) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color:
                        active ? const Color(0xFFE2E8F0) : Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      tab.icon,
                      size: 14,
                      color: active
                          ? const Color(0xFF0F766E)
                          : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      tab.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: active
                            ? const Color(0xFF0F766E)
                            : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _rangeChip(String key, String label) {
    final active = _range == key;
    return GestureDetector(
      onTap: () => setState(() => _range = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFCCFBF1) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? const Color(0xFF0F766E) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? const Color(0xFF0F766E) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildRangeTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _rangeChip('DAILY_14', 'Daily (14d)'),
          const SizedBox(width: 8),
          _rangeChip('WEEKLY_60', 'Weekly (60d)'),
          const SizedBox(width: 8),
          _rangeChip('MONTHLY_180', 'Monthly (180d)'),
        ],
      ),
    );
  }

  Widget _kpiCard({
    required String value,
    required String label,
    required String sub,
    required Color valueColor,
    Color bg = Colors.white,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 38 / 1.7,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              letterSpacing: 0.9,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF475569),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsGrid(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var count = 1;
        if (constraints.maxWidth >= 1100) {
          count = 4;
        } else if (constraints.maxWidth >= 760) {
          count = 2;
        }
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: count,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: count == 1 ? 3.2 : 2.0,
          children: children,
        );
      },
    );
  }

  Widget _buildTicketVolumeContent() {
    final total = _scopedTickets.length;
    final resolved = _resolvedCount;
    final open = _openCount;
    final rate = total == 0 ? 0 : (resolved * 100 / total);
    final points = _buildVolumeSeries();
    final maxY = max<double>(
      1,
      points.fold<double>(0,
          (m, p) => max(m, max(p.created.toDouble(), p.resolved.toDouble()))),
    );

    return Column(
      children: [
        _statsGrid([
          _kpiCard(
            value: '$total',
            label: 'Total Tickets',
            sub: '$total in selected range',
            valueColor: const Color(0xFF0F766E),
            bg: const Color(0xFFECFEFF).withValues(alpha: 0.35),
          ),
          _kpiCard(
            value: '$resolved',
            label: 'Resolved / Closed',
            sub:
                '${total > 0 ? (resolved * 100 / total).toStringAsFixed(0) : 0}% overall rate',
            valueColor: const Color(0xFF16A34A),
            bg: const Color(0xFFF0FDF4),
          ),
          _kpiCard(
            value: '$open',
            label: 'Open / Active',
            sub: '$open in range',
            valueColor: const Color(0xFFD97706),
            bg: const Color(0xFFFFFBEB),
          ),
          _kpiCard(
            value: '${rate.toStringAsFixed(0)}%',
            label: 'Resolution Rate',
            sub: 'all-time range view',
            valueColor: const Color(0xFF7C3AED),
            bg: const Color(0xFFF5F3FF),
          ),
        ]),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ticket Volume - Last ${_daysForRange(_range)} Days (IST)',
                style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'Created vs resolved tickets per period',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),
              if (points.isEmpty)
                const SizedBox(
                  height: 180,
                  child: Center(
                    child: Text(
                      'No ticket data available',
                      style: TextStyle(color: Color(0xFF94A3B8)),
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 230,
                  child: BarChart(
                    BarChartData(
                      maxY: maxY * 1.25,
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) => const FlLine(
                            color: Color(0xFFF1F5F9), strokeWidth: 1),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx < 0 || idx >= points.length) {
                                return const SizedBox.shrink();
                              }
                              final full = points[idx].label;
                              final short = _range == 'DAILY_14'
                                  ? full
                                  : full.split('-').first;
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Transform.rotate(
                                  angle: _range == 'DAILY_14' ? -0.55 : 0,
                                  child: Text(
                                    short,
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: points.asMap().entries.map((entry) {
                        final i = entry.key;
                        final point = entry.value;
                        return BarChartGroupData(
                          x: i,
                          barsSpace: 3,
                          barRods: [
                            BarChartRodData(
                              toY: point.created.toDouble(),
                              width: _range == 'DAILY_14' ? 8 : 12,
                              color: const Color(0xFF8FE3EE),
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4)),
                            ),
                            BarChartRodData(
                              toY: point.resolved.toDouble(),
                              width: _range == 'DAILY_14' ? 8 : 12,
                              color: const Color(0xFF52B788),
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4)),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 16,
                children: const [
                  _LegendDot(color: Color(0xFF8FE3EE), label: 'Created'),
                  _LegendDot(
                      color: Color(0xFF52B788), label: 'Resolved/Closed'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAgentPerformanceContent() {
    final rows = _buildAgentRows();
    final totalAssigned = rows.fold<int>(0, (sum, row) => sum + row.assigned);
    final totalResolved = rows.fold<int>(0, (sum, row) => sum + row.resolved);
    final avgRate =
        totalAssigned == 0 ? 0 : totalResolved * 100 / totalAssigned;

    return Column(
      children: [
        _statsGrid([
          _kpiCard(
            value: '${rows.length}',
            label: 'Total Agents',
            sub: 'with assigned tickets',
            valueColor: const Color(0xFF0F766E),
            bg: const Color(0xFFECFEFF).withValues(alpha: 0.35),
          ),
          _kpiCard(
            value: '$totalAssigned',
            label: 'Total Assigned',
            sub: 'of ${_scopedTickets.length} total tickets',
            valueColor: const Color(0xFFD97706),
            bg: const Color(0xFFFFFBEB),
          ),
          _kpiCard(
            value: '${avgRate.toStringAsFixed(0)}%',
            label: 'Avg Resolution Rate',
            sub: 'team average',
            valueColor: const Color(0xFF16A34A),
            bg: const Color(0xFFF0FDF4),
          ),
        ]),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        'CONSULTANT / AGENT',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 0.6,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'ASSIGNED',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 0.6,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'RESOLVED',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 0.6,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'AVG TIME',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 0.6,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'RATE',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 0.6,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (rows.isEmpty)
                SizedBox(
                  height: 250,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.bar_chart_rounded,
                          size: 46,
                          color: Color(0xFFCBD5E1),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No assigned tickets yet',
                          style: TextStyle(
                            fontSize: 22 / 1.4,
                            color: Color(0xFF475569),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "When tickets are assigned, performance metrics will appear here.",
                          style:
                              TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton(
                          onPressed: _load,
                          child: const Text('Refresh Data'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...rows.map((row) {
                  final rate = row.resolutionRate;
                  final avgMinutes = row.avgResolutionMinutes;
                  final avgStr = avgMinutes == 0
                      ? '--'
                      : avgMinutes >= 60
                          ? '${(avgMinutes / 60).toStringAsFixed(1)}h'
                          : '${avgMinutes}m';
                  final rateColor = rate >= 80
                      ? const Color(0xFF16A34A)
                      : rate >= 50
                          ? const Color(0xFFD97706)
                          : const Color(0xFFDC2626);
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: Text(
                            row.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF0F172A),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${row.assigned}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${row.resolved}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: rateColor),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            avgStr,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${rate.toStringAsFixed(0)}%',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: rateColor),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerSatisfaction() {
    final ratings = <double>[];
    for (final ticket in _scopedTickets) {
      final ratingRaw = ticket['rating'] ??
          ticket['feedbackRating'] ??
          ticket['customerRating'] ??
          ticket['avgRating'];
      final rating = double.tryParse('${ratingRaw ?? ''}');
      if (rating != null && rating > 0) ratings.add(rating);
    }

    final avg =
        ratings.isEmpty ? 0 : ratings.reduce((a, b) => a + b) / ratings.length;
    final buckets = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    for (final rating in ratings) {
      final bucket = rating.round().clamp(1, 5);
      buckets[bucket] = (buckets[bucket] ?? 0) + 1;
    }
    final totalReviews = ratings.length;
    final fiveStars = buckets[5] ?? 0;

    return Column(
      children: [
        _statsGrid([
          _kpiCard(
            value: ratings.isEmpty ? '--' : '${avg.toStringAsFixed(1)} / 5',
            label: 'Average Rating',
            sub: 'from $totalReviews reviews',
            valueColor: const Color(0xFFF59E0B),
            bg: const Color(0xFFFFFBEB),
          ),
          _kpiCard(
            value: '$totalReviews',
            label: 'Total Reviews',
            sub: '$totalReviews total reviews collected',
            valueColor: const Color(0xFF7C3AED),
            bg: const Color(0xFFF5F3FF),
          ),
          _kpiCard(
            value: '$fiveStars',
            label: '5-Star Reviews',
            sub:
                '${totalReviews == 0 ? 0 : ((fiveStars * 100) / totalReviews).toStringAsFixed(0)}% of total',
            valueColor: const Color(0xFF16A34A),
            bg: const Color(0xFFF0FDF4),
          ),
        ]),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Rating Distribution', style: AppTextStyles.h4),
              const SizedBox(height: 12),
              for (var star = 5; star >= 1; star--)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 30,
                        child: Text(
                          '$star *',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF334155),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: totalReviews == 0
                                ? 0
                                : (buckets[star] ?? 0) / totalReviews,
                            minHeight: 8,
                            backgroundColor: const Color(0xFFF1F5F9),
                            valueColor: AlwaysStoppedAnimation(
                              star >= 4
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFCBD5E1),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 72,
                        child: Text(
                          '${buckets[star] ?? 0} (${totalReviews == 0 ? 0 : (((buckets[star] ?? 0) * 100) / totalReviews).round()}%)',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF475569),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSlaContent() {
    final breached =
        _scopedTickets.where(_isSlaBreached).toList(growable: false);
    final breachRate = _scopedTickets.isEmpty
        ? 0
        : breached.length * 100 / _scopedTickets.length;
    final openBreaches = breached
        .where((ticket) => _isOpenStatus((ticket['status'] ?? '').toString()))
        .length;
    final byPriority = <String, int>{};
    for (final ticket in breached) {
      final p = (ticket['priority'] ?? 'MEDIUM').toString().toUpperCase();
      byPriority[p] = (byPriority[p] ?? 0) + 1;
    }
    final sorted = byPriority.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: [
        _statsGrid([
          _kpiCard(
            value: '${breached.length}',
            label: 'SLA Breached',
            sub: 'in selected range',
            valueColor: const Color(0xFFDC2626),
            bg: const Color(0xFFFEF2F2),
          ),
          _kpiCard(
            value: '${breachRate.toStringAsFixed(0)}%',
            label: 'Breach Rate',
            sub: 'of total tickets',
            valueColor: const Color(0xFFD97706),
            bg: const Color(0xFFFFFBEB),
          ),
          _kpiCard(
            value: '$openBreaches',
            label: 'Open Breaches',
            sub: 'need immediate action',
            valueColor: const Color(0xFFB91C1C),
            bg: const Color(0xFFFEF2F2),
          ),
        ]),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SLA Breaches by Priority', style: AppTextStyles.h4),
              const SizedBox(height: 10),
              if (sorted.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'No SLA breaches in this range',
                      style: TextStyle(color: Color(0xFF94A3B8)),
                    ),
                  ),
                )
              else
                ...sorted.map((entry) {
                  final color = getPriorityColor(entry.key);
                  final maxVal = sorted.first.value.toDouble();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.key,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ),
                            Text(
                              '${entry.value}',
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: LinearProgressIndicator(
                            value: entry.value / maxVal,
                            minHeight: 8,
                            backgroundColor: color.withValues(alpha: 0.12),
                            valueColor: AlwaysStoppedAnimation(color),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBookingsRevenueContent() {
    final scoped = _scopedBookings;
    final completed = scoped.where(_isCompletedBooking).toList(growable: false);
    final totalRevenue = completed.fold<double>(
        0, (sum, booking) => sum + (booking.amount ?? 0));
    final pendingOrConfirmed = scoped.where(_isPendingBooking).length;
    final consultantRows = _buildConsultantBookingRows();
    final activeConsultants =
        consultantRows.where((row) => row.name != 'Unassigned').length;

    return Column(
      children: [
        _statsGrid([
          _kpiCard(
            value: '${scoped.length}',
            label: 'Total Bookings',
            sub: '$pendingOrConfirmed pending / confirmed',
            valueColor: const Color(0xFF0F766E),
            bg: const Color(0xFFECFEFF).withValues(alpha: 0.35),
          ),
          _kpiCard(
            value: '${completed.length}',
            label: 'Completed',
            sub:
                '${scoped.isEmpty ? 0 : ((completed.length * 100) / scoped.length).toStringAsFixed(0)}% completion rate',
            valueColor: const Color(0xFF16A34A),
            bg: const Color(0xFFF0FDF4),
          ),
          _kpiCard(
            value: _money(totalRevenue),
            label: 'Total Revenue',
            sub: 'from completed bookings',
            valueColor: const Color(0xFF059669),
            bg: const Color(0xFFF0FDF4),
          ),
          _kpiCard(
            value: '$activeConsultants',
            label: 'Active Consultants',
            sub: '$activeConsultants with bookings',
            valueColor: const Color(0xFF7C3AED),
            bg: const Color(0xFFF5F3FF),
          ),
        ]),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Consultant Breakdown', style: AppTextStyles.h4),
              const SizedBox(height: 10),
              if (consultantRows.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: Text(
                      'No booking data available',
                      style: TextStyle(color: Color(0xFF94A3B8)),
                    ),
                  ),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: 680,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: Text(
                                  'CONSULTANT',
                                  style: TextStyle(
                                    fontSize: 10,
                                    letterSpacing: 0.6,
                                    color: Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'TOTAL',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 10,
                                    letterSpacing: 0.6,
                                    color: Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'PENDING',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 10,
                                    letterSpacing: 0.6,
                                    color: Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'COMPLETED',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 10,
                                    letterSpacing: 0.6,
                                    color: Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'REVENUE',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 10,
                                    letterSpacing: 0.6,
                                    color: Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...consultantRows.map((row) => Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 4,
                                    child: Text(
                                      row.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF0F172A),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '${row.total}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F766E),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '${row.pending}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFD97706),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '${row.completed}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF16A34A),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      row.revenue == 0
                                          ? '--'
                                          : _money(row.revenue),
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF0F766E)),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF0F766E),
      onRefresh: () => _load(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Analytics & Reports', style: AppTextStyles.h2),
                    const SizedBox(height: 4),
                    const Text(
                      'Comprehensive analytics across all tickets, agents, and customer satisfaction',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Refresh'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F766E),
                  side: const BorderSide(color: Color(0xFFA5F3FC)),
                  backgroundColor: const Color(0xFFECFEFF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildMetricTabs(),
          const SizedBox(height: 12),
          _buildRangeTabs(),
          const SizedBox(height: 14),
          if (_metric == 'ticket_volume') _buildTicketVolumeContent(),
          if (_metric == 'agent_performance') _buildAgentPerformanceContent(),
          if (_metric == 'customer_satisfaction') _buildCustomerSatisfaction(),
          if (_metric == 'sla_breach') _buildSlaContent(),
          if (_metric == 'bookings_revenue') _buildBookingsRevenueContent(),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
        ),
      ],
    );
  }
}
