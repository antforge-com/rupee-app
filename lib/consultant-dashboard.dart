// lib/features/consultant/consultant_dashboard.dart
// ignore_for_file: file_names, unnecessary_non_null_assertion, use_of_void_result
//
// FIXED:
//
// PUBSPEC dependencies needed (add if not present):
//   image_picker: ^1.0.7
//   cached_network_image: ^3.3.1
//   provider: any
//   dio: any
//   intl: any

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart' as dio_pkg;
import 'package:finadvise/api_client.dart';
import 'package:finadvise/app_theme.dart';
import 'package:finadvise/booking_answers_screen.dart';
import 'package:finadvise/consultant_earnings_tab.dart';
import 'package:finadvise/login_screen.dart';
import 'package:finadvise/meet_the_masters_brand.dart';
import 'package:finadvise/models/models.dart';
import 'package:finadvise/services/services.dart';
import 'package:finadvise/shared/ticket_number_formatter.dart';
import 'package:finadvise/shared_widgets.dart';
import 'package:flutter/material.dart' hide Feedback;
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

extension _TicketCompat on Ticket {
  String? get attachmentUrl {
    try {
      return (this as dynamic).attachmentUrl as String?;
    } catch (_) {
      return null;
    }
  }

  String? get ticketNumber {
    try {
      return (this as dynamic).ticketNumber as String?;
    } catch (_) {
      return null;
    }
  }
}

extension _ConsultantCompat on ConsultantModel {
  double get experience =>
      ((this as dynamic).yearsOfExperience as num?)?.toDouble() ?? 0.0;

  /// Returns h:mm AM/PM string for start time, empty if missing
  String get shiftStart => _parseLocalTime((this as dynamic).shiftStartTime);

  /// Returns h:mm AM/PM string for end time, empty if missing
  String get shiftEnd => _parseLocalTime((this as dynamic).shiftEndTime);

  String get shiftTimingsDisplay {
    final s = shiftStart;
    final e = shiftEnd;
    if (s.isEmpty && e.isEmpty) return 'Not set';
    return '$s - $e';
  }

  String? get profilePhotoUrl {
    try {
      final p = (this as dynamic).profilePhoto as String?;
      if (p == null || p.isEmpty) return null;
      final url = ApiClient.buildBackendAssetUrl(p);
      return url.isEmpty ? null : url;
    } catch (_) {
      return null;
    }
  }
}

String _parseLocalTime(dynamic raw) {
  if (raw == null) return '';
  try {
    final minutes = _timeToMinutes(raw);
    if (minutes != null) return _minutesToAmPm(minutes);

    final s = _sanitizeDisplayText(raw);
    final fallbackMinutes = _timeToMinutes(s);
    if (fallbackMinutes != null) return _minutesToAmPm(fallbackMinutes);

    if (s.isNotEmpty) return s;
  } catch (_) {}
  return '';
}

int? _timeToMinutes(dynamic raw) {
  if (raw == null) return null;
  if (raw is Map) {
    final hour = (raw['hour'] as num?)?.toInt();
    final minute = (raw['minute'] as num?)?.toInt();
    if (hour == null || minute == null) return null;
    return (hour * 60) + minute;
  }

  final value = raw.toString().trim().toUpperCase();
  if (value.isEmpty) return null;

  final hhmm = RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?$').firstMatch(value);
  if (hhmm != null) {
    final hour = int.tryParse(hhmm.group(1) ?? '');
    final minute = int.tryParse(hhmm.group(2) ?? '');
    if (hour == null || minute == null) return null;
    return (hour * 60) + minute;
  }

  final ampm = RegExp(r'^(\d{1,2})(?::(\d{2}))?\s*(AM|PM)$').firstMatch(value);
  if (ampm != null) {
    var hour = int.tryParse(ampm.group(1) ?? '') ?? 0;
    final minute = int.tryParse(ampm.group(2) ?? '0') ?? 0;
    final period = ampm.group(3) ?? 'AM';
    if (period == 'PM' && hour != 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;
    return (hour * 60) + minute;
  }

  return null;
}

String _minutesToAmPm(int totalMinutes) {
  final normalized = ((totalMinutes % 1440) + 1440) % 1440;
  final hour24 = normalized ~/ 60;
  final minute = normalized % 60;
  final suffix = hour24 >= 12 ? 'PM' : 'AM';
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  return '$hour12:${minute.toString().padLeft(2, '0')} $suffix';
}

String _sanitizeDisplayText(dynamic value, {String fallback = ''}) {
  final raw = value?.toString() ?? '';
  if (raw.trim().isEmpty) return fallback;

  var text = raw.trim();
  const replacements = <String, String>{
    'ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â': '-',
    'ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Å“': '-',
    'ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢': '->',
    'Ã¢â‚¬â€': '-',
    'Ã¢â‚¬â€œ': '-',
    'Ã¢â‚¬Â¦': '...',
    'Ã¢â‚¬Â¢': '-',
    'Ã‚Â·': ' - ',
    'Ã¢â‚¬Ëœ': "'",
    'Ã¢â‚¬â„¢': "'",
    'Ã¢â‚¬Å“': '"',
    'Ã¢â‚¬Â': '"',
    'Ã¢â€šÂ¹': 'Rs ',
    'â‚¹': 'Rs ',
    'Ã¢â€šÂ¬': '',
    'â‚¬': '',
    'Ã‚': '',
    '\uFFFD': '',
  };
  replacements.forEach((bad, good) {
    text = text.replaceAll(bad, good);
  });

  text = text
      .replaceAll(RegExp(r'[ÃƒÃ‚]+'), '')
      .replaceAll(RegExp(r'[â‚¬]+'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  return text.isEmpty ? fallback : text;
}

String _cleanSpecialBookingNotes(dynamic value, {String fallback = ''}) {
  final raw = value?.toString().trim() ?? '';
  if (raw.isEmpty) return fallback;
  const prefix = '[[SPECIAL_BOOKING_META]]';
  var cleaned = raw;

  if (cleaned.startsWith(prefix)) {
    final remainder = cleaned.substring(prefix.length);
    final lines = remainder.split('\n');
    if (lines.isNotEmpty && lines.first.trim().startsWith('{')) {
      cleaned = lines.skip(1).join('\n').trim();
    } else {
      cleaned = remainder.trim();
    }
  }

  return _sanitizeDisplayText(cleaned, fallback: fallback);
}

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
    return _SlaInfo(
        _SlaState.onTrack, 'Due ${DateFormat('d MMM HH:mm').format(deadline)}');
  } catch (_) {
    return null;
  }
}

Color _slaColor(_SlaState s) {
  switch (s) {
    case _SlaState.breached:
      return AppColors.danger;
    case _SlaState.warning:
      return AppColors.warning;
    case _SlaState.onTrack:
      return AppColors.success;
  }
}

Color _statusColor(String s) {
  switch (s.toUpperCase()) {
    case 'CONFIRMED':
      return AppColors.info;
    case 'COMPLETED':
      return AppColors.success;
    case 'PENDING':
      return AppColors.warning;
    case 'CANCELLED':
      return AppColors.danger;
    case 'NEW':
      return AppColors.primaryLight;
    case 'OPEN':
      return AppColors.info;
    case 'IN_PROGRESS':
      return AppColors.warning;
    case 'RESOLVED':
      return AppColors.success;
    case 'CLOSED':
      return AppColors.textMuted;
    case 'ESCALATED':
      return AppColors.danger;
    default:
      return AppColors.textMuted;
  }
}

Color _priorityColor(String p) {
  switch (p.toUpperCase()) {
    case 'CRITICAL':
      return const Color(0xFF7C3AED);
    case 'URGENT':
      return AppColors.danger;
    case 'HIGH':
      return AppColors.warning;
    case 'MEDIUM':
      return AppColors.info;
    default:
      return AppColors.textMuted;
  }
}

final _ticketService = TicketService();
final _offerService = OfferService();
final _consultantService = ConsultantService();

Future<List<dynamic>> _getTicketComments(int id) async {
  try {
    final r = await _ticketService.getTicketComments(id);
    return r.map((e) => e.toJson()).toList();
  } catch (_) {
    return [];
  }
}

Future<Map<String, dynamic>?> _postComment({
  required int ticketId,
  required int senderId,
  required bool isConsultantReply,
  required String message,
}) async {
  try {
    final r = await _ticketService.addComment(ticketId, message,
        senderId: senderId, isConsultantReply: isConsultantReply);
    return r?.toJson();
  } catch (_) {
    return null;
  }
}

Future<List<dynamic>> _getInternalNotes(int id) async {
  try {
    final r = await _ticketService.getNotes(id);
    return r.map((e) => e.toJson()).toList();
  } catch (_) {
    return [];
  }
}

Future<Map<String, dynamic>?> _postNote({
  required int ticketId,
  required int authorId,
  required String noteText,
}) async {
  try {
    final r = await _ticketService.addNote(ticketId,
        authorId: authorId, noteText: noteText);
    return r?.toJson();
  } catch (_) {
    return null;
  }
}

Future<bool> _escalateTicket(int id, String reason) async {
  try {
    return await _ticketService.escalateTicket(id, reason);
  } catch (_) {
    return false;
  }
}

Future<List<dynamic>> _getMyOffers() async {
  try {
    return await _offerService.getMyOffers();
  } catch (_) {
    return [];
  }
}

Future<Map<String, dynamic>?> _saveOffer(Map<String, dynamic> data,
    {int? id}) async {
  try {
    return id != null
        ? (await _offerService.updateOffer(id, data) ? data : null)
        : (await _offerService.createOffer(data) ? data : null);
  } catch (_) {
    return null;
  }
}

Future<bool> _deleteOffer(int id) async {
  return await _offerService.deleteOffer(id);
}

Future<List<dynamic>> _getMasterSlots() async {
  try {
    return await _consultantService.getAllMasterSlots();
  } catch (_) {
    return [];
  }
}

Future<bool> _createMasterSlot(String t) async {
  try {
    return await _consultantService.createMasterSlot(t);
  } catch (_) {
    return false;
  }
}

Future<bool> _updateMasterSlotApi(int id, String t) async {
  try {
    return await _consultantService.updateMasterSlot(id, t);
  } catch (_) {
    return false;
  }
}

Future<bool> _deleteMasterSlotApi(int id) async {
  try {
    return await _consultantService.deleteMasterSlot(id);
  } catch (_) {
    return false;
  }
}

// MAIN DASHBOARD SHELL

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
    (
      icon: Icons.calendar_today_outlined,
      activeIcon: Icons.calendar_today,
      label: 'Bookings'
    ),
    (
      icon: Icons.confirmation_number_outlined,
      activeIcon: Icons.confirmation_number,
      label: 'Tickets'
    ),
    (
      icon: Icons.schedule_outlined,
      activeIcon: Icons.schedule,
      label: 'Schedule'
    ),
    (icon: Icons.star_outline, activeIcon: Icons.star, label: 'Feedback'),
    (
      icon: Icons.payments_outlined,
      activeIcon: Icons.payments,
      label: 'Earnings'
    ),
    (
      icon: Icons.local_offer_outlined,
      activeIcon: Icons.local_offer,
      label: 'Offers'
    ),
    (icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile'),
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
    setState(() {
      _authLoading = true;
      _authError = null;
    });
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
          _authError =
              'Consultant ID not found. Please logout and login again.';
        });
        return;
      }
      setState(() {
        _consultantIdInt = cId;
        _userId = uId;
        _authLoading = false;
      });
      context.read<NotificationService>().initialize('CONSULTANT', uId ?? cId);
      _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) context.read<NotificationService>().refresh();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _authLoading = false;
        _authError = e.toString();
      });
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
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await AuthService().logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (_) => false);
      }
    }
  }

  void _openNotifications() {
    final svc = context.read<NotificationService>();
    svc.refresh().catchError((_) {});
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.95,
        minChildSize: 0.4,
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
              child: const Text('Logout',
                  style: TextStyle(color: AppColors.danger)),
            ),
          ]),
        ),
      );
    }
    switch (_selectedIndex) {
      case 0:
        return _ConsultantBookingsTab(
            consultantId: _consultantIdInt!, userId: _userId ?? 0);
      case 1:
        return _ConsultantTicketsTab(
            consultantId: _consultantIdInt!, userId: _userId ?? 0);
      case 2:
        return _ConsultantScheduleTab(consultantId: _consultantIdInt!);
      case 3:
        return _ConsultantFeedbacksTab(consultantId: _consultantIdInt!);
      case 4:
        return ConsultantEarningsTab(consultantId: _consultantIdInt!);
      case 5:
        return _ConsultantOffersTab(consultantId: _consultantIdInt!);
      case 6:
        return _ConsultantProfileTab(consultantId: _consultantIdInt!);
      default:
        return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _selectedIndex = 0),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(
              width: 40,
              height: 40,
              child: MeetTheMastersLogoBadge(
                size: 40,
                padding: 5,
                showAmbientGlow: false,
              ),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('MEET THE MASTERS',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.brandBlue,
                      letterSpacing: 1.4)),
              Text(
                _sanitizeDisplayText(_navItems[_selectedIndex].label,
                    fallback: 'Dashboard'),
                style: AppTextStyles.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ]),
          ]),
        ),
        actions: [
          IconButton(
            tooltip: 'Profile',
            onPressed: () => setState(() => _selectedIndex = 6),
            icon: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.accent.withValues(alpha: 0.2),
              child: const Icon(Icons.person_outline,
                  color: AppColors.accent, size: 18),
            ),
          ),
          Consumer<NotificationService>(
            builder: (_, svc, __) => Stack(children: [
              IconButton(
                tooltip: 'Notifications',
                icon: const Icon(Icons.notifications_outlined,
                    color: AppColors.textPrimary),
                onPressed: _openNotifications,
              ),
              if (svc.unreadCount > 0)
                Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                          color: AppColors.danger, shape: BoxShape.circle),
                      child: Text(
                        svc.unreadCount > 9 ? '9+' : '${svc.unreadCount}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold),
                      ),
                    )),
            ]),
          ),
          PopupMenuButton<String>(
            offset: const Offset(0, 48),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            icon: const Icon(Icons.more_vert_rounded,
                color: AppColors.textPrimary),
            onSelected: (v) {
              if (v == 'logout') _confirmLogout();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'logout',
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
          items: _navItems
              .map((n) => BottomNavigationBarItem(
                    icon: Icon(n.icon, size: 22),
                    activeIcon: Icon(n.activeIcon, size: 22),
                    label: n.label,
                  ))
              .toList(),
        ),
      ),
    );
  }
}

// BOOKINGS TAB

class _ConsultantBookingsTab extends StatefulWidget {
  final int consultantId;
  final int userId;
  const _ConsultantBookingsTab(
      {required this.consultantId, required this.userId});
  @override
  State<_ConsultantBookingsTab> createState() => _ConsultantBookingsTabState();
}

