// lib/booking_page.dart
// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:finadvise/api_client.dart';
import 'package:finadvise/app_theme.dart';
import 'package:finadvise/booking_answers_screen.dart';
import 'package:finadvise/models/models.dart';
import 'package:finadvise/services/booking_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';

void _snack(BuildContext ctx, String msg, {bool error = false}) {
  ScaffoldMessenger.of(ctx)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor:
            error ? const Color(0xFFDC2626) : const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        duration: Duration(seconds: error ? 4 : 2),
      ),
    );
}

String _apiError(Object error, {String fallback = 'Something went wrong.'}) {
  if (error is DioException) {
    if (error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionTimeout) {
      return 'Server took too long to respond. Please try again.';
    }
    final data = error.response?.data;
    if (data is Map) {
      final msg = data['message'] ?? data['error'];
      if (msg != null && '$msg'.trim().isNotEmpty) return '$msg'.trim();
    }
  }
  return fallback;
}

Map<String, Color> _statusColors = {
  'CONFIRMED': const Color(0xFF0F766E),
  'PENDING': const Color(0xFFD97706),
  'REQUESTED': const Color(0xFFC2410C),
  'COMPLETED': const Color(0xFF16A34A),
  'CANCELLED': const Color(0xFFEF4444),
};

Color _statusColor(String status) =>
    _statusColors[status.toUpperCase()] ?? const Color(0xFF64748B);
Color _statusBg(String status) => _statusColor(status).withValues(alpha: 0.1);

String _fmtDate(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  try {
    final iso = _normalizeDateKey(raw);
    if (iso == '9999-12-31') return raw;
    return DateFormat('d MMM yyyy').format(DateTime.parse(iso));
  } catch (_) {
    return raw;
  }
}

List<dynamic> _extractArray(
  dynamic data, {
  List<String> keys = const ['content', 'data', 'items'],
}) {
  if (data is List) return data;
  if (data is Map) {
    for (final key in keys) {
      final candidate = data[key];
      if (candidate is List) return candidate;
    }
  }
  return const [];
}

int? _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}');
}

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}') ?? 0;
}

String _string(dynamic value) => (value ?? '').toString().trim();

String _firstNonEmpty(List<dynamic> values) {
  for (final value in values) {
    final text = _string(value);
    if (text.isNotEmpty) return text;
  }
  return '';
}

dynamic _firstMeaningfulValue(List<dynamic> values) {
  for (final value in values) {
    if (value == null) continue;
    if (value is String && value.trim().isEmpty) continue;
    if (value is Map && value.isEmpty) continue;
    return value;
  }
  return null;
}

String _prettifyName(String raw) {
  if (raw.isEmpty) return raw;
  if (raw.contains('@')) {
    final local = raw.split('@').first;
    return local
        .replaceAll(RegExp(r'[._\-]+'), ' ')
        .split(' ')
        .where((p) => p.isNotEmpty)
        .map((p) => p[0].toUpperCase() + p.substring(1))
        .join(' ');
  }
  return raw;
}

String _normalizeDateKey(String raw) {
  final value = _string(raw);
  if (value.isEmpty) return '9999-12-31';

  final isoMatch = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(value);
  if (isoMatch != null) {
    return '${isoMatch.group(1)}-${isoMatch.group(2)}-${isoMatch.group(3)}';
  }

  final dashMatch = RegExp(r'^(\d{1,2})-(\d{1,2})-(\d{4})$').firstMatch(value);
  if (dashMatch != null) {
    final dd = dashMatch.group(1)!.padLeft(2, '0');
    final mm = dashMatch.group(2)!.padLeft(2, '0');
    final yyyy = dashMatch.group(3)!;
    return '$yyyy-$mm-$dd';
  }

  final slashMatch = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(value);
  if (slashMatch != null) {
    final dd = slashMatch.group(1)!.padLeft(2, '0');
    final mm = slashMatch.group(2)!.padLeft(2, '0');
    final yyyy = slashMatch.group(3)!;
    return '$yyyy-$mm-$dd';
  }

  try {
    return DateTime.parse(value).toIso8601String().split('T').first;
  } catch (_) {
    return value;
  }
}

