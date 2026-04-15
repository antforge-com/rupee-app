// lib/features/consultant/consultant_dashboard.dart
// ignore_for_file: file_names, unnecessary_non_null_assertion, use_of_void_result
// ════════════════════════════════════════════════════════════════════════════
// FULLY REAL-TIME Consultant Dashboard — 100% feature parity with Web
//
// FIXED:
//  ✓ Profile tab ab load hoga — proper try/catch, error state with retry
//  ✓ Shift time controllers sahi se populate hote hain (Map parsing)
//  ✓ Photo display (NetworkImage) + photo upload (image_picker)
//  ✓ Flutter showTimePicker se shift times set karo
//  ✓ DisplayPrice (charges + ₹200) shown in edit form
//  ✓ Auth timeout — agar consultantId na mile toh retry option
//
// PUBSPEC dependencies needed (add if not present):
//   image_picker: ^1.0.7
//   cached_network_image: ^3.3.1
//   provider: any
//   dio: any
//   intl: any
// ════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart' as dio_pkg;
import 'package:finadvise/api_client.dart';
import 'package:finadvise/app_theme.dart';
import 'package:finadvise/auth_service.dart';
import 'package:finadvise/consultant_earnings_tab.dart';
import 'package:finadvise/consultant_timeslot_manager.dart';
import 'package:finadvise/login_screen.dart';
import 'package:finadvise/models/models.dart';
import 'package:finadvise/services/booking_service.dart';
import 'package:finadvise/services/consultant_service.dart';
import 'package:finadvise/services/feedback_service.dart';
import 'package:finadvise/services/notification_service.dart';
import 'package:finadvise/services/ticket_service.dart';
import 'package:finadvise/shared_widgets.dart';
import 'package:flutter/material.dart' hide Feedback;
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

// ─── Constants ───────────────────────────────────────────────────────────────

const _kApiBase = 'http://52.55.178.31:8081';

// ─── Extensions ──────────────────────────────────────────────────────────────

extension _TicketCompat on Ticket {
  String? get attachmentUrl {
    try { return (this as dynamic).attachmentUrl as String?; } catch (_) { return null; }
  }
  String? get ticketNumber {
    try { return (this as dynamic).ticketNumber as String?; } catch (_) { return null; }
  }
}

extension _ConsultantCompat on ConsultantModel {
  double get experience =>
      ((this as dynamic).yearsOfExperience as num?)?.toDouble() ?? 0.0;

  /// Returns HH:mm string for start time, empty if missing
  String get shiftStart => _parseLocalTime((this as dynamic).shiftStartTime);
  /// Returns HH:mm string for end time, empty if missing
  String get shiftEnd   => _parseLocalTime((this as dynamic).shiftEndTime);

  String get shiftTimingsDisplay {
    final s = shiftStart;
    final e = shiftEnd;
    if (s.isEmpty && e.isEmpty) return '—';
    return '$s – $e';
  }

  String? get profilePhotoUrl {
    try {
      final p = (this as dynamic).profilePhoto as String?;
      if (p == null || p.isEmpty) return null;
      if (p.startsWith('http') || p.startsWith('blob:')) return p;
      return '$_kApiBase${p.startsWith('/') ? p : '/$p'}';
    } catch (_) { return null; }
  }
}

String _parseLocalTime(dynamic raw) {
  if (raw == null) return '';
  try {
    if (raw is Map) {
      final h = (raw['hour'] as num? ?? 0).toInt();
      final m = (raw['minute'] as num? ?? 0).toInt();
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    }
    final s = raw.toString();
    if (s.length >= 5) return s.substring(0, 5);
  } catch (_) {}
  return '';
}

// ─── SLA helpers ─────────────────────────────────────────────────────────────

enum _SlaState { onTrack, warning, breached }

class _SlaInfo {
  final _SlaState state;
  final String label;
  const _SlaInfo(this.state, this.label);
}

_SlaInfo? _computeSla(Ticket t) {
  if (t.slaResolveBy == null) return null;
  if (['RESOLVED', 'CLOSED'].contains(t.status.toUpperCase())) return null;
  try {
    final deadline = DateTime.parse(t.slaResolveBy!);
    final diff = deadline.difference(DateTime.now());
    if (diff.isNegative) {
      return _SlaInfo(_SlaState.breached, 'BREACHED ${(-diff.inMinutes)}m ago');
    } else if (diff.inHours < 2) {
      return _SlaInfo(_SlaState.warning, 'DUE in ${diff.inMinutes}m');
    }
    return _SlaInfo(_SlaState.onTrack,
        'Due ${DateFormat('d MMM HH:mm').format(deadline)}');
  } catch (_) { return null; }
}

Color _slaColor(_SlaState s) {
  switch (s) {
    case _SlaState.breached: return AppColors.danger;
    case _SlaState.warning:  return AppColors.warning;
    case _SlaState.onTrack:  return AppColors.success;
  }
}

Color _statusColor(String s) {
  switch (s.toUpperCase()) {
    case 'CONFIRMED':   return AppColors.info;
    case 'COMPLETED':   return AppColors.success;
    case 'PENDING':     return AppColors.warning;
    case 'CANCELLED':   return AppColors.danger;
    case 'NEW':         return AppColors.primaryLight;
    case 'OPEN':        return AppColors.info;
    case 'IN_PROGRESS': return AppColors.warning;
    case 'RESOLVED':    return AppColors.success;
    case 'CLOSED':      return AppColors.textMuted;
    case 'ESCALATED':   return AppColors.danger;
    default:            return AppColors.textMuted;
  }
}

Color _priorityColor(String p) {
  switch (p.toUpperCase()) {
    case 'CRITICAL': return const Color(0xFF7C3AED);
    case 'URGENT':   return AppColors.danger;
    case 'HIGH':     return AppColors.warning;
    case 'MEDIUM':   return AppColors.info;
    default:         return AppColors.textMuted;
  }
}

// ─── Direct API wrappers ──────────────────────────────────────────────────────

final _api = ApiClient();

Future<List<dynamic>> _getTicketComments(int id) async {
  try {
    final r = await _api.dio.get('/api/tickets/$id/comments');
    final d = r.data;
    return d is List ? d : (d is Map ? (d['content'] ?? d['data'] ?? []) : []);
  } catch (_) { return []; }
}

Future<Map<String, dynamic>?> _postComment({
  required int ticketId, required int senderId,
  required bool isConsultantReply, required String message,
}) async {
  try {
    final r = await _api.dio.post('/api/tickets/comments', data: {
      'ticketId': ticketId, 'senderId': senderId,
      'isConsultantReply': isConsultantReply, 'message': message,
    });
    return r.data as Map<String, dynamic>;
  } catch (_) { return null; }
}

Future<List<dynamic>> _getInternalNotes(int id) async {
  try {
    final r = await _api.dio.get('/api/tickets/$id/notes');
    return r.data is List ? r.data : [];
  } catch (_) { return []; }
}

Future<Map<String, dynamic>?> _postNote({
  required int ticketId, required int authorId, required String noteText,
}) async {
  try {
    final r = await _api.dio.post('/api/tickets/$ticketId/notes',
        data: {'authorId': authorId, 'noteText': noteText});
    return r.data as Map<String, dynamic>;
  } catch (_) { return null; }
}

Future<bool> _escalateTicket(int id, String reason) async {
  try {
    await _api.dio.post('/api/tickets/$id/escalate', data: {'reason': reason});
    return true;
  } catch (_) { return false; }
}

Future<List<dynamic>> _getMyOffers() async {
  try {
    final r = await _api.dio.get('/api/offers/my-offers');
    final d = r.data;
    return d is List ? d : (d is Map ? (d['content'] ?? d['data'] ?? []) : []);
  } catch (_) { return []; }
}

Future<Map<String, dynamic>?> _saveOffer(Map<String, dynamic> data, {int? id}) async {
  try {
    final r = id != null
        ? await _api.dio.put('/api/offers/$id', data: data)
        : await _api.dio.post('/api/offers', data: data);
    return r.data as Map<String, dynamic>;
  } catch (_) { return null; }
}

Future<bool> _deleteOffer(int id) async {
  try { await _api.dio.delete('/api/offers/$id'); return true; }
  catch (_) { return false; }
}

Future<List<dynamic>> _getMasterSlots() async {
  try {
    final r = await _api.dio.get('/api/master-timeslots',
        queryParameters: {'page': 0, 'size': 100});
    final d = r.data;
    return d is Map ? (d['content'] ?? d['data'] ?? []) : (d is List ? d : []);
  } catch (_) { return []; }
}

Future<bool> _createMasterSlot(String t) async {
  try {
    await _api.dio.post('/api/master-timeslots', data: {'timeRange': t});
    return true;
  } catch (_) { return false; }
}

Future<bool> _updateMasterSlotApi(int id, String t) async {
  try {
    await _api.dio.put('/api/master-timeslots/$id', data: {'timeRange': t});
    return true;
  } catch (_) { return false; }
}

Future<bool> _deleteMasterSlotApi(int id) async {
  try { await _api.dio.delete('/api/master-timeslots/$id'); return true; }
  catch (_) { return false; }
}

// ════════════════════════════════════════════════════════════════════════════
// MAIN DASHBOARD SHELL
// ════════════════════════════════════════════════════════════════════════════

class ConsultantDashboard extends StatefulWidget {
  const ConsultantDashboard({super.key});
  @override
  State<ConsultantDashboard> createState() => _ConsultantDashboardState();
}

class _ConsultantDashboardState extends State<ConsultantDashboard> {
  int _selectedIndex = 0;
  int? _consultantIdInt;
  int? _userId;
  bool _authLoading = true;
  String? _authError;
  Timer? _refreshTimer;