class _ConsultantBookingsTabState extends State<_ConsultantBookingsTab>
    with SingleTickerProviderStateMixin {
  static const int _pageSize = 10;

  final _svc = BookingService();
  late TabController _tabs;
  List<Booking> _bookings = [];
  final Map<int, List<Booking>> _pageCache = {};
  List<Map<String, dynamic>> _specialBookings = [];
  bool _loading = true;
  bool _paging = false;
  bool _specialLoading = false;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalElements = 0;
  int _requestToken = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _load(refreshSpecial: true);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load({
    int page = 1,
    bool force = false,
    bool clearCache = false,
    bool refreshSpecial = false,
  }) async {
    final targetPage = page < 1 ? 1 : page;
    if (clearCache) _pageCache.clear();

    if (!force) {
      final cached = _pageCache[targetPage];
      if (cached != null) {
        if (mounted) {
          setState(() {
            _bookings = cached;
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
        if (_bookings.isEmpty || force || clearCache) {
          _loading = true;
          _paging = false;
        } else {
          _paging = true;
        }
        if (refreshSpecial && _specialBookings.isEmpty) {
          _specialLoading = true;
        }
      });
    }

    final requestToken = ++_requestToken;
    try {
      final regularFuture = _svc.getBookingsByConsultantPaginated(
        widget.consultantId,
        page: targetPage - 1,
        size: _pageSize,
      );
      final specialFuture = refreshSpecial
          ? _svc.getSpecialBookingsByConsultant(widget.consultantId)
          : Future.value(_specialBookings);
      final results = await Future.wait([regularFuture, specialFuture]);
      if (requestToken != _requestToken || !mounted) return;

      final regular =
          results[0] as ({List<dynamic> content, int totalElements});
      final bookings = regular.content.whereType<Booking>().toList();
      final rawTotalElements =
          regular.totalElements <= 0 ? bookings.length : regular.totalElements;
      var computedTotalPages = rawTotalElements <= 0
          ? (bookings.length == _pageSize ? targetPage + 1 : targetPage)
          : ((rawTotalElements + _pageSize - 1) ~/ _pageSize);
      if (computedTotalPages <= 0) computedTotalPages = 1;
      final safeCurrentPage =
          targetPage > computedTotalPages ? computedTotalPages : targetPage;

      _pageCache[targetPage] = bookings;

      setState(() {
        _bookings = bookings;
        _specialBookings = results[1] as List<Map<String, dynamic>>;
        _currentPage = safeCurrentPage;
        _totalPages = computedTotalPages;
        _totalElements = rawTotalElements;
        _loading = false;
        _paging = false;
        _specialLoading = false;
      });
      unawaited(_prefetchAdjacentPages(safeCurrentPage));
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _paging = false;
          _specialLoading = false;
        });
      }
    }
  }

  Future<void> _prefetchAdjacentPages(int currentPage) async {
    final neighbors = [currentPage - 1, currentPage + 1];
    for (final page in neighbors) {
      if (page < 1 || page > _totalPages) continue;
      if (_pageCache.containsKey(page)) continue;
      unawaited(_prefetchPage(page));
    }
  }

  Future<void> _prefetchPage(int page) async {
    try {
      final result = await _svc.getBookingsByConsultantPaginated(
        widget.consultantId,
        page: page - 1,
        size: _pageSize,
      );
      if (!mounted || _pageCache.containsKey(page)) return;
      _pageCache[page] = result.content.whereType<Booking>().toList();
    } catch (_) {}
  }

  Future<void> _refreshCurrent({bool refreshSpecial = false}) => _load(
        page: _currentPage,
        force: true,
        clearCache: true,
        refreshSpecial: refreshSpecial,
      );

  void _goToPage(int page) {
    if (page < 1 || page > _totalPages || page == _currentPage) return;
    _load(page: page);
  }

  List<int> _visiblePages() {
    if (_totalPages <= 1) return const [1];
    final pages = <int>{1, _totalPages, _currentPage};
    for (var p = _currentPage - 1; p <= _currentPage + 1; p++) {
      if (p >= 1 && p <= _totalPages) pages.add(p);
    }
    final out = pages.toList()..sort();
    return out;
  }

  Widget _paginationBar() {
    if (_totalPages <= 1) return const SizedBox.shrink();
    final pages = _visiblePages();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        IconButton(
          onPressed:
              _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null,
          icon: const Icon(Icons.chevron_left_rounded),
          visualDensity: VisualDensity.compact,
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (var i = 0; i < pages.length; i++) ...[
                if (i > 0 && pages[i] - pages[i - 1] > 1)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text('...',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w700)),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: GestureDetector(
                    onTap: () => _goToPage(pages[i]),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _currentPage == pages[i]
                            ? AppColors.accent
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _currentPage == pages[i]
                              ? AppColors.accent
                              : AppColors.border,
                        ),
                      ),
                      child: Text(
                        '${pages[i]}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _currentPage == pages[i]
                              ? Colors.white
                              : AppColors.textSecondary,
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
          onPressed: _currentPage < _totalPages
              ? () => _goToPage(_currentPage + 1)
              : null,
          icon: const Icon(Icons.chevron_right_rounded),
          visualDensity: VisualDensity.compact,
        ),
      ]),
    );
  }

  List<Booking> get _upcoming =>
      _bookings.where((b) => _isUpcomingBooking(b)).toList();
  List<Booking> get _pending =>
      _bookings.where((b) => b.status.toUpperCase() == 'PENDING').toList();
  List<Booking> get _history => _bookings
      .where((b) =>
          b.isExpired ||
          ['COMPLETED', 'CANCELLED'].contains(b.status.toUpperCase()))
      .toList();

  int? _parseTimeToMinutes(String raw) {
    final value = raw.trim().toUpperCase();
    if (value.isEmpty) return null;

    final hhmm = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(value);
    if (hhmm != null) {
      final hour = int.tryParse(hhmm.group(1) ?? '');
      final minute = int.tryParse(hhmm.group(2) ?? '');
      if (hour == null || minute == null) return null;
      return hour * 60 + minute;
    }

    final ampm =
        RegExp(r'^(\d{1,2})(?::(\d{2}))?\s*(AM|PM)$').firstMatch(value);
    if (ampm != null) {
      var hour = int.tryParse(ampm.group(1) ?? '') ?? 0;
      final minute = int.tryParse(ampm.group(2) ?? '0') ?? 0;
      final period = ampm.group(3) ?? 'AM';
      if (period == 'PM' && hour != 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;
      return hour * 60 + minute;
    }
    return null;
  }

  int? _endTimeMinutes(String? timeRange) {
    final value = (timeRange ?? '').trim();
    if (value.isEmpty) return null;
    final parts = value.split(RegExp(r'\s*[-–]\s*'));
    final end = parts.isEmpty ? value : parts.last;
    return _parseTimeToMinutes(end);
  }

  bool _isUpcomingBooking(Booking booking) {
    final status = booking.status.trim().toUpperCase();
    const terminalStatuses = {
      'COMPLETED',
      'CANCELLED',
      'REJECTED',
      'FAILED',
      'EXPIRED'
    };
    if (terminalStatuses.contains(status)) {
      return false;
    }

    // Keep pending requests in the Pending tab only.
    if (status == 'PENDING') {
      return false;
    }

    final slotDateRaw = (booking.slotDate ?? '').trim();
    final parsedDate = slotDateRaw.isNotEmpty
        ? DateTime.tryParse(slotDateRaw)?.toLocal()
        : null;
    if (parsedDate != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final bookingDay =
          DateTime(parsedDate.year, parsedDate.month, parsedDate.day);

      if (bookingDay.isAfter(today)) return true;
      if (bookingDay.isBefore(today)) return false;

      final endMinutes = _endTimeMinutes(booking.timeRange);
      if (endMinutes == null) return true;
      final endTime = DateTime(
          now.year, now.month, now.day, endMinutes ~/ 60, endMinutes % 60);
      return now.isBefore(endTime);
    }

    const activeStatuses = {
      'CONFIRMED',
      'SCHEDULED',
      'BOOKED',
      'PAID',
      'IN_PROGRESS',
      'RESCHEDULED',
      'UPCOMING'
    };
    if (activeStatuses.contains(status)) return true;
    return !booking.isExpired;
  }

  Future<void> _updateStatus(Booking b, String newStatus) async {
    final normalizedStatus = newStatus.trim().toUpperCase();
    Future<bool> attemptUpdate({String? paymentStatus, bool minimal = false}) {
      return _svc.updateBooking(
        b.id,
        bookingStatus: normalizedStatus,
        paymentStatus: paymentStatus,
        consultantId: minimal ? null : (b.consultantId ?? widget.consultantId),
        timeSlotId: minimal ? null : b.timeSlotId,
        meetingMode: minimal ? null : b.meetingMode,
        meetingLink: minimal ? null : b.meetingLink,
        meetingId: minimal ? null : b.meetingId,
        meetingNotes: minimal ? null : b.meetingNotes,
      );
    }

    final attempts = <Future<bool> Function()>[
      () => attemptUpdate(),
      () => attemptUpdate(minimal: true),
    ];
    if (normalizedStatus == 'CONFIRMED') {
      attempts.insert(
        0,
        () => attemptUpdate(paymentStatus: 'SUCCESS'),
      );
      attempts.add(
        () => attemptUpdate(paymentStatus: 'PAID'),
      );
      attempts.add(
        () => attemptUpdate(paymentStatus: 'SUCCESS', minimal: true),
      );
    }

    var ok = false;
    for (final attempt in attempts) {
      ok = await attempt();
      if (ok) break;
    }

    if (mounted) {
      _snack(ok ? 'Status -> $normalizedStatus' : 'Update failed', ok);
      if (ok) _refreshCurrent(refreshSpecial: true);
    }
  }

  Future<void> _cancelBooking(Booking b) async {
    final confirm = await _confirmDialog('Cancel Booking #${b.id}?',
        'This cannot be undone.', 'Cancel', AppColors.danger);
    if (confirm != true) return;
    final ok = await _svc.cancelBooking(b.id);
    if (mounted) {
      _snack(ok ? 'Booking cancelled' : 'Cancel failed', ok);
      if (ok) _refreshCurrent(refreshSpecial: true);
    }
  }

  Future<void> _markComplete(Booking b) async {
    final confirm = await _confirmDialog(
        'Mark as Completed?',
        'Booking #${b.id} will be marked complete.',
        'Complete',
        AppColors.success);
    if (confirm != true) return;
    final ok = await _svc.updateBooking(
          b.id,
          bookingStatus: 'COMPLETED',
          consultantId: b.consultantId ?? widget.consultantId,
          timeSlotId: b.timeSlotId,
          meetingMode: b.meetingMode,
          meetingLink: b.meetingLink,
          meetingId: b.meetingId,
          meetingNotes: b.meetingNotes,
        ) ||
        await _svc.updateBooking(b.id, bookingStatus: 'COMPLETED');
    if (mounted) {
      _snack(ok ? 'Marked as completed' : 'Update failed', ok);
      if (ok) _refreshCurrent(refreshSpecial: true);
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
        padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _handleBar(),
              Text('Meeting Link for Booking #${b.id}',
                  style: AppTextStyles.h3),
              const SizedBox(height: 16),
              TextField(
                  controller: ctrl,
                  decoration: const InputDecoration(
                      labelText: 'Meeting URL',
                      hintText: 'https://meet.jit.si/...',
                      prefixIcon: Icon(Icons.videocam_outlined))),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Save Link',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                  onPressed: () async {
                    final ok = await _svc.addMeetingLink(b.id,
                        meetingLink: ctrl.text.trim());
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      _snack(ok ? 'Meeting link saved!' : 'Failed to save', ok);
                      if (ok) _refreshCurrent(refreshSpecial: true);
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
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text('Booking #${b.id}', style: AppTextStyles.h3)),
              const Divider(height: 1),
              if (b.meetingLink != null && b.meetingLink!.isNotEmpty)
                _actionTile(
                    Icons.copy_outlined, 'Copy Meeting Link', AppColors.info,
                    () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: b.meetingLink!));
                  _snack('Meeting link copied!', true);
                }),
              _actionTile(Icons.description_outlined, 'View Client Answers',
                  AppColors.primary, () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BookingAnswersScreen(
                      bookingId: b.id,
                      bookingType: 'NORMAL',
                      userId: b.userId,
                      clientName: _sanitizeDisplayText(b.clientName,
                          fallback: 'Client'),
                    ),
                  ),
                );
              }),
              if (b.status.toUpperCase() == 'PENDING')
                _actionTile(Icons.check_circle_outline, 'Confirm Booking',
                    AppColors.success, () {
                  Navigator.pop(context);
                  _updateStatus(b, 'CONFIRMED');
                }),
              if (b.status.toUpperCase() == 'CONFIRMED')
                _actionTile(Icons.task_alt_rounded, 'Mark as Completed',
                    AppColors.success, () {
                  Navigator.pop(context);
                  _markComplete(b);
                }),
              if (!['CANCELLED', 'COMPLETED'].contains(b.status.toUpperCase()))
                _actionTile(
                    Icons.cancel_outlined, 'Cancel Booking', AppColors.danger,
                    () {
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _pill(_pending.length, AppColors.warning, 'Pending'),
            const SizedBox(width: 8),
            _pill(_upcoming.length, AppColors.info, 'Upcoming'),
            const Spacer(),
            Text('$_totalElements total', style: AppTextStyles.caption),
          ]),
          const SizedBox(height: 6),
          Text(
            'Page $_currentPage of $_totalPages • 10 bookings per page',
            style: AppTextStyles.caption,
          ),
        ]),
      ),
      Container(
        color: AppColors.surface,
        child: TabBar(
          controller: _tabs,
          isScrollable: true,
          labelPadding: const EdgeInsets.symmetric(horizontal: 14),
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.accent,
          tabs: [
            Tab(text: 'Upcoming (${_upcoming.length})'),
            Tab(text: 'Pending (${_pending.length})'),
            const Tab(text: 'History'),
            Tab(text: 'Special (${_specialBookings.length})'),
          ],
        ),
      ),
      const Divider(height: 1),
      if (_paging)
        const LinearProgressIndicator(color: AppColors.accent, minHeight: 2),
      Expanded(
        child: _loading
            ? ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: 4,
                itemBuilder: (_, __) => const Padding(
                    padding: EdgeInsets.only(bottom: 12), child: ShimmerCard()))
            : RefreshIndicator(
                onRefresh: () => _refreshCurrent(refreshSpecial: true),
                child: TabBarView(controller: _tabs, children: [
                  _buildList(_upcoming, 'No upcoming sessions'),
                  _buildList(_pending, 'No pending bookings'),
                  _buildList(_history, 'No history yet'),
                  _buildSpecialList(),
                ]),
              ),
      ),
    ]);
  }

  Widget _buildList(List<Booking> list, String emptyTitle) {
    if (list.isEmpty) {
      if (_totalPages > 1) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            EmptyState(icon: Icons.calendar_today_outlined, title: emptyTitle),
            _paginationBar(),
          ],
        );
      }
      return EmptyState(icon: Icons.calendar_today_outlined, title: emptyTitle);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length + (_totalPages > 1 ? 1 : 0),
      itemBuilder: (_, i) {
        if (i >= list.length) return _paginationBar();
        final b = list[i];
        final color = _statusColor(b.status);
        final clientName = _sanitizeDisplayText(b.clientName, fallback: 'User');
        final meetingMode = _sanitizeDisplayText(b.meetingMode);
        final slotDate = _sanitizeDisplayText(b.slotDate);
        final timeRange = _sanitizeDisplayText(b.timeRange);
        final bookingMetaParts = <String>[
          if (meetingMode.isNotEmpty) meetingMode,
          if (slotDate.isNotEmpty) slotDate,
          if (timeRange.isNotEmpty) timeRange,
        ];
        final bookingSubtitle = bookingMetaParts.isEmpty
            ? '#${b.id}'
            : '#${b.id} - ${bookingMetaParts.join(' - ')}';
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => _showActionSheet(b),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10)),
                        child:
                            Icon(Icons.event_outlined, color: color, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('Session with $clientName',
                                style: AppTextStyles.h4,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            Text(bookingSubtitle,
                                style: AppTextStyles.caption,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                          ])),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8)),
                              child: Text(b.status,
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: color)),
                            ),
                            if (b.amount != null) ...[
                              const SizedBox(height: 4),
                              Text('₹${b.amount!.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.success,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ]),
                    ]),
                    if (b.meetingLink != null && b.meetingLink!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(
                              ClipboardData(text: b.meetingLink!));
                          _snack('Meeting link copied!', true);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                              color: AppColors.info.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color:
                                      AppColors.info.withValues(alpha: 0.25))),
                          child: Row(children: [
                            const Icon(Icons.videocam_outlined,
                                size: 14, color: AppColors.info),
                            const SizedBox(width: 6),
                            Expanded(
                                child: Text(b.meetingLink!,
                                    style: const TextStyle(
                                        fontSize: 11, color: AppColors.info),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis)),
                            const Icon(Icons.copy_rounded,
                                size: 12, color: AppColors.info),
                          ]),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(children: [
                      if (b.meetingMode?.toUpperCase() == 'ONLINE') ...[
                        Expanded(
                            child: ElevatedButton.icon(
                          onPressed: b.meetingLink?.isNotEmpty == true
                              ? () => launchUrl(Uri.parse(b.meetingLink!))
                              : null,
                          icon: const Icon(Icons.videocam_rounded,
                              size: 16, color: Colors.white),
                          label: const Text('Join Meeting',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        )),
                        const SizedBox(width: 8),
                      ],
                      if (b.status.toUpperCase() == 'CONFIRMED')
                        Expanded(
                            child: ElevatedButton.icon(
                          onPressed: () => _markComplete(b),
                          icon:
                              const Icon(Icons.check_circle_outline, size: 16),
                          label: const Text('Complete',
                              style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              padding: const EdgeInsets.symmetric(vertical: 8)),
                        ))
                      else if (b.status.toUpperCase() == 'PENDING')
                        Expanded(
                            child: ElevatedButton.icon(
                          onPressed: () => _updateStatus(b, 'CONFIRMED'),
                          icon: const Icon(Icons.thumb_up_outlined, size: 16),
                          label: const Text('Confirm',
                              style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.info,
                              padding: const EdgeInsets.symmetric(vertical: 8)),
                        )),
                    ]),
                  ]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSpecialList() {
    if (_specialLoading) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 3,
        itemBuilder: (_, __) => const Padding(
            padding: EdgeInsets.only(bottom: 12), child: ShimmerCard()),
      );
    }
    if (_specialBookings.isEmpty) {
      return const EmptyState(
        icon: Icons.star_border_rounded,
        title: 'No Special Bookings',
        subtitle: 'Users who request custom sessions will appear here',
      );
    }
    return RefreshIndicator(
      onRefresh: () => _refreshCurrent(refreshSpecial: true),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _specialBookings.length,
        itemBuilder: (_, i) {
          final sb = _specialBookings[i];
          return _SpecialBookingCard(
            booking: sb,
            onGiveSlot: () => _showGiveSlotSheet(sb),
            onReschedule: () => _showRescheduleSheet(sb),
            onRefresh: () {
              unawaited(_refreshCurrent(refreshSpecial: true));
            },
          );
        },
      ),
    );
  }

  void _showGiveSlotSheet(Map<String, dynamic> sb) {
    final id = (sb['id'] as num?)?.toInt() ?? 0;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _GiveSlotSheet(
        bookingId: id,
        onSaved: () {
          Navigator.pop(ctx);
          _refreshCurrent(refreshSpecial: true);
        },
      ),
    );
  }

  void _showRescheduleSheet(Map<String, dynamic> sb) {
    final id = (sb['id'] as num?)?.toInt() ?? 0;
    final scheduledDate = _sanitizeDisplayText(
      sb['scheduledDate'] ??
          sb['scheduled_date'] ??
          sb['slotDate'] ??
          sb['date'] ??
          sb['bookingDate'],
    );
    final scheduledTime = _sanitizeDisplayText(
      sb['scheduledTime'] ??
          sb['scheduled_time'] ??
          sb['startTime'] ??
          sb['slotTime'] ??
          sb['time'],
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _RescheduleSlotSheet(
        bookingId: id,
        currentDate: scheduledDate,
        currentTime: scheduledTime,
        onSaved: () {
          Navigator.pop(ctx);
          _refreshCurrent(refreshSpecial: true);
        },
      ),
    );
  }

  void _snack(String msg, [bool success = true]) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? AppColors.success : AppColors.danger,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Widget _pill(int count, Color color, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text('$count $label',
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ]),
      );

  Future<bool?> _confirmDialog(
      String title, String content, String action, Color color) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: color,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, true),
            child: Text(action, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _actionTile(
          IconData icon, String label, Color color, VoidCallback onTap) =>
      ListTile(
          leading: Icon(icon, color: color, size: 20),
          title: Text(label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          onTap: onTap,
          dense: true);
}

// TICKETS TAB

// SPECIAL BOOKING CARD
// Shows REQUESTED (needs slot) differently from CONFIRMED (slot given)

class _SpecialBookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final VoidCallback onGiveSlot;
  final VoidCallback onReschedule;
  final VoidCallback onRefresh;
  const _SpecialBookingCard({
    required this.booking,
    required this.onGiveSlot,
    required this.onReschedule,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final id = (booking['id'] as num?)?.toInt() ?? 0;
    final status = (booking['status'] ?? 'REQUESTED').toString().toUpperCase();
    final userId = (booking['userId'] as num?)?.toInt() ?? 0;
    final duration = (booking['durationInHours'] as num?)?.toInt() ?? 1;
    final mode =
        _sanitizeDisplayText(booking['meetingMode'], fallback: 'ONLINE')
            .toUpperCase();
    final notes = _cleanSpecialBookingNotes(booking['userNotes']);
    final amount =
        double.tryParse(booking['totalAmount']?.toString() ?? '0') ?? 0;
    final schedDate = _sanitizeDisplayText(
      booking['scheduledDate'] ??
          booking['scheduled_date'] ??
          booking['slotDate'] ??
          booking['date'] ??
          booking['bookingDate'],
    );
    final schedTime = _sanitizeDisplayText(
      booking['scheduledTime'] ??
          booking['scheduled_time'] ??
          booking['startTime'] ??
          booking['slotTime'] ??
          booking['time'],
    );
    final meetLink = (booking['meetingLink'] ?? '').toString().trim();
    final isRequested = status == 'REQUESTED';
    final isConfirmed = status == 'CONFIRMED';
    final isCompleted = status == 'COMPLETED';
    final isCancelled = status == 'CANCELLED';

    final Color statusColor = isRequested
        ? AppColors.warning
        : isConfirmed
            ? AppColors.success
            : isCompleted
                ? AppColors.info
                : AppColors.danger;

    final IconData statusIcon = isRequested
        ? Icons.schedule_rounded
        : isConfirmed
            ? Icons.check_circle_rounded
            : isCompleted
                ? Icons.task_alt_rounded
                : Icons.cancel_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isRequested
              ? AppColors.warning.withOpacity(0.5)
              : AppColors.border,
          width: isRequested ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: isRequested
                ? AppColors.warning.withOpacity(0.06)
                : AppColors.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(statusIcon, color: statusColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Special Booking #$id',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A))),
                  const SizedBox(height: 2),
                  Text(
                      'User #$userId - $duration hr${duration > 1 ? 's' : ''} - $mode',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF64748B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ])),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Text(status.replaceAll('_', ' '),
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: statusColor)),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Amount
            Row(children: [
              _infoChip(Icons.currency_rupee_rounded,
                  '₹${amount.toStringAsFixed(0)}', AppColors.success),
              const SizedBox(width: 8),
              _infoChip(
                  Icons.access_time_rounded,
                  '$duration hr${duration > 1 ? 's' : ''}',
                  AppColors.primaryLight),
              const SizedBox(width: 8),
              _infoChip(
                  mode == 'ONLINE'
                      ? Icons.videocam_rounded
                      : mode == 'PHONE'
                          ? Icons.phone_rounded
                          : Icons.location_on_rounded,
                  mode,
                  AppColors.textSecondary),
            ]),

            // Scheduled date/time (shown only when CONFIRMED or COMPLETED)
            if ((isConfirmed || isCompleted) && schedDate.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.success.withOpacity(0.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_today_rounded,
                      size: 14, color: AppColors.success),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(
                    'Scheduled: $schedDate${schedTime.isNotEmpty ? ' - ${schedTime.substring(0, schedTime.length > 5 ? 5 : schedTime.length)}' : ''}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success),
                  )),
                ]),
              ),
            ],

            // Meeting link (if given)
            if (meetLink.isNotEmpty) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: meetLink));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Meeting link copied!'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: AppColors.success,
                  ));
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.info.withOpacity(0.25)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.videocam_outlined,
                        size: 14, color: AppColors.info),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(meetLink,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.info),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis)),
                    const Icon(Icons.copy_rounded,
                        size: 12, color: AppColors.info),
                  ]),
                ),
              ),
            ],

            // REQUESTED notice
            if (isRequested) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 14, color: AppColors.warning),
                  const SizedBox(width: 8),
                  const Expanded(
                      child: Text(
                    'User is waiting for you to assign a date, time & meeting link.',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.warning,
                        fontWeight: FontWeight.w500),
                  )),
                ]),
              ),
            ],

            // User notes
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.notes_rounded,
                    size: 14, color: Color(0xFF94A3B8)),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(notes,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF64748B)))),
              ]),
            ],
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BookingAnswersScreen(
                      bookingId: id,
                      userId: userId,
                      clientName: 'Client #$userId',
                      bookingType: 'SPECIAL',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.assignment_ind_outlined, size: 16),
              label: const Text('View Client Assessment',
                  style: TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                foregroundColor: AppColors.primaryLight,
                side: const BorderSide(color: AppColors.primaryLight),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ),
        if (!isCancelled && !isCompleted)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(children: [
              if (isRequested)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onGiveSlot,
                    icon: const Icon(Icons.schedule_rounded,
                        size: 16, color: Colors.white),
                    label: const Text('Assign Slot',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryLight,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              if (isConfirmed) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReschedule,
                    icon: const Icon(Icons.edit_calendar_rounded, size: 16),
                    label: const Text('Reschedule',
                        style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      foregroundColor: AppColors.primaryLight,
                      side: const BorderSide(color: AppColors.primaryLight),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ]),
          ),
      ]),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ]),
      );
}