int _parseTimeToMinutes(String value) {
  final raw = _string(value);
  if (raw.isEmpty) return 1 << 30;
  final firstPart = raw.split(RegExp('[-\u2013]')).first.trim();
  final match = RegExp(r'(\d{1,2})(?::(\d{2}))?(?::\d{2})?\s*(AM|PM)?',
          caseSensitive: false)
      .firstMatch(firstPart);
  if (match == null) return 1 << 30;

  var hour = int.tryParse(match.group(1) ?? '') ?? 0;
  final minute = int.tryParse(match.group(2) ?? '0') ?? 0;
  final period = (match.group(3) ?? '').toUpperCase();
  if (period == 'PM' && hour != 12) hour += 12;
  if (period == 'AM' && hour == 12) hour = 0;
  return hour * 60 + minute;
}

String _minutesTo12h(int totalMinutes) {
  final minutesInDay = ((totalMinutes % 1440) + 1440) % 1440;
  final hour24 = minutesInDay ~/ 60;
  final minute = minutesInDay % 60;
  final period = hour24 >= 12 ? 'PM' : 'AM';
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  return '$hour12:${minute.toString().padLeft(2, '0')} $period';
}

String _timeValueToString(dynamic raw) {
  if (raw is Map) {
    final hour = _toInt(raw['hour']);
    if (hour != null) {
      final minute = _toInt(raw['minute']) ?? 0;
      return '${hour.toString().padLeft(2, '0')}:'
          '${minute.toString().padLeft(2, '0')}';
    }
  }
  final text = _string(raw);
  if (text.isEmpty) return '';
  final basic = RegExp(r'^\d{2}:\d{2}');
  if (basic.hasMatch(text)) return text.substring(0, 5);
  return text;
}

String _buildSpecialTimeRange(String startValue, int durationHours) {
  final startMin = _parseTimeToMinutes(startValue);
  if (startMin >= (1 << 30)) return '';
  final endMin = startMin + max(1, durationHours) * 60;
  return '${_minutesTo12h(startMin)} - ${_minutesTo12h(endMin)}';
}