  static const _navItems = [
    (icon: Icons.calendar_today_outlined, activeIcon: Icons.calendar_today,     label: 'Bookings'),
    (icon: Icons.confirmation_number_outlined, activeIcon: Icons.confirmation_number, label: 'Tickets'),
    (icon: Icons.schedule_outlined,        activeIcon: Icons.schedule,           label: 'Schedule'),
    (icon: Icons.star_outline,             activeIcon: Icons.star,               label: 'Feedback'),
    (icon: Icons.payments_outlined,        activeIcon: Icons.payments,           label: 'Earnings'),
    (icon: Icons.person_outline,           activeIcon: Icons.person,             label: 'Profile'),
  ];

  @override
  void initState() {
    super.initState();
    _initAuth();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _initAuth() async {
    setState(() { _authLoading = true; _authError = null; });
    try {
      final auth = AuthService();
      final cIdStr = await auth.getConsultantId();
      final uIdStr = await auth.getUserId();
      final cId = int.tryParse(cIdStr ?? '');
      final uId = int.tryParse(uIdStr ?? '');

      if (!mounted) return;
      if (cId == null) {
        setState(() {
          _authLoading = false;
          _authError = 'Consultant ID not found. Please logout and login again.';
        });
        return;
      }
      setState(() {
        _consultantIdInt = cId;
        _userId = uId;
        _authLoading = false;
      });
      context.read<NotificationService>().initialize('CONSULTANT', cId);
      _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) context.read<NotificationService>().refresh();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _authLoading = false; _authError = e.toString(); });
    }
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await AuthService().logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(context,
            MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
      }
    }
  }

  void _openNotifications() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65, maxChildSize: 0.95, minChildSize: 0.4,
        expand: false,
        builder: (_, sc) => _NotificationPanel(
            scrollController: sc, onClose: () => Navigator.pop(ctx)),
      ),
    );
  }

  Widget _currentTab() {
    // Auth still loading
    if (_authLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    // Auth error — show retry
    if (_authError != null || _consultantIdInt == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.error_outline, size: 56, color: AppColors.danger),
            const SizedBox(height: 16),
            Text(_authError ?? 'Could not load consultant profile',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _initAuth,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _confirmLogout,
              child: const Text('Logout', style: TextStyle(color: AppColors.danger)),
            ),
          ]),
        ),
      );
    }
    switch (_selectedIndex) {
      case 0: return _ConsultantBookingsTab(
          consultantId: _consultantIdInt!, userId: _userId ?? 0);
      case 1: return _ConsultantTicketsTab(
          consultantId: _consultantIdInt!, userId: _userId ?? 0);
      case 2: return _ConsultantScheduleTab(consultantId: _consultantIdInt!);
      case 3: return _ConsultantFeedbacksTab(consultantId: _consultantIdInt!);
      case 4: return ConsultantEarningsTab(consultantId: _consultantIdInt!);
      case 5: return _ConsultantProfileTab(consultantId: _consultantIdInt!);
      default: return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: AppColors.accent, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.work_outline, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('FINADVISE',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                    color: AppColors.primary, letterSpacing: 1)),
            Text(_navItems[_selectedIndex].label, style: AppTextStyles.caption),
          ]),
        ]),
        actions: [
          Consumer<NotificationService>(
            builder: (_, svc, __) => Stack(children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined,
                    color: AppColors.textPrimary),
                onPressed: _openNotifications,
              ),
              if (svc.unreadCount > 0)
                Positioned(right: 8, top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                          color: AppColors.danger, shape: BoxShape.circle),
                      child: Text(
                        svc.unreadCount > 9 ? '9+' : '${svc.unreadCount}',
                        style: const TextStyle(color: Colors.white,
                            fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    )),
            ]),
          ),
          PopupMenuButton<String>(
            offset: const Offset(0, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            icon: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.accent.withValues(alpha: 0.2),
              child: const Icon(Icons.person_outline,
                  color: AppColors.accent, size: 18),
            ),
            onSelected: (v) {
              if (v == 'logout') _confirmLogout();
              if (v == 'profile') setState(() => _selectedIndex = 5);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'profile',
                  child: Row(children: [
                    Icon(Icons.person_outline, size: 18,
                        color: AppColors.textSecondary),
                    SizedBox(width: 10), Text('My Profile'),
                  ])),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'logout',
                  child: Row(children: [
                    Icon(Icons.logout, size: 18, color: AppColors.danger),
                    SizedBox(width: 10),
                    Text('Logout', style: TextStyle(color: AppColors.danger)),
                  ])),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _currentTab(),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border)),
            color: AppColors.surface),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (i) => setState(() => _selectedIndex = i),
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.accent,
          unselectedItemColor: AppColors.textMuted,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedFontSize: 10,
          unselectedFontSize: 10,
          items: _navItems.map((n) => BottomNavigationBarItem(
            icon: Icon(n.icon, size: 22),
            activeIcon: Icon(n.activeIcon, size: 22),
            label: n.label,
          )).toList(),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// BOOKINGS TAB
// ════════════════════════════════════════════════════════════════════════════

class _ConsultantBookingsTab extends StatefulWidget {
  final int consultantId;
  final int userId;
  const _ConsultantBookingsTab({required this.consultantId, required this.userId});
  @override
  State<_ConsultantBookingsTab> createState() => _ConsultantBookingsTabState();
}

class _ConsultantBookingsTabState extends State<_ConsultantBookingsTab>
    with SingleTickerProviderStateMixin {
  final _svc = BookingService();
  late TabController _tabs;
  List<Booking> _bookings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    _bookings = await _svc.getBookingsByConsultant(widget.consultantId, size: 100);
    if (mounted) setState(() => _loading = false);
  }

  List<Booking> get _upcoming =>
      _bookings.where((b) => b.status.toUpperCase() == 'CONFIRMED' && !b.isExpired).toList();
  List<Booking> get _pending =>
      _bookings.where((b) => b.status.toUpperCase() == 'PENDING').toList();
  List<Booking> get _history =>
      _bookings.where((b) =>
          b.isExpired || ['COMPLETED', 'CANCELLED'].contains(b.status.toUpperCase())).toList();

  Future<void> _updateStatus(Booking b, String newStatus) async {
    final ok = await _svc.updateBooking(b.id, bookingStatus: newStatus);
    if (mounted) {
      _snack(ok ? 'Status → $newStatus' : 'Update failed', ok);
      if (ok) _load();
    }
  }

  Future<void> _cancelBooking(Booking b) async {
    final confirm = await _confirmDialog(
        'Cancel Booking #${b.id}?', 'This cannot be undone.', 'Cancel', AppColors.danger);
    if (confirm != true) return;
    final ok = await _svc.cancelBooking(b.id);
    if (mounted) {
      _snack(ok ? 'Booking cancelled' : 'Cancel failed', ok);
      if (ok) _load();
    }
  }

  Future<void> _markComplete(Booking b) async {
    final confirm = await _confirmDialog(
        'Mark as Completed?', 'Booking #${b.id} will be marked complete.', 'Complete', AppColors.success);
    if (confirm != true) return;
    final ok = await _svc.updateBooking(b.id, bookingStatus: 'COMPLETED');
    if (mounted) {
      _snack(ok ? 'Marked as completed ✓' : 'Update failed', ok);
      if (ok) _load();
    }
  }

  void _showMeetingLinkSheet(Booking b) {
    final ctrl = TextEditingController(text: b.meetingLink ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          _handleBar(),
          Text('Meeting Link — Booking #${b.id}', style: AppTextStyles.h3),
          const SizedBox(height: 16),
          TextField(controller: ctrl,
              decoration: const InputDecoration(
                  labelText: 'Meeting URL',
                  hintText: 'https://meet.jit.si/...',
                  prefixIcon: Icon(Icons.videocam_outlined))),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, height: 48,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('Save Link',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              onPressed: () async {
                final ok = await _svc.addMeetingLink(b.id, meetingLink: ctrl.text.trim());
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  _snack(ok ? 'Meeting link saved!' : 'Failed to save', ok);
                  if (ok) _load();
                }
              },
            ),
          ),
        ]),
      ),
    );
  }

  void _showActionSheet(Booking b) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text('Booking #${b.id}', style: AppTextStyles.h3)),
          const Divider(height: 1),
          if (b.meetingLink != null && b.meetingLink!.isNotEmpty)
            _actionTile(Icons.copy_outlined, 'Copy Meeting Link', AppColors.info, () {
              Navigator.pop(context);
              Clipboard.setData(ClipboardData(text: b.meetingLink!));
              _snack('Meeting link copied!', true);
            }),
          _actionTile(Icons.video_call_outlined, 'Set / Update Meeting Link',
              AppColors.primaryLight, () {
            Navigator.pop(context);
            _showMeetingLinkSheet(b);
          }),
          if (b.status.toUpperCase() == 'PENDING')
            _actionTile(Icons.check_circle_outline, 'Confirm Booking', AppColors.success, () {
              Navigator.pop(context);
              _updateStatus(b, 'CONFIRMED');
            }),
          if (b.status.toUpperCase() == 'CONFIRMED')
            _actionTile(Icons.task_alt_rounded, 'Mark as Completed', AppColors.success, () {
              Navigator.pop(context);
              _markComplete(b);
            }),
          if (!['CANCELLED', 'COMPLETED'].contains(b.status.toUpperCase()))
            _actionTile(Icons.cancel_outlined, 'Cancel Booking', AppColors.danger, () {
              Navigator.pop(context);
              _cancelBooking(b);
            }),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        color: AppColors.surface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          _pill(_pending.length, AppColors.warning, 'Pending'),
          const SizedBox(width: 8),
          _pill(_upcoming.length, AppColors.info, 'Upcoming'),
          const Spacer(),
          Text('${_bookings.length} total', style: AppTextStyles.caption),
        ]),
      ),
      Container(
        color: AppColors.surface,
        child: TabBar(
          controller: _tabs,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.accent,
          tabs: [
            Tab(text: 'Upcoming (${_upcoming.length})'),
            Tab(text: 'Pending (${_pending.length})'),
            const Tab(text: 'History'),
          ],
        ),
      ),
      const Divider(height: 1),
      Expanded(
        child: _loading
            ? ListView.builder(padding: const EdgeInsets.all(16),
                itemCount: 4,
                itemBuilder: (_, __) => const Padding(
                    padding: EdgeInsets.only(bottom: 12), child: ShimmerCard()))
            : RefreshIndicator(
                onRefresh: _load,
                child: TabBarView(controller: _tabs, children: [
                  _buildList(_upcoming, 'No upcoming sessions'),
                  _buildList(_pending, 'No pending bookings'),
                  _buildList(_history, 'No history yet'),
                ]),
              ),
      ),
    ]);
  }

  Widget _buildList(List<Booking> list, String emptyTitle) {
    if (list.isEmpty) return EmptyState(icon: Icons.calendar_today_outlined, title: emptyTitle);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final b = list[i];
        final color = _statusColor(b.status);
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => _showActionSheet(b),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.event_outlined, color: color, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Booking #${b.id}', style: AppTextStyles.h4),
                    Text([
                      if (b.meetingMode != null) b.meetingMode,
                      if (b.slotDate != null) b.slotDate,
                      if (b.timeRange != null) b.timeRange,
                    ].where((x) => x != null && x!.isNotEmpty).join('  ·  '),
                        style: AppTextStyles.caption),
                    if (b.clientName != null)
                      Text('Client: ${b.clientName}', style: AppTextStyles.caption),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(b.status,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                    ),
                    if (b.amount != null) ...[
                      const SizedBox(height: 4),
                      Text('₹${b.amount!.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 13,
                              color: AppColors.success, fontWeight: FontWeight.w700)),
                    ],
                  ]),
                ]),
                if (b.meetingLink != null && b.meetingLink!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: b.meetingLink!));
                      _snack('Meeting link copied!', true);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.info.withValues(alpha: 0.25))),
                      child: Row(children: [
                        const Icon(Icons.videocam_outlined, size: 14, color: AppColors.info),
                        const SizedBox(width: 6),
                        Expanded(child: Text(b.meetingLink!,
                            style: const TextStyle(fontSize: 11, color: AppColors.info),
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                        const Icon(Icons.copy_rounded, size: 12, color: AppColors.info),
                      ]),
                    ),
                  ),
                ],
                if (['CONFIRMED', 'PENDING'].contains(b.status.toUpperCase())) ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: OutlinedButton.icon(
                      onPressed: () => _showMeetingLinkSheet(b),
                      icon: const Icon(Icons.video_call_outlined, size: 16),
                      label: Text(b.meetingLink?.isNotEmpty == true ? 'Update Link' : 'Add Link',
                          style: const TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          side: const BorderSide(color: AppColors.primaryLight),
                          foregroundColor: AppColors.primaryLight),
                    )),
                    const SizedBox(width: 8),
                    if (b.status.toUpperCase() == 'CONFIRMED')
                      Expanded(child: ElevatedButton.icon(
                        onPressed: () => _markComplete(b),
                        icon: const Icon(Icons.check_circle_outline, size: 16),
                        label: const Text('Complete', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            padding: const EdgeInsets.symmetric(vertical: 8)),
                      ))
                    else if (b.status.toUpperCase() == 'PENDING')
                      Expanded(child: ElevatedButton.icon(
                        onPressed: () => _updateStatus(b, 'CONFIRMED'),
                        icon: const Icon(Icons.thumb_up_outlined, size: 16),
                        label: const Text('Confirm', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.info,
                            padding: const EdgeInsets.symmetric(vertical: 8)),
                      )),
                  ]),
                ],
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _pill(int count, Color color, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 6, height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text('$count $label', style: TextStyle(fontSize: 11, color: color,
          fontWeight: FontWeight.w600)),
    ]),
  );

  Future<bool?> _confirmDialog(String title, String content, String action, Color color) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title), content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: color,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, true),
            child: Text(action, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _snack(String msg, bool ok) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? AppColors.success : AppColors.danger,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  Widget _actionTile(IconData icon, String label, Color color, VoidCallback onTap) =>
    ListTile(leading: Icon(icon, color: color, size: 20),
        title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        onTap: onTap, dense: true);
}