// POST /api/special-bookings/{id}/give-slot

class _GiveSlotSheet extends StatefulWidget {
  final int bookingId;
  final VoidCallback onSaved;
  const _GiveSlotSheet({required this.bookingId, required this.onSaved});
  @override
  State<_GiveSlotSheet> createState() => _GiveSlotSheetState();
}

class _GiveSlotSheetState extends State<_GiveSlotSheet> {
  final _svc = BookingService();

  DateTime? _selDate;
  TimeOfDay? _selTime;
  bool _saving = false;
  String _err = '';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primaryLight),
        ),
        child: child!,
      ),
    );
    if (picked != null)
      setState(() {
        _selDate = picked;
        _err = '';
      });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selTime ?? const TimeOfDay(hour: 10, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primaryLight),
        ),
        child: child!,
      ),
    );
    if (picked != null)
      setState(() {
        _selTime = picked;
        _err = '';
      });
  }

  Future<void> _submit() async {
    if (_selDate == null) {
      setState(() => _err = 'Please select a date.');
      return;
    }
    if (_selTime == null) {
      setState(() => _err = 'Please select a time.');
      return;
    }

    setState(() {
      _saving = true;
      _err = '';
    });

    // Format date as YYYY-MM-DD and time as HH:MM:SS for the backend
    final dateStr =
        '${_selDate!.year}-${_selDate!.month.toString().padLeft(2, '0')}-${_selDate!.day.toString().padLeft(2, '0')}';
    final timeStr =
        '${_selTime!.hour.toString().padLeft(2, '0')}:${_selTime!.minute.toString().padLeft(2, '0')}:00';

    final ok = await _svc.giveSlotSpecialBooking(widget.bookingId, {
      'date': dateStr,
      'startTime': timeStr,
      'scheduledDate': dateStr,
      'scheduledTime': timeStr,
      'newDate': dateStr,
      'newTime': timeStr,
      'time': timeStr,
    });

    if (mounted) {
      setState(() => _saving = false);
      if (ok) {
        widget.onSaved();
      } else {
        setState(() => _err = 'Failed to assign slot. Please try again.');
      }
    }
  }

  String _fmtDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                  child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2)),
              )),
              const SizedBox(height: 16),

              // Header
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF1E3A5F), Color(0xFF2563EB)]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(children: [
                  const Icon(Icons.schedule_rounded,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const Text('Assign Session Slot',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                        Text('Booking #${widget.bookingId}',
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF93C5FD))),
                      ])),
                ]),
              ),
              const SizedBox(height: 20),

              // Error banner
              if (_err.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: AppColors.danger.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.warning_rounded,
                        size: 16, color: AppColors.danger),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(_err,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.danger,
                                fontWeight: FontWeight.w600))),
                  ]),
                ),

              // Date picker
              _sectionLabel('DATE *'),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: _selDate != null
                        ? const Color(0xFFEFF6FF)
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selDate != null
                          ? AppColors.primaryLight
                          : AppColors.border,
                      width: _selDate != null ? 1.5 : 1,
                    ),
                  ),
                  child: Row(children: [
                    Icon(Icons.calendar_today_rounded,
                        size: 18,
                        color: _selDate != null
                            ? AppColors.primaryLight
                            : AppColors.textSecondary),
                    const SizedBox(width: 10),
                    Text(
                        _selDate != null
                            ? _fmtDate(_selDate!)
                            : 'Tap to select date',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _selDate != null
                              ? AppColors.primaryLight
                              : AppColors.textSecondary,
                        )),
                  ]),
                ),
              ),
              const SizedBox(height: 14),

              // Time picker
              _sectionLabel('START TIME *'),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickTime,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: _selTime != null
                        ? const Color(0xFFEFF6FF)
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selTime != null
                          ? AppColors.primaryLight
                          : AppColors.border,
                      width: _selTime != null ? 1.5 : 1,
                    ),
                  ),
                  child: Row(children: [
                    Icon(Icons.access_time_rounded,
                        size: 18,
                        color: _selTime != null
                            ? AppColors.primaryLight
                            : AppColors.textSecondary),
                    const SizedBox(width: 10),
                    Text(
                        _selTime != null
                            ? _selTime!.format(context)
                            : 'Tap to select time',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _selTime != null
                              ? AppColors.primaryLight
                              : AppColors.textSecondary,
                        )),
                  ]),
                ),
              ),
              const SizedBox(height: 24),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.check_circle_outline_rounded,
                          color: Colors.white, size: 18),
                  label: Text(
                      _saving ? 'Assigning...' : 'Confirm & Assign Slot',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryLight,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    disabledBackgroundColor:
                        AppColors.primaryLight.withOpacity(0.5),
                  ),
                ),
              ),
            ]),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(text,
      style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.textSecondary,
          letterSpacing: 0.5));
}

// PUT /api/special-bookings/{id}/reschedule

class _RescheduleSlotSheet extends StatefulWidget {
  final int bookingId;
  final String currentDate;
  final String currentTime;
  final VoidCallback onSaved;
  const _RescheduleSlotSheet({
    required this.bookingId,
    required this.currentDate,
    required this.currentTime,
    required this.onSaved,
  });
  @override
  State<_RescheduleSlotSheet> createState() => _RescheduleSlotSheetState();
}

class _RescheduleSlotSheetState extends State<_RescheduleSlotSheet> {
  final _svc = BookingService();
  DateTime? _selDate;
  TimeOfDay? _selTime;
  bool _saving = false;
  String _err = '';

