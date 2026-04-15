// lib/booking_page.dart
// ════════════════════════════════════════════════════════════════════════════
// BookingsPage — Flutter (matches web BookingsPage.tsx feature-for-feature)
//
// Features:
//   ✓ isAdmin flag (admin = all bookings, consultant = own bookings)
//   ✓ Stats strip: Total, Pending, Confirmed, Completed, Revenue
//   ✓ Filter pills: ALL / PENDING / CONFIRMED / COMPLETED / CANCELLED
//   ✓ Booking cards: avatar, user, consultant, date, time, mode, amount, status
//   ✓ Pagination (Spring-style page 0-based)
//   ✓ Admin actions: Edit status dialog + Delete/Cancel booking
//   ✓ Pull-to-refresh
//   ✓ Action snackbar toast
//   ✓ Empty & error states
//
// API endpoints used:
//   GET /api/bookings               (admin — all, paginated)
//   GET /api/bookings/consultant/{id}  (consultant — own, paginated)
//   PUT /api/bookings/{id}          (update status)
//   DELETE /api/bookings/{id}       (cancel/delete)
//   GET /api/consultants/{id}       (resolve consultant name)
//   GET /api/users/{id}             (resolve user name)
// ════════════════════════════════════════════════════════════════════════════

import 'package:finadvise/api_client.dart';
import 'package:finadvise/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BOOKING MODEL (local — parsed from API response)
// ─────────────────────────────────────────────────────────────────────────────

class _Booking {
  final int id;
  final String userName;
  final String advisorName;
  final String date;
  final String time;
  final String status;
  final double amount;
  final String meetingMode;

  _Booking({
    required this.id,
    required this.userName,
    required this.advisorName,
    required this.date,
    required this.time,
    required this.status,
    required this.amount,
    required this.meetingMode,
  });

  _Booking copyWith({String? status}) => _Booking(
        id: id,
        userName: userName,
        advisorName: advisorName,
        date: date,
        time: time,
        status: status ?? this.status,
        amount: amount,
        meetingMode: meetingMode,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// MODULE-LEVEL CACHES (survive hot reload, same as web _consultantCache)
// ─────────────────────────────────────────────────────────────────────────────
final _consultantCache = <int, String>{};
final _userCache = <int, String>{};

// ─────────────────────────────────────────────────────────────────────────────
// PAGE WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class BookingsPage extends StatefulWidget {
  final bool isAdmin;
  final int? consultantId; // Required when isAdmin = false
  const BookingsPage({super.key, this.isAdmin = false, this.consultantId});

  @override
  State<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage> {
  static const int _pageSize = 10;

  final _dio = ApiClient().dio;

  List<_Booking> _bookings = [];
  int _totalElements = 0;
  int _totalPages = 0;
  int _currentPage = 0;
  bool _loading = true;
  String? _error;
  String _filter = 'ALL';

  // page cache: pageNumber → list (instant adjacent-page navigation)
  final Map<int, List<_Booking>> _pageCache = {};

  // admin action state
  int? _deletingId;
  _Booking? _editingBooking;
  String _editStatus = 'PENDING';
  bool _savingEdit = false;

  @override
  void initState() {
    super.initState();
    _loadPage(0);
  }

  // ── LOAD PAGE ──────────────────────────────────────────────────────────────

  Future<void> _loadPage(int page) async {
    if (_pageCache.containsKey(page)) {
      setState(() {
        _bookings = _pageCache[page]!;
        _currentPage = page;
        _loading = false;
      });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final Map<String, dynamic> params = {'page': page, 'size': _pageSize};
      final response = widget.isAdmin
          ? await _dio.get('/api/bookings', queryParameters: params)
          : await _fetchConsultantBookings(page, params);

      final raw = response.data;
      final List<dynamic> content;
      int total = 0;
      int totalPgs = 1;

      if (raw is Map) {
        content = raw['content'] ?? raw['data'] ?? [];
        total = raw['totalElements'] ?? raw['total'] ?? content.length;
        totalPgs = raw['totalPages'] ?? 1;
      } else if (raw is List) {
        content = raw;
        total = raw.length;
        totalPgs = 1;
      } else {
        content = [];
      }

      final mapped = await _mapRaw(content);
      if (!mounted) return;
      setState(() {
        _bookings = mapped;
        _totalElements = total;
        _totalPages = totalPgs;
        _currentPage = page;
        _loading = false;
        _pageCache[page] = mapped;
      });

      // Pre-fetch adjacent pages silently
      _prefetch(page - 1);
      _prefetch(page + 1);
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'Failed to load bookings. Tap retry.'; });
    }
  }