// ════════════════════════════════════════════════════════════════════════════
// TICKETS TAB
// ════════════════════════════════════════════════════════════════════════════

class _ConsultantTicketsTab extends StatefulWidget {
  final int consultantId;
  final int userId;
  const _ConsultantTicketsTab({required this.consultantId, required this.userId});
  @override
  State<_ConsultantTicketsTab> createState() => _ConsultantTicketsTabState();
}

class _ConsultantTicketsTabState extends State<_ConsultantTicketsTab> {
  final _svc = TicketService();
  List<Ticket> _tickets = [];
  bool _loading = true;
  String _filter = 'ALL';
  static const _filters = ['ALL', 'NEW', 'OPEN', 'IN_PROGRESS', 'RESOLVED'];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    _tickets = await _svc.getTicketsByConsultant(widget.consultantId);
    if (mounted) setState(() => _loading = false);
  }

  List<Ticket> get _filtered => _filter == 'ALL'
      ? _tickets
      : _tickets.where((t) => t.status.toUpperCase() == _filter).toList();

  int get _slaRiskCount => _tickets.where((t) {
    final s = _computeSla(t);
    return s?.state == _SlaState.breached || s?.state == _SlaState.warning;
  }).length;

  void _openDetail(Ticket t) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.92, maxChildSize: 0.95, minChildSize: 0.6,
        expand: false,
        builder: (_, sc) => _TicketDetailSheet(
          ticket: t, consultantId: widget.consultantId,
          scrollController: sc,
          onStatusChanged: (newStatus) {
            setState(() {
              final idx = _tickets.indexWhere((x) => x.id == t.id);
              if (idx != -1) {
                _tickets[idx] = Ticket(
                  id: t.id, category: t.category, description: t.description,
                  status: newStatus, priority: t.priority, userId: t.userId,
                  consultantId: t.consultantId, userName: t.userName,
                  slaRespondBy: t.slaRespondBy, slaResolveBy: t.slaResolveBy,
                  createdAt: t.createdAt,
                );
              }
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      if (_slaRiskCount > 0)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AppColors.danger.withValues(alpha: 0.1),
          child: Row(children: [
            const Icon(Icons.warning_rounded, color: AppColors.danger, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(
              '$_slaRiskCount ticket${_slaRiskCount > 1 ? 's' : ''} at SLA risk — respond now',
              style: const TextStyle(color: AppColors.danger,
                  fontSize: 12, fontWeight: FontWeight.w600),
            )),
          ]),
        ),
      Container(
        color: AppColors.surface,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: _filters.map((f) {
            final count = f == 'ALL'
                ? _tickets.length
                : _tickets.where((t) => t.status.toUpperCase() == f).length;
            final active = _filter == f;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('$f ($count)', style: TextStyle(fontSize: 12,
                    color: active ? Colors.white : AppColors.textSecondary)),
                selected: active,
                selectedColor: AppColors.primaryLight,
                backgroundColor: AppColors.surfaceVariant,
                onSelected: (_) => setState(() => _filter = f),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                side: BorderSide.none,
              ),
            );
          }).toList()),
        ),
      ),
      const Divider(height: 1),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _filtered.isEmpty
                ? const EmptyState(icon: Icons.inbox_outlined,
                    title: 'No tickets assigned')
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final t = _filtered[i];
                        return _TicketListCard(
                          ticket: t, sla: _computeSla(t),
                          onTap: () => _openDetail(t),
                        );
                      },
                    ),
                  ),
      ),
    ]);
  }
}

class _TicketListCard extends StatelessWidget {
  final Ticket ticket;
  final _SlaInfo? sla;
  final VoidCallback onTap;
  const _TicketListCard({required this.ticket, required this.sla, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sc = _statusColor(ticket.status);
    final pc = _priorityColor(ticket.priority);
    final slaBreached = sla?.state == _SlaState.breached;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(children: [
          if (sla != null)
            Container(height: 3, color: _slaColor(sla!.state)),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('#${ticket.id}  ${ticket.category.isEmpty ? "General" : ticket.category}',
                      style: AppTextStyles.h4, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (ticket.description != null)
                    Text(ticket.description!, style: AppTextStyles.caption,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                ])),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: sc.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(ticket.status,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: sc)),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: pc.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(ticket.priority,
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: pc)),
                  ),
                ]),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.person_outline, size: 13, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(ticket.userName ?? 'User', style: AppTextStyles.caption),
                const Spacer(),
                if (sla != null) Row(children: [
                  Icon(slaBreached ? Icons.alarm_off : Icons.timer_outlined,
                      size: 12, color: _slaColor(sla!.state)),
                  const SizedBox(width: 3),
                  Text(sla!.label, style: TextStyle(fontSize: 10,
                      color: _slaColor(sla!.state), fontWeight: FontWeight.w700)),
                ]),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _TicketDetailSheet extends StatefulWidget {
  final Ticket ticket;
  final int consultantId;
  final ScrollController scrollController;
  final Function(String) onStatusChanged;
  const _TicketDetailSheet({required this.ticket, required this.consultantId,
      required this.scrollController, required this.onStatusChanged});
  @override
  State<_TicketDetailSheet> createState() => _TicketDetailSheetState();
}