  @override
  void initState() {
    super.initState();
    // Pre-fill with existing scheduled date/time
    try {
      if (widget.currentDate.isNotEmpty) {
        _selDate = DateTime.parse(widget.currentDate);
      }
    } catch (_) {}
    try {
      if (widget.currentTime.isNotEmpty) {
        final parts = widget.currentTime.split(':');
        if (parts.length >= 2) {
          _selTime =
              TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
        }
      }
    } catch (_) {}
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme:
                const ColorScheme.light(primary: AppColors.primaryLight)),
        child: child!,
      ),
    );
    if (picked != null)
      setState(() {
        _selDate = picked;
        _err = '';
      });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selTime ?? const TimeOfDay(hour: 10, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme:
                const ColorScheme.light(primary: AppColors.primaryLight)),
        child: child!,
      ),
    );
    if (picked != null)
      setState(() {
        _selTime = picked;
        _err = '';
      });
  }

  Future<void> _submit() async {
    if (_selDate == null) {
      setState(() => _err = 'Please select a new date.');
      return;
    }
    if (_selTime == null) {
      setState(() => _err = 'Please select a new time.');
      return;
    }
    setState(() {
      _saving = true;
      _err = '';
    });

    final dateStr =
        '${_selDate!.year}-${_selDate!.month.toString().padLeft(2, '0')}-${_selDate!.day.toString().padLeft(2, '0')}';
    final timeStr =
        '${_selTime!.hour.toString().padLeft(2, '0')}:${_selTime!.minute.toString().padLeft(2, '0')}:00';

    final ok = await _svc.rescheduleSpecialBooking(
      widget.bookingId,
      newDate: dateStr,
      newTime: timeStr,
    );

    if (mounted) {
      setState(() => _saving = false);
      if (ok) {
        widget.onSaved();
      } else {
        setState(() => _err = 'Failed to reschedule. Please try again.');
      }
    }
  }

  String _fmtDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
                child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2)),
            )),
            const SizedBox(height: 16),

            Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.edit_calendar_rounded,
                    color: AppColors.warning, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('Reschedule Session',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                    Text('Booking #${widget.bookingId}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ])),
            ]),
            const SizedBox(height: 20),

            if (_err.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.warning_rounded,
                      size: 16, color: AppColors.danger),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(_err,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.danger))),
                ]),
              ),

            // New Date
            const Text('NEW DATE *',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: _selDate != null
                      ? const Color(0xFFEFF6FF)
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selDate != null
                        ? AppColors.primaryLight
                        : AppColors.border,
                    width: _selDate != null ? 1.5 : 1,
                  ),
                ),
                child: Row(children: [
                  Icon(Icons.calendar_today_rounded,
                      size: 18,
                      color: _selDate != null
                          ? AppColors.primaryLight
                          : AppColors.textSecondary),
                  const SizedBox(width: 10),
                  Text(
                      _selDate != null
                          ? _fmtDate(_selDate!)
                          : 'Select new date',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _selDate != null
                              ? AppColors.primaryLight
                              : AppColors.textSecondary)),
                ]),
              ),
            ),
            const SizedBox(height: 14),

            // New Time
            const Text('NEW TIME *',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickTime,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: _selTime != null
                      ? const Color(0xFFEFF6FF)
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selTime != null
                        ? AppColors.primaryLight
                        : AppColors.border,
                    width: _selTime != null ? 1.5 : 1,
                  ),
                ),
                child: Row(children: [
                  Icon(Icons.access_time_rounded,
                      size: 18,
                      color: _selTime != null
                          ? AppColors.primaryLight
                          : AppColors.textSecondary),
                  const SizedBox(width: 10),
                  Text(
                      _selTime != null
                          ? _selTime!.format(context)
                          : 'Select new time',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _selTime != null
                              ? AppColors.primaryLight
                              : AppColors.textSecondary)),
                ]),
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check_circle_outline_rounded,
                        color: Colors.white, size: 18),
                label: Text(_saving ? 'Saving...' : 'Confirm Reschedule',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  disabledBackgroundColor: AppColors.warning.withOpacity(0.5),
                ),
              ),
            ),
          ]),
    );
  }
}

class _ConsultantTicketsTab extends StatefulWidget {
  final int consultantId;
  final int userId;
  const _ConsultantTicketsTab(
      {required this.consultantId, required this.userId});
  @override
  State<_ConsultantTicketsTab> createState() => _ConsultantTicketsTabState();
}

class _ConsultantTicketsTabState extends State<_ConsultantTicketsTab> {
  static const int _pageSize = 10;

  final _svc = TicketService();
  List<Ticket> _tickets = [];
  final Map<int, List<Ticket>> _pageCache = {};
  bool _loading = true;
  bool _paging = false;
  String _filter = 'ALL';
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalElements = 0;
  int _requestToken = 0;
  final ScrollController _filterChipScrollCtrl = ScrollController();
  static const _filters = ['ALL', 'NEW', 'OPEN', 'IN_PROGRESS', 'RESOLVED'];
  late final Map<String, GlobalKey> _filterChipKeys = {
    for (final f in _filters) f: GlobalKey(),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({
    int page = 1,
    bool force = false,
    bool clearCache = false,
  }) async {
    final targetPage = page < 1 ? 1 : page;
    if (clearCache) _pageCache.clear();

    if (!force) {
      final cached = _pageCache[targetPage];
      if (cached != null) {
        if (mounted) {
          setState(() {
            _tickets = cached;
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
        if (_tickets.isEmpty || force || clearCache) {
          _loading = true;
          _paging = false;
        } else {
          _paging = true;
        }
      });
    }

    final requestToken = ++_requestToken;
    try {
      final result = await _svc.getTicketsByConsultantPaginated(
        widget.consultantId,
        page: targetPage - 1,
        size: _pageSize,
        sortBy: 'createdAt',
      );
      if (requestToken != _requestToken || !mounted) return;

      final rowsRaw = result['tickets'];
      final rows =
          rowsRaw is List ? rowsRaw.whereType<Ticket>().toList() : <Ticket>[];
      final rawTotalElements = _asInt(result['totalElements']) ?? rows.length;
      var computedTotalPages = _asInt(result['totalPages']) ??
          (rawTotalElements <= 0
              ? (rows.length == _pageSize ? targetPage + 1 : targetPage)
              : ((rawTotalElements + _pageSize - 1) ~/ _pageSize));
      if (computedTotalPages <= 0) computedTotalPages = 1;
      final safeCurrentPage =
          targetPage > computedTotalPages ? computedTotalPages : targetPage;
      final safeTotalElements =
          rawTotalElements < rows.length ? rows.length : rawTotalElements;

      _pageCache[targetPage] = rows;

      setState(() {
        _tickets = rows;
        _currentPage = safeCurrentPage;
        _totalPages = computedTotalPages;
        _totalElements = safeTotalElements;
        _loading = false;
        _paging = false;
      });
      unawaited(_prefetchAdjacentPages(safeCurrentPage));
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _paging = false;
        });
      }
    }
  }

  Future<void> _prefetchAdjacentPages(int currentPage) async {
    final neighbors = [currentPage - 1, currentPage + 1];
    for (final page in neighbors) {
      if (page < 1 || page > _totalPages) continue;
      if (_pageCache.containsKey(page)) continue;
      unawaited(_prefetchPage(page));
    }
  }

  Future<void> _prefetchPage(int page) async {
    try {
      final result = await _svc.getTicketsByConsultantPaginated(
        widget.consultantId,
        page: page - 1,
        size: _pageSize,
        sortBy: 'createdAt',
      );
      if (!mounted || _pageCache.containsKey(page)) return;
      final rowsRaw = result['tickets'];
      final rows =
          rowsRaw is List ? rowsRaw.whereType<Ticket>().toList() : <Ticket>[];
      _pageCache[page] = rows;
    } catch (_) {}
  }

  Future<void> _refreshCurrent() => _load(
        page: _currentPage,
        force: true,
        clearCache: true,
      );

  void _goToPage(int page) {
    if (page < 1 || page > _totalPages || page == _currentPage) return;
    _load(page: page);
  }

  List<int> _visiblePages() {
    if (_totalPages <= 1) return const [1];
    final pages = <int>{1, _totalPages, _currentPage};
    for (var p = _currentPage - 1; p <= _currentPage + 1; p++) {
      if (p >= 1 && p <= _totalPages) pages.add(p);
    }
    final out = pages.toList()..sort();
    return out;
  }