  Future<dynamic> _fetchConsultantBookings(int page, Map<String, dynamic> params) async {
    final consultantId = widget.consultantId;
    if (consultantId == null) throw Exception('Consultant ID not provided');
    return _dio.get('/api/bookings/consultant/$consultantId', queryParameters: params);
  }

  Future<void> _prefetch(int page) async {
    if (page < 0 || (_totalPages > 0 && page >= _totalPages) || _pageCache.containsKey(page)) return;
    try {
      final Map<String, dynamic> params = {'page': page, 'size': _pageSize};
      final response = widget.isAdmin
          ? await _dio.get('/api/bookings', queryParameters: params)
          : await _fetchConsultantBookings(page, params);
      final raw = response.data;
      final List<dynamic> content = raw is Map ? (raw['content'] ?? raw['data'] ?? []) : (raw is List ? raw : []);
      final mapped = await _mapRaw(content);
      if (mounted) setState(() => _pageCache[page] = mapped);
    } catch (_) { /* silent */ }
  }

  // ── MAP RAW → _Booking ─────────────────────────────────────────────────────

  Future<List<_Booking>> _mapRaw(List<dynamic> raw) async {
    if (raw.isEmpty) return [];

    // Collect uncached consultant IDs
    final uncachedCids = raw.map((b) => b['consultantId']).whereType<int>()
        .where((id) => !_consultantCache.containsKey(id))
        .toSet().toList();

    // Collect uncached user IDs
    final uncachedUids = raw.map((b) => b['userId'] ?? b['user']?['id']).whereType<int>()
        .where((id) => !_userCache.containsKey(id))
        .toSet().toList();

    // Parallel enrichment
    await Future.wait([
      ...uncachedCids.map(_fetchConsultantName),
      ...uncachedUids.map(_fetchUserName),
    ]);

    return raw.map((b) {
      final int? cid = b['consultantId'];
      final int? uid = b['userId'] ?? b['user']?['id'];

      final userName = _prettify(
        b['user']?['name'] ?? b['user']?['fullName'] ?? b['user']?['username'] ??
        b['userName'] ?? b['clientName'] ??
        (uid != null ? _userCache[uid] : null) ??
        (uid != null ? 'User #$uid' : 'Booking #${b['id']}'),
      );

      final advisorName =
        b['consultant']?['name'] ?? b['consultant']?['fullName'] ??
        b['advisorName'] ?? b['consultantName'] ??
        (cid != null ? _consultantCache[cid] : null) ??
        (cid != null ? 'Consultant #$cid' : 'Consultant');

      final status = (b['bookingStatus'] ?? b['BookingStatus'] ?? b['status'] ?? 'PENDING')
          .toString().toUpperCase();

      return _Booking(
        id: b['id'] ?? 0,
        userName: userName,
        advisorName: advisorName,
        date: b['slotDate'] ?? b['bookingDate'] ?? b['date'] ?? '',
        time: b['timeRange'] ?? b['slotTime'] ?? b['bookingTime'] ?? '',
        status: status,
        amount: (b['amount'] ?? b['charges'] ?? b['fee'] ?? 0).toDouble(),
        meetingMode: b['meetingMode'] ?? b['mode'] ?? '',
      );
    }).toList()
      ..sort((a, b) {
        final dc = b.date.compareTo(a.date);
        return dc != 0 ? dc : b.id.compareTo(a.id);
      });
  }

