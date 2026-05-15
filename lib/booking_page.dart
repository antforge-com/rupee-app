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
    final dateCmp = bDate.compareTo(aDate);
    if (dateCmp != 0) return dateCmp;
    final aTime = _parseTimeToMinutes(a.timeRange ?? '');
    final bTime = _parseTimeToMinutes(b.timeRange ?? '');
    return bTime.compareTo(aTime);
  });
  return list;
}

bool _isPastBookingDate(String? raw) {
  final key = _normalizeDateKey(raw ?? '');
  if (key.isEmpty || key == '9999-12-31') return false;
  try {
    final day = DateTime.parse(key);
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    return day.isBefore(startOfToday);
  } catch (_) {
    return false;
  }
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
  final String? paymentStatus;
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
    this.paymentStatus,
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
        paymentStatus: b.paymentStatus,
        meetingLink: b.meetingLink,
      );

  _BookingItem copyWith({
    String? status,
    String? meetingLink,
    String? consultantName,
    String? clientName,
  }) {
    return _BookingItem(
      id: id,
      status: status ?? this.status,
      userId: userId,
      consultantId: consultantId,
      consultantName: consultantName ?? this.consultantName,
      clientName: clientName ?? this.clientName,
      slotDate: slotDate,
      timeRange: timeRange,
      meetingMode: meetingMode,
      amount: amount,
      paymentStatus: paymentStatus,
      meetingLink: meetingLink ?? this.meetingLink,
      isSpecial: isSpecial,
      specialStatus: specialStatus,
      duration: duration,
    );
  }

  String get rawStatusUpper => status.toUpperCase();
  String get statusUpper {
    if (rawStatusUpper == 'COMPLETED' || rawStatusUpper == 'CANCELLED') {
      return rawStatusUpper;
    }
    if (_isPastBookingDate(slotDate)) return 'COMPLETED';
    return rawStatusUpper;
  }

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
  Map<int, String> _userNames = {};
  Map<int, String> _consultantNames = {};

  bool _loading = true;
  bool _paging = false;          // page-transition spinner
  int _currentPage = 1;          // 1-based
  int _totalPages = 1;
  int _totalElements = 0;
  int _specialTotal = 0;
  int _requestToken = 0;
  final Map<int, List<_BookingItem>> _pageCache = {};

  String _filter = 'ALL';
  String _search = '';
  Timer? _pollTimer;
  final ScrollController _filterChipScrollCtrl = ScrollController();
  late final Map<String, GlobalKey> _filterChipKeys = {
    'ALL': GlobalKey(),
    'PENDING': GlobalKey(),
    'CONFIRMED': GlobalKey(),
    'COMPLETED': GlobalKey(),
    'CANCELLED': GlobalKey(),
    'SPECIAL': GlobalKey(),
  };

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
    _load(page: 1);
    _pollTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _load(page: _currentPage, silent: true),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _filterChipScrollCtrl.dispose();
    super.dispose();
  }

  List<String> get _filters => _specialTotal > 0
      ? const [..._baseFilters, 'SPECIAL']
      : const [..._baseFilters];

  List<_BookingItem> get _mergedBookings =>
      _sortChronologically([..._specialBookings, ..._regularBookings]);

  void _scrollFilterChipIntoView(String filter) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_filterChipScrollCtrl.hasClients) return;
      final chipContext = _filterChipKeys[filter]?.currentContext;
      if (chipContext == null) return;
      final scrollContext =
          _filterChipScrollCtrl.position.context.storageContext;
      final chipBox = chipContext.findRenderObject() as RenderBox?;
      final scrollBox = scrollContext.findRenderObject() as RenderBox?;
      if (chipBox == null || scrollBox == null) {
        Scrollable.ensureVisible(
          chipContext,
          alignment: 0.12,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
        return;
      }
      final chipOffset =
          chipBox.localToGlobal(Offset.zero, ancestor: scrollBox).dx;
      final targetOffset = (_filterChipScrollCtrl.offset + chipOffset - 12)
          .clamp(0.0, _filterChipScrollCtrl.position.maxScrollExtent);
      _filterChipScrollCtrl.animateTo(
        targetOffset.toDouble(),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _setFilter(String filter) {
    setState(() {
      _filter = filter;
      _search = '';
    });
    _load(page: 1, force: true, clearCache: true);
    _scrollFilterChipIntoView(filter);
  }

  String _normalizeName(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '';
    final lower = text.toLowerCase();
    if (lower == 'null' || lower == 'undefined') return '';
    if (text.contains('@')) {
      final local = text.split('@').first;
      final cleaned = local
          .replaceAll(RegExp(r'[._\-]+'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (cleaned.isNotEmpty) {
        return cleaned
            .split(' ')
            .where((p) => p.isNotEmpty)
            .map((p) =>
                '${p.substring(0, 1).toUpperCase()}${p.substring(1).toLowerCase()}')
            .join(' ');
      }
    }
    return text;
  }

  String _displayClientName(_BookingItem booking) {
    final direct = _normalizeName(booking.clientName ?? '');
    if (direct.isNotEmpty && direct.toLowerCase() != 'client') return direct;
    final id = booking.userId;
    if (id != null && _userNames[id]?.trim().isNotEmpty == true) {
      return _userNames[id]!.trim();
    }
    if (direct.isNotEmpty) return direct;
    return id != null ? 'User #$id' : 'Client';
  }

  String _displayConsultantName(_BookingItem booking) {
    final direct = _normalizeName(booking.consultantName ?? '');
    if (direct.isNotEmpty && direct.toLowerCase() != 'consultant') {
      return direct;
    }
    final id = booking.consultantId;
    if (id != null && _consultantNames[id]?.trim().isNotEmpty == true) {
      return _consultantNames[id]!.trim();
    }
    if (direct.isNotEmpty) return direct;
    return id != null ? 'Consultant #$id' : 'Consultant';
  }

  bool _isRevenueBooking(_BookingItem booking) {
    return booking.statusUpper == 'COMPLETED';
  }

  Future<Map<String, Map<int, String>>> _fetchNameLookups() async {
    final users = <int, String>{};
    final consultants = <int, String>{};
    final userIds = <int>{};

    try {
      final userResp = await _dio.get('/api/users');
      final userRows = _extractArray(
        userResp.data,
        keys: const ['content', 'data', 'items', 'users'],
      );
      for (final raw in userRows.whereType<Map>()) {
        final row = Map<String, dynamic>.from(raw);
        final id = _toInt(row['id'] ?? row['userId']);
        if (id == null) continue;
        userIds.add(id);
        final name = _normalizeName(
          (row['name'] ??
                  row['fullName'] ??
                  row['displayName'] ??
                  row['identifier'] ??
                  row['email'] ??
                  '')
              .toString(),
        );
        if (name.isNotEmpty) users[id] = name;
      }
    } catch (_) {}

    if (userIds.isNotEmpty) {
      final profiles = await Future.wait<MapEntry<int, String>?>(
        userIds.map((id) async {
          try {
            final response = await _dio.get('/api/onboarding/$id');
            if (response.data is! Map) return null;
            final row = Map<String, dynamic>.from(response.data as Map);
            final name = _normalizeName(
              (row['name'] ??
                      row['fullName'] ??
                      row['displayName'] ??
                      row['email'] ??
                      '')
                  .toString(),
            );
            if (name.isEmpty) return null;
            return MapEntry(id, name);
          } catch (_) {
            return null;
          }
        }),
      );
      for (final entry in profiles.whereType<MapEntry<int, String>>()) {
        users[entry.key] = entry.value;
      }
    }

    try {
      final consultantResp = await _dio.get('/api/consultants');
      final consultantRows = _extractArray(
        consultantResp.data,
        keys: const ['content', 'data', 'items', 'consultants'],
      );
      for (final raw in consultantRows.whereType<Map>()) {
        final row = Map<String, dynamic>.from(raw);
        final id = _toInt(row['id'] ?? row['consultantId']);
        if (id == null) continue;
        final name = _normalizeName(
          (row['name'] ?? row['fullName'] ?? row['displayName'] ?? '')
              .toString(),
        );
        if (name.isNotEmpty) consultants[id] = name;
      }
    } catch (_) {}

    return {'users': users, 'consultants': consultants};
  }

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
        return _displayClientName(b).toLowerCase().contains(q) ||
            _displayConsultantName(b).toLowerCase().contains(q) ||
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
      .where(_isRevenueBooking)
      .fold(0.0, (sum, b) => sum + b.amount);

  Future<void> _load({
    int page = 1,
    bool silent = false,
    bool force = false,
    bool clearCache = false,
  }) async {
    final targetPage = page < 1 ? 1 : page;
    if (clearCache) _pageCache.clear();

    // Use cache when available and not forced
    if (!force) {
      final cached = _pageCache[targetPage];
      if (cached != null) {
        final special = _specialBookings;
        if (mounted) {
          setState(() {
            _regularBookings = cached;
            _currentPage = targetPage;
            _loading = false;
            _paging = false;
          });
        }
        unawaited(_prefetchAdjacentPages(targetPage));
        return;
      }
    }

    if (mounted) {
      setState(() {
        if (_regularBookings.isEmpty || force || clearCache) {
          if (!silent) _loading = true;
        } else {
          _paging = true;
        }
      });
    }

    final token = ++_requestToken;
    try {
      final regularFuture = _fetchRegularPage(targetPage - 1); // 0-based API
      final specialFuture = (targetPage == 1 || _specialBookings.isEmpty)
          ? _fetchSpecialBookings()
          : Future.value(_specialBookings);
      final namesFuture = (targetPage == 1 || _userNames.isEmpty)
          ? _fetchNameLookups()
          : Future.value({'users': _userNames, 'consultants': _consultantNames});

      final results = await Future.wait<dynamic>([regularFuture, specialFuture, namesFuture]);
      if (token != _requestToken) return;

      final regularPage = results[0] as _RegularPageResult;
      final specialItems = results[1] as List<_BookingItem>;
      final lookupRaw = results[2] as Map;
      final usersLookup = Map<int, String>.from((lookupRaw['users'] as Map?) ?? const {});
      final consultantsLookup = Map<int, String>.from((lookupRaw['consultants'] as Map?) ?? const {});

      _pageCache[targetPage] = regularPage.items;

      if (!mounted || token != _requestToken) return;
      setState(() {
        _regularBookings = regularPage.items;
        _specialBookings = specialItems;
        _userNames = usersLookup;
        _consultantNames = consultantsLookup;
        _specialTotal = specialItems.length;
        _currentPage = targetPage;
        _totalPages = regularPage.totalPages;
        _totalElements = regularPage.totalElements;
        _loading = false;
        _paging = false;
      });
      unawaited(_prefetchAdjacentPages(targetPage));
    } catch (_) {
      if (mounted && !silent) {
        setState(() {
          _loading = false;
          _paging = false;
        });
      } else if (mounted) {
        setState(() => _paging = false);
      }
    }
  }

  Future<void> _prefetchAdjacentPages(int current) async {
    for (final page in [current - 1, current + 1]) {
      if (page < 1 || page > _totalPages) continue;
      if (_pageCache.containsKey(page)) continue;
      unawaited(_prefetchBookingPage(page));
    }
  }

  Future<void> _prefetchBookingPage(int page) async {
    try {
      final result = await _fetchRegularPage(page - 1);
      if (!mounted || _pageCache.containsKey(page)) return;
      _pageCache[page] = result.items;
    } catch (_) {}
  }

  void _goToPage(int page) {
    if (page < 1 || page > _totalPages || page == _currentPage) return;
    _load(page: page);
  }

  List<int> _visiblePageNumbers() {
    if (_totalPages <= 1) return const [1];
    final pages = <int>{1, _totalPages, _currentPage};
    for (var p = _currentPage - 1; p <= _currentPage + 1; p++) {
      if (p >= 1 && p <= _totalPages) pages.add(p);
    }
    return (pages.toList()..sort());
  }

  Widget _paginationBar() {
    if (_totalPages <= 1) return const SizedBox.shrink();
    final pages = _visiblePageNumbers();
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        IconButton(
          onPressed: _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null,
          icon: const Icon(Icons.chevron_left_rounded),
          visualDensity: VisualDensity.compact,
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (var i = 0; i < pages.length; i++) ...[
                if (i > 0 && pages[i] - pages[i - 1] > 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text('...', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: GestureDetector(
                    onTap: () => _goToPage(pages[i]),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _currentPage == pages[i] ? AppColors.primaryLight : Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: _currentPage == pages[i] ? AppColors.primaryLight : AppColors.border,
                        ),
                      ),
                      child: Text(
                        '${pages[i]}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _currentPage == pages[i] ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ]),
          ),
        ),
        IconButton(
          onPressed: _currentPage < _totalPages ? () => _goToPage(_currentPage + 1) : null,
          icon: const Icon(Icons.chevron_right_rounded),
          visualDensity: VisualDensity.compact,
        ),
        if (_paging)
          const SizedBox(
            width: 14, height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryLight),
          ),
      ]),
    );
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

      var date = _firstNonEmpty([
        row['scheduledDate'],
        row['scheduled_date'],
        row['slotDate'],
        row['slot_date'],
        row['bookingDate'],
        row['booking_date'],
        row['date'],
        row['preferredDate'],
        meta?['scheduledDate'],
        meta?['preferredDate'],
      ]);

      final scheduledAt = _firstNonEmpty([
        row['scheduledAt'],
        row['scheduled_at'],
      ]);
      if (date.isEmpty && scheduledAt.isNotEmpty) {
        final parsed = DateTime.tryParse(scheduledAt);
        if (parsed != null) {
          date = parsed.toIso8601String().split('T').first;
        }
      }

      final scheduledTimeRaw = _firstMeaningfulValue([
        row['scheduledTime'],
        row['scheduled_time'],
        row['startTime'],
        row['slotTime'],
        row['slot_time'],
        row['time'],
        meta?['scheduledTime'],
        meta?['preferredTime'],
      ]);
      final scheduledTime = _timeValueToString(scheduledTimeRaw);

      var timeRange = _firstNonEmpty([
        row['scheduledTimeRange'],
        row['scheduled_time_range'],
        row['timeRange'],
        row['time_range'],
        meta?['scheduledTimeRange'],
        meta?['preferredTimeRange'],
      ]);
      if (timeRange.isEmpty && scheduledTime.isEmpty && scheduledAt.isNotEmpty) {
        final parsed = DateTime.tryParse(scheduledAt);
        if (parsed != null) {
          final hh = parsed.hour.toString().padLeft(2, '0');
          final mm = parsed.minute.toString().padLeft(2, '0');
          timeRange = _buildSpecialTimeRange('$hh:$mm', durationHours);
        }
      }
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
          userId: _toInt(
            row['userId'] ??
                row['user_id'] ??
                (row['user'] is Map ? row['user']['id'] : null),
          ),
          consultantId: _toInt(
                row['consultantId'] ??
                    row['consultant_id'] ??
                    (row['consultant'] is Map ? row['consultant']['id'] : null),
              ) ??
              consultantId,
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
                row['baseAmount'] ??
                row['paidAmount'] ??
                row['charges'],
          ),
          paymentStatus: _firstNonEmpty([
            row['paymentStatus'],
            row['payment_status'],
            row['payment'] is Map ? row['payment']['status'] : null,
          ]),
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

  Future<void> _changeBookingStatus(
    _BookingItem booking,
    String status,
  ) async {
    if (booking.isSpecial) return;
    try {
      if (status == 'CANCELLED') {
        await _dio.patch('/api/bookings/${booking.id}/cancel');
      } else {
        await _dio.put(
          '/api/bookings/${booking.id}',
          data: {'bookingStatus': status},
        );
      }
      setState(() => _updateRegularBooking(booking, status: status));
      _snack(context, 'Booking #${booking.id} updated to $status');
    } catch (error) {
      _snack(
        context,
        _apiError(error, fallback: 'Failed to update booking status'),
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
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
                controller: _filterChipScrollCtrl,
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _filters.map((f) {
                    final active = _filter == f;
                    final count = counts[f] ?? 0;
                    return Padding(
                      key: _filterChipKeys[f],
                      padding: const EdgeInsets.only(right: 8, bottom: 10),
                      child: FilterChip(
                        label: Text('$f${f != 'ALL' ? ' ($count)' : ''}'),
                        selected: active,
                        onSelected: (_) => _setFilter(f),
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
                const Spacer(),
                Text(
                  'Page $_currentPage of $_totalPages',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
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
                              onPressed: () => _setFilter('ALL'),
                              child: const Text('Show all bookings'),
                            ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => _load(page: 1, force: true, clearCache: true),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                        itemCount: filtered.length + 1,
                        itemBuilder: (_, i) {
                          if (i == filtered.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8, bottom: 12),
                              child: Column(children: [
                                if (_totalPages > 1) _paginationBar(),
                                const SizedBox(height: 4),
                                Text(
                                  'Page $_currentPage of $_totalPages  •  $_totalElements bookings',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ]),
                            );
                          }
                          final booking = filtered[i];
                          final clientDisplayName = _displayClientName(booking);
                          final consultantDisplayName =
                              _displayConsultantName(booking);
                          return _BookingCard(
                            booking: booking,
                            isAdmin: widget.isAdmin,
                            clientDisplayName: clientDisplayName,
                            consultantDisplayName: consultantDisplayName,
                            onViewAnswers: widget.isAdmin
                                ? null
                                : () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => BookingAnswersScreen(
                                          bookingId: booking.isSpecial
                                              ? null
                                              : booking.id,
                                          specialBookingId: booking.isSpecial
                                              ? booking.id
                                              : null,
                                          bookingType: booking.isSpecial
                                              ? 'SPECIAL'
                                              : 'NORMAL',
                                          userId: booking.userId,
                                          clientName: clientDisplayName,
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
                            onStatusChanged: widget.isAdmin
                                ? (status) =>
                                    _changeBookingStatus(booking, status)
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
  final String clientDisplayName;
  final String consultantDisplayName;
  final VoidCallback onCancel;
  final VoidCallback? onViewAnswers;
  final VoidCallback? onConfirm;
  final VoidCallback? onAddMeetingLink;
  final VoidCallback? onMarkCompleted;
  final ValueChanged<String>? onStatusChanged;

  const _BookingCard({
    required this.booking,
    required this.isAdmin,
    required this.clientDisplayName,
    required this.consultantDisplayName,
    required this.onCancel,
    this.onViewAnswers,
    this.onConfirm,
    this.onAddMeetingLink,
    this.onMarkCompleted,
    this.onStatusChanged,
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

    final who = isAdmin ? clientDisplayName : consultantDisplayName;
    final counterpart = isAdmin ? consultantDisplayName : clientDisplayName;
    final initial = who.isNotEmpty ? who[0].toUpperCase() : '#';

    final hasDate = b.slotDate != null && b.slotDate!.isNotEmpty;
    final hasTime = b.timeRange != null && b.timeRange!.isNotEmpty;
    final hasDuration = b.isSpecial && b.duration != null && b.duration!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCancelled
              ? const Color(0xFFFECACA)
              : isCompleted
                  ? const Color(0xFFD1FAE5)
                  : color.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: avatar + name + status chip ──────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Text(initial,
                      style: TextStyle(color: color,
                          fontWeight: FontWeight.w800, fontSize: 14)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(who,
                              style: const TextStyle(fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary),
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (b.isSpecial)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B),
                                borderRadius: BorderRadius.circular(10)),
                            child: const Text('SPECIAL',
                                style: TextStyle(fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.3)),
                          ),
                      ]),
                      const SizedBox(height: 2),
                      Text(
                        isAdmin
                            ? 'Consultant: $counterpart'
                            : 'Client: $counterpart',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                          color: _statusBg(chipStatus),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(chipStatus,
                          style: TextStyle(fontSize: 10, color: color,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3)),
                    ),
                  ],
                ),
                if (isAdmin && !b.isSpecial && onStatusChanged != null)
                  PopupMenuButton<String>(
                    tooltip: 'Change status',
                    icon: const Icon(Icons.more_vert_rounded,
                        color: AppColors.textSecondary, size: 18),
                    onSelected: onStatusChanged,
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'PENDING',   child: Text('Mark Pending')),
                      PopupMenuItem(value: 'CONFIRMED', child: Text('Mark Confirmed')),
                      PopupMenuItem(value: 'COMPLETED', child: Text('Mark Completed')),
                      PopupMenuItem(value: 'CANCELLED', child: Text('Mark Cancelled')),
                    ],
                  ),
              ],
            ),
          ),

          // ── Date / Time / Mode info box ───────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: awaitingSchedule
                    ? const Color(0xFFFFF7ED)
                    : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: awaitingSchedule
                      ? const Color(0xFFFED7AA)
                      : const Color(0xFFBBF7D0),
                ),
              ),
              child: awaitingSchedule
                  ? Row(children: const [
                      Icon(Icons.schedule_rounded,
                          size: 14, color: Color(0xFFC2410C)),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text('Awaiting schedule from consultant',
                            style: TextStyle(fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFC2410C))),
                      ),
                    ])
                  : Wrap(
                      spacing: 18,
                      runSpacing: 8,
                      children: [
                        if (hasDate)
                          _infoCell(Icons.calendar_today_rounded,
                              'Date', _fmtDate(b.slotDate),
                              AppColors.primaryLight),
                        if (hasTime)
                          _infoCell(Icons.access_time_rounded,
                              'Time', b.timeRange!, AppColors.info),
                        if (!hasDate && !hasTime && hasDuration)
                          _infoCell(Icons.hourglass_top_rounded,
                              'Duration', b.duration!,
                              const Color(0xFFC2410C)),
                        if (b.meetingMode != null &&
                            b.meetingMode!.isNotEmpty)
                          _infoCell(
                            b.meetingMode!.toUpperCase() == 'ONLINE'
                                ? Icons.videocam_rounded
                                : b.meetingMode!.toUpperCase() == 'PHONE'
                                    ? Icons.phone_rounded
                                    : Icons.location_on_rounded,
                            'Mode', b.meetingMode!,
                            AppColors.textSecondary),
                        if (b.amount > 0)
                          _infoCell(Icons.currency_rupee_rounded,
                              'Amount',
                              'Rs ${b.amount.toStringAsFixed(2)}',
                              const Color(0xFF059669)),
                      ],
                    ),
            ),
          ),

          // ── Booking ID ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
            child: Text('#${b.id}',
                style: const TextStyle(fontSize: 10,
                    color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          ),

          // ── Meeting link ──────────────────────────────────────────────
          if (b.meetingLink != null && b.meetingLink!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color:
                      const Color(0xFF059669).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFF059669)
                          .withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.videocam_rounded,
                      size: 14, color: Color(0xFF059669)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(b.meetingLink!,
                        style: const TextStyle(fontSize: 11,
                            color: Color(0xFF059669),
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
              ),
            ),

          // ── Action buttons ────────────────────────────────────────────
          if (onViewAnswers != null ||
              (isAdmin && !b.isSpecial && !isCancelled && !isCompleted) ||
              canCancel) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 10, 14, 0),
              child:
                  Divider(height: 1, color: AppColors.border),
            ),
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (onViewAnswers != null)
                    OutlinedButton.icon(
                      onPressed: onViewAnswers,
                      icon: const Icon(Icons.quiz_outlined, size: 14),
                      label: const Text('View Answers'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryLight,
                        side: const BorderSide(
                            color: AppColors.primaryLight),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        textStyle: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  if (isAdmin && isPending && onConfirm != null)
                    OutlinedButton.icon(
                      onPressed: onConfirm,
                      icon: const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 14),
                      label: const Text('Confirm'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF059669),
                        side: const BorderSide(
                            color: Color(0xFF059669)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        textStyle: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  if (isAdmin && isConfirmed && onAddMeetingLink != null)
                    OutlinedButton.icon(
                      onPressed: onAddMeetingLink,
                      icon: const Icon(Icons.link_rounded, size: 14),
                      label: Text(b.meetingLink?.isNotEmpty == true
                          ? 'Update Link'
                          : 'Add Link'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.info,
                        side: const BorderSide(color: AppColors.info),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        textStyle: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  if (isAdmin &&
                      isConfirmed &&
                      onMarkCompleted != null)
                    OutlinedButton.icon(
                      onPressed: onMarkCompleted,
                      icon: const Icon(Icons.done_all_rounded,
                          size: 14),
                      label: const Text('Complete'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF7C3AED),
                        side: const BorderSide(
                            color: Color(0xFF7C3AED)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        textStyle: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  if (canCancel)
                    OutlinedButton.icon(
                      onPressed: onCancel,
                      icon: const Icon(Icons.cancel_outlined, size: 14),
                      label: const Text('Cancel'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side:
                            const BorderSide(color: AppColors.danger),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        textStyle: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ),
          ] else
            const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _infoCell(
          IconData icon, String label, String value, Color color) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 9,
                      color: color.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3)),
              Text(value,
                  style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w700)),
            ]),
      ]);


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