  Widget _paginationBar() {
    if (_totalPages <= 1) return const SizedBox.shrink();
    final pages = _visiblePages();
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        IconButton(
          onPressed:
              _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null,
          icon: const Icon(Icons.chevron_left_rounded),
          visualDensity: VisualDensity.compact,
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (var i = 0; i < pages.length; i++) ...[
                if (i > 0 && pages[i] - pages[i - 1] > 1)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text('...',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w700)),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: GestureDetector(
                    onTap: () => _goToPage(pages[i]),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _currentPage == pages[i]
                            ? AppColors.accent
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _currentPage == pages[i]
                              ? AppColors.accent
                              : AppColors.border,
                        ),
                      ),
                      child: Text(
                        '${pages[i]}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _currentPage == pages[i]
                              ? Colors.white
                              : AppColors.textSecondary,
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
          onPressed: _currentPage < _totalPages
              ? () => _goToPage(_currentPage + 1)
              : null,
          icon: const Icon(Icons.chevron_right_rounded),
          visualDensity: VisualDensity.compact,
        ),
      ]),
    );
  }

  @override
  void dispose() {
    _filterChipScrollCtrl.dispose();
    super.dispose();
  }

  List<Ticket> get _filtered => _filter == 'ALL'
      ? _tickets
      : _tickets.where((t) => t.status.toUpperCase() == _filter).toList();

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value == null) return null;
    return int.tryParse(value.toString().trim());
  }

  int get _slaRiskCount => _tickets.where((t) {
        final s = _computeSla(t);
        return s?.state == _SlaState.breached || s?.state == _SlaState.warning;
      }).length;

  void _scrollFilterIntoView(String filter) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final chipContext = _filterChipKeys[filter]?.currentContext;
      if (chipContext == null) return;
      Scrollable.ensureVisible(
        chipContext,
        alignment: 0.12,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _setFilter(String filter) {
    setState(() => _filter = filter);
    _scrollFilterIntoView(filter);
  }

  void _openDetail(Ticket t) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        maxChildSize: 0.95,
        minChildSize: 0.6,
        expand: false,
        builder: (_, sc) => _TicketDetailSheet(
          ticket: t,
          consultantId: widget.consultantId,
          scrollController: sc,
          onStatusChanged: (newStatus) {
            setState(() {
              final idx = _tickets.indexWhere((x) => x.id == t.id);
              if (idx != -1) {
                _tickets[idx] = Ticket(
                  id: t.id,
                  category: t.category,
                  description: t.description,
                  status: newStatus,
                  priority: t.priority,
                  userId: t.userId,
                  consultantId: t.consultantId,
                  userName: t.userName,
                  slaRespondBy: t.slaRespondBy,
                  slaResolveBy: t.slaResolveBy,
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
            const Icon(Icons.warning_rounded,
                color: AppColors.danger, size: 16),
            const SizedBox(width: 8),
            Expanded(
                child: Text(
              '$_slaRiskCount ticket${_slaRiskCount > 1 ? 's' : ''} at SLA risk • respond now',
              style: const TextStyle(
                  color: AppColors.danger,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            )),
          ]),
        ),
      Container(
        color: AppColors.surface,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SingleChildScrollView(
            controller: _filterChipScrollCtrl,
            scrollDirection: Axis.horizontal,
            child: Row(
                children: _filters.map((f) {
              final count = f == 'ALL'
                  ? _tickets.length
                  : _tickets.where((t) => t.status.toUpperCase() == f).length;
              final active = _filter == f;
              return Padding(
                key: _filterChipKeys[f],
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('$f ($count)',
                      style: TextStyle(
                          fontSize: 12,
                          color:
                              active ? Colors.white : AppColors.textSecondary)),
                  selected: active,
                  selectedColor: AppColors.primaryLight,
                  backgroundColor: AppColors.surfaceVariant,
                  onSelected: (_) => _setFilter(f),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  side: BorderSide.none,
                ),
              );
            }).toList()),
          ),
          const SizedBox(height: 6),
          Text(
            'Page $_currentPage of $_totalPages • $_totalElements tickets',
            style: AppTextStyles.caption,
          ),
        ]),
      ),
      if (_paging)
        const LinearProgressIndicator(color: AppColors.accent, minHeight: 2),
      const Divider(height: 1),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _filtered.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const EmptyState(
                          icon: Icons.inbox_outlined,
                          title: 'No tickets assigned'),
                      if (_totalPages > 1) _paginationBar(),
                    ],
                  )
                : RefreshIndicator(
                    onRefresh: _refreshCurrent,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filtered.length + (_totalPages > 1 ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i >= _filtered.length) return _paginationBar();
                        final t = _filtered[i];
                        return _TicketListCard(
                          ticket: t,
                          sla: _computeSla(t),
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
  const _TicketListCard(
      {required this.ticket, required this.sla, required this.onTap});

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
          if (sla != null) Container(height: 3, color: _slaColor(sla!.state)),
          Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                          '${formatTicketNumberFromTicket(ticket)}  ${ticket.category.isEmpty ? "General" : ticket.category}',
                          style: AppTextStyles.h4,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      if (ticket.description != null)
                        Text(ticket.description!,
                            style: AppTextStyles.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                    ])),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: sc.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(ticket.status,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: sc)),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: pc.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(ticket.priority,
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: pc)),
                  ),
                ]),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.person_outline,
                    size: 13, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(ticket.userName ?? 'User', style: AppTextStyles.caption),
                const Spacer(),
                if (sla != null)
                  Row(children: [
                    Icon(slaBreached ? Icons.alarm_off : Icons.timer_outlined,
                        size: 12, color: _slaColor(sla!.state)),
                    const SizedBox(width: 3),
                    Text(sla!.label,
                        style: TextStyle(
                            fontSize: 10,
                            color: _slaColor(sla!.state),
                            fontWeight: FontWeight.w700)),
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
  const _TicketDetailSheet(
      {required this.ticket,
      required this.consultantId,
      required this.scrollController,
      required this.onStatusChanged});
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
  static const _statuses = [
    'NEW',
    'OPEN',
    'IN_PROGRESS',
    'PENDING',
    'RESOLVED',
    'CLOSED'
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _localStatus = widget.ticket.status;
    _loadComments();
    _loadNotes();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _replyCtrl.dispose();
    _noteCtrl.dispose();
    _scrollToBottom.dispose();
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

  DateTime? _parseToLocalDateTime(dynamic raw) {
    final value = raw?.toString().trim() ?? '';
    if (value.isEmpty) return null;
    final hasTimezone =
        value.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(value);
    final normalized = hasTimezone ? value : '${value}Z';
    final parsed = DateTime.tryParse(normalized);
    if (parsed != null) return parsed.toLocal();
    final fallback = DateTime.tryParse(value);
    return fallback?.toLocal();
  }

  String _formatChatTime(dynamic raw) {
    final parsed = _parseToLocalDateTime(raw);
    if (parsed == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(parsed.year, parsed.month, parsed.day);
    if (msgDay == today) {
      return '${DateFormat('hh:mm a').format(parsed)} IST';
    } else if (today.difference(msgDay).inDays < 7) {
      return '${DateFormat('d MMM, hh:mm a').format(parsed)} IST';
    }
    return '${DateFormat('d MMM yyyy, hh:mm a').format(parsed)} IST';
  }

  Future<void> _sendReply() async {
    if (_replyCtrl.text.trim().isEmpty) return;
    final msg = _replyCtrl.text.trim();
    setState(() => _sendingReply = true);
    final saved = await _postComment(
      ticketId: widget.ticket.id,
      senderId: widget.consultantId,
      isConsultantReply: true,
      message: msg,
    );
    if (mounted) {
      if (saved != null) {
        final nowIso = DateTime.now().toUtc().toIso8601String();
        final normalized = {
          ...saved,
          'createdAt':
              (saved['createdAt'] ?? saved['timestamp'] ?? nowIso).toString(),
        };
        _replyCtrl.clear();
        setState(() {
          _comments.add(normalized);
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollToBottom.hasClients) {
            _scrollToBottom.animateTo(_scrollToBottom.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut);
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
    final saved = await _postNote(
        ticketId: widget.ticket.id,
        authorId: widget.consultantId,
        noteText: txt);
    if (mounted) {
      if (saved != null) {
        _noteCtrl.clear();
        setState(() {
          _notes.add(saved);
        });
        _snack('Note saved', true);
      } else {
        _snack('Failed to save note', false);
      }
      setState(() => _sendingNote = false);
    }
  }

  Future<void> _changeStatus(String newStatus) async {
    if (_updatingStatus || _localStatus == newStatus) return;
    setState(() => _updatingStatus = true);
    final ok =
        await TicketService().updateTicketStatus(widget.ticket.id, newStatus);
    if (mounted) {
      if (ok) {
        setState(() => _localStatus = newStatus);
        widget.onStatusChanged(newStatus);
        _snack('Status -> $newStatus', true);
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
          const Text('Provide a reason for escalation:',
              style: TextStyle(fontSize: 13)),
          const SizedBox(height: 12),
          TextField(
              controller: ctrl,
              maxLines: 3,
              decoration: const InputDecoration(
                  hintText: 'Why is this being escalated?',
                  border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child:
                const Text('Escalate', style: TextStyle(color: Colors.white)),
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
        _snack('Escalated • supervisor notified', true);
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
    final slaTicket = Ticket(
        id: widget.ticket.id,
        category: widget.ticket.category,
        description: widget.ticket.description,
        status: _localStatus,
        priority: widget.ticket.priority,
        userId: widget.ticket.userId,
        consultantId: widget.ticket.consultantId,
        userName: widget.ticket.userName,
        slaRespondBy: widget.ticket.slaRespondBy,
        slaResolveBy: widget.ticket.slaResolveBy,
        createdAt: widget.ticket.createdAt);
    final sla = _computeSla(slaTicket);

    return Column(children: [
      Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: _handleBar()),
      Padding(
        padding: EdgeInsets.fromLTRB(
            16, 0, 16, MediaQuery.of(context).viewInsets.bottom > 0 ? 0 : 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                      '${formatTicketNumberFromTicket(widget.ticket)}  ${widget.ticket.category}',
                      style: AppTextStyles.h3),
                  if (widget.ticket.userName != null)
                    Text('Client: ${widget.ticket.userName}',
                        style: AppTextStyles.caption),
                ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: sc.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: sc.withValues(alpha: 0.4))),
              child: Text(_localStatus,
                  style: TextStyle(
                      color: sc, fontWeight: FontWeight.w700, fontSize: 12)),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                  color: pc.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Text(widget.ticket.priority,
                  style: TextStyle(
                      color: pc, fontWeight: FontWeight.w700, fontSize: 11)),
            ),
          ]),
          if (sla != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: _slaColor(sla.state).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: _slaColor(sla.state).withValues(alpha: 0.3))),
              child: Row(children: [
                Icon(
                    sla.state == _SlaState.breached
                        ? Icons.alarm_off
                        : Icons.timer_outlined,
                    size: 14,
                    color: _slaColor(sla.state)),
                const SizedBox(width: 6),
                Text(sla.label,
                    style: TextStyle(
                        fontSize: 11,
                        color: _slaColor(sla.state),
                        fontWeight: FontWeight.w700)),
              ]),
            ),
          ],
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
                children: _statuses.map((s) {
              final active = _localStatus.toUpperCase() == s;
              final c = _statusColor(s);
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: active ? null : () => _changeStatus(s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: active
                            ? c.withValues(alpha: 0.15)
                            : c.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: active ? c : c.withValues(alpha: 0.3),
                            width: active ? 2 : 1)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (active && !_updatingStatus)
                        Icon(Icons.check, size: 12, color: c),
                      if (_updatingStatus && active)
                        SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: c)),
                      if (active) const SizedBox(width: 4),
                      Text(s,
                          style: TextStyle(
                              color: c,
                              fontWeight: FontWeight.w700,
                              fontSize: 12)),
                    ]),
                  ),
                ),
              );
            }).toList()),
          ),
          if (!['RESOLVED', 'CLOSED', 'ESCALATED']
              .contains(_localStatus.toUpperCase())) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _escalating ? null : _showEscalateDialog,
                icon: _escalating
                    ? const SizedBox(
                        width: 14,
                        height: 14,
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
                      ? const Center(
                          child: Text('No messages yet',
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
                              senderName: isAgent
                                  ? 'You'
                                  : (widget.ticket.userName ?? 'Client'),
                              time: _formatChatTime(
                                  c['createdAt'] ?? c['timestamp']),
                            );
                          }),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(
                  12,
                  8,
                  12,
                  (MediaQuery.of(context).viewInsets.bottom > 0
                          ? MediaQuery.of(context).viewInsets.bottom
                          : MediaQuery.of(context).padding.bottom) +
                      8),
              decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border))),
              child: Row(children: [
                Expanded(
                    child: TextField(
                  controller: _replyCtrl,
                  maxLines: null,
                  decoration: InputDecoration(
                    hintText: 'Type your message...',
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                )),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendingReply ? null : _sendReply,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        color: _sendingReply
                            ? AppColors.textMuted
                            : AppColors.accent,
                        shape: BoxShape.circle),
                    child: _sendingReply
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded,
                            color: Colors.white, size: 20),
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
                      ? const Center(
                          child: Text('No internal notes',
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
                                  color:
                                      AppColors.warning.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: AppColors.warning
                                          .withValues(alpha: 0.25))),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      const Icon(Icons.lock_outline,
                                          size: 13, color: AppColors.warning),
                                      const SizedBox(width: 4),
                                      const Text('Internal Note',
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: AppColors.warning,
                                              fontWeight: FontWeight.w700)),
                                      const Spacer(),
                                      if (n['createdAt'] != null ||
                                          n['timestamp'] != null)
                                        Text(
                                            _formatChatTime(n['createdAt'] ??
                                                n['timestamp']),
                                            style: AppTextStyles.caption),
                                    ]),
                                    const SizedBox(height: 6),
                                    Text(n['noteText'] ?? '',
                                        style: AppTextStyles.body),
                                  ]),
                            );
                          }),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border))),
              child: Row(children: [
                const Icon(Icons.lock_outline,
                    size: 16, color: AppColors.warning),
                const SizedBox(width: 8),
                Expanded(
                    child: TextField(
                  controller: _noteCtrl,
                  decoration: InputDecoration(
                    hintText: 'Add private note...',
                    filled: true,
                    fillColor: AppColors.warning.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                )),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendingNote ? null : _saveNote,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        color: _sendingNote
                            ? AppColors.textMuted
                            : AppColors.warning,
                        shape: BoxShape.circle),
                    child: _sendingNote
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_outlined,
                            color: Colors.white, size: 20),
                  ),
                ),
              ]),
            ),
          ]),

          // Details
          ListView(
              controller: widget.scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                _detailRow('Ticket Number',
                    formatTicketNumberFromTicket(widget.ticket)),
                if (widget.ticket.ticketNumber != null)
                  _detailRow('Reference Number', widget.ticket.ticketNumber!),
                _detailRow('Category', widget.ticket.category),
                _detailRow('Priority', widget.ticket.priority),
                _detailRow('Status', _localStatus),
                if (widget.ticket.userName != null)
                  _detailRow('Client', widget.ticket.userName!),
                if (widget.ticket.description != null) ...[
                  const SizedBox(height: 8),
                  const Text('Description',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted)),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border)),
                    child: Text(widget.ticket.description!,
                        style: AppTextStyles.body),
                  ),
                ],
                if (widget.ticket.attachmentUrl != null) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(
                          ClipboardData(text: widget.ticket.attachmentUrl!));
                      if (mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Attachment URL copied'),
                                behavior: SnackBarBehavior.floating));
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10)),
                      child: Row(children: [
                        const Icon(Icons.attach_file_rounded,
                            size: 16, color: AppColors.info),
                        const SizedBox(width: 8),
                        const Text('View Attachment',
                            style: TextStyle(
                                color: AppColors.info,
                                fontWeight: FontWeight.w600)),
                        const Spacer(),
                        const Icon(Icons.copy_rounded,
                            size: 14, color: AppColors.info),
                      ]),
                    ),
                  ),
                ],
                if (widget.ticket.slaResolveBy != null) ...[
                  const SizedBox(height: 12),
                  _detailRow('SLA Deadline', () {
                    final parsed =
                        _parseToLocalDateTime(widget.ticket.slaResolveBy);
                    if (parsed != null) {
                      return '${DateFormat('d MMM yyyy, hh:mm a').format(parsed)} IST';
                    }
                    return widget.ticket.slaResolveBy!;
                  }()),
                ],
                if (widget.ticket.createdAt != null)
                  _detailRow('Created', () {
                    final parsed =
                        _parseToLocalDateTime(widget.ticket.createdAt);
                    if (parsed != null) {
                      return '${DateFormat('d MMM yyyy, hh:mm a').format(parsed)} IST';
                    }
                    return widget.ticket.createdAt!;
                  }()),
              ]),
        ]),
      ),
    ]);
  }

  Widget _detailRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          SizedBox(
              width: 110, child: Text(label, style: AppTextStyles.caption)),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13))),
        ]),
      );
}

class _ChatBubble extends StatelessWidget {
  final String message;
  final bool isAgent;
  final String senderName;
  final String time;
  const _ChatBubble(
      {required this.message,
      required this.isAgent,
      required this.senderName,
      required this.time});

  @override
  Widget build(BuildContext context) {
    final bgColor = isAgent ? AppColors.accent : AppColors.background;
    final textColor = isAgent ? Colors.white : AppColors.textPrimary;
    return Align(
      alignment: isAgent ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Column(
            crossAxisAlignment:
                isAgent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(senderName,
                  style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isAgent ? 16 : 4),
                      bottomRight: Radius.circular(isAgent ? 4 : 16),
                    )),
                child: Text(message,
                    style:
                        TextStyle(fontSize: 14, color: textColor, height: 1.4)),
              ),
              const SizedBox(height: 2),
              Text(time, style: AppTextStyles.caption),
            ]),
      ),
    );
  }
}

// SCHEDULE TAB

class _ConsultantScheduleTab extends StatefulWidget {
  final int consultantId;
  const _ConsultantScheduleTab({required this.consultantId});
  @override
  State<_ConsultantScheduleTab> createState() => _ConsultantScheduleTabState();
}

class _ConsultantScheduleTabState extends State<_ConsultantScheduleTab> {
  final _svc = ConsultantService();
  ConsultantModel? _consultant;
  List<TimeSlot> _allSlots = [];
  List<_ScheduleMasterSlot> _masterSlots = [];
  Set<String> _specialDays = <String>{};
  Set<String> _selectedSlotKeys = <String>{};
  bool _loading = true;
  bool _saving = false;
  String _selectedDate = '';