class _TicketDetailSheetState extends State<_TicketDetailSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<dynamic> _comments = [];
  List<dynamic> _notes = [];
  bool _loadingComments = true;
  bool _loadingNotes = true;
  bool _sendingReply = false;
  bool _sendingNote = false;
  bool _updatingStatus = false;
  bool _escalating = false;
  String _localStatus = '';
  final _replyCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _scrollToBottom = ScrollController();
  static const _statuses = ['NEW', 'OPEN', 'IN_PROGRESS', 'PENDING', 'RESOLVED', 'CLOSED'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _localStatus = widget.ticket.status;
    _loadComments();
    _loadNotes();
  }

  @override
  void dispose() {
    _tabs.dispose(); _replyCtrl.dispose();
    _noteCtrl.dispose(); _scrollToBottom.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _loadingComments = true);
    _comments = await _getTicketComments(widget.ticket.id);
    if (mounted) setState(() => _loadingComments = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollToBottom.hasClients) {
        _scrollToBottom.jumpTo(_scrollToBottom.position.maxScrollExtent);
      }
    });
  }

  Future<void> _loadNotes() async {
    setState(() => _loadingNotes = true);
    _notes = await _getInternalNotes(widget.ticket.id);
    if (mounted) setState(() => _loadingNotes = false);
  }

  Future<void> _sendReply() async {
    if (_replyCtrl.text.trim().isEmpty) return;
    final msg = _replyCtrl.text.trim();
    setState(() => _sendingReply = true);
    final saved = await _postComment(
      ticketId: widget.ticket.id, senderId: widget.consultantId,
      isConsultantReply: true, message: msg,
    );
    if (mounted) {
      if (saved != null) {
        _replyCtrl.clear();
        setState(() { _comments.add(saved); });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollToBottom.hasClients) {
            _scrollToBottom.animateTo(_scrollToBottom.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
          }
        });
        if (_localStatus.toUpperCase() == 'NEW') await _changeStatus('OPEN');
      } else {
        _snack('Failed to send reply', false);
      }
      setState(() => _sendingReply = false);
    }
  }

  Future<void> _saveNote() async {
    if (_noteCtrl.text.trim().isEmpty) return;
    final txt = _noteCtrl.text.trim();
    setState(() => _sendingNote = true);
    final saved = await _postNote(ticketId: widget.ticket.id,
        authorId: widget.consultantId, noteText: txt);
    if (mounted) {
      if (saved != null) {
        _noteCtrl.clear();
        setState(() { _notes.add(saved); });
        _snack('🔒 Note saved', true);
      } else {
        _snack('Failed to save note', false);
      }
      setState(() => _sendingNote = false);
    }
  }

  Future<void> _changeStatus(String newStatus) async {
    if (_updatingStatus || _localStatus == newStatus) return;
    setState(() => _updatingStatus = true);
    final ok = await TicketService().updateTicketStatus(widget.ticket.id, newStatus);
    if (mounted) {
      if (ok) {
        setState(() => _localStatus = newStatus);
        widget.onStatusChanged(newStatus);
        _snack('Status → $newStatus', true);
      } else {
        _snack('Status update failed', false);
      }
      setState(() => _updatingStatus = false);
    }
  }

  Future<void> _showEscalateDialog() async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Escalate Ticket'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Provide a reason for escalation:', style: TextStyle(fontSize: 13)),
          const SizedBox(height: 12),
          TextField(controller: ctrl, maxLines: 3,
              decoration: const InputDecoration(
                  hintText: 'Why is this being escalated?', border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Escalate', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;
    setState(() => _escalating = true);
    final ok = await _escalateTicket(widget.ticket.id, reason);
    if (mounted) {
      if (ok) {
        setState(() => _localStatus = 'ESCALATED');
        widget.onStatusChanged('ESCALATED');
        _snack('🚨 Escalated — supervisor notified', true);
      } else {
        _snack('Escalation failed', false);
      }
      setState(() => _escalating = false);
    }
  }

  void _snack(String msg, bool ok) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? AppColors.success : AppColors.danger,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final sc = _statusColor(_localStatus);
    final pc = _priorityColor(widget.ticket.priority);
    final slaTicket = Ticket(id: widget.ticket.id, category: widget.ticket.category,
        description: widget.ticket.description, status: _localStatus,
        priority: widget.ticket.priority, userId: widget.ticket.userId,
        consultantId: widget.ticket.consultantId, userName: widget.ticket.userName,
        slaRespondBy: widget.ticket.slaRespondBy, slaResolveBy: widget.ticket.slaResolveBy,
        createdAt: widget.ticket.createdAt);
    final sla = _computeSla(slaTicket);

    return Column(children: [
      Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: _handleBar()),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('#${widget.ticket.id}  ${widget.ticket.category}', style: AppTextStyles.h3),
              if (widget.ticket.userName != null)
                Text('Client: ${widget.ticket.userName}', style: AppTextStyles.caption),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: sc.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: sc.withValues(alpha: 0.4))),
              child: Text(_localStatus,
                  style: TextStyle(color: sc, fontWeight: FontWeight.w700, fontSize: 12)),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(color: pc.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Text(widget.ticket.priority,
                  style: TextStyle(color: pc, fontWeight: FontWeight.w700, fontSize: 11)),
            ),
          ]),
          if (sla != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: _slaColor(sla.state).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _slaColor(sla.state).withValues(alpha: 0.3))),
              child: Row(children: [
                Icon(sla.state == _SlaState.breached ? Icons.alarm_off : Icons.timer_outlined,
                    size: 14, color: _slaColor(sla.state)),
                const SizedBox(width: 6),
                Text(sla.label, style: TextStyle(fontSize: 11,
                    color: _slaColor(sla.state), fontWeight: FontWeight.w700)),
              ]),
            ),
          ],
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: _statuses.map((s) {
              final active = _localStatus.toUpperCase() == s;
              final c = _statusColor(s);
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: active ? null : () => _changeStatus(s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: active ? c.withValues(alpha: 0.15) : c.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: active ? c : c.withValues(alpha: 0.3),
                            width: active ? 2 : 1)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (active && !_updatingStatus) Icon(Icons.check, size: 12, color: c),
                      if (_updatingStatus && active)
                        SizedBox(width: 12, height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2, color: c)),
                      if (active) const SizedBox(width: 4),
                      Text(s, style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12)),
                    ]),
                  ),
                ),
              );
            }).toList()),
          ),
          if (!['RESOLVED', 'CLOSED', 'ESCALATED'].contains(_localStatus.toUpperCase())) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _escalating ? null : _showEscalateDialog,
                icon: _escalating
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.call_missed_outgoing_rounded,
                        size: 16, color: AppColors.danger),
                label: const Text('Escalate to Supervisor',
                    style: TextStyle(color: AppColors.danger, fontSize: 13)),
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.danger),
                    padding: const EdgeInsets.symmetric(vertical: 8)),
              ),
            ),
          ],
        ]),
      ),
      TabBar(
        controller: _tabs,
        labelColor: AppColors.accent,
        unselectedLabelColor: AppColors.textMuted,
        indicatorColor: AppColors.accent,
        tabs: [
          Tab(text: 'Chat (${_comments.length})'),
          Tab(text: 'Notes (${_notes.length})'),
          const Tab(text: 'Details'),
        ],
      ),
      const Divider(height: 1),
      Expanded(
        child: TabBarView(controller: _tabs, children: [
          // Chat
          Column(children: [
            Expanded(
              child: _loadingComments
                  ? const Center(child: CircularProgressIndicator())
                  : _comments.isEmpty
                      ? const Center(child: Text('No messages yet',
                          style: TextStyle(color: AppColors.textMuted)))
                      : ListView.builder(
                          controller: _scrollToBottom,
                          padding: const EdgeInsets.all(16),
                          itemCount: _comments.length,
                          itemBuilder: (_, i) {
                            final c = _comments[i] as Map<String, dynamic>;
                            final isAgent = c['consultantReply'] == true ||
                                c['isConsultantReply'] == true;
                            return _ChatBubble(
                              message: c['message'] ?? '',
                              isAgent: isAgent,
                              senderName: isAgent ? 'You' : (widget.ticket.userName ?? 'Client'),
                              time: c['createdAt'] != null
                                  ? DateFormat('d MMM HH:mm').format(
                                      DateTime.tryParse(c['createdAt']) ?? DateTime.now())
                                  : '',
                            );
                          }),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
              child: Row(children: [
                Expanded(child: TextField(
                  controller: _replyCtrl, maxLines: null,
                  decoration: InputDecoration(
                    hintText: 'Type reply…', filled: true, fillColor: AppColors.background,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                )),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendingReply ? null : _sendReply,
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                        color: _sendingReply ? AppColors.textMuted : AppColors.accent,
                        shape: BoxShape.circle),
                    child: _sendingReply
                        ? const Padding(padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ]),
            ),
          ]),

          // Notes
          Column(children: [
            Expanded(
              child: _loadingNotes
                  ? const Center(child: CircularProgressIndicator())
                  : _notes.isEmpty
                      ? const Center(child: Text('No internal notes',
                          style: TextStyle(color: AppColors.textMuted)))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _notes.length,
                          itemBuilder: (_, i) {
                            final n = _notes[i] as Map<String, dynamic>;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                  color: AppColors.warning.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: AppColors.warning.withValues(alpha: 0.25))),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  const Icon(Icons.lock_outline, size: 13, color: AppColors.warning),
                                  const SizedBox(width: 4),
                                  const Text('Internal Note', style: TextStyle(
                                      fontSize: 10, color: AppColors.warning, fontWeight: FontWeight.w700)),
                                  const Spacer(),
                                  if (n['createdAt'] != null)
                                    Text(DateFormat('d MMM HH:mm').format(
                                        DateTime.tryParse(n['createdAt']) ?? DateTime.now()),
                                        style: AppTextStyles.caption),
                                ]),
                                const SizedBox(height: 6),
                                Text(n['noteText'] ?? '', style: AppTextStyles.body),
                              ]),
                            );
                          }),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
              child: Row(children: [
                const Icon(Icons.lock_outline, size: 16, color: AppColors.warning),
                const SizedBox(width: 8),
                Expanded(child: TextField(
                  controller: _noteCtrl,
                  decoration: InputDecoration(
                    hintText: 'Add private note…', filled: true,
                    fillColor: AppColors.warning.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                )),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendingNote ? null : _saveNote,
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                        color: _sendingNote ? AppColors.textMuted : AppColors.warning,
                        shape: BoxShape.circle),
                    child: _sendingNote
                        ? const Padding(padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_outlined, color: Colors.white, size: 20),
                  ),
                ),
              ]),
            ),
          ]),

          // Details
          ListView(controller: widget.scrollController, padding: const EdgeInsets.all(16), children: [
            _detailRow('Ticket #', '${widget.ticket.id}'),
            if (widget.ticket.ticketNumber != null)
              _detailRow('Ticket No.', widget.ticket.ticketNumber!),
            _detailRow('Category', widget.ticket.category),
            _detailRow('Priority', widget.ticket.priority),
            _detailRow('Status', _localStatus),
            if (widget.ticket.userName != null) _detailRow('Client', widget.ticket.userName!),
            if (widget.ticket.description != null) ...[
              const SizedBox(height: 8),
              const Text('Description', style: TextStyle(fontSize: 11,
                  fontWeight: FontWeight.w700, color: AppColors.textMuted)),
              const SizedBox(height: 4),
              Container(
                width: double.infinity, padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border)),
                child: Text(widget.ticket.description!, style: AppTextStyles.body),
              ),
            ],
            if (widget.ticket.attachmentUrl != null) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: widget.ticket.attachmentUrl!));
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Attachment URL copied'),
                          behavior: SnackBarBehavior.floating));
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    const Icon(Icons.attach_file_rounded, size: 16, color: AppColors.info),
                    const SizedBox(width: 8),
                    const Text('View Attachment',
                        style: TextStyle(color: AppColors.info, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    const Icon(Icons.copy_rounded, size: 14, color: AppColors.info),
                  ]),
                ),
              ),
            ],
            if (widget.ticket.slaResolveBy != null) ...[
              const SizedBox(height: 12),
              _detailRow('SLA Deadline', () {
                try { return DateFormat('d MMM yyyy, HH:mm')
                    .format(DateTime.parse(widget.ticket.slaResolveBy!)); }
                catch (_) { return widget.ticket.slaResolveBy!; }
              }()),
            ],
            if (widget.ticket.createdAt != null)
              _detailRow('Created', () {
                try { return DateFormat('d MMM yyyy, HH:mm')
                    .format(DateTime.parse(widget.ticket.createdAt!)); }
                catch (_) { return widget.ticket.createdAt!; }
              }()),
          ]),
        ]),
      ),
    ]);
  }

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      SizedBox(width: 110, child: Text(label, style: AppTextStyles.caption)),
      Expanded(child: Text(value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
    ]),
  );
}