Map<String, dynamic>? _specialMeta(dynamic rawNotes) {
  const prefix = '[[SPECIAL_BOOKING_META]]';
  if (rawNotes is! String || !rawNotes.startsWith(prefix)) return null;
  final jsonText = rawNotes.substring(prefix.length).split('\n').first.trim();
  if (jsonText.isEmpty) return null;
  try {
    final decoded = jsonDecode(jsonText);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (_) {}
  return null;
}

List<_BookingItem> _sortChronologically(List<_BookingItem> source) {
  final list = [...source];
  list.sort((a, b) {
    final aDate = _normalizeDateKey(a.slotDate ?? '');
    final bDate = _normalizeDateKey(b.slotDate ?? '');
    final dateCmp = aDate.compareTo(bDate);
    if (dateCmp != 0) return dateCmp;
    final aTime = _parseTimeToMinutes(a.timeRange ?? '');
    final bTime = _parseTimeToMinutes(b.timeRange ?? '');
    return aTime.compareTo(bTime);
  });
  return list;
}

class _RegularPageResult {
  final List<_BookingItem> items;
  final int nextPage;
  final int totalPages;
  final int totalElements;
  final bool hasMore;

  const _RegularPageResult({
    required this.items,
    required this.nextPage,
    required this.totalPages,
    required this.totalElements,
    required this.hasMore,
  });
}

class _BookingItem {
  final int id;
  final int? userId;
  final int? consultantId;
  final String? consultantName;
  final String? clientName;
  final String? slotDate;
  final String? timeRange;
  final String status;
  final String? meetingMode;
  final double amount;
  final String? meetingLink;
  final bool isSpecial;
  final String? specialStatus;
  final String? duration;

  const _BookingItem({
    required this.id,
    required this.status,
    this.userId,
    this.consultantId,
    this.consultantName,
    this.clientName,
    this.slotDate,
    this.timeRange,
    this.meetingMode,
    this.amount = 0,
    this.meetingLink,
    this.isSpecial = false,
    this.specialStatus,
    this.duration,
  });

  factory _BookingItem.fromRegular(Booking b) => _BookingItem(
        id: b.id,
        status: b.status.toUpperCase(),
        userId: b.userId,
        consultantId: b.consultantId,
        consultantName: b.consultantName,
        clientName: b.clientName,
        slotDate: b.slotDate,
        timeRange: b.timeRange,
        meetingMode: b.meetingMode,
        amount: b.amount ?? 0,
        meetingLink: b.meetingLink,
      );

  _BookingItem copyWith({
    String? status,
    String? meetingLink,
  }) {
    return _BookingItem(
      id: id,
      status: status ?? this.status,
      userId: userId,
      consultantId: consultantId,
      consultantName: consultantName,
      clientName: clientName,
      slotDate: slotDate,
      timeRange: timeRange,
      meetingMode: meetingMode,
      amount: amount,
      meetingLink: meetingLink ?? this.meetingLink,
      isSpecial: isSpecial,
      specialStatus: specialStatus,
      duration: duration,
    );
  }

  String get statusUpper => status.toUpperCase();
  String get specialStatusUpper => (specialStatus ?? '').toUpperCase();
  String get displayStatus => isSpecial && specialStatusUpper == 'REQUESTED'
      ? 'REQUESTED'
      : statusUpper;
}

class BookingsPage extends StatefulWidget {
  final bool isAdmin;

  const BookingsPage({super.key, this.isAdmin = false});

  @override
  State<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage> {
  final BookingService _bookingService = BookingService();
  final Dio _dio = ApiClient().dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  List<_BookingItem> _regularBookings = [];
  List<_BookingItem> _specialBookings = [];

  bool _loading = true;
  bool _loadingMore = false;
  int _nextPage = 0;
  int _totalPages = 1;
  int _totalElements = 0;
  bool _hasMore = true;
  int _specialTotal = 0;

  String _filter = 'ALL';
  String _search = '';
  Timer? _pollTimer;

  static const _pageSize = 10;
  static const _baseFilters = [
    'ALL',
    'PENDING',
    'CONFIRMED',
    'COMPLETED',
    'CANCELLED',
  ];

  @override
  void initState() {
    super.initState();
    _load(reset: true);
    _pollTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _load(reset: true, silent: true),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  List<String> get _filters => _specialTotal > 0
      ? const [..._baseFilters, 'SPECIAL']
      : const [..._baseFilters];

  List<_BookingItem> get _mergedBookings =>
      _sortChronologically([..._specialBookings, ..._regularBookings]);

  List<_BookingItem> get _filtered {
    List<_BookingItem> list = _mergedBookings;
    if (_filter == 'SPECIAL') {
      list = list.where((b) => b.isSpecial).toList();
    } else if (_filter != 'ALL') {
      list = list.where((b) => b.statusUpper == _filter).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((b) {
        return (b.clientName ?? '').toLowerCase().contains(q) ||
            (b.consultantName ?? '').toLowerCase().contains(q) ||
            b.id.toString().contains(q);
      }).toList();
    }
    return list;
  }

  Map<String, int> get _counts {
    final all = _mergedBookings;
    final totalRegular = max(_totalElements, _regularBookings.length);
    return {
      'ALL': totalRegular + _specialTotal,
      'PENDING': all.where((b) => b.statusUpper == 'PENDING').length,
      'CONFIRMED': all.where((b) => b.statusUpper == 'CONFIRMED').length,
      'COMPLETED': all.where((b) => b.statusUpper == 'COMPLETED').length,
      'CANCELLED': all.where((b) => b.statusUpper == 'CANCELLED').length,
      'SPECIAL': _specialTotal,
    };
  }

  double get _revenue => _mergedBookings
      .where((b) => b.statusUpper == 'COMPLETED')
      .fold(0.0, (sum, b) => sum + b.amount);

  Future<void> _load({bool reset = false, bool silent = false}) async {
    if (reset) {
      if (!silent) {
        setState(() {
          _loading = true;
          _nextPage = 0;
          _hasMore = true;
          _regularBookings = [];
          _specialBookings = [];
          _specialTotal = 0;
          _totalElements = 0;
          _totalPages = 1;
        });
      } else {
        _nextPage = 0;
        _hasMore = true;
        _totalElements = 0;
        _totalPages = 1;
      }
    } else {
      if (_loadingMore || !_hasMore) return;
      setState(() => _loadingMore = true);
    }

    try {
      final pageToLoad = reset ? 0 : _nextPage;
      final regularFuture = _fetchRegularPage(pageToLoad);
      final specialFuture =
          reset ? _fetchSpecialBookings() : Future.value(_specialBookings);

      final results =
          await Future.wait<dynamic>([regularFuture, specialFuture]);
      final regularPage = results[0] as _RegularPageResult;
      final specialItems = results[1] as List<_BookingItem>;

      if (!mounted) return;
      setState(() {
        if (reset) {
          _regularBookings = regularPage.items;
          _specialBookings = specialItems;
        } else {
          _regularBookings.addAll(regularPage.items);
        }
        _specialTotal = _specialBookings.length;
        _nextPage = regularPage.nextPage;
        _totalPages = regularPage.totalPages;
        _totalElements = regularPage.totalElements;
        _hasMore = regularPage.hasMore;
        _loading = false;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted && !silent) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      } else if (mounted) {
        setState(() => _loadingMore = false);
      }
    }
  }

  Future<_RegularPageResult> _fetchRegularPage(int page) async {
    if (widget.isAdmin) {
      final result = await _bookingService.getAllBookingsPaginated(
        page: page,
        size: _pageSize,
      );
      final rowsRaw = result['bookings'];
      final rows =
          rowsRaw is List ? rowsRaw.whereType<Booking>().toList() : <Booking>[];

      final mapped = rows.map(_BookingItem.fromRegular).toList();
      final totalPages = max(1, _toInt(result['totalPages']) ?? 1);
      final currentPage = _toInt(result['currentPage']) ?? page;
      final totalElements = _toInt(result['totalElements']) ?? mapped.length;
      final nextPage = currentPage + 1;

      return _RegularPageResult(
        items: mapped,
        nextPage: nextPage,
        totalPages: totalPages,
        totalElements: totalElements,
        hasMore: nextPage < totalPages,
      );
    }

    final consultantId = _toInt(await _storage.read(key: 'consultant_id'));
    final rows = consultantId != null && consultantId > 0
        ? await _bookingService.getBookingsByConsultant(
            consultantId,
            page: page,
            size: _pageSize,
          )
        : await _bookingService.getMyBookings(page: page, size: _pageSize);
    final mapped = rows.map(_BookingItem.fromRegular).toList();
    return _RegularPageResult(
      items: mapped,
      nextPage: page + 1,
      totalPages: page + (mapped.length == _pageSize ? 2 : 1),
      totalElements: _totalElements + mapped.length,
      hasMore: mapped.length == _pageSize,
    );
  }

  Future<List<_BookingItem>> _fetchSpecialBookings() async {
    int? consultantId;
    if (!widget.isAdmin) {
      consultantId = _toInt(await _storage.read(key: 'consultant_id'));
      if (consultantId == null) return const [];
    }

    final endpoints = <String>[
      if (widget.isAdmin) '/api/special-bookings?page=0&size=200',
      if (widget.isAdmin) '/api/special-bookings/all',
      if (widget.isAdmin) '/api/special-bookings',
      if (!widget.isAdmin && consultantId != null)
        '/api/special-bookings/consultant/$consultantId',
      if (!widget.isAdmin && consultantId != null)
        '/api/consultants/$consultantId/special-bookings',
      if (!widget.isAdmin && consultantId != null)
        '/api/special-bookings?consultantId=$consultantId',
    ];

    for (final endpoint in endpoints) {
      try {
        final response = await _dio.get(endpoint);
        final raw = _extractArray(response.data);
        return _mapSpecialRaw(raw, consultantId: consultantId);
      } catch (_) {}
    }
    return const [];
  }

  List<_BookingItem> _mapSpecialRaw(
    List<dynamic> raw, {
    int? consultantId,
  }) {
    final mapped = <_BookingItem>[];
    for (final item in raw.whereType<Map>()) {
      final row = Map<String, dynamic>.from(item);
      final id = _toInt(row['id']) ?? 0;
      if (id <= 0) continue;

      final rawStatus = _string(row['status']).toUpperCase();
      final displayStatus = rawStatus == 'REQUESTED'
          ? 'PENDING'
          : rawStatus == 'SCHEDULED'
              ? 'CONFIRMED'
              : (rawStatus.isEmpty ? 'PENDING' : rawStatus);

      final meta = _specialMeta(row['userNotes']);
      final durationHours = max(
          1, _toInt(row['durationInHours'] ?? row['duration_in_hours']) ?? 1);
      final duration = durationHours == 1 ? '1 hr' : '$durationHours hrs';

      final date = _firstNonEmpty([
        row['scheduledDate'],
        row['scheduled_date'],
        meta?['scheduledDate'],
        meta?['preferredDate'],
      ]);

      final scheduledTimeRaw = _firstMeaningfulValue([
        row['scheduledTime'],
        row['scheduled_time'],
        meta?['scheduledTime'],
        meta?['preferredTime'],
      ]);
      final scheduledTime = _timeValueToString(scheduledTimeRaw);

      var timeRange = _firstNonEmpty([
        row['scheduledTimeRange'],
        row['timeRange'],
        meta?['scheduledTimeRange'],
        meta?['preferredTimeRange'],
      ]);
      if (timeRange.isEmpty && scheduledTime.isNotEmpty) {
        timeRange = _buildSpecialTimeRange(scheduledTime, durationHours);
      }

      final userName = _prettifyName(_firstNonEmpty([
        row['user'] is Map ? row['user']['name'] : null,
        row['user'] is Map ? row['user']['fullName'] : null,
        row['user'] is Map ? row['user']['username'] : null,
        row['userName'],
        row['clientName'],
      ]));

      final advisorName = _firstNonEmpty([
        row['consultant'] is Map ? row['consultant']['name'] : null,
        row['consultant'] is Map ? row['consultant']['fullName'] : null,
        row['consultantName'],
      ]);

      mapped.add(
        _BookingItem(
          id: id,
          status: displayStatus,
          userId: _toInt(row['userId'] ?? row['user_id']),
          consultantId: _toInt(row['consultantId']) ?? consultantId,
          consultantName: advisorName.isEmpty ? 'Consultant' : advisorName,
          clientName: userName.isEmpty ? 'Client' : userName,
          slotDate: date.isEmpty ? null : date,
          timeRange: timeRange.isEmpty ? null : timeRange,
          meetingMode: _firstNonEmpty([
            row['meetingMode'],
            row['meeting_mode'],
            'ONLINE',
          ]).toUpperCase(),
          amount: _toDouble(
            row['sessionAmount'] ??
                row['totalAmount'] ??
                row['total_amount'] ??
                row['amount'] ??
                row['charges'],
          ),
          isSpecial: true,
          specialStatus: rawStatus.isEmpty ? null : rawStatus,
          duration: duration,
        ),
      );
    }
    return mapped;
  }

  void _updateRegularBooking(
    _BookingItem booking, {
    required String status,
    String? meetingLink,
  }) {
    _regularBookings = _regularBookings.map((b) {
      if (b.id != booking.id) return b;
      return b.copyWith(status: status, meetingLink: meetingLink);
    }).toList();
  }

  Future<void> _cancelBooking(_BookingItem booking) async {
    if (booking.isSpecial) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Cancel Booking?'),
        content: Text('Cancel booking #${booking.id}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            child: const Text('Cancel Booking'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _dio.patch('/api/bookings/${booking.id}/cancel');
      setState(() => _updateRegularBooking(booking, status: 'CANCELLED'));
      _snack(context, 'Booking #${booking.id} cancelled');
    } catch (error) {
      _snack(
        context,
        _apiError(error, fallback: 'Failed to cancel booking'),
        error: true,
      );
    }
  }

  Future<void> _confirmBooking(_BookingItem booking) async {
    if (booking.isSpecial) return;
    try {
      await _dio.put(
        '/api/bookings/${booking.id}',
        data: {'bookingStatus': 'CONFIRMED'},
      );
      setState(() => _updateRegularBooking(booking, status: 'CONFIRMED'));
      _snack(context, 'Booking #${booking.id} confirmed');
    } catch (error) {
      _snack(
        context,
        _apiError(error, fallback: 'Failed to confirm booking'),
        error: true,
      );
    }
  }

  Future<void> _addMeetingLink(_BookingItem booking) async {
    if (booking.isSpecial) return;

    final ctrl = TextEditingController(text: booking.meetingLink ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Add Meeting Link'),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            hintText: 'https://meet.google.com/...',
            prefixIcon: const Icon(Icons.link_rounded),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.primaryLight),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;

    try {
      await _dio.put(
        '/api/bookings/${booking.id}',
        data: {'meetingLink': result, 'bookingStatus': 'CONFIRMED'},
      );
      setState(
        () => _updateRegularBooking(
          booking,
          status: 'CONFIRMED',
          meetingLink: result,
        ),
      );
      _snack(context, 'Meeting link added');
    } catch (error) {
      _snack(
        context,
        _apiError(error, fallback: 'Failed to add meeting link'),
        error: true,
      );
    }
  }

  Future<void> _markCompleted(_BookingItem booking) async {
    if (booking.isSpecial) return;
    try {
      await _dio.put(
        '/api/bookings/${booking.id}',
        data: {'bookingStatus': 'COMPLETED'},
      );
      setState(() => _updateRegularBooking(booking, status: 'COMPLETED'));
      _snack(context, 'Booking #${booking.id} marked as completed');
    } catch (error) {
      _snack(
        context,
        _apiError(error, fallback: 'Failed to update booking'),
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final showLoadMore = _hasMore && _filter != 'SPECIAL';
    final counts = _counts;

    return Column(
      children: [
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          child: Column(
            children: [
              TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: widget.isAdmin
                      ? 'Search by client, consultant...'
                      : 'Search bookings...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  filled: true,
                  fillColor: AppColors.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _filters.map((f) {
                    final active = _filter == f;
                    final count = counts[f] ?? 0;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8, bottom: 10),
                      child: FilterChip(
                        label: Text('$f${f != 'ALL' ? ' ($count)' : ''}'),
                        selected: active,
                        onSelected: (_) {
                          setState(() {
                            _filter = f;
                            _search = '';
                          });
                          _load(reset: true);
                        },
                        selectedColor: f == 'SPECIAL'
                            ? const Color(0xFFB45309).withValues(alpha: 0.12)
                            : (f != 'ALL'
                                ? _statusColor(f).withValues(alpha: 0.12)
                                : AppColors.primaryLight
                                    .withValues(alpha: 0.12)),
                        checkmarkColor: f == 'SPECIAL'
                            ? const Color(0xFFB45309)
                            : (f != 'ALL'
                                ? _statusColor(f)
                                : AppColors.primaryLight),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: active
                              ? (f == 'SPECIAL'
                                  ? const Color(0xFFB45309)
                                  : (f != 'ALL'
                                      ? _statusColor(f)
                                      : AppColors.primaryLight))
                              : AppColors.textSecondary,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              if (_specialTotal > 0)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Special bookings: $_specialTotal',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFB45309),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (!_loading)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: AppColors.surfaceVariant,
            child: Row(
              children: [
                Text(
                  '${filtered.length} booking${filtered.length != 1 ? 's' : ''}',
                  style: AppTextStyles.caption
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 12),
                Text(
                  'Revenue: Rs ${_revenue.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF059669),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (showLoadMore)
                  const Text(
                    '  -  scroll for more',
                    style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                  ),
              ],
            ),
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 56,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _filter == 'ALL'
                                ? 'No bookings yet'
                                : _filter == 'SPECIAL'
                                    ? 'No special bookings found'
                                    : 'No $_filter bookings',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (_filter != 'ALL')
                            TextButton(
                              onPressed: () {
                                setState(() => _filter = 'ALL');
                                _load(reset: true);
                              },
                              child: const Text('Show all bookings'),
                            ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => _load(reset: true),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                        itemCount: filtered.length +
                            (_loadingMore ? 1 : 0) +
                            (showLoadMore && !_loadingMore ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (i == filtered.length && _loadingMore) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          if (i == filtered.length && showLoadMore) {
                            return TextButton(
                              onPressed: _load,
                              child: const Text('Load more'),
                            );
                          }
                          if (i >= filtered.length)
                            return const SizedBox.shrink();
                          final booking = filtered[i];
                          return _BookingCard(
                            booking: booking,
                            isAdmin: widget.isAdmin,
                            onViewAnswers: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BookingAnswersScreen(
                                  bookingId: booking.isSpecial ? null : booking.id,
                                  specialBookingId: booking.isSpecial ? booking.id : null,
                                  bookingType: booking.isSpecial ? 'SPECIAL' : 'NORMAL',
                                  userId: booking.userId,
                                  clientName: booking.clientName ?? 'Client',
                                ),
                              ),
                            ),
                            onCancel: () => _cancelBooking(booking),
                            onConfirm: widget.isAdmin
                                ? () => _confirmBooking(booking)
                                : null,
                            onAddMeetingLink: widget.isAdmin
                                ? () => _addMeetingLink(booking)
                                : null,
                            onMarkCompleted: widget.isAdmin
                                ? () => _markCompleted(booking)
                                : null,
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}

class _BookingCard extends StatelessWidget {
  final _BookingItem booking;
  final bool isAdmin;
  final VoidCallback onCancel;
  final VoidCallback? onViewAnswers;
  final VoidCallback? onConfirm;
  final VoidCallback? onAddMeetingLink;
  final VoidCallback? onMarkCompleted;

  const _BookingCard({
    required this.booking,
    required this.isAdmin,
    required this.onCancel,
    this.onViewAnswers,
    this.onConfirm,
    this.onAddMeetingLink,
    this.onMarkCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final status = b.statusUpper;
    final chipStatus = b.displayStatus;
    final color = _statusColor(chipStatus);
    final isCancelled = status == 'CANCELLED';
    final isCompleted = status == 'COMPLETED';
    final isConfirmed = status == 'CONFIRMED';
    final isPending = status == 'PENDING';
    final canCancel = !b.isSpecial && !isCancelled && !isCompleted;
    final awaitingSchedule = b.isSpecial &&
        b.specialStatusUpper == 'REQUESTED' &&
        _string(b.slotDate).isEmpty;

    final who = (b.clientName ?? b.consultantName ?? '').trim();
    final initial = who.isNotEmpty ? who[0].toUpperCase() : '#';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCancelled ? const Color(0xFFFECACA) : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: color.withValues(alpha: 0.1),
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              isAdmin
                                  ? (b.clientName ?? 'User #${b.userId ?? ''}')
                                  : (b.consultantName ?? 'Consultant'),
                              style: AppTextStyles.h4,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (b.isSpecial)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFB45309),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'SPECIAL',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        isAdmin
                            ? (b.consultantName ?? 'Consultant')
                            : (b.clientName ?? ''),
                        style: AppTextStyles.caption,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusBg(chipStatus),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    chipStatus,
                    style: TextStyle(
                      fontSize: 10,
                      color: color,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                if (awaitingSchedule)
                  _detailChip(
                    Icons.calendar_month_rounded,
                    'Awaiting schedule from consultant',
                    const Color(0xFFC2410C),
                  )
                else if (b.slotDate != null && b.slotDate!.isNotEmpty)
                  _detailChip(
                    Icons.calendar_today_rounded,
                    _fmtDate(b.slotDate),
                    AppColors.primaryLight,
                  ),
                if (b.timeRange != null && b.timeRange!.isNotEmpty)
                  _detailChip(
                      Icons.access_time_rounded, b.timeRange!, AppColors.info),
                if (b.isSpecial &&
                    b.duration != null &&
                    b.duration!.isNotEmpty &&
                    (b.timeRange == null || b.timeRange!.isEmpty))
                  _detailChip(
                    Icons.hourglass_top_rounded,
                    b.duration!,
                    const Color(0xFFC2410C),
                  ),
                if (b.meetingMode != null && b.meetingMode!.isNotEmpty)
                  _detailChip(
                    b.meetingMode!.toUpperCase() == 'ONLINE'
                        ? Icons.videocam_rounded
                        : b.meetingMode!.toUpperCase() == 'PHONE'
                            ? Icons.phone_rounded
                            : Icons.location_on_rounded,
                    b.meetingMode!,
                    AppColors.textSecondary,
                  ),
                if (b.amount > 0)
                  _detailChip(
                    Icons.currency_rupee_rounded,
                    'Rs ${b.amount.toStringAsFixed(0)}',
                    const Color(0xFF059669),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '#${b.id}',
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (b.meetingLink != null && b.meetingLink!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF059669).withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.videocam_rounded,
                      size: 14,
                      color: Color(0xFF059669),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        b.meetingLink!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF059669),
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (isAdmin && !b.isSpecial && !isCancelled && !isCompleted) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (isPending && onConfirm != null)
                    OutlinedButton.icon(
                      onPressed: onConfirm,
                      icon: const Icon(Icons.check_circle_outline_rounded,
                          size: 15),
                      label: const Text('Confirm'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF059669),
                        side: const BorderSide(color: Color(0xFF059669)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (isConfirmed && onAddMeetingLink != null)
                    OutlinedButton.icon(
                      onPressed: onAddMeetingLink,
                      icon: const Icon(Icons.link_rounded, size: 15),
                      label: Text(
                        b.meetingLink?.isNotEmpty == true
                            ? 'Edit Link'
                            : 'Add Link',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryLight,
                        side: const BorderSide(color: AppColors.primaryLight),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (isConfirmed && onMarkCompleted != null)
                    OutlinedButton.icon(
                      onPressed: onMarkCompleted,
                      icon: const Icon(Icons.done_all_rounded, size: 15),
                      label: const Text('Complete'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF7C3AED),
                        side: const BorderSide(color: Color(0xFF7C3AED)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (canCancel)
                    OutlinedButton.icon(
                      onPressed: onCancel,
                      icon: const Icon(Icons.cancel_outlined, size: 15),
                      label: const Text('Cancel'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFDC2626)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ],
            if (onViewAnswers != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: onViewAnswers,
                  icon: const Icon(Icons.description_outlined, size: 15),
                  label: const Text('View Answers'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
            if (!isAdmin && canCancel) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.cancel_outlined, size: 15),
                  label: const Text('Cancel Booking'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailChip(IconData icon, String label, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
                fontSize: 12, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      );
}