  List<DateTime> get _days =>
      List.generate(30, (i) => DateTime.now().add(Duration(days: i)));
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
      _svc.getMasterSlots(widget.consultantId),
      _svc.getConsultantById(widget.consultantId),
      _svc.getSpecialDaysByConsultant(widget.consultantId),
    ]);
    if (mounted) {
      setState(() {
        _allSlots = results[0] as List<TimeSlot>;
        _consultant = results[2] as ConsultantModel?;
        _masterSlots =
            _normalizeMasterSlots(results[1] as List<dynamic>, _consultant);
        _specialDays = _normalizeSpecialDays(results[3] as List<dynamic>);
        _selectedSlotKeys = {};
        _loading = false;
      });
    }
  }

  Set<String> _normalizeSpecialDays(List<dynamic> rows) {
    final dates = <String>{};
    for (final row in rows) {
      if (row is String && row.trim().isNotEmpty) {
        dates.add(row.trim());
        continue;
      }
      if (row is Map) {
        final value = (row['specialDate'] ??
                row['special_date'] ??
                row['date'] ??
                row['slotDate'] ??
                '')
            .toString()
            .trim();
        if (value.isNotEmpty) dates.add(value);
      }
    }
    return dates;
  }

  int? _parseMinutes(dynamic raw) {
    if (raw == null) return null;
    final value = raw.toString().trim().toUpperCase();
    if (value.isEmpty) return null;

    final hhmm = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(value);
    if (hhmm != null) {
      final hour = int.tryParse(hhmm.group(1) ?? '');
      final minute = int.tryParse(hhmm.group(2) ?? '');
      if (hour == null || minute == null) return null;
      return hour * 60 + minute;
    }

    final ampm =
        RegExp(r'^(\d{1,2})(?::(\d{2}))?\s*(AM|PM)$').firstMatch(value);
    if (ampm != null) {
      var hour = int.tryParse(ampm.group(1) ?? '') ?? 0;
      final minute = int.tryParse(ampm.group(2) ?? '0') ?? 0;
      final period = ampm.group(3) ?? 'AM';
      if (period == 'PM' && hour != 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;
      return hour * 60 + minute;
    }
    return null;
  }

  String _minutesLabel(int totalMinutes) {
    final normalized = ((totalMinutes % 1440) + 1440) % 1440;
    final hour24 = normalized ~/ 60;
    final minute = normalized % 60;
    final suffix = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    return '$hour12:${minute.toString().padLeft(2, '0')} $suffix';
  }

  _ScheduleMasterSlot? _toMasterSlot(
      dynamic raw, ConsultantModel? consultant, int fallbackMinutes) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final id =
        (map['id'] as num?)?.toInt() ?? int.tryParse('${map['id'] ?? ''}') ?? 0;
    final timeRange = (map['timeRange'] ?? '').toString().trim();
    if (id <= 0 || timeRange.isEmpty) return null;

    final parts = timeRange.split(RegExp(r'\s*[-–]\s*'));
    if (parts.length < 2) return null;
    final startMinutes = _parseMinutes(parts.first);
    final endMinutes = _parseMinutes(parts.last);
    if (startMinutes == null || endMinutes == null) return null;

    var durationMinutes = (map['durationMinutes'] as num?)?.toInt() ??
        (map['duration'] as num?)?.toInt() ??
        (map['durationInMinutes'] as num?)?.toInt() ??
        (endMinutes - startMinutes);
    if (durationMinutes <= 0) {
      durationMinutes = fallbackMinutes > 0 ? fallbackMinutes : 60;
    }

    final shiftStart = _parseMinutes(consultant?.shiftStart);
    final shiftEnd = _parseMinutes(consultant?.shiftEnd);
    final withinShift = shiftStart == null ||
        shiftEnd == null ||
        (startMinutes >= shiftStart && endMinutes <= shiftEnd);
    if (!withinShift) return null;

    return _ScheduleMasterSlot(
      id: id,
      timeRange: timeRange,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      durationMinutes: durationMinutes,
    );
  }

  List<_ScheduleMasterSlot> _normalizeMasterSlots(
      List<dynamic> rows, ConsultantModel? consultant) {
    final fallbackMinutes = consultant?.slotsDuration ?? 60;
    final slots = rows
        .map((row) => _toMasterSlot(row, consultant, fallbackMinutes))
        .whereType<_ScheduleMasterSlot>()
        .toList()
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    return slots;
  }

  String _slotStartKey(String value) {
    final parts = value.split(RegExp(r'\s*[-–]\s*'));
    final start = parts.isEmpty ? value : parts.first;
    final minutes = _parseMinutes(start);
    if (minutes == null) return value;
    final hour = (minutes ~/ 60).toString().padLeft(2, '0');
    final minute = (minutes % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _masterSlotKey(_ScheduleMasterSlot slot) =>
      '${(slot.startMinutes ~/ 60).toString().padLeft(2, '0')}:${(slot.startMinutes % 60).toString().padLeft(2, '0')}';

  _ScheduleDisplaySlot _displaySlotFor(_ScheduleMasterSlot master) {
    TimeSlot? existing;
    for (final slot in _allSlots) {
      if (slot.slotDate != _selectedDate) continue;
      final matchesMaster = slot.masterTimeSlotId == master.id;
      final matchesStart =
          _slotStartKey(slot.timeRange) == _masterSlotKey(master);
      if (matchesMaster || matchesStart) {
        existing = slot;
        break;
      }
    }

    return _ScheduleDisplaySlot(
      master: master,
      existing: existing,
      status: existing?.status.toUpperCase() ?? 'AVAILABLE',
    );
  }

  List<_ScheduleDisplaySlot> get _slotsForDate =>
      _masterSlots.map(_displaySlotFor).toList();

  bool get _isSpecialDay => _specialDays.contains(_selectedDate);
  bool get _hasSelectedActionableSlots => _slotsForDate.any(
        (slot) =>
            _selectedSlotKeys.contains(slot.key) && slot.status != 'BOOKED',
      );

  Color _slotColor(String status) {
    switch (status.toUpperCase()) {
      case 'AVAILABLE':
        return AppColors.success;
      case 'BOOKED':
        return AppColors.primaryLight;
      case 'UNAVAILABLE':
        return AppColors.warning;
      default:
        return AppColors.textMuted;
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

  Future<void> _toggleDisplaySlot(_ScheduleDisplaySlot slot) async {
    if (slot.status == 'BOOKED') {
      _snack('Booked slots cannot be changed.', false);
      return;
    }

    setState(() => _saving = true);
    final targetStatus =
        slot.status == 'UNAVAILABLE' ? 'AVAILABLE' : 'UNAVAILABLE';
    bool ok;
    if (slot.existing != null) {
      ok = await _svc.updateTimeSlot(slot.existing!.id, {
        'status': targetStatus,
      });
    } else {
      ok = targetStatus == 'UNAVAILABLE' &&
          await _svc.addCustomSlot(
                consultantId: widget.consultantId,
                slotDate: _selectedDate,
                masterTimeSlotId: slot.master.id,
                durationMinutes: slot.master.durationMinutes,
                status: 'UNAVAILABLE',
              ) !=
              null;
    }

    if (mounted) {
      setState(() => _saving = false);
      _snack(
        ok
            ? (targetStatus == 'UNAVAILABLE' ? 'Slot blocked' : 'Slot restored')
            : 'Update failed',
        ok,
      );
      if (ok) _load();
    }
  }

  Future<void> _toggleSelectedSlots(String targetStatus) async {
    if (_selectedSlotKeys.isEmpty || !_hasSelectedActionableSlots) {
      _snack('Please select at least one available/unavailable slot', false);
      return;
    }
    setState(() => _saving = true);
    var allOk = true;
    for (final slot in _slotsForDate) {
      if (!_selectedSlotKeys.contains(slot.key) || slot.status == 'BOOKED') {
        continue;
      }
      if (slot.status == targetStatus) {
        continue;
      }

      bool ok;
      if (slot.existing != null) {
        ok = await _svc.updateTimeSlot(slot.existing!.id, {
          'status': targetStatus,
        });
      } else {
        if (targetStatus == 'UNAVAILABLE') {
          ok = await _svc.addCustomSlot(
                consultantId: widget.consultantId,
                slotDate: _selectedDate,
                masterTimeSlotId: slot.master.id,
                durationMinutes: slot.master.durationMinutes,
                status: 'UNAVAILABLE',
              ) !=
              null;
        } else {
          // Slot is virtual + available already, so restore is effectively done.
          ok = true;
        }
      }
      allOk = allOk && ok;
    }

    if (mounted) {
      setState(() {
        _saving = false;
        _selectedSlotKeys = {};
      });
      _snack(
        allOk
            ? (targetStatus == 'UNAVAILABLE'
                ? 'Selected slots blocked'
                : 'Selected slots restored')
            : 'Some slots could not be updated',
        allOk,
      );
      await _load();
    }
  }

  Future<void> _toggleSpecialDay() async {
    setState(() => _saving = true);
    final ok = _isSpecialDay
        ? await _svc.unpublishSpecialDay(widget.consultantId, _selectedDate)
        : await _svc.publishSpecialDay(widget.consultantId, _selectedDate);
    if (mounted) {
      setState(() => _saving = false);
      _snack(
        ok
            ? (_isSpecialDay
                ? 'Special day removed'
                : 'Date published as special day')
            : 'Failed to update special day',
        ok,
      );
      if (ok) _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final available =
        _slotsForDate.where((s) => s.status == 'AVAILABLE').length;
    final booked = _slotsForDate.where((s) => s.status == 'BOOKED').length;
    final blocked =
        _slotsForDate.where((s) => s.status == 'UNAVAILABLE').length;
    final hasSelectedActionableSlots = _slotsForDate.any(
      (slot) => _selectedSlotKeys.contains(slot.key) && slot.status != 'BOOKED',
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: Column(children: [
                Container(
                  color: AppColors.surface,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(children: [
                    _statPill(available, AppColors.success, 'Available'),
                    const SizedBox(width: 8),
                    _statPill(booked, AppColors.info, 'Booked'),
                    const SizedBox(width: 8),
                    _statPill(blocked, AppColors.warning, 'Blocked'),
                    const SizedBox(width: 8),
                    _statPill(
                        _specialDays.length, AppColors.warning, 'Special'),
                    const Spacer(),
                    Flexible(
                      child: Text(
                        _sanitizeDisplayText(_consultant?.shiftTimingsDisplay,
                            fallback: 'Shift not set'),
                        style: AppTextStyles.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ]),
                ),
                if (_saving)
                  const LinearProgressIndicator(color: AppColors.accent),
                const Divider(height: 1),
                Container(
                  color: AppColors.surface,
                  height: 74,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: _days.length,
                    itemBuilder: (_, i) {
                      final d = _days[i];
                      final key = _dateKey(d);
                      final isSelected = key == _selectedDate;
                      final slotCount = _masterSlots.length;
                      final isSpecial = _specialDays.contains(key);
                      return GestureDetector(
                        onTap: () => setState(() {
                          _selectedDate = key;
                          _selectedSlotKeys = {};
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 8),
                          width: 52,
                          decoration: BoxDecoration(
                              color: isSelected
                                  ? (isSpecial
                                      ? AppColors.warning
                                      : AppColors.accent)
                                  : AppColors.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: isSelected
                                      ? (isSpecial
                                          ? AppColors.warning
                                          : AppColors.accent)
                                      : AppColors.border)),
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(DateFormat('EEE').format(d).toUpperCase(),
                                    style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? Colors.white70
                                            : AppColors.textMuted)),
                                Text('${d.day}',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: isSelected
                                            ? Colors.white
                                            : AppColors.textPrimary)),
                                if (isSpecial)
                                  Container(
                                      width: 16,
                                      height: 3,
                                      decoration: BoxDecoration(
                                          color: isSelected
                                              ? Colors.white54
                                              : AppColors.warning,
                                          borderRadius:
                                              BorderRadius.circular(2)))
                                else if (slotCount > 0)
                                  Container(
                                      width: 16,
                                      height: 3,
                                      decoration: BoxDecoration(
                                          color: isSelected
                                              ? Colors.white54
                                              : AppColors.accent,
                                          borderRadius:
                                              BorderRadius.circular(2))),
                              ]),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _isSpecialDay
                              ? AppColors.warning.withOpacity(0.08)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _isSpecialDay
                                ? AppColors.warning.withOpacity(0.32)
                                : AppColors.border,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              _isSpecialDay
                                  ? Icons.star_rounded
                                  : Icons.event_available_rounded,
                              color: _isSpecialDay
                                  ? AppColors.warning
                                  : AppColors.primaryLight,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isSpecialDay
                                        ? 'Special Day'
                                        : 'Standard Day',
                                    style: AppTextStyles.h4,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _isSpecialDay
                                        ? 'Users can request special bookings for this date. Standard master slots are hidden until you remove special-day mode.'
                                        : 'Only admin master slots that fit your shift hours are shown here. Consultants can block or restore them, but cannot add their own master ranges.',
                                    style: AppTextStyles.caption,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: _isSpecialDay
                                    ? AppColors.warning
                                    : AppColors.primaryLight,
                              ),
                              onPressed: _saving ? null : _toggleSpecialDay,
                              child: Text(
                                _isSpecialDay
                                    ? 'Remove Special'
                                    : 'Publish as Special',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_isSpecialDay)
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Special bookings enabled',
                                  style: AppTextStyles.h4),
                              const SizedBox(height: 8),
                              Text(
                                'Customers can now submit special-booking requests for ${DateFormat('d MMM').format(DateTime.parse(_selectedDate))}. Exact slot confirmation happens from your special bookings list.',
                                style: AppTextStyles.body,
                              ),
                            ],
                          ),
                        )
                      else if (_masterSlots.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 48),
                            child: Column(
                              children: [
                                const Icon(Icons.calendar_today_outlined,
                                    size: 48, color: AppColors.textMuted),
                                const SizedBox(height: 12),
                                Text(
                                  'No admin master slots fall inside your shift hours.',
                                  style: AppTextStyles.body,
                                ),
                              ],
                            ),
                          ),
                        )
                      else ...[
                        Row(
                          children: [
                            Text('Step 2 - Select Time',
                                style: AppTextStyles.label),
                            const Spacer(),
                            OutlinedButton(
                              onPressed: () {
                                final keys = _slotsForDate
                                    .where((slot) => slot.status != 'BOOKED')
                                    .map((slot) => slot.key)
                                    .toSet();
                                setState(() {
                                  _selectedSlotKeys =
                                      _selectedSlotKeys.length == keys.length
                                          ? <String>{}
                                          : keys;
                                });
                              },
                              child: Text(
                                _selectedSlotKeys.isEmpty
                                    ? 'Select All'
                                    : 'Deselect All',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.warning),
                                  onPressed: _saving ||
                                          !hasSelectedActionableSlots
                                      ? null
                                      : () =>
                                          _toggleSelectedSlots('UNAVAILABLE'),
                                  child: const Text('Block Selected'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.success),
                                  onPressed: _saving ||
                                          !hasSelectedActionableSlots
                                      ? null
                                      : () => _toggleSelectedSlots('AVAILABLE'),
                                  child: const Text('Restore Selected'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ..._slotsForDate.map((slot) {
                          final c = _slotColor(slot.status);
                          final isBooked = slot.status == 'BOOKED';
                          final isSelected =
                              _selectedSlotKeys.contains(slot.key) && !isBooked;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: c.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: isSelected
                                      ? AppColors.accent
                                      : c.withValues(alpha: 0.3),
                                  width: isSelected ? 1.5 : 1),
                            ),
                            child: Row(
                              children: [
                                if (!isBooked)
                                  Checkbox(
                                    value: isSelected,
                                    shape: const CircleBorder(),
                                    side: BorderSide(
                                      color: isSelected
                                          ? AppColors.accent
                                          : AppColors.textMuted,
                                      width: 1.4,
                                    ),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                    onChanged: (_) {
                                      setState(() {
                                        if (isSelected) {
                                          _selectedSlotKeys.remove(slot.key);
                                        } else {
                                          _selectedSlotKeys.add(slot.key);
                                        }
                                      });
                                    },
                                  ),
                                Container(
                                  width: 4,
                                  height: 40,
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                      color: c,
                                      borderRadius: BorderRadius.circular(2)),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(slot.master.timeRange,
                                          style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              color: c)),
                                      Text(slot.status,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: c.withValues(alpha: 0.8))),
                                    ],
                                  ),
                                ),
                                if (!isBooked)
                                  GestureDetector(
                                    onTap: _saving
                                        ? null
                                        : !isSelected
                                            ? () => _snack(
                                                'Select the checkbox first, then use Block/Restore.',
                                                false)
                                            : () => _toggleDisplaySlot(slot),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                          color: !isSelected
                                              ? AppColors.surfaceVariant
                                              : slot.status == 'UNAVAILABLE'
                                                  ? AppColors.success
                                                      .withValues(alpha: 0.1)
                                                  : AppColors.warning
                                                      .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: !isSelected
                                                  ? AppColors.border
                                                  : slot.status == 'UNAVAILABLE'
                                                      ? AppColors.success
                                                      : AppColors.warning)),
                                      child: Text(
                                          slot.status == 'UNAVAILABLE'
                                              ? 'Restore'
                                              : 'Block',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: !isSelected
                                                  ? AppColors.textMuted
                                                  : slot.status == 'UNAVAILABLE'
                                                      ? AppColors.success
                                                      : AppColors.warning)),
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                        color: AppColors.info
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8)),
                                    child: const Text('Booked',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.info,
                                            fontWeight: FontWeight.w700)),
                                  ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ]),
            ),
    );
  }

  Widget _statPill(int count, Color color, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20)),
        child: Text('$count $label',
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      );
}

class _ScheduleMasterSlot {
  final int id;
  final String timeRange;
  final int startMinutes;
  final int endMinutes;
  final int durationMinutes;

  const _ScheduleMasterSlot({
    required this.id,
    required this.timeRange,
    required this.startMinutes,
    required this.endMinutes,
    required this.durationMinutes,
  });
}

class _ScheduleDisplaySlot {
  final _ScheduleMasterSlot master;
  final TimeSlot? existing;
  final String status;

  const _ScheduleDisplaySlot({
    required this.master,
    required this.existing,
    required this.status,
  });

  String get key => '${master.id}|${master.startMinutes}';
}

// FEEDBACK TAB

class _ConsultantFeedbacksTab extends StatefulWidget {
  final int consultantId;
  const _ConsultantFeedbacksTab({required this.consultantId});
  @override
  State<_ConsultantFeedbacksTab> createState() =>
      _ConsultantFeedbacksTabState();
}

class _ConsultantFeedbacksTabState extends State<_ConsultantFeedbacksTab> {
  List<Feedback> _feedbacks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _feedbacks =
        await FeedbackService().getFeedbacksByConsultant(widget.consultantId);
    if (mounted) setState(() => _loading = false);
  }

  double get _avg => _feedbacks.isEmpty
      ? 0
      : _feedbacks.fold(0.0, (s, f) => s + f.rating) / _feedbacks.length;

  Map<int, int> get _distribution {
    final m = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    for (final f in _feedbacks) {
      final r = f.rating.clamp(1, 5);
      m[r] = (m[r] ?? 0) + 1;
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_feedbacks.isEmpty)
      return const EmptyState(
          icon: Icons.star_outline,
          title: 'No feedback yet',
          subtitle: 'Client reviews from completed sessions appear here');

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight]),
              borderRadius: BorderRadius.circular(20)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Average Rating',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 4),
            Row(children: [
              Text(_avg.toStringAsFixed(1),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w800)),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(
                    children: List.generate(
                        5,
                        (i) => Icon(
                            i < _avg.round()
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: AppColors.gold,
                            size: 22))),
                const SizedBox(height: 4),
                Text('${_feedbacks.length} reviews',
                    style:
                        const TextStyle(color: Colors.white60, fontSize: 12)),
              ]),
            ]),
            const SizedBox(height: 16),
            ...[5, 4, 3, 2, 1].map((star) {
              final count = _distribution[star] ?? 0;
              final ratio =
                  _feedbacks.isEmpty ? 0.0 : count / _feedbacks.length;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  Text('$star',
                      style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  const Icon(Icons.star_rounded,
                      color: AppColors.gold, size: 11),
                  const SizedBox(width: 6),
                  Expanded(
                      child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                              value: ratio,
                              backgroundColor: Colors.white12,
                              valueColor:
                                  const AlwaysStoppedAnimation(AppColors.gold),
                              minHeight: 6))),
                  const SizedBox(width: 8),
                  Text('$count',
                      style:
                          const TextStyle(color: Colors.white60, fontSize: 11)),
                ]),
              );
            }),
          ]),
        ),
        const SizedBox(height: 20),
        ..._feedbacks.map((f) {
          final safeClientName =
              _sanitizeDisplayText(f.clientName, fallback: 'Client');
          final safeInitial =
              safeClientName.isNotEmpty ? safeClientName[0].toUpperCase() : 'C';
          final safeComments = _sanitizeDisplayText(f.comments);
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                CircleAvatar(
                    radius: 18,
                    backgroundColor:
                        AppColors.primaryLight.withValues(alpha: 0.15),
                    child: Text(safeInitial,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryLight))),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(safeClientName,
                        style: AppTextStyles.h4,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis)),
                Row(
                    children: List.generate(
                        5,
                        (i) => Icon(
                            i < f.rating
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: AppColors.gold,
                            size: 16))),
              ]),
              if (safeComments.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(safeComments,
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.textSecondary)),
              ],
              if (f.createdAt != null) ...[
                const SizedBox(height: 8),
                Text(f.createdAt!, style: AppTextStyles.caption),
              ],
            ]),
          );
        }),
      ]),
    );
  }
}