class _ChatBubble extends StatelessWidget {
  final String message;
  final bool isAgent;
  final String senderName;
  final String time;
  const _ChatBubble({required this.message, required this.isAgent,
      required this.senderName, required this.time});

  @override
  Widget build(BuildContext context) {
    final bgColor = isAgent ? AppColors.accent : AppColors.background;
    final textColor = isAgent ? Colors.white : AppColors.textPrimary;
    return Align(
      alignment: isAgent ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Column(
            crossAxisAlignment: isAgent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
          Text(senderName, style: const TextStyle(fontSize: 10,
              color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isAgent ? 16 : 4),
                  bottomRight: Radius.circular(isAgent ? 4 : 16),
                )),
            child: Text(message, style: TextStyle(fontSize: 14, color: textColor, height: 1.4)),
          ),
          const SizedBox(height: 2),
          Text(time, style: AppTextStyles.caption),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SCHEDULE TAB
// ════════════════════════════════════════════════════════════════════════════

class _ConsultantScheduleTab extends StatefulWidget {
  final int consultantId;
  const _ConsultantScheduleTab({required this.consultantId});
  @override
  State<_ConsultantScheduleTab> createState() => _ConsultantScheduleTabState();
}

class _ConsultantScheduleTabState extends State<_ConsultantScheduleTab> {
  final _svc = ConsultantService();
  List<TimeSlot> _allSlots = [];
  List<dynamic> _masterSlots = [];
  bool _loading = true;
  String _selectedDate = '';

  List<DateTime> get _days => List.generate(30, (i) => DateTime.now().add(Duration(days: i)));
  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _selectedDate = _dateKey(DateTime.now());
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _svc.getSlotsByConsultant(widget.consultantId),
      _getMasterSlots(),
    ]);
    if (mounted) {
      setState(() {
        _allSlots = results[0] as List<TimeSlot>;
        _masterSlots = results[1] as List<dynamic>;
        _loading = false;
      });
    }
  }

  List<TimeSlot> get _slotsForDate =>
      _allSlots.where((s) => s.slotDate == _selectedDate).toList();

  Future<void> _toggleSlot(TimeSlot slot) async {
    final newStatus = slot.status == 'UNAVAILABLE' ? 'AVAILABLE' : 'UNAVAILABLE';
    final ok = await _svc.updateTimeSlot(slot.id, {
      'status': newStatus, 'consultantId': widget.consultantId,
      'slotDate': slot.slotDate, 'masterTimeSlotId': slot.masterTimeSlotId,
      'durationMinutes': 60,
    });
    if (mounted) {
      _snack(ok ? (newStatus == 'UNAVAILABLE' ? 'Slot blocked' : 'Slot restored') : 'Update failed', ok);
      if (ok) _load();
    }
  }

  void _openMasterSlots() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7, maxChildSize: 0.95, minChildSize: 0.4,
        expand: false,
        builder: (_, sc) => _MasterSlotsSheet(
          masterSlots: _masterSlots, scrollController: sc, onChanged: _load),
      ),
    );
  }

  void _openFullManager() async {
    await Navigator.push(context, MaterialPageRoute(
        builder: (_) => ConsultantTimeslotManager(consultantId: widget.consultantId)));
    _load();
  }

  Color _slotColor(String status) {
    switch (status) {
      case 'AVAILABLE':   return AppColors.success;
      case 'BOOKED':      return AppColors.primaryLight;
      case 'UNAVAILABLE': return AppColors.textMuted;
      default:            return AppColors.textMuted;
    }
  }

  void _snack(String msg, bool ok) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? AppColors.success : AppColors.danger,
      behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final available = _allSlots.where((s) => s.status == 'AVAILABLE').length;
    final booked = _allSlots.where((s) => s.status == 'BOOKED').length;
    final blocked = _allSlots.where((s) => s.status == 'UNAVAILABLE').length;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end, children: [
        FloatingActionButton.small(
          heroTag: 'masterSlots', onPressed: _openMasterSlots,
          backgroundColor: AppColors.warning, tooltip: 'Master Time Ranges',
          child: const Icon(Icons.access_time_rounded, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 8),
        FloatingActionButton.extended(
          heroTag: 'manageSchedule', onPressed: _openFullManager,
          backgroundColor: AppColors.primaryLight,
          icon: const Icon(Icons.tune_rounded, color: Colors.white),
          label: const Text('Manage Schedule',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: Column(children: [
                Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(children: [
                    _statPill(available, AppColors.success, 'Available'),
                    const SizedBox(width: 8),
                    _statPill(booked, AppColors.info, 'Booked'),
                    const SizedBox(width: 8),
                    _statPill(blocked, AppColors.textMuted, 'Blocked'),
                    const Spacer(),
                    Text('${_allSlots.length} total', style: AppTextStyles.caption),
                  ]),
                ),
                const Divider(height: 1),
                Container(
                  color: AppColors.surface, height: 74,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: _days.length,
                    itemBuilder: (_, i) {
                      final d = _days[i];
                      final key = _dateKey(d);
                      final isSelected = key == _selectedDate;
                      final slotCount = _allSlots.where((s) => s.slotDate == key).length;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedDate = key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 8), width: 52,
                          decoration: BoxDecoration(
                              color: isSelected ? AppColors.accent : AppColors.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: isSelected ? AppColors.accent : AppColors.border)),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text(DateFormat('EEE').format(d).toUpperCase(),
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                                    color: isSelected ? Colors.white70 : AppColors.textMuted)),
                            Text('${d.day}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                                color: isSelected ? Colors.white : AppColors.textPrimary)),
                            if (slotCount > 0)
                              Container(width: 16, height: 3,
                                  decoration: BoxDecoration(
                                      color: isSelected ? Colors.white54 : AppColors.accent,
                                      borderRadius: BorderRadius.circular(2))),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _slotsForDate.isEmpty
                      ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.calendar_today_outlined, size: 48, color: AppColors.textMuted),
                          const SizedBox(height: 12),
                          Text('No slots for ${DateFormat('d MMM').format(DateTime.parse(_selectedDate))}',
                              style: AppTextStyles.body),
                          const SizedBox(height: 8),
                          OutlinedButton(onPressed: _openFullManager, child: const Text('Add Slots')),
                        ]))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                          itemCount: _slotsForDate.length,
                          itemBuilder: (_, i) {
                            final s = _slotsForDate[i];
                            final c = _slotColor(s.status);
                            final isBooked = s.status == 'BOOKED';
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                  color: c.withValues(alpha: 0.07),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: c.withValues(alpha: 0.3))),
                              child: Row(children: [
                                Container(width: 4, height: 40, margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(s.timeRange, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: c)),
                                  Text(s.status, style: TextStyle(fontSize: 11, color: c.withValues(alpha: 0.8))),
                                ])),
                                if (!isBooked)
                                  GestureDetector(
                                    onTap: () => _toggleSlot(s),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                          color: s.status == 'UNAVAILABLE'
                                              ? AppColors.success.withValues(alpha: 0.1)
                                              : AppColors.warning.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                              color: s.status == 'UNAVAILABLE'
                                                  ? AppColors.success : AppColors.warning)),
                                      child: Text(s.status == 'UNAVAILABLE' ? 'Restore' : 'Block',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                                              color: s.status == 'UNAVAILABLE' ? AppColors.success : AppColors.warning)),
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8)),
                                    child: const Text('Booked', style: TextStyle(fontSize: 11,
                                        color: AppColors.info, fontWeight: FontWeight.w700)),
                                  ),
                              ]),
                            );
                          },
                        ),
                ),
              ]),
            ),
    );
  }

  Widget _statPill(int count, Color color, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20)),
    child: Text('$count $label', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
  );
}

class _MasterSlotsSheet extends StatefulWidget {
  final List<dynamic> masterSlots;
  final ScrollController scrollController;
  final VoidCallback onChanged;
  const _MasterSlotsSheet({required this.masterSlots,
      required this.scrollController, required this.onChanged});
  @override
  State<_MasterSlotsSheet> createState() => _MasterSlotsSheetState();
}