  Future<void> _fetchConsultantName(int id) async {
    try {
      final r = await _dio.get('/api/consultants/$id');
      _consultantCache[id] = r.data?['name'] ?? r.data?['fullName'] ?? 'Consultant #$id';
    } catch (_) {
      try {
        final r = await _dio.get('/api/users/$id');
        _consultantCache[id] = r.data?['name'] ?? r.data?['fullName'] ?? 'Consultant #$id';
      } catch (_) { _consultantCache[id] = 'Consultant #$id'; }
    }
  }

  Future<void> _fetchUserName(int id) async {
    try {
      final r = await _dio.get('/api/users/$id');
      _userCache[id] = _prettify(
        r.data?['name'] ?? r.data?['fullName'] ?? r.data?['username'] ?? r.data?['email'] ?? 'User #$id',
      );
    } catch (_) { _userCache[id] = 'User #$id'; }
  }

  String _prettify(String raw) {
    if (raw.contains('@')) {
      return raw.split('@')[0]
          .replaceAll(RegExp(r'[._\-]'), ' ')
          .split(' ')
          .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
          .join(' ');
    }
    return raw;
  }

  // ── ADMIN ACTIONS ──────────────────────────────────────────────────────────

  Future<void> _deleteBooking(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Booking?'),
        content: Text('Cancel booking #$id? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deletingId = id);
    try {
      await _dio.delete('/api/bookings/$id');
      setState(() {
        _bookings.removeWhere((b) => b.id == id);
        _totalElements = (_totalElements - 1).clamp(0, 999999);
        _pageCache.clear();
        _deletingId = null;
      });
      _showSnack('Booking #$id cancelled.', ok: true);
    } catch (_) {
      setState(() => _deletingId = null);
      _showSnack('Failed to cancel booking.', ok: false);
    }
  }

  void _openEditDialog(_Booking b) {
    setState(() { _editingBooking = b; _editStatus = b.status; });
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (_, ss) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: EdgeInsets.zero,
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0xFF1E3A5F), Color(0xFF2563EB)]),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('EDIT BOOKING', style: TextStyle(fontSize: 10, color: Color(0xFF93C5FD), fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                          const SizedBox(height: 4),
                          Text('Booking #${b.id}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                        ],
                      )),
                      IconButton(
                        onPressed: () { Navigator.pop(ctx); setState(() => _editingBooking = null); },
                        icon: const Icon(Icons.close, color: Colors.white, size: 20),
                        style: IconButton.styleFrom(backgroundColor: Colors.white24, shape: const CircleBorder()),
                      ),
                    ],
                  ),
                ),
                // Body
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _editInfoRow('User', b.userName),
                      const SizedBox(height: 12),
                      _editInfoRow('Consultant', b.advisorName),
                      const SizedBox(height: 16),
                      const Text('Booking Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.8)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _editStatus,
                            isExpanded: true,
                            items: ['PENDING', 'CONFIRMED', 'COMPLETED', 'CANCELLED']
                                .map((s) => DropdownMenuItem(value: s, child: Row(
                                  children: [
                                    Container(width: 8, height: 8, margin: const EdgeInsets.only(right: 10),
                                        decoration: BoxDecoration(color: _statusColor(s), shape: BoxShape.circle)),
                                    Text(s, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                  ],
                                ))).toList(),
                            onChanged: (v) { if (v != null) { setState(() => _editStatus = v); ss(() {}); } },
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () { Navigator.pop(ctx); setState(() => _editingBooking = null); },
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _savingEdit ? null : () => _saveEdit(ctx, ss),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryLight,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: _savingEdit
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _editInfoRow(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.8)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
    ],
  );

  Future<void> _saveEdit(BuildContext ctx, StateSetter ss) async {
    if (_editingBooking == null) return;
    ss(() => _savingEdit = true);
    setState(() => _savingEdit = true);
    try {
      await _dio.put('/api/bookings/${_editingBooking!.id}', data: {'bookingStatus': _editStatus});
      final updatedBooking = _editingBooking!.copyWith(status: _editStatus);
      setState(() {
        _bookings = _bookings.map((b) => b.id == updatedBooking.id ? updatedBooking : b).toList();
        _pageCache.clear();
        _editingBooking = null;
        _savingEdit = false;
      });
      if (mounted) Navigator.pop(ctx);
      _showSnack('Booking #${updatedBooking.id} updated.', ok: true);
    } catch (_) {
      ss(() => _savingEdit = false);
      setState(() => _savingEdit = false);
      _showSnack('Update failed. Try again.', ok: false);
    }
  }

  void _showSnack(String msg, {required bool ok}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? AppColors.success : AppColors.danger,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 3),
    ));
  }

  // ── HELPERS ────────────────────────────────────────────────────────────────

  List<_Booking> get _filtered =>
      _filter == 'ALL' ? _bookings : _bookings.where((b) => b.status == _filter).toList();

  Map<String, int> get _counts => {
    'ALL': _totalElements,
    'PENDING': _bookings.where((b) => b.status == 'PENDING').length,
    'CONFIRMED': _bookings.where((b) => b.status == 'CONFIRMED').length,
    'COMPLETED': _bookings.where((b) => b.status == 'COMPLETED').length,
    'CANCELLED': _bookings.where((b) => b.status == 'CANCELLED').length,
  };

  double get _revenue => _bookings.where((b) => b.status == 'COMPLETED').fold(0, (s, b) => s + b.amount);

  Color _statusColor(String s) {
    switch (s) {
      case 'CONFIRMED': return AppColors.primaryLight;
      case 'COMPLETED': return AppColors.success;
      case 'CANCELLED': return AppColors.danger;
      default: return AppColors.warning;
    }
  }

  Color _statusBg(String s) {
    switch (s) {
      case 'CONFIRMED': return const Color(0xFFEFF6FF);
      case 'COMPLETED': return const Color(0xFFF0FDF4);
      case 'CANCELLED': return const Color(0xFFFEF2F2);
      default: return const Color(0xFFFFFBEB);
    }
  }

  IconData _modeIcon(String m) {
    switch (m.toUpperCase()) {
      case 'ONLINE': return Icons.videocam_outlined;
      case 'PHONE': return Icons.phone_outlined;
      default: return Icons.location_on_outlined;
    }
  }

  String _modeLabel(String m) {
    switch (m.toUpperCase()) {
      case 'ONLINE': return 'Online';
      case 'PHONE': return 'Phone';
      case 'PHYSICAL': return 'In-Person';
      default: return m;
    }
  }

  // ── PAGINATION PAGES ───────────────────────────────────────────────────────

  List<dynamic> _pageNums() {
    if (_totalPages <= 7) return List.generate(_totalPages, (i) => i);
    final set = <int>{
      0, _totalPages - 1,
      if (_currentPage > 0) _currentPage - 1,
      _currentPage,
      if (_currentPage < _totalPages - 1) _currentPage + 1,
    };
    final sorted = set.toList()..sort();
    final result = <dynamic>[];
    for (int i = 0; i < sorted.length; i++) {
      if (i > 0 && sorted[i] - sorted[i - 1] > 1) result.add('…');
      result.add(sorted[i]);
    }
    return result;
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          _pageCache.clear();
          await _loadPage(_currentPage);
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(children: [
                // ── Header row ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.isAdmin ? 'All Bookings' : 'My Bookings',
                      style: AppTextStyles.h3.copyWith(fontSize: 22),
                    ),
                    TextButton.icon(
                      onPressed: () { _pageCache.clear(); _loadPage(_currentPage); },
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Refresh'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primaryLight,
                        backgroundColor: const Color(0xFFEFF6FF),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Color(0xFFBFDBFE))),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Stats strip ──
                if (!_loading && _bookings.isNotEmpty) _buildStatsStrip(),

                // ── Error banner ──
                if (_error != null) _buildErrorBanner(),

                // ── Filter pills ──
                _buildFilterPills(),
                const SizedBox(height: 4),
              ]),
            )),

            // ── Content ──
            if (_loading)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
            else if (_filtered.isEmpty)
              SliverFillRemaining(child: _buildEmpty())
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _buildBookingCard(_filtered[i], i),
                    childCount: _filtered.length,
                  ),
                ),
              ),

            // ── Pagination ──
            if (!_loading && _totalPages > 1)
              SliverToBoxAdapter(child: _buildPagination()),
          ],
        ),
      ),
    );
  }

  // ── STATS STRIP ────────────────────────────────────────────────────────────

  Widget _buildStatsStrip() {
    final items = [
      {'label': 'Total', 'value': '$_totalElements', 'color': AppColors.primaryLight, 'bg': const Color(0xFFEFF6FF)},
      {'label': 'Pending', 'value': '${_counts['PENDING']}', 'color': AppColors.warning, 'bg': const Color(0xFFFFFBEB)},
      {'label': 'Confirmed', 'value': '${_counts['CONFIRMED']}', 'color': AppColors.primaryLight, 'bg': const Color(0xFFEFF6FF)},
      {'label': 'Completed', 'value': '${_counts['COMPLETED']}', 'color': AppColors.success, 'bg': const Color(0xFFF0FDF4)},
      {'label': 'Revenue', 'value': '₹${NumberFormat('#,##,###').format(_revenue.toInt())}', 'color': AppColors.success, 'bg': const Color(0xFFF0FDF4)},
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: items.map((item) => Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              color: item['bg'] as Color,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: (item['color'] as Color).withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['value'] as String, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: item['color'] as Color)),
                Text(item['label'] as String, style: const TextStyle(fontSize: 9, color: Color(0xFF64748B), fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              ],
            ),
          ),
        )).toList(),
      ),
    );
  }

  // ── ERROR BANNER ───────────────────────────────────────────────────────────

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded, color: Color(0xFFB91C1C), size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13, fontWeight: FontWeight.w600))),
        TextButton(
          onPressed: () => _loadPage(_currentPage),
          style: TextButton.styleFrom(backgroundColor: AppColors.danger, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
          child: const Text('Retry', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  // ── FILTER PILLS ───────────────────────────────────────────────────────────

  Widget _buildFilterPills() {
    const filters = ['ALL', 'PENDING', 'CONFIRMED', 'COMPLETED', 'CANCELLED'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final active = _filter == f;
          final cnt = _counts[f] ?? 0;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () { setState(() { _filter = f; }); },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: active ? AppColors.primaryLight : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: active ? AppColors.primaryLight : const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  '$f ($cnt)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── BOOKING CARD ───────────────────────────────────────────────────────────

  Widget _buildBookingCard(_Booking b, int idx) {
    final sc = _statusColor(b.status);
    final sbg = _statusBg(b.status);
    final isDeleting = _deletingId == b.id;

    return Opacity(
      opacity: isDeleting ? 0.5 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border(
            left: BorderSide(color: sc, width: 4),
            top: const BorderSide(color: Color(0xFFF1F5F9)),
            right: const BorderSide(color: Color(0xFFF1F5F9)),
            bottom: const BorderSide(color: Color(0xFFF1F5F9)),
          ),
          boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                // Avatar
                Container(
                  width: 46, height: 46,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)]),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    b.userName.isNotEmpty ? b.userName[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
                  ),
                ),
                const SizedBox(width: 12),
                // Name + subtitle
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isAdmin ? b.userName : 'Session with ${b.advisorName}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF0F172A)),
                    ),
                    if (widget.isAdmin)
                      Text('Consultant: ${b.advisorName}', style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                  ],
                )),
                // Serial + status badge
                Row(children: [
                  Text('#${_currentPage * _pageSize + idx + 1}', style: const TextStyle(fontSize: 11, color: Color(0xFFCBD5E1))),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(color: sbg, borderRadius: BorderRadius.circular(20), border: Border.all(color: sc.withValues(alpha: 0.4))),
                    child: Text(b.status, style: TextStyle(color: sc, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  ),
                ]),
              ]),

              // Date / time / mode / amount chips
              if (b.date.isNotEmpty || b.time.isNotEmpty || b.meetingMode.isNotEmpty || b.amount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Wrap(spacing: 8, runSpacing: 6, children: [
                    if (b.date.isNotEmpty)
                      _chip(Icons.calendar_today_outlined, b.date, const Color(0xFF64748B)),
                    if (b.time.isNotEmpty)
                      _timeChip(b.time),
                    if (b.meetingMode.isNotEmpty)
                      _chip(_modeIcon(b.meetingMode), _modeLabel(b.meetingMode), const Color(0xFF64748B)),
                    if (b.amount > 0)
                      _chip(Icons.currency_rupee, NumberFormat('#,##,###').format(b.amount.toInt()), AppColors.success),
                  ]),
                ),

              // Admin action buttons
              if (widget.isAdmin)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isDeleting ? null : () => _openEditDialog(b),
                        icon: const Icon(Icons.edit_outlined, size: 14),
                        label: const Text('Edit Status', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryLight,
                          side: const BorderSide(color: Color(0xFFBFDBFE)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isDeleting ? null : () => _deleteBooking(b.id),
                        icon: isDeleting
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.cancel_outlined, size: 14),
                        label: Text(isDeleting ? 'Cancelling…' : 'Cancel', style: const TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          side: BorderSide(color: AppColors.danger.withValues(alpha: 0.4)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ]),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _timeChip(String time) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(20)),
      child: Text(time, style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
    );
  }

  // ── EMPTY STATE ────────────────────────────────────────────────────────────

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📅', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            _totalElements == 0 ? 'No bookings yet.' : 'No ${_filter.toLowerCase()} bookings on this page.',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  // ── PAGINATION ─────────────────────────────────────────────────────────────

  Widget _buildPagination() {
    final pages = _pageNums();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(children: [
        Text(
          'Page ${_currentPage + 1} of $_totalPages  ·  $_totalElements total bookings',
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6, runSpacing: 6, alignment: WrapAlignment.center,
          children: [
            _pageBtn('← Prev', _currentPage > 0, () => _loadPage(_currentPage - 1)),
            ...pages.map((pg) {
              if (pg == '…') return const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Text('…', style: TextStyle(color: Color(0xFF94A3B8))));
              final p = pg as int;
              final active = p == _currentPage;
              final cached = _pageCache.containsKey(p);
              return GestureDetector(
                onTap: () => _loadPage(p),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 36, height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active ? AppColors.primaryLight : (cached ? const Color(0xFFEFF6FF) : Colors.white),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: active ? AppColors.primaryLight : (cached ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0)),
                      width: active ? 2 : 1.5,
                    ),
                  ),
                  child: Text(
                    '${p + 1}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                      color: active ? Colors.white : (cached ? AppColors.primaryLight : const Color(0xFF374151)),
                    ),
                  ),
                ),
              );
            }),
            _pageBtn('Next →', _currentPage < _totalPages - 1, () => _loadPage(_currentPage + 1)),
          ],
        ),
      ]),
    );
  }

  Widget _pageBtn(String label, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: enabled ? Colors.white : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700,
            color: enabled ? AppColors.primaryLight : const Color(0xFFCBD5E1),
          ),
        ),
      ),
    );
  }
}