class _ConsultantOffersTab extends StatefulWidget {
  final int consultantId;
  const _ConsultantOffersTab({required this.consultantId});
  @override
  State<_ConsultantOffersTab> createState() => _ConsultantOffersTabState();
}

class _ConsultantOffersTabState extends State<_ConsultantOffersTab> {
  List<dynamic> _offers = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _offers = await _offerService.getMyOffers();
    } catch (_) {
      _offers = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _delete(int id) async {
    final ok = await _offerService.deleteOffer(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Offer deleted' : 'Failed to delete'),
        backgroundColor: ok ? AppColors.success : AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ));
      if (ok) _load();
    }
  }

  void _openForm([Map<String, dynamic>? existing]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _OfferForm(
        offer: existing,
        consultantId: widget.consultantId,
        onSaved: () {
          Navigator.pop(context);
          _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('My Offers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _openForm(),
            tooltip: 'Create offer',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _offers.isEmpty
              ? Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                      Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(20)),
                          child: const Icon(Icons.local_offer_outlined,
                              size: 32, color: AppColors.textSecondary)),
                      const SizedBox(height: 16),
                      const Text('No Offers Yet',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text('Create offers to attract more clients',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textSecondary)),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => _openForm(),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Create First Offer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryLight,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ]))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _offers.length,
                    itemBuilder: (ctx, i) {
                      final o = _offers[i] as Map<String, dynamic>;
                      final id = (o['id'] as num?)?.toInt() ?? 0;
                      final title =
                          _sanitizeDisplayText(o['title'], fallback: 'Offer');
                      final disc = _sanitizeDisplayText(o['discount']);
                      final isActive =
                          o['active'] == true || o['isActive'] == true;
                      final desc = _sanitizeDisplayText(o['description']);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: isActive
                                  ? AppColors.primaryLight.withOpacity(0.4)
                                  : AppColors.border),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2))
                          ],
                        ),
                        child: ListTile(
                          contentPadding:
                              const EdgeInsets.fromLTRB(16, 10, 12, 10),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.primaryLight.withOpacity(0.1)
                                  : AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.local_offer_rounded,
                                color: isActive
                                    ? AppColors.primaryLight
                                    : AppColors.textSecondary,
                                size: 22),
                          ),
                          title: Text(title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14)),
                          subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (disc.isNotEmpty)
                                  Text(disc,
                                      style: TextStyle(
                                          color: AppColors.gold,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12)),
                                if (desc.isNotEmpty)
                                  Text(desc,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12)),
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? AppColors.accent.withOpacity(0.1)
                                        : AppColors.surfaceVariant,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(isActive ? 'ACTIVE' : 'INACTIVE',
                                      style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: isActive
                                              ? AppColors.accent
                                              : AppColors.textSecondary)),
                                ),
                              ]),
                          trailing:
                              Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(
                                icon: const Icon(Icons.edit_outlined,
                                    size: 18, color: AppColors.primaryLight),
                                onPressed: () => _openForm(o)),
                            IconButton(
                                icon: const Icon(Icons.delete_outline_rounded,
                                    size: 18, color: AppColors.danger),
                                onPressed: () async {
                                  final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                            title: const Text('Delete Offer?'),
                                            content: Text('Delete "$title"?'),
                                            actions: [
                                              TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          context, false),
                                                  child: const Text('Cancel')),
                                              TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          context, true),
                                                  child: const Text('Delete',
                                                      style: TextStyle(
                                                          color: AppColors
                                                              .danger))),
                                            ],
                                          ));
                                  if (ok == true) _delete(id);
                                }),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _OfferForm extends StatefulWidget {
  final Map<String, dynamic>? offer;
  final int consultantId;
  final VoidCallback onSaved;
  const _OfferForm(
      {this.offer, required this.consultantId, required this.onSaved});
  @override
  State<_OfferForm> createState() => _OfferFormState();
}

class _OfferFormState extends State<_OfferForm> {
  final _titleCtrl = TextEditingController();
  final _discCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _validFrom = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String _validTo = DateFormat('yyyy-MM-dd')
      .format(DateTime.now().add(const Duration(days: 30)));
  bool _active = true;
  bool _saving = false;
  String _err = '';

  @override
  void initState() {
    super.initState();
    if (widget.offer != null) {
      _titleCtrl.text = widget.offer!['title']?.toString() ?? '';
      _discCtrl.text = widget.offer!['discount']?.toString() ?? '';
      _descCtrl.text = widget.offer!['description']?.toString() ?? '';
      final from = widget.offer!['validFrom']?.toString();
      final to = widget.offer!['validTo']?.toString();
      if (from != null && from.length >= 10) _validFrom = from.substring(0, 10);
      if (to != null && to.length >= 10) _validTo = to.substring(0, 10);
      _active =
          widget.offer!['active'] == true || widget.offer!['isActive'] == true;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _discCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final current = isFrom ? _validFrom : _validTo;
    final initial = DateTime.tryParse(current) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked == null) return;
    setState(() {
      final value = DateFormat('yyyy-MM-dd').format(picked);
      if (isFrom) {
        _validFrom = value;
      } else {
        _validTo = value;
      }
    });
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      setState(() => _err = 'Title is required.');
      return;
    }
    if (_discCtrl.text.trim().isEmpty) {
      setState(() => _err = 'Discount is required.');
      return;
    }
    if (_validFrom.isEmpty || _validTo.isEmpty) {
      setState(() => _err = 'Valid From and Valid To dates are required.');
      return;
    }
    final fromDate = DateTime.tryParse(_validFrom);
    final toDate = DateTime.tryParse(_validTo);
    if (fromDate == null || toDate == null) {
      setState(() => _err = 'Please choose valid offer dates.');
      return;
    }
    if (toDate.isBefore(fromDate)) {
      setState(() => _err = 'Valid To date cannot be before Valid From date.');
      return;
    }
    setState(() {
      _saving = true;
      _err = '';
    });
    final data = {
      'title': _titleCtrl.text.trim(),
      'discount': _discCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'active': _active,
      'validFrom': '${_validFrom}T00:00:00',
      'validTo': '${_validTo}T23:59:59',
      'consultantId': widget.consultantId,
    };
    final id = (widget.offer?['id'] as num?)?.toInt() ??
        int.tryParse('${widget.offer?['id'] ?? ''}');
    final result = id != null
        ? (await _offerService.updateOffer(id, data) ? data : null)
        : (await _offerService.createOffer(data) ? data : null);
    if (mounted) {
      setState(() => _saving = false);
      if (result != null) {
        widget.onSaved();
      } else {
        setState(() => _err = 'Failed to save offer. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                      child: Text(
                          widget.offer != null ? 'Edit Offer' : 'New Offer',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800))),
                  IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context)),
                ]),
                if (_err.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: AppColors.danger.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(_err,
                        style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                _field('Title *', _titleCtrl, 'e.g. Early Bird Discount'),
                const SizedBox(height: 12),
                _field('Discount *', _discCtrl, 'e.g. 20% off, Rs 500 off'),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: _dateField(
                      label: 'Valid From *',
                      value: _validFrom,
                      onTap: () => _pickDate(isFrom: true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _dateField(
                      label: 'Valid To *',
                      value: _validTo,
                      onTap: () => _pickDate(isFrom: false),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                _field(
                    'Description', _descCtrl, 'Brief description (optional)'),
                const SizedBox(height: 14),
                Row(children: [
                  const Text('Active',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const Spacer(),
                  Switch(
                      value: _active,
                      onChanged: (v) => setState(() => _active = v),
                      activeColor: AppColors.primaryLight),
                ]),
                const SizedBox(height: 16),
                SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryLight,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text(
                              widget.offer != null
                                  ? 'Update Offer'
                                  : 'Create Offer',
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700)),
                    )),
              ]),
        ),
      );

  Widget _field(String label, TextEditingController ctrl, String hint) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5)),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: AppColors.textMuted),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.primaryLight)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                filled: true,
                fillColor: AppColors.background),
          ),
        ],
      );

  Widget _dateField({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5)),
          const SizedBox(height: 6),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: InputDecorator(
              decoration: InputDecoration(
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                suffixIcon: const Icon(Icons.calendar_today_outlined, size: 16),
                filled: true,
                fillColor: AppColors.background,
              ),
              child: Text(value, style: const TextStyle(fontSize: 13)),
            ),
          ),
        ],
      );
}

class _ConsultantProfileTab extends StatefulWidget {
  final int consultantId;
  const _ConsultantProfileTab({required this.consultantId});
  @override
  State<_ConsultantProfileTab> createState() => _ConsultantProfileTabState();
}