class _MasterSlotsSheetState extends State<_MasterSlotsSheet> {
  late List<dynamic> _slots;
  bool _saving = false;

  @override
  void initState() { super.initState(); _slots = List.from(widget.masterSlots); }

  void _showAddEdit({Map<String, dynamic>? slot}) {
    final ctrl = TextEditingController(text: slot != null ? slot['timeRange'] : '');
    final isEdit = slot != null;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isEdit ? 'Edit Time Range' : 'Add Time Range'),
        content: TextField(controller: ctrl,
            decoration: const InputDecoration(
                labelText: 'Time Range', hintText: 'e.g. 10:00 AM – 11:00 AM')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final val = ctrl.text.trim();
              if (val.isEmpty) return;
              Navigator.pop(context);
              setState(() => _saving = true);
              bool ok = isEdit
                  ? await _updateMasterSlotApi(slot!['id'] as int, val)
                  : await _createMasterSlot(val);
              if (ok) {
                widget.onChanged();
                final fresh = await _getMasterSlots();
                if (mounted) setState(() { _slots = fresh; _saving = false; });
              } else {
                if (mounted) setState(() => _saving = false);
              }
            },
            child: Text(isEdit ? 'Save' : 'Add', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(Map<String, dynamic> slot) async {
    final ok = await showDialog<bool>(context: context,
        builder: (_) => AlertDialog(
          title: const Text('Delete Time Range?'),
          content: Text('Delete "${slot['timeRange']}"?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        ));
    if (ok != true) return;
    setState(() => _saving = true);
    final deleted = await _deleteMasterSlotApi(slot['id'] as int);
    if (deleted) {
      widget.onChanged();
      final fresh = await _getMasterSlots();
      if (mounted) setState(() { _slots = fresh; _saving = false; });
    } else {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(children: [
          _handleBar(), const Spacer(),
          Text('Master Time Ranges', style: AppTextStyles.h3),
          const Spacer(),
          IconButton(icon: const Icon(Icons.add_circle_outline, color: AppColors.accent),
              onPressed: () => _showAddEdit(), tooltip: 'Add time range'),
        ]),
      ),
      const Divider(height: 1),
      if (_saving) const LinearProgressIndicator(color: AppColors.accent),
      Expanded(
        child: _slots.isEmpty
            ? const Center(child: Text('No master time ranges yet',
                style: TextStyle(color: AppColors.textMuted)))
            : ListView.builder(
                controller: widget.scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _slots.length,
                itemBuilder: (_, i) {
                  final s = _slots[i] as Map<String, dynamic>;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border)),
                    child: Row(children: [
                      const Icon(Icons.access_time_rounded, size: 18, color: AppColors.accent),
                      const SizedBox(width: 12),
                      Expanded(child: Text(s['timeRange'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                        onPressed: () => _showAddEdit(slot: s),
                        padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                        onPressed: () => _delete(s),
                        padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                      ),
                    ]),
                  );
                }),
      ),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════════════════
// FEEDBACK TAB
// ════════════════════════════════════════════════════════════════════════════

class _ConsultantFeedbacksTab extends StatefulWidget {
  final int consultantId;
  const _ConsultantFeedbacksTab({required this.consultantId});
  @override
  State<_ConsultantFeedbacksTab> createState() => _ConsultantFeedbacksTabState();
}

class _ConsultantFeedbacksTabState extends State<_ConsultantFeedbacksTab> {
  List<Feedback> _feedbacks = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    _feedbacks = await FeedbackService().getFeedbacksByConsultant(widget.consultantId);
    if (mounted) setState(() => _loading = false);
  }

  double get _avg => _feedbacks.isEmpty ? 0 :
      _feedbacks.fold(0.0, (s, f) => s + f.rating) / _feedbacks.length;

  Map<int, int> get _distribution {
    final m = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    for (final f in _feedbacks) { final r = f.rating.clamp(1, 5); m[r] = (m[r] ?? 0) + 1; }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_feedbacks.isEmpty) return const EmptyState(icon: Icons.star_outline,
        title: 'No feedback yet', subtitle: 'Client reviews from completed sessions appear here');

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
              borderRadius: BorderRadius.circular(20)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Average Rating', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 4),
            Row(children: [
              Text(_avg.toStringAsFixed(1), style: const TextStyle(color: Colors.white,
                  fontSize: 48, fontWeight: FontWeight.w800)),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: List.generate(5, (i) => Icon(
                  i < _avg.round() ? Icons.star_rounded : Icons.star_border_rounded,
                  color: AppColors.gold, size: 22))),
                const SizedBox(height: 4),
                Text('${_feedbacks.length} reviews',
                    style: const TextStyle(color: Colors.white60, fontSize: 12)),
              ]),
            ]),
            const SizedBox(height: 16),
            ...[5, 4, 3, 2, 1].map((star) {
              final count = _distribution[star] ?? 0;
              final ratio = _feedbacks.isEmpty ? 0.0 : count / _feedbacks.length;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  Text('$star', style: const TextStyle(color: Colors.white60,
                      fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  const Icon(Icons.star_rounded, color: AppColors.gold, size: 11),
                  const SizedBox(width: 6),
                  Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: ratio,
                          backgroundColor: Colors.white12,
                          valueColor: const AlwaysStoppedAnimation(AppColors.gold),
                          minHeight: 6))),
                  const SizedBox(width: 8),
                  Text('$count', style: const TextStyle(color: Colors.white60, fontSize: 11)),
                ]),
              );
            }),
          ]),
        ),
        const SizedBox(height: 20),
        ..._feedbacks.map((f) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(radius: 18,
                  backgroundColor: AppColors.primaryLight.withValues(alpha: 0.15),
                  child: Text((f.clientName ?? 'C')[0].toUpperCase(),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                          color: AppColors.primaryLight))),
              const SizedBox(width: 10),
              Expanded(child: Text(f.clientName ?? 'Client', style: AppTextStyles.h4)),
              Row(children: List.generate(5, (i) => Icon(
                i < f.rating ? Icons.star_rounded : Icons.star_border_rounded,
                color: AppColors.gold, size: 16))),
            ]),
            if (f.comments != null && f.comments!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(f.comments!, style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
            ],
            if (f.createdAt != null) ...[
              const SizedBox(height: 8),
              Text(f.createdAt!, style: AppTextStyles.caption),
            ],
          ]),
        )),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// PROFILE TAB — FULLY FIXED
// ════════════════════════════════════════════════════════════════════════════

class _ConsultantProfileTab extends StatefulWidget {
  final int consultantId;
  const _ConsultantProfileTab({required this.consultantId});
  @override
  State<_ConsultantProfileTab> createState() => _ConsultantProfileTabState();
}