class _ConsultantProfileTabState extends State<_ConsultantProfileTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _adminService = AdminService();
  final _analyticsService = AnalyticsService();
  ConsultantModel? _profile;
  bool _loading = true;
  String? _errorMsg;
  bool _editMode = false;
  bool _saving = false;

  // Form controllers
  final _nameCtrl = TextEditingController();
  final _designCtrl = TextEditingController();
  final _feeCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _skillsCtrl = TextEditingController();
  final _shiftStartCtrl = TextEditingController();
  final _shiftEndCtrl = TextEditingController();
  final _expCtrl = TextEditingController();

  // Photo
  File? _photoFile; // selected from gallery
  String? _photoUrl; // existing photo from API

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
    _nameCtrl.dispose();
    _designCtrl.dispose();
    _feeCtrl.dispose();
    _descCtrl.dispose();
    _skillsCtrl.dispose();
    _shiftStartCtrl.dispose();
    _shiftEndCtrl.dispose();
    _expCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    try {
      final profile =
          await ConsultantService().getConsultantById(widget.consultantId);
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
      setState(() {
        _loading = false;
        _errorMsg = 'Error: $e';
      });
    }
  }

  /// Populate all form controllers safely from profile data
  void _populateControllers(ConsultantModel p) {
    try {
      _nameCtrl.text = p.name ?? '';
      _designCtrl.text = p.designation ?? '';
      _feeCtrl.text = (p.charges ?? 0).toStringAsFixed(0);
      _descCtrl.text = p.description ?? '';
      _skillsCtrl.text = p.skills.join(', ');
      // FIXED: use extension methods that safely parse LocalTime Maps
      _shiftStartCtrl.text = p.shiftStart;
      _shiftEndCtrl.text = p.shiftEnd;
      _expCtrl.text = p.experience.toStringAsFixed(0);
      _photoUrl = p.profilePhotoUrl;
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

  Future<void> _pickTime(TextEditingController ctrl) async {
    TimeOfDay? initial;
    try {
      if (ctrl.text.isNotEmpty) {
        final value = ctrl.text.trim().toUpperCase();
        final hhmm =
            RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?$').firstMatch(value);
        if (hhmm != null) {
          initial = TimeOfDay(
            hour: int.tryParse(hhmm.group(1) ?? '') ?? 0,
            minute: int.tryParse(hhmm.group(2) ?? '') ?? 0,
          );
        } else {
          final ampm =
              RegExp(r'^(\d{1,2})(?::(\d{2}))?\s*(AM|PM)$').firstMatch(value);
          if (ampm != null) {
            var hour = int.tryParse(ampm.group(1) ?? '') ?? 0;
            final minute = int.tryParse(ampm.group(2) ?? '0') ?? 0;
            final period = ampm.group(3) ?? 'AM';
            if (period == 'PM' && hour != 12) hour += 12;
            if (period == 'AM' && hour == 12) hour = 0;
            initial = TimeOfDay(hour: hour, minute: minute);
          }
        }
      }
    } catch (_) {}

    final picked = await showTimePicker(
      context: context,
      initialTime: initial ?? TimeOfDay.now(),
    );
    if (picked != null) {
      final suffix = picked.hour >= 12 ? 'PM' : 'AM';
      final hour12 = picked.hour % 12 == 0 ? 12 : picked.hour % 12;
      ctrl.text = '$hour12:${picked.minute.toString().padLeft(2, '0')} $suffix';
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameCtrl.text.trim();
    final design = _designCtrl.text.trim();
    final fee = double.tryParse(_feeCtrl.text.trim()) ?? 0;
    if (name.isEmpty || design.isEmpty || fee <= 0) {
      _snack('Name, designation and fee are required', false);
      return;
    }

    final email = (_profile?.email ?? '').trim();
    if (email.isEmpty) {
      _snack(
          'Email is missing in profile. Please reload and try again.', false);
      return;
    }

    String? normalizeShift(String raw) {
      final t = raw.trim();
      if (t.isEmpty) return null;
      final upper = t.toUpperCase();
      int? hour;
      int? minute;

      final hhmm = RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?$').firstMatch(upper);
      if (hhmm != null) {
        hour = int.tryParse(hhmm.group(1) ?? '');
        minute = int.tryParse(hhmm.group(2) ?? '');
      } else {
        final ampm =
            RegExp(r'^(\d{1,2})(?::(\d{2}))?\s*(AM|PM)$').firstMatch(upper);
        if (ampm != null) {
          hour = int.tryParse(ampm.group(1) ?? '') ?? 0;
          minute = int.tryParse(ampm.group(2) ?? '0') ?? 0;
          final period = ampm.group(3) ?? 'AM';
          if (period == 'PM' && hour != 12) hour += 12;
          if (period == 'AM' && hour == 12) hour = 0;
        }
      }

      if (hour == null || minute == null) return null;
      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
      return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:00';
    }

    final shiftStart = normalizeShift(_shiftStartCtrl.text);
    final shiftEnd = normalizeShift(_shiftEndCtrl.text);
    if (shiftStart == null || shiftEnd == null) {
      _snack('Shift start and end time are required (example: 9:00 AM)', false);
      return;
    }

    final skills = _skillsCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (skills.isEmpty) {
      _snack('At least one skill is required', false);
      return;
    }

    final slotsDuration = _profile?.slotsDuration ?? 60;
    if (slotsDuration <= 0) {
      _snack('Slot duration is invalid. Please refresh and try again.', false);
      return;
    }

    setState(() => _saving = true);
    try {
      final data = {
        'name': name,
        'designation': design,
        'charges': fee,
        'description': _descCtrl.text.trim(),
        'skills': skills,
        'email': email,
        'shiftStartTime': shiftStart,
        'shiftEndTime': shiftEnd,
        'yearsOfExperience': double.tryParse(_expCtrl.text.trim()) ?? 0,
        'slotsDuration': slotsDuration,
      };

      dio_pkg.MultipartFile? photoMultipart;
      if (_photoFile != null) {
        photoMultipart = await dio_pkg.MultipartFile.fromFile(
          _photoFile!.path,
          filename: 'profile_photo.jpg',
        );
      }

      final ok = await _consultantService.updateProfile(
          widget.consultantId, data,
          profilePhoto: photoMultipart);
      if (!mounted) return;
      if (ok) {
        setState(() {
          _editMode = false;
          _saving = false;
          _photoFile = null;
        });
        _snack('Profile saved', true);
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

  void _openOfferForm({Map<String, dynamic>? existing}) {
    final isEdit = existing != null;
    final titleCtrl =
        TextEditingController(text: isEdit ? existing['title'] : '');
    final descCtrl =
        TextEditingController(text: isEdit ? existing['description'] : '');
    final discCtrl =
        TextEditingController(text: isEdit ? existing['discount'] : '');
    final defaultFrom = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final defaultTo = DateFormat('yyyy-MM-dd')
        .format(DateTime.now().add(const Duration(days: 30)));
    final fromCtrl = TextEditingController(
        text: isEdit && existing['validFrom'] != null
            ? existing['validFrom'].toString().substring(0, 10)
            : defaultFrom);
    final toCtrl = TextEditingController(
        text: isEdit && existing['validTo'] != null
            ? existing['validTo'].toString().substring(0, 10)
            : defaultTo);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: SingleChildScrollView(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _handleBar(),
                Text(isEdit ? 'Edit Offer' : 'New Offer',
                    style: AppTextStyles.h3),
                const SizedBox(height: 16),
                _field(titleCtrl, 'Title *', hintText: 'e.g. Summer Special'),
                const SizedBox(height: 12),
                _field(descCtrl, 'Description',
                    hintText: 'What does this offer include?', maxLines: 2),
                const SizedBox(height: 12),
                _field(discCtrl, 'Discount *',
                    hintText: 'e.g. 20% OFF or Rs 500 off'),
                const SizedBox(height: 12),
                // Info about approval
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Row(children: [
                    Icon(Icons.info_outline, size: 16, color: AppColors.info),
                    SizedBox(width: 8),
                    Expanded(
                        child: Text(
                      'Offers are submitted to admin for approval before going live.',
                      style: TextStyle(fontSize: 12, color: AppColors.info),
                    )),
                  ]),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: _field(fromCtrl, 'Valid From *',
                          hintText: 'YYYY-MM-DD', onTap: () async {
                    final d = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365)));
                    if (d != null)
                      fromCtrl.text = DateFormat('yyyy-MM-dd').format(d);
                  })),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _field(toCtrl, 'Valid To *',
                          hintText: 'YYYY-MM-DD', onTap: () async {
                    final d = await showDatePicker(
                        context: ctx,
                        initialDate:
                            DateTime.now().add(const Duration(days: 7)),
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 730)));
                    if (d != null)
                      toCtrl.text = DateFormat('yyyy-MM-dd').format(d);
                  })),
                ]),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      final title = titleCtrl.text.trim();
                      final disc = discCtrl.text.trim();
                      if (title.isEmpty || disc.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                            content: Text('Title and discount are required')));
                        return;
                      }
                      if (fromCtrl.text.trim().isEmpty ||
                          toCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                            content: Text(
                                'Valid From and Valid To dates are required')));
                        return;
                      }
                      final fromDate = DateTime.tryParse(fromCtrl.text.trim());
                      final toDate = DateTime.tryParse(toCtrl.text.trim());
                      if (fromDate == null || toDate == null) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                            content: Text('Please enter valid offer dates')));
                        return;
                      }
                      if (toDate.isBefore(fromDate)) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                            content: Text(
                                'Valid To date cannot be before Valid From')));
                        return;
                      }
                      final payload = <String, dynamic>{
                        'title': title,
                        'description': descCtrl.text.trim(),
                        'discount': disc,
                        'validFrom': '${fromCtrl.text.trim()}T00:00:00',
                        'validTo': '${toCtrl.text.trim()}T23:59:59',
                        'active': existing?['active'] == true ||
                            existing?['isActive'] == true ||
                            !isEdit,
                        'consultantId': widget.consultantId,
                      };
                      final existingId = existing == null
                          ? null
                          : ((existing['id'] as num?)?.toInt() ??
                              int.tryParse(existing['id'].toString()));
                      final saved = await _saveOffer(payload,
                          id: isEdit ? existingId : null);
                      _snack(
                          saved != null
                              ? (isEdit
                                  ? 'Offer updated'
                                  : 'Offer submitted for approval')
                              : 'Save failed',
                          saved != null);
                      if (saved != null && mounted) {
                        Navigator.pop(ctx);
                      }
                      _loadOffers();
                    },
                    child: Text(isEdit ? 'Save Changes' : 'Submit for Approval',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteOffer(Map<String, dynamic> offer) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
              title: const Text('Delete Offer?'),
              content: Text('Delete "${offer['title']}"?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Delete',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ));
    if (ok != true) return;
    final id = offer['id'];
    final deleted =
        await _deleteOffer(id is int ? id : int.tryParse(id.toString()) ?? 0);
    _snack(deleted ? 'Offer deleted' : 'Delete failed', deleted);
    if (deleted) _loadOffers();
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
            const Icon(Icons.person_off_outlined,
                size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(_errorMsg!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 14)),
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
      Expanded(
          child: TabBarView(controller: _tabs, children: [
        RefreshIndicator(
          onRefresh: _loadProfile,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF1E3A5F), AppColors.primaryLight]),
                    borderRadius: BorderRadius.circular(20)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
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
                                    style: const TextStyle(
                                        fontSize: 30,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white))
                                : null,
                            onBackgroundImageError:
                                (_photoUrl != null && _photoUrl!.isNotEmpty)
                                    ? (_, __) {} // silent fallback
                                    : null,
                          ),
                          if (_editMode)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                    color: AppColors.accent,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2)),
                                child: const Icon(Icons.camera_alt_outlined,
                                    size: 14, color: Colors.white),
                              ),
                            ),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      Text(_sanitizeDisplayText(_profile?.name),
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(_sanitizeDisplayText(_profile?.designation),
                          style: const TextStyle(
                              fontSize: 13, color: Colors.white70),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                              5,
                              (i) => Icon(
                                  i < (_profile?.rating ?? 0).round()
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                  color: AppColors.gold,
                                  size: 20))),
                      const SizedBox(height: 12),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10)),
                              child: Text(
                                  '₹${(_profile?.charges ?? 0).toStringAsFixed(0)} / session',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700)),
                            ),
                            const SizedBox(width: 8),
                            // DisplayPrice: charges + 200 (what customer sees)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white24)),
                              child: Text(
                                'Customer sees: ₹${((_profile?.charges ?? 0) + 200).toStringAsFixed(0)}',
                                style: const TextStyle(
                                    color: Colors.white60, fontSize: 11),
                              ),
                            ),
                          ]),
                    ]),
              ),
              const SizedBox(height: 20),

              // Edit/View toggle
              Row(children: [
                const Text('Profile Details',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const Spacer(),
                if (_errorMsg != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Text('Partial load',
                        style:
                            TextStyle(fontSize: 11, color: AppColors.warning)),
                  ),
                TextButton.icon(
                  onPressed: _saving
                      ? null
                      : () => setState(() => _editMode = !_editMode),
                  icon: Icon(_editMode ? Icons.close : Icons.edit_outlined,
                      size: 16),
                  label: Text(_editMode ? 'Cancel' : 'Edit'),
                ),
              ]),
              const SizedBox(height: 12),

              if (!_editMode) ...[
                // View mode
                _infoCard([
                  _infoRow(
                      'Email',
                      _sanitizeDisplayText(_profile?.email,
                          fallback: 'Not provided')),
                  _infoRow('Experience',
                      '${_profile?.experience.toStringAsFixed(0) ?? 0} years'),
                  _infoRow(
                      'Availability',
                      _sanitizeDisplayText(_profile?.shiftTimingsDisplay,
                          fallback: 'Not set')),
                ]),
                if (_profile?.description != null &&
                    _profile!.description!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('About',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border)),
                    child: Text(_sanitizeDisplayText(_profile!.description!),
                        style: AppTextStyles.body
                            .copyWith(color: AppColors.textSecondary)),
                  ),
                ],
                if (_profile!.skills.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Skills',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 6),
                  Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _profile!.skills
                          .map((s) => _sanitizeDisplayText(s))
                          .where((s) => s.isNotEmpty)
                          .map((s) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                    color:
                                        AppColors.accent.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: AppColors.accent
                                            .withValues(alpha: 0.3))),
                                child: Text(s,
                                    style: const TextStyle(
                                        color: AppColors.accent,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12)),
                              ))
                          .toList()),
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
                      const Icon(Icons.check_circle_outline,
                          size: 16, color: AppColors.success),
                      const SizedBox(width: 8),
                      Text(
                          'Photo selected: ${_photoFile!.path.split('/').last}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.success)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(() => _photoFile = null),
                        child: const Icon(Icons.close,
                            size: 16, color: AppColors.textMuted),
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
                _field(_feeCtrl, 'Fee (₹) *',
                    keyboardType: TextInputType.number),
                // Display price hint
                if (_feeCtrl.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Customer sees: ₹${((double.tryParse(_feeCtrl.text) ?? 0) + 200).toStringAsFixed(0)} (fee + ₹200)',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.success),
                    ),
                  ),
                const SizedBox(height: 12),
                // FIXED: Shift times use Flutter's showTimePicker
                Row(children: [
                  Expanded(
                      child: _field(_shiftStartCtrl, 'Shift Start',
                          hintText: 'e.g. 9:00 AM',
                          onTap: () => _pickTime(_shiftStartCtrl))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _field(_shiftEndCtrl, 'Shift End',
                          hintText: 'e.g. 6:00 PM',
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
                _field(_descCtrl, 'Description',
                    maxLines: 4, hintText: 'About yourself'),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _saveProfile,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Save Profile',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
              const SizedBox(height: 32),
            ]),
          ),
        ),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8)),
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
              Expanded(
                  child: Text(
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
                    ? const EmptyState(
                        icon: Icons.local_offer_outlined,
                        title: 'No offers yet',
                        subtitle: 'Create special offers for your clients')
                    : RefreshIndicator(
                        onRefresh: _loadOffers,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _offers.length,
                          itemBuilder: (_, i) {
                            final o = _offers[i] as Map<String, dynamic>;
                            final status =
                                (o['status'] ?? 'PENDING').toString();
                            final isApproved = status == 'APPROVED';
                            final isRejected = status == 'REJECTED';
                            final statusColor = isApproved
                                ? AppColors.success
                                : isRejected
                                    ? AppColors.danger
                                    : AppColors.warning;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Expanded(
                                            child: Text(o['title'] ?? '',
                                                style: AppTextStyles.h4)),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                              color: statusColor.withValues(
                                                  alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                          child: Text(status,
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: statusColor,
                                                  fontWeight: FontWeight.w700)),
                                        ),
                                      ]),
                                      if (o['description'] != null &&
                                          (o['description'] as String)
                                              .isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(o['description'].toString(),
                                            style: AppTextStyles.caption),
                                      ],
                                      const SizedBox(height: 8),
                                      Row(children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                              color: AppColors.success
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                          child: Text(o['discount'] ?? '',
                                              style: const TextStyle(
                                                  color: AppColors.success,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13)),
                                        ),
                                        const Spacer(),
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined,
                                              size: 18,
                                              color: AppColors.textSecondary),
                                          onPressed: () =>
                                              _openOfferForm(existing: o),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                        const SizedBox(width: 12),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline,
                                              size: 18,
                                              color: AppColors.danger),
                                          onPressed: () =>
                                              _confirmDeleteOffer(o),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      ]),
                                      if (o['validFrom'] != null ||
                                          o['validTo'] != null) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                            [
                                              if (o['validFrom'] != null)
                                                'From: ${o['validFrom'].toString().substring(0, 10)}',
                                              if (o['validTo'] != null)
                                                'To: ${o['validTo'].toString().substring(0, 10)}',
                                            ].join('  •  '),
                                            style: AppTextStyles.caption),
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
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border)),
        child: Column(children: rows),
      );

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          SizedBox(
              width: 100, child: Text(label, style: AppTextStyles.caption)),
          Expanded(
              child: Text(value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13))),
        ]),
      );

  Widget _field(TextEditingController ctrl, String label,
      {String? hintText,
      int maxLines = 1,
      TextInputType keyboardType = TextInputType.text,
      VoidCallback? onTap}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      readOnly: onTap != null,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        isDense: true,
        suffixIcon: onTap != null
            ? const Icon(Icons.access_time_rounded, size: 18)
            : null,
      ),
    );
  }
}

// NOTIFICATIONS PANEL (uses real API: GET /api/notifications)

class _NotificationPanel extends StatelessWidget {
  final ScrollController scrollController;
  final VoidCallback onClose;
  const _NotificationPanel(
      {required this.scrollController, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Row(children: [
          _handleBar(),
          const Spacer(),
          const Text('Notifications',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const Spacer(),
          Consumer<NotificationService>(
            builder: (_, svc, __) => TextButton(
              onPressed: svc.unreadCount > 0 ? svc.markAllRead : null,
              child:
                  const Text('Mark all read', style: TextStyle(fontSize: 12)),
            ),
          ),
        ]),
      ),
      const Divider(height: 1),
      Expanded(
        child: Consumer<NotificationService>(
          builder: (_, svc, __) {
            if (svc.isLoading)
              return const Center(child: CircularProgressIndicator());
            if (svc.notifications.isEmpty) {
              return const Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    Icon(Icons.notifications_none_outlined,
                        size: 48, color: AppColors.textMuted),
                    SizedBox(height: 12),
                    Text('No notifications yet',
                        style: TextStyle(color: AppColors.textMuted)),
                    SizedBox(height: 6),
                    Text('New bookings and ticket updates will appear here.',
                        style:
                            TextStyle(color: AppColors.textMuted, fontSize: 12),
                        textAlign: TextAlign.center),
                  ]));
            }
            return RefreshIndicator(
              onRefresh: svc.refresh,
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: svc.notifications.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 56),
                itemBuilder: (_, i) {
                  final n = svc.notifications[i];
                  final color = _notifColor(n);
                  final icon = _notifIcon(n);
                  final subtitle = _notifSubtitle(n);
                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          shape: BoxShape.circle),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    title: Text(
                        n.title.trim().isNotEmpty
                            ? n.title.trim()
                            : 'Notification',
                        style: TextStyle(
                            fontWeight:
                                n.isRead ? FontWeight.w400 : FontWeight.w700,
                            fontSize: 13)),
                    subtitle: subtitle.isNotEmpty
                        ? Text(subtitle,
                            style: const TextStyle(fontSize: 12),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis)
                        : null,
                    trailing: !n.isRead
                        ? Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                                color: AppColors.accent,
                                shape: BoxShape.circle))
                        : null,
                    onTap: () async {
                      if (n.id > 0 && !n.isRead) {
                        await svc.markAsRead(n.id);
                      }
                      if (!context.mounted) return;
                      _openNotificationDetails(context, n, subtitle);
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

Color _notifColor(AppNotification n) {
  final type = n.type.toUpperCase();
  switch (type) {
    case 'SUCCESS':
    case 'TICKET_UPDATED':
      return AppColors.success;
    case 'ERROR':
    case 'ESCALATION':
      return AppColors.danger;
    case 'WARNING':
      return AppColors.warning;
    default:
      return AppColors.info;
  }
}

IconData _notifIcon(AppNotification n) {
  final type = n.type.toUpperCase();
  switch (type) {
    case 'SUCCESS':
    case 'TICKET_UPDATED':
      return Icons.check_circle_outline;
    case 'ERROR':
    case 'ESCALATION':
      return Icons.error_outline;
    case 'NEW_ASSIGNMENT':
      return Icons.assignment_ind_outlined;
    default:
      return Icons.info_outline;
  }
}

String _notifSubtitle(AppNotification n) {
  if (n.body.trim().isNotEmpty) return n.body.trim();
  final data = n.data ?? const <String, dynamic>{};
  for (final key in ['message', 'body', 'content', 'description', 'text']) {
    final val = data[key];
    if (val != null && val.toString().trim().isNotEmpty) {
      return val.toString().trim();
    }
  }
  return '';
}

void _openNotificationDetails(
  BuildContext context,
  AppNotification notification,
  String subtitle,
) {
  final title = notification.title.trim().isNotEmpty
      ? notification.title.trim()
      : 'Notification';
  final message = subtitle.trim().isNotEmpty
      ? subtitle.trim()
      : 'No additional details available.';
  final stamp =
      DateFormat('d MMM, h:mm a').format(notification.createdAt.toLocal());

  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.h3),
          const SizedBox(height: 8),
          Text(stamp, style: AppTextStyles.caption),
          const SizedBox(height: 14),
          Text(message, style: AppTextStyles.body),
        ],
      ),
    ),
  );
}

Widget _handleBar() => Center(
        child: Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
          color: AppColors.border, borderRadius: BorderRadius.circular(2)),
    ));