class _ConsultantProfileTabState extends State<_ConsultantProfileTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  ConsultantModel? _profile;
  bool _loading = true;
  String? _errorMsg;       // ← NEW: error state
  bool _editMode = false;
  bool _saving = false;

  // Form controllers
  final _nameCtrl      = TextEditingController();
  final _designCtrl    = TextEditingController();
  final _feeCtrl       = TextEditingController();
  final _descCtrl      = TextEditingController();
  final _skillsCtrl    = TextEditingController();
  final _shiftStartCtrl = TextEditingController();
  final _shiftEndCtrl  = TextEditingController();
  final _expCtrl       = TextEditingController();

  // Photo
  File? _photoFile;           // selected from gallery
  String? _photoUrl;           // existing photo from API

  // Offers
  List<dynamic> _offers = [];
  bool _loadingOffers = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadProfile();
    _loadOffers();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _nameCtrl.dispose(); _designCtrl.dispose(); _feeCtrl.dispose();
    _descCtrl.dispose(); _skillsCtrl.dispose(); _shiftStartCtrl.dispose();
    _shiftEndCtrl.dispose(); _expCtrl.dispose();
    super.dispose();
  }

  // ── FIXED: proper try/catch, no more infinite spinner ─────────────────────

  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() { _loading = true; _errorMsg = null; });
    try {
      final profile = await ConsultantService().getConsultantById(widget.consultantId);
      if (!mounted) return;
      if (profile != null) {
        _profile = profile;
        _populateControllers(profile);
        setState(() => _loading = false);
      } else {
        setState(() {
          _loading = false;
          _errorMsg = 'Could not load profile. Please check your connection.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _errorMsg = 'Error: $e'; });
    }
  }

  /// Populate all form controllers safely from profile data
  void _populateControllers(ConsultantModel p) {
    try {
      _nameCtrl.text   = p.name ?? '';
      _designCtrl.text = p.designation ?? '';
      _feeCtrl.text    = (p.charges ?? 0).toStringAsFixed(0);
      _descCtrl.text   = p.description ?? '';
      _skillsCtrl.text = p.skills.join(', ');
      // FIXED: use extension methods that safely parse LocalTime Maps
      _shiftStartCtrl.text = p.shiftStart;
      _shiftEndCtrl.text   = p.shiftEnd;
      _expCtrl.text        = p.experience.toStringAsFixed(0);
      _photoUrl            = p.profilePhotoUrl;
    } catch (e) {
      // Even if population throws, loading is still done
      debugPrint('Profile controller populate error: $e');
    }
  }

  Future<void> _loadOffers() async {
    setState(() => _loadingOffers = true);
    _offers = await _getMyOffers();
    if (mounted) setState(() => _loadingOffers = false);
  }

  // ── Photo picker ──────────────────────────────────────────────────────────

  Future<void> _pickPhoto() async {
    try {
      final picker = ImagePicker();
      final xFile = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80, maxWidth: 800);
      if (xFile == null) return;
      setState(() => _photoFile = File(xFile.path));
    } catch (e) {
      _snack('Could not pick photo: $e', false);
    }
  }

  // ── Shift time picker ─────────────────────────────────────────────────────

  Future<void> _pickTime(TextEditingController ctrl) async {
    TimeOfDay? initial;
    try {
      if (ctrl.text.isNotEmpty) {
        final parts = ctrl.text.split(':');
        if (parts.length >= 2) {
          initial = TimeOfDay(
              hour: int.tryParse(parts[0]) ?? 0,
              minute: int.tryParse(parts[1]) ?? 0);
        }
      }
    } catch (_) {}

    final picked = await showTimePicker(
      context: context,
      initialTime: initial ?? TimeOfDay.now(),
      builder: (ctx, child) => MediaQuery(
          data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
          child: child!),
    );
    if (picked != null) {
      ctrl.text =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    }
  }

  // ── Save profile ──────────────────────────────────────────────────────────

  Future<void> _saveProfile() async {
    final name   = _nameCtrl.text.trim();
    final design = _designCtrl.text.trim();
    final fee    = double.tryParse(_feeCtrl.text.trim()) ?? 0;
    if (name.isEmpty || design.isEmpty || fee <= 0) {
      _snack('Name, designation and fee are required', false);
      return;
    }
    setState(() => _saving = true);
    try {
      final skills = _skillsCtrl.text
          .split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      final data = {
        'name': name,
        'designation': design,
        'charges': fee,
        'description': _descCtrl.text.trim(),
        'skills': skills,
        'email': _profile?.email ?? '',
        'shiftStartTime': _shiftStartCtrl.text.trim(),
        'shiftEndTime':   _shiftEndCtrl.text.trim(),
        'yearsOfExperience': double.tryParse(_expCtrl.text.trim()) ?? 0,
      };

      dio_pkg.MultipartFile? photoMultipart;
      if (_photoFile != null) {
        photoMultipart = await dio_pkg.MultipartFile.fromFile(
          _photoFile!.path,
          filename: 'profile_photo.jpg',
        );
      }

      final ok = await ConsultantService()
          .updateProfile(widget.consultantId, data, profilePhoto: photoMultipart);
      if (!mounted) return;
      if (ok) {
        setState(() { _editMode = false; _saving = false; _photoFile = null; });
        _snack('Profile saved ✓', true);
        _loadProfile();
      } else {
        setState(() => _saving = false);
        _snack('Save failed. Please try again.', false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('Error: $e', false);
    }
  }

  // ── Offers ────────────────────────────────────────────────────────────────

  void _openOfferForm({Map<String, dynamic>? existing}) {
    final isEdit = existing != null;
    final titleCtrl = TextEditingController(text: isEdit ? existing['title'] : '');
    final descCtrl  = TextEditingController(text: isEdit ? existing['description'] : '');
    final discCtrl  = TextEditingController(text: isEdit ? existing['discount'] : '');
    final fromCtrl  = TextEditingController(
        text: isEdit && existing['validFrom'] != null
            ? existing['validFrom'].toString().substring(0, 10) : '');
    final toCtrl    = TextEditingController(
        text: isEdit && existing['validTo'] != null
            ? existing['validTo'].toString().substring(0, 10) : '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            _handleBar(),
            Text(isEdit ? 'Edit Offer' : 'New Offer', style: AppTextStyles.h3),
            const SizedBox(height: 16),
            _field(titleCtrl, 'Title *', hintText: 'e.g. Summer Special'),
            const SizedBox(height: 12),
            _field(descCtrl, 'Description',
                hintText: 'What does this offer include?', maxLines: 2),
            const SizedBox(height: 12),
            _field(discCtrl, 'Discount *', hintText: 'e.g. 20% OFF or ₹500 off'),
            const SizedBox(height: 12),
            // Info about approval
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10)),
              child: const Row(children: [
                Icon(Icons.info_outline, size: 16, color: AppColors.info),
                SizedBox(width: 8),
                Expanded(child: Text(
                  'Offers are submitted to admin for approval before going live.',
                  style: TextStyle(fontSize: 12, color: AppColors.info),
                )),
              ]),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _field(fromCtrl, 'Valid From', hintText: 'YYYY-MM-DD',
                  onTap: () async {
                    final d = await showDatePicker(context: ctx,
                        initialDate: DateTime.now(), firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (d != null) fromCtrl.text = DateFormat('yyyy-MM-dd').format(d);
                  })),
              const SizedBox(width: 12),
              Expanded(child: _field(toCtrl, 'Valid To', hintText: 'YYYY-MM-DD',
                  onTap: () async {
                    final d = await showDatePicker(context: ctx,
                        initialDate: DateTime.now().add(const Duration(days: 7)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 730)));
                    if (d != null) toCtrl.text = DateFormat('yyyy-MM-dd').format(d);
                  })),
            ]),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  final title = titleCtrl.text.trim();
                  final disc = discCtrl.text.trim();
                  if (title.isEmpty || disc.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Title and discount are required')));
                    return;
                  }
                  Navigator.pop(ctx);
                  final payload = <String, dynamic>{
                    'title': title, 'description': descCtrl.text.trim(),
                    'discount': disc, 'consultantId': widget.consultantId, 'active': true,
                    if (fromCtrl.text.isNotEmpty) 'validFrom': '${fromCtrl.text}T00:00:00',
                    if (toCtrl.text.isNotEmpty)   'validTo':   '${toCtrl.text}T00:00:00',
                  };
                  final saved = await _saveOffer(payload,
                      id: isEdit ? (existing['id'] as int?) : null);
                  _snack(saved != null
                      ? (isEdit ? 'Offer updated' : 'Offer submitted for approval')
                      : 'Save failed', saved != null);
                  _loadOffers();
                },
                child: Text(isEdit ? 'Save Changes' : 'Submit for Approval',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteOffer(Map<String, dynamic> offer) async {
    final ok = await showDialog<bool>(context: context,
        builder: (_) => AlertDialog(
          title: const Text('Delete Offer?'),
          content: Text('Delete "${offer['title']}"?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        ));
    if (ok != true) return;
    final id = offer['id'];
    final deleted = await _deleteOffer(id is int ? id : int.tryParse(id.toString()) ?? 0);
    _snack(deleted ? 'Offer deleted' : 'Delete failed', deleted);
    if (deleted) _loadOffers();
  }

  void _snack(String msg, bool ok) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? AppColors.success : AppColors.danger,
      behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2),
    ));
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // FIXED: Show loading spinner
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    // FIXED: Show error state with retry button
    if (_errorMsg != null && _profile == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.person_off_outlined, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(_errorMsg!, textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadProfile,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ]),
        ),
      );
    }

    return Column(children: [
      TabBar(
        controller: _tabs,
        labelColor: AppColors.accent,
        unselectedLabelColor: AppColors.textMuted,
        indicatorColor: AppColors.accent,
        tabs: const [Tab(text: 'Profile'), Tab(text: 'Offers')],
      ),
      const Divider(height: 1),
      Expanded(child: TabBarView(controller: _tabs, children: [
        // ── Profile tab ───────────────────────────────────────────────────
        RefreshIndicator(
          onRefresh: _loadProfile,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Profile hero — FIXED: shows actual photo
              Container(
                width: double.infinity, padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF1E3A5F), AppColors.primaryLight]),
                    borderRadius: BorderRadius.circular(20)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  // Avatar / Photo
                  GestureDetector(
                    onTap: _editMode ? _pickPhoto : null,
                    child: Stack(children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.white24,
                        backgroundImage: _photoFile != null
                            ? FileImage(_photoFile!) as ImageProvider
                            : (_photoUrl != null && _photoUrl!.isNotEmpty)
                                ? NetworkImage(_photoUrl!)
                                : null,
                        child: (_photoFile == null &&
                            (_photoUrl == null || _photoUrl!.isEmpty))
                            ? Text((_profile?.name ?? 'C')[0].toUpperCase(),
                                style: const TextStyle(fontSize: 30,
                                    fontWeight: FontWeight.w800, color: Colors.white))
                            : null,
                        onBackgroundImageError: (_photoUrl != null && _photoUrl!.isNotEmpty)
                            ? (_, __) {}  // silent fallback
                            : null,
                      ),
                      if (_editMode)
                        Positioned(bottom: 0, right: 0,
                          child: Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(color: AppColors.accent,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2)),
                            child: const Icon(Icons.camera_alt_outlined,
                                size: 14, color: Colors.white),
                          ),
                        ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  Text(_profile?.name ?? '', style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                  Text(_profile?.designation ?? '',
                      style: const TextStyle(fontSize: 13, color: Colors.white70)),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (i) => Icon(
                    i < (_profile?.rating ?? 0).round()
                        ? Icons.star_rounded : Icons.star_border_rounded,
                    color: AppColors.gold, size: 20))),
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10)),
                      child: Text('₹${(_profile?.charges ?? 0).toStringAsFixed(0)} / session',
                          style: const TextStyle(color: Colors.white,
                              fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 8),
                    // DisplayPrice: charges + 200 (what customer sees)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white24)),
                      child: Text(
                        'Customer sees: ₹${((_profile?.charges ?? 0) + 200).toStringAsFixed(0)}',
                        style: const TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                    ),
                  ]),
                ]),
              ),
              const SizedBox(height: 20),

              // Edit/View toggle
              Row(children: [
                const Text('Profile Details',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const Spacer(),
                if (_errorMsg != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Text('Partial load',
                        style: TextStyle(fontSize: 11, color: AppColors.warning)),
                  ),
                TextButton.icon(
                  onPressed: _saving ? null : () => setState(() => _editMode = !_editMode),
                  icon: Icon(_editMode ? Icons.close : Icons.edit_outlined, size: 16),
                  label: Text(_editMode ? 'Cancel' : 'Edit'),
                ),
              ]),
              const SizedBox(height: 12),

              if (!_editMode) ...[
                // View mode
                _infoCard([
                  _infoRow('Email', _profile?.email ?? '—'),
                  _infoRow('Experience', '${_profile?.experience.toStringAsFixed(0) ?? 0} years'),
                  _infoRow('Availability', _profile?.shiftTimingsDisplay ?? '—'),
                ]),
                if (_profile?.description != null && _profile!.description!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('About', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity, padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border)),
                    child: Text(_profile!.description!,
                        style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
                  ),
                ],
                if (_profile!.skills.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Skills', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, runSpacing: 8,
                      children: _profile!.skills.map((s) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.accent.withValues(alpha: 0.3))),
                        child: Text(s, style: const TextStyle(
                            color: AppColors.accent, fontWeight: FontWeight.w600, fontSize: 12)),
                      )).toList()),
                ],
              ] else ...[
                // Edit mode
                // Photo hint
                if (_photoFile != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      const Icon(Icons.check_circle_outline, size: 16, color: AppColors.success),
                      const SizedBox(width: 8),
                      Text('Photo selected: ${_photoFile!.path.split('/').last}',
                          style: const TextStyle(fontSize: 12, color: AppColors.success)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(() => _photoFile = null),
                        child: const Icon(Icons.close, size: 16, color: AppColors.textMuted),
                      ),
                    ]),
                  ),
                OutlinedButton.icon(
                  onPressed: _pickPhoto,
                  icon: const Icon(Icons.photo_library_outlined, size: 16),
                  label: const Text('Change Photo'),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 44)),
                ),
                const SizedBox(height: 12),
                _field(_nameCtrl, 'Name *'),
                const SizedBox(height: 12),
                _field(_designCtrl, 'Designation *'),
                const SizedBox(height: 12),
                _field(_feeCtrl, 'Fee (₹) *', keyboardType: TextInputType.number),
                // Display price hint
                if (_feeCtrl.text.isNotEmpty) Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '✓ Customer sees: ₹${((double.tryParse(_feeCtrl.text) ?? 0) + 200).toStringAsFixed(0)} (fee + ₹200)',
                    style: const TextStyle(fontSize: 11, color: AppColors.success),
                  ),
                ),
                const SizedBox(height: 12),
                // FIXED: Shift times use Flutter's showTimePicker
                Row(children: [
                  Expanded(child: _field(_shiftStartCtrl, 'Shift Start',
                      hintText: 'e.g. 09:00',
                      onTap: () => _pickTime(_shiftStartCtrl))),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_shiftEndCtrl, 'Shift End',
                      hintText: 'e.g. 18:00',
                      onTap: () => _pickTime(_shiftEndCtrl))),
                ]),
                const SizedBox(height: 4),
                const Text('  Tap the fields above to open time picker',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                const SizedBox(height: 12),
                _field(_expCtrl, 'Experience (years)',
                    keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                _field(_skillsCtrl, 'Skills (comma separated)',
                    hintText: 'e.g. Tax Planning, Investments'),
                const SizedBox(height: 12),
                _field(_descCtrl, 'Description', maxLines: 4,
                    hintText: 'About yourself…'),
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, height: 48,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _saveProfile,
                    child: _saving
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Save Profile',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
              const SizedBox(height: 32),
            ]),
          ),
        ),

        // ── Offers tab ────────────────────────────────────────────────────
        Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(children: [
              const Text('My Offers',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _openOfferForm(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Offer', style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
              ),
            ]),
          ),
          // Approval info notice
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10)),
            child: const Row(children: [
              Icon(Icons.verified_outlined, size: 15, color: AppColors.info),
              SizedBox(width: 8),
              Expanded(child: Text(
                'Offers you create are submitted to admin. Once approved, they appear on the booking page.',
                style: TextStyle(fontSize: 11, color: AppColors.info),
              )),
            ]),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          Expanded(
            child: _loadingOffers
                ? const Center(child: CircularProgressIndicator())
                : _offers.isEmpty
                    ? const EmptyState(icon: Icons.local_offer_outlined,
                        title: 'No offers yet',
                        subtitle: 'Create special offers for your clients')
                    : RefreshIndicator(
                        onRefresh: _loadOffers,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _offers.length,
                          itemBuilder: (_, i) {
                            final o = _offers[i] as Map<String, dynamic>;
                            final status = (o['status'] ?? 'PENDING').toString();
                            final isApproved = status == 'APPROVED';
                            final isRejected = status == 'REJECTED';
                            final statusColor = isApproved ? AppColors.success
                                : isRejected ? AppColors.danger : AppColors.warning;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Row(children: [
                                    Expanded(child: Text(o['title'] ?? '', style: AppTextStyles.h4)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                          color: statusColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8)),
                                      child: Text(status, style: TextStyle(
                                          fontSize: 10, color: statusColor, fontWeight: FontWeight.w700)),
                                    ),
                                  ]),
                                  if (o['description'] != null && (o['description'] as String).isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(o['description'].toString(), style: AppTextStyles.caption),
                                  ],
                                  const SizedBox(height: 8),
                                  Row(children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                          color: AppColors.success.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8)),
                                      child: Text(o['discount'] ?? '', style: const TextStyle(
                                          color: AppColors.success,
                                          fontWeight: FontWeight.w700, fontSize: 13)),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 18,
                                          color: AppColors.textSecondary),
                                      onPressed: () => _openOfferForm(existing: o),
                                      padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                                    ),
                                    const SizedBox(width: 12),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18,
                                          color: AppColors.danger),
                                      onPressed: () => _confirmDeleteOffer(o),
                                      padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                                    ),
                                  ]),
                                  if (o['validFrom'] != null || o['validTo'] != null) ...[
                                    const SizedBox(height: 6),
                                    Text([
                                      if (o['validFrom'] != null)
                                        'From: ${o['validFrom'].toString().substring(0, 10)}',
                                      if (o['validTo'] != null)
                                        'To: ${o['validTo'].toString().substring(0, 10)}',
                                    ].join('  ·  '), style: AppTextStyles.caption),
                                  ],
                                ]),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ]),
      ])),
    ]);
  }

  Widget _infoCard(List<Widget> rows) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border)),
    child: Column(children: rows),
  );

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      SizedBox(width: 100, child: Text(label, style: AppTextStyles.caption)),
      Expanded(child: Text(value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
    ]),
  );

  Widget _field(TextEditingController ctrl, String label,
      {String? hintText, int maxLines = 1,
        TextInputType keyboardType = TextInputType.text,
        VoidCallback? onTap}) {
    return TextField(
      controller: ctrl, maxLines: maxLines, keyboardType: keyboardType,
      readOnly: onTap != null, onTap: onTap,
      decoration: InputDecoration(
        labelText: label, hintText: hintText,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        isDense: true,
        suffixIcon: onTap != null
            ? const Icon(Icons.access_time_rounded, size: 18) : null,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// NOTIFICATIONS PANEL (uses real API: GET /api/notifications)
// ════════════════════════════════════════════════════════════════════════════

class _NotificationPanel extends StatelessWidget {
  final ScrollController scrollController;
  final VoidCallback onClose;
  const _NotificationPanel({required this.scrollController, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Row(children: [
          _handleBar(), const Spacer(),
          const Text('Notifications',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const Spacer(),
          Consumer<NotificationService>(
            builder: (_, svc, __) => TextButton(
              onPressed: svc.unreadCount > 0 ? svc.markAllRead : null,
              child: const Text('Mark all read', style: TextStyle(fontSize: 12)),
            ),
          ),
        ]),
      ),
      const Divider(height: 1),
      Expanded(
        child: Consumer<NotificationService>(
          builder: (_, svc, __) {
            if (svc.isLoading) return const Center(child: CircularProgressIndicator());
            if (svc.notifications.isEmpty) {
              return const Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.notifications_none_outlined, size: 48, color: AppColors.textMuted),
                SizedBox(height: 12),
                Text('No notifications yet',
                    style: TextStyle(color: AppColors.textMuted)),
                SizedBox(height: 6),
                Text('New bookings and ticket updates will appear here.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                    textAlign: TextAlign.center),
              ]));
            }
            return RefreshIndicator(
              onRefresh: svc.refresh,
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: svc.notifications.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
                itemBuilder: (_, i) {
                  final n = svc.notifications[i];
                  final color = _notifColor(n);
                  final icon = _notifIcon(n);
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    leading: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    title: Text(_safeGet(n, 'title', 'Notification'),
                        style: TextStyle(
                            fontWeight: _safeRead<bool>(n, 'isRead') == true
                                ? FontWeight.w400 : FontWeight.w700,
                            fontSize: 13)),
                    subtitle: Text(_notifSubtitle(n),
                        style: const TextStyle(fontSize: 12),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: _safeRead<bool>(n, 'isRead') != true
                        ? Container(width: 8, height: 8,
                            decoration: const BoxDecoration(
                                color: AppColors.accent, shape: BoxShape.circle))
                        : null,
                    onTap: () {
                      final rawId = _safeRead(n, 'id');
                      final int parsedId = int.tryParse(rawId?.toString() ?? '') ?? 0;
                      if (parsedId > 0) svc.markAsRead(parsedId);
                    },
                  );
                },
              ),
            );
          },
        ),
      ),
    ]);
  }
}

Color _notifColor(dynamic n) {
  final type = _safeGet(n, 'type', '');
  switch (type) {
    case 'success': case 'TICKET_UPDATED': return AppColors.success;
    case 'error':   case 'ESCALATION':     return AppColors.danger;
    case 'warning':                         return AppColors.warning;
    default:                                return AppColors.info;
  }
}

IconData _notifIcon(dynamic n) {
  final type = _safeGet(n, 'type', '');
  switch (type) {
    case 'success': case 'TICKET_UPDATED': return Icons.check_circle_outline;
    case 'error':   case 'ESCALATION':     return Icons.error_outline;
    case 'NEW_ASSIGNMENT':                  return Icons.assignment_ind_outlined;
    default:                                return Icons.info_outline;
  }
}

String _notifSubtitle(dynamic n) {
  for (final key in ['message', 'body', 'description']) {
    final val = _safeRead(n, key);
    if (val != null && val.toString().isNotEmpty) return val.toString();
  }
  return '';
}

String _safeGet(dynamic obj, String key, String fallback) =>
    _safeRead<String>(obj, key) ?? fallback;

T? _safeRead<T>(dynamic obj, String key) {
  try { return (obj as dynamic)[key] as T?; } catch (_) { return null; }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

Widget _handleBar() => Center(child: Container(
  width: 40, height: 4,
  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
));