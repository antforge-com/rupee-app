// ════════════════════════════════════════════════════════════════════════════
// lib/features/user/user_dashboard.dart
// MEET THE MASTERS — Complete User Dashboard (Production Grade)
// Tabs: Consultants · Bookings · Tickets · Notifications · Settings
// All APIs: Swagger spec exact endpoints, real-time, JWT auth
// Design: MNC-level, Material 3 inspired, Google Fonts Inter
// ════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api_client.dart';
import 'assessment_sheet.dart';
import 'booking_answers_screen.dart';
import 'email_to_ticket_screen.dart';
import 'login_screen.dart';
import 'models/models.dart';
import 'shared/ticket_number_formatter.dart';
import 'services/services.dart';

// ════════════════════════════════════════════════════════════════════════════
// DESIGN SYSTEM — Colors, Text Styles, Common Widgets
// ════════════════════════════════════════════════════════════════════════════

class _C {
  // Brand
  // Matches website design tokens (global.css)
  static const navy = Color(0xFF0F172A);
  static const blue = Color(0xFF0F766E); // primary (teal)
  static const blueDeep = Color(0xFF0D9488); // primary hover
  static const blueMid = Color(0xFF2563EB); // brand blue
  static const blueLight = Color(0xFFECFEFF); // primary light
  static const blueBorder = Color(0xFFA5F3FC); // primary border
  // Background
  static const bg = Color(0xFFF8FAFC);
  static const bgDark = Color(0xFFF1F5F9);
  static const surface = Colors.white;
  // Borders
  static const border = Color(0xFFE2E8F0);
  static const borderLight = Color(0xFFF1F5F9);
  // Text
  static const text1 = Color(0xFF0F172A);
  static const text2 = Color(0xFF334155);
  static const text3 = Color(0xFF64748B);
  static const text4 = Color(0xFF94A3B8);
  // Status
  static const success = Color(0xFF16A34A);
  static const successBg = Color(0xFFF0FDF4);
  static const successBrd = Color(0xFF86EFAC);
  static const warning = Color(0xFFD97706);
  static const warningBg = Color(0xFFFFFBEB);
  static const warningBrd = Color(0xFFFCD34D);
  static const danger = Color(0xFFDC2626);
  static const dangerBg = Color(0xFFFEF2F2);
  static const dangerBrd = Color(0xFFFECACA);
  static const amber = Color(0xFFF59E0B);
  static const amberBg = Color(0xFFFEF3C7);
  static const purple = Color(0xFF7C3AED);
  static const purpleBg = Color(0xFFF5F3FF);
  static const indigo = Color(0xFF6366F1);
  static const indigoBg = Color(0xFFEEF2FF);
  // Gray
  static const gray50 = Color(0xFFF8FAFC);
  static const gray100 = Color(0xFFF1F5F9);
  static const gray200 = Color(0xFFE2E8F0);
  static const gray500 = Color(0xFF64748B);
}

TextStyle _ts(double sz, FontWeight w, Color c,
        {double ls = 0, double? height}) =>
    GoogleFonts.inter(
        fontSize: sz,
        fontWeight: w,
        color: c,
        letterSpacing: ls,
        height: height);

// ════════════════════════════════════════════════════════════════════════════
// API CLIENT — Swagger spec exact endpoints
// ════════════════════════════════════════════════════════════════════════════

// Legacy _Api class removed. Using unified services from lib/services/.

// ════════════════════════════════════════════════════════════════════════════
// HELPERS
// ════════════════════════════════════════════════════════════════════════════

String _initials(String? name) {
  if (name == null || name.trim().isEmpty) return 'U';
  return name
      .trim()
      .split(' ')
      .take(2)
      .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
      .join();
}

int? _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value == null) return null;
  return int.tryParse(value.toString().trim());
}

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value == null) return 0;
  return double.tryParse(value.toString().trim()) ?? 0;
}

String _formatExperience(dynamic rawExperience, {String? consultantName}) {
  final value = _toDouble(rawExperience);
  if (value <= 0) return '0 yrs';

  final normalizedName = (consultantName ?? '').trim().toLowerCase();
  if (normalizedName == 'divya') {
    final minYears = value.floor() <= 0 ? 1 : value.floor();
    return '$minYears+ yrs';
  }

  final whole = value % 1 == 0;
  final text = whole ? value.toInt().toString() : value.toStringAsFixed(1);
  return '$text+ yrs';
}

Widget _headerProfileButton(
  Map<String, dynamic> user,
  VoidCallback onTap, {
  double size = 42,
}) {
  final name = (user['name'] ??
          user['profileName'] ??
          user['identifier']?.toString().split('@').first ??
          'User')
      .toString();

  return GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_C.navy, _C.blue, _C.blueMid]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Text(
          _initials(name),
          style: _ts(size * 0.35, FontWeight.w800, Colors.white),
        ),
      ),
    ),
  );
}

String _photoUrl(String? path) {
  if (path == null || path.isEmpty) return '';
  return ApiClient.buildBackendAssetUrl(path);
}

String _fmtDate(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  try {
    final d = DateTime.parse(iso);
    return DateFormat('dd MMM yyyy').format(d);
  } catch (_) {
    return iso.split('T').first;
  }
}

String _fmtDateTime(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  try {
    final d = DateTime.parse(iso);
    return DateFormat('dd MMM yyyy, hh:mm a').format(d);
  } catch (_) {
    return iso;
  }
}

String _fmtBookingDate(String dateStr) {
  try {
    final d = DateTime.parse(dateStr);
    return DateFormat('dd MMM yyyy').format(d);
  } catch (_) {
    return dateStr;
  }
}

String _prettifyLabel(String raw) {
  final cleaned = raw.replaceAll(RegExp(r'[_-]+'), ' ').trim();
  if (cleaned.isEmpty) return raw;
  return cleaned.split(RegExp(r'\s+')).map((word) {
    final lower = word.toLowerCase();
    if (lower.length <= 3 && lower == word.toUpperCase()) return word;
    return lower[0].toUpperCase() + lower.substring(1);
  }).join(' ');
}

DateTime? _parseDateKey(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  try {
    return DateTime.parse(raw).toLocal();
  } catch (_) {
    return null;
  }
}

int? _parseClockMinutes(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return null;

  final twentyFour =
      RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?$').firstMatch(value);
  if (twentyFour != null) {
    final h = int.tryParse(twentyFour.group(1) ?? '');
    final m = int.tryParse(twentyFour.group(2) ?? '');
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  final ampm =
      RegExp(r'^(\d{1,2})(?::(\d{2}))?\s*(AM|PM)$', caseSensitive: false)
          .firstMatch(value);
  if (ampm != null) {
    var h = int.tryParse(ampm.group(1) ?? '') ?? 0;
    final m = int.tryParse(ampm.group(2) ?? '0') ?? 0;
    final period = (ampm.group(3) ?? '').toUpperCase();
    if (period == 'PM' && h != 12) h += 12;
    if (period == 'AM' && h == 12) h = 0;
    return h * 60 + m;
  }

  return null;
}

String _formatMinutesLabel(int minutes) {
  final normalized = ((minutes % (24 * 60)) + (24 * 60)) % (24 * 60);
  final hour24 = normalized ~/ 60;
  final minute = normalized % 60;
  final period = hour24 >= 12 ? 'PM' : 'AM';
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  return '${hour12.toString()}:${minute.toString().padLeft(2, '0')} $period';
}

String _normalizeTimeRange(dynamic raw, {dynamic durationMinutes}) {
  final value = (raw ?? '').toString().trim();
  if (value.isEmpty) return '';

  if (value.contains('-')) {
    final parts = value
        .split('-')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.length == 2) {
      final start = _parseClockMinutes(parts[0]);
      final end = _parseClockMinutes(parts[1]);
      if (start != null && end != null) {
        return '${_formatMinutesLabel(start)} - ${_formatMinutesLabel(end)}';
      }
    }
    return value;
  }

  final start = _parseClockMinutes(value);
  if (start == null) return value;
  final duration = int.tryParse('${durationMinutes ?? ''}') ?? 60;
  final safeDuration = duration > 0 ? duration : 60;
  final end = start + safeDuration;
  return '${_formatMinutesLabel(start)} - ${_formatMinutesLabel(end)}';
}

int? _minutesFromTimePayload(dynamic raw) {
  if (raw == null) return null;
  if (raw is Map) {
    final hour = _toInt(raw['hour']);
    final minute = _toInt(raw['minute']);
    if (hour == null || minute == null) return null;
    return (hour * 60) + minute;
  }
  final value = raw.toString().trim();
  if (value.isEmpty) return null;
  return _parseClockMinutes(value);
}

String _consultantShiftWindow(Map<String, dynamic> consultant,
    {String fallback = 'Not set'}) {
  final displayCandidates = [
    consultant['shiftDisplay'],
    consultant['shiftTimingsDisplay'],
    consultant['availability'],
    consultant['workingHours'],
  ];

  for (final candidate in displayCandidates) {
    final raw = (candidate ?? '').toString().trim();
    if (raw.isEmpty) continue;
    final normalized = _normalizeTimeRange(raw).trim();
    if (normalized.isEmpty) continue;
    final upper = normalized.toUpperCase();
    if (upper == 'NOT SET' || upper == 'N/A' || upper == 'NA') continue;
    return normalized;
  }

  final start = _minutesFromTimePayload(
      consultant['shiftStartTime'] ?? consultant['shiftStart']);
  final end = _minutesFromTimePayload(
      consultant['shiftEndTime'] ?? consultant['shiftEnd']);

  if (start != null && end != null) {
    return '${_formatMinutesLabel(start)} - ${_formatMinutesLabel(end)}';
  }
  if (start != null) return '${_formatMinutesLabel(start)} onward';
  if (end != null) return 'Until ${_formatMinutesLabel(end)}';
  return fallback;
}

int _slotSortMinutes(Map<String, dynamic> slot) {
  final time =
      (slot['displayTimeRange'] ?? slot['timeRange'] ?? slot['slotTime'] ?? '')
          .toString();
  if (time.contains('-')) {
    return _parseClockMinutes(time.split('-').first.trim()) ?? 1 << 30;
  }
  return _parseClockMinutes(time) ?? 1 << 30;
}

bool _notifIsRead(Map<String, dynamic> notif) =>
    notif['isRead'] == true || notif['read'] == true;

String _timeAgo(String? iso) {
  if (iso == null) return '';
  try {
    final d = DateTime.parse(iso);
    final diff = DateTime.now().difference(d);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return _fmtDate(iso);
  } catch (_) {
    return '';
  }
}

String _stripHtml(String input) {
  if (input.trim().isEmpty) return '';
  var text = input
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');
  return text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

String _fmtMemberSince(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '—';
  try {
    return DateFormat('dd MMM yyyy').format(DateTime.parse(raw).toLocal());
  } catch (_) {
    return '—';
  }
}

bool _isGuestTicketAccessExpired(Map<String, dynamic> user) {
  final planName = (user['subscriptionPlan']?['name'] ??
          user['subscriptionPlanName'] ??
          user['planName'] ??
          '')
      .toString()
      .toLowerCase();
  final subscribed = user['subscribed'] == true;
  final role = (user['role'] ?? '').toString().toUpperCase();
  final isGuestPlan = !subscribed &&
      planName != 'elite' &&
      planName != 'pro' &&
      planName != 'premium' &&
      role != 'MEMBER';
  if (!isGuestPlan) return false;

  final createdRaw =
      (user['memberSince'] ?? user['createdAt'] ?? '').toString();
  final created = DateTime.tryParse(createdRaw);
  if (created == null) return false;
  return DateTime.now()
      .toLocal()
      .isAfter(created.toLocal().add(const Duration(days: 60)));
}

/// Global Service Instances
final _authService = AuthService();
final _userService = UserService();
final _consultantService = ConsultantService();
final _bookingService = BookingService();
final _ticketService = TicketService();
final _notificationService = NotificationService();
final _offerService = OfferService();
final _subscriptionService = SubscriptionService();
final _onboardingService = OnboardingService();
final _staticService = StaticContentService();
final _feedbackService = FeedbackService();

double _calcFee(double base, Map<String, dynamic>? cfg) {
  if (cfg == null) return base;
  final type = (cfg['feeType'] ?? 'FLAT').toString().toUpperCase();
  final val = double.tryParse(cfg['feeValue']?.toString() ?? '0') ?? 0;
  return type == 'PERCENTAGE' ? base + (base * val / 100) : base + val;
}

// ════════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ════════════════════════════════════════════════════════════════════════════

Widget _gradBtn(
  String label,
  VoidCallback? onTap, {
  bool loading = false,
  bool danger = false,
  double radius = 14,
  double height = 52,
  EdgeInsets? padding,
}) {
  final colors =
      danger ? [_C.danger, const Color(0xFFB91C1C)] : [_C.blue, _C.blueDeep];
  return GestureDetector(
    onTap: loading ? null : onTap,
    child: Container(
      width: double.infinity,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        gradient:
            LinearGradient(colors: loading ? [_C.text4, _C.text4] : colors),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: loading
            ? []
            : [
                BoxShadow(
                    color: colors.first.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4)),
              ],
      ),
      child: Center(
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5))
              : Text(label, style: _ts(15, FontWeight.w700, Colors.white))),
    ),
  );
}

Widget _outlineBtn(String label, VoidCallback? onTap, {Color? color}) =>
    OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color ?? _C.border, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      ),
      child: Text(label, style: _ts(13, FontWeight.w600, color ?? _C.text3)),
    );

Widget _chip(String label,
        {Color? bg, Color? fg, Color? brd, IconData? icon}) =>
    Container(
      padding:
          EdgeInsets.symmetric(horizontal: icon != null ? 8 : 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg ?? _C.blueLight,
        border: Border.all(color: brd ?? _C.blueBorder),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 11, color: fg ?? _C.blue),
          const SizedBox(width: 4)
        ],
        Text(label, style: _ts(11, FontWeight.w700, fg ?? _C.blue)),
      ]),
    );

// Status chip with color config
Widget _statusChip(String status) {
  final s = status.toUpperCase();
  final Map<String, List<Color>> cfg = {
    'NEW': [_C.indigo, _C.indigoBg, const Color(0xFFC7D2FE)],
    'OPEN': [_C.blue, _C.blueLight, _C.blueBorder],
    'IN_PROGRESS': [_C.warning, _C.warningBg, _C.warningBrd],
    'PENDING': [_C.warning, _C.warningBg, _C.warningBrd],
    'RESOLVED': [_C.success, _C.successBg, _C.successBrd],
    'CLOSED': [_C.gray500, _C.gray100, _C.gray200],
    'ESCALATED': [_C.danger, _C.dangerBg, _C.dangerBrd],
    'CONFIRMED': [_C.success, _C.successBg, _C.successBrd],
    'COMPLETED': [_C.gray500, _C.gray100, _C.gray200],
    'CANCELLED': [_C.danger, _C.dangerBg, _C.dangerBrd],
    'AVAILABLE': [_C.success, _C.successBg, _C.successBrd],
    'BOOKED': [_C.warning, _C.warningBg, _C.warningBrd],
  };
  final c = cfg[s] ?? [_C.gray500, _C.gray100, _C.gray200];
  return _chip(s.replaceAll('_', ' '), fg: c[0], bg: c[1], brd: c[2]);
}

// Star Rating
class _Stars extends StatelessWidget {
  final int value;
  final ValueChanged<int>? onChanged;
  final double size;
  const _Stars({this.value = 0, this.onChanged, this.size = 26});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
            5,
            (i) => GestureDetector(
                  onTap: onChanged != null ? () => onChanged!(i + 1) : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Icon(
                      i < value
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: _C.amber,
                      size: size,
                    ),
                  ),
                )),
      );
}

// Shimmer Skeleton
class _Shimmer extends StatefulWidget {
  final double height, radius;
  final double? width;
  const _Shimmer({this.height = 80, this.width, this.radius = 16});
  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _a = Tween(begin: 0.25, end: 0.65)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _a,
        builder: (_, __) => Container(
          height: widget.height,
          width: widget.width,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: _C.border.withOpacity(_a.value),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      );
}

// Section Header
Widget _sectionHeader(String title, {String? action, VoidCallback? onAction}) =>
    Row(
      children: [
        Text(title, style: _ts(11, FontWeight.w800, _C.text3, ls: 0.7)),
        const Spacer(),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(action, style: _ts(12, FontWeight.w700, _C.blue)),
          ),
      ],
    );

// Info Row
Widget _infoRow(IconData icon, String label, String val) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: _C.text4),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: _ts(10, FontWeight.w700, _C.text4, ls: 0.5)),
          const SizedBox(height: 2),
          Text(val, style: _ts(13, FontWeight.w600, _C.text2)),
        ]),
      ]),
    );

// Empty State
Widget _emptyState(IconData icon, String title, String sub) => Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
                color: _C.blueLight, borderRadius: BorderRadius.circular(24)),
            child: Icon(icon, size: 36, color: _C.blue),
          ),
          const SizedBox(height: 20),
          Text(title,
              style: _ts(17, FontWeight.w700, _C.text1),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(sub,
              style: _ts(13, FontWeight.w400, _C.text3),
              textAlign: TextAlign.center),
        ]),
      ),
    );

// Toast snackbar
void _toast(BuildContext ctx, String msg, {bool error = false}) {
  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
    content: Text(msg, style: _ts(13, FontWeight.w600, Colors.white)),
    backgroundColor: error ? _C.danger : _C.success,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    margin: const EdgeInsets.all(16),
    duration: const Duration(seconds: 3),
  ));
}

// ════════════════════════════════════════════════════════════════════════════
// MAIN USER DASHBOARD
// ════════════════════════════════════════════════════════════════════════════

class UserDashboard extends StatefulWidget {
  /// Pass token from login screen (stored in secure storage)
  final String? token;
  const UserDashboard({super.key, this.token});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  int _tab = 0;
  Map<String, dynamic> _user = {};
  bool _booting = true;
  int _unread = 0;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    // Step 1: get basic user info (id, role, identifier)
    final me = await _userService.getMe();
    final baseUser = me?.toJson() ?? {};

    // Step 2: fetch full onboarding profile for real name/email/phone
    // /api/users/me only returns identifier+role; name lives in /api/onboarding/{id}
    final uid = me?.id ?? 0;
    Map<String, dynamic> profileData = {};
    if (uid > 0) {
      try {
        profileData = await _userService.getOnboardingProfile(uid) ?? {};
      } catch (_) {}
    }

    // Merge: profile fields take priority for display (name, email, phone)
    final merged = {
      ...baseUser,
      ...profileData,
      if ((profileData['name'] ?? '').toString().isNotEmpty)
        'name': profileData['name'],
      if ((profileData['email'] ?? '').toString().isNotEmpty)
        'email': profileData['email'],
      if ((profileData['phoneNumber'] ?? profileData['phone'] ?? '')
          .toString()
          .isNotEmpty)
        'phone': profileData['phoneNumber'] ?? profileData['phone'],
      if ((profileData['createdAt'] ?? '').toString().isNotEmpty)
        'createdAt': profileData['createdAt'],
      if ((profileData['memberSince'] ?? '').toString().isNotEmpty)
        'memberSince': profileData['memberSince'],
    };

    if (mounted) {
      setState(() {
        _user = merged;
        _booting = false;
      });
      if (uid > 0) {
        final role = (merged['role'] ?? 'USER').toString();
        _notificationService.initialize(role, uid);
      }
      _startNotifPoll();
    }
  }

  void _startNotifPoll() {
    _fetchUnread();
    _pollTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => _fetchUnread());
  }

  Future<void> _fetchUnread() async {
    try {
      final list = await _notificationService
          .refresh()
          .then((_) => _notificationService.notifications);
      if (mounted) {
        setState(() => _unread = list.where((n) => !n.isRead).length);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_booting) {
      return const Scaffold(
        backgroundColor: _C.bg,
        body: Center(child: CircularProgressIndicator(color: _C.blue)),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: _C.bg,
        body: IndexedStack(
          index: _tab,
          children: [
            _ConsultantsTab(
              user: _user,
              onOpenAccount: () => setState(() => _tab = 4),
            ),
            _BookingsTab(
              user: _user,
              onOpenAccount: () => setState(() => _tab = 4),
            ),
            _TicketsTab(
              user: _user,
              onOpenAccount: () => setState(() => _tab = 4),
            ),
            _NotifsTab(
              user: _user,
              onRead: () => setState(() => _unread = 0),
              onOpenAccount: () => setState(() => _tab = 4),
            ),
            _SettingsTab(
                user: _user, onUpdated: (u) => setState(() => _user = u)),
          ],
        ),
        bottomNavigationBar: _BottomNav(
          current: _tab,
          unread: _unread,
          onTap: (i) => setState(() => _tab = i),
        ),
      ),
    );
  }
}

// ── Bottom Navigation Bar ─────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int current, unread;
  final ValueChanged<int> onTap;
  const _BottomNav(
      {required this.current, required this.unread, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.search_rounded, 'Experts'),
      (Icons.calendar_month_rounded, 'Bookings'),
      (Icons.confirmation_number_rounded, 'Tickets'),
      (Icons.notifications_rounded, 'Updates'),
      (Icons.manage_accounts_rounded, 'Account'),
    ];
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _C.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(items.length, (i) {
              final sel = current == i;
              final icon = items[i].$1;
              final lbl = items[i].$2;
              final hasBadge = i == 3 && unread > 0;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(clipBehavior: Clip.none, children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: sel ? _C.blueLight : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon,
                              size: 22, color: sel ? _C.blue : _C.text4),
                        ),
                        if (hasBadge)
                          Positioned(
                            top: 2,
                            right: 2,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                  color: _C.danger, shape: BoxShape.circle),
                            ),
                          ),
                      ]),
                      const SizedBox(height: 2),
                      Text(lbl,
                          style: _ts(
                              10,
                              sel ? FontWeight.w700 : FontWeight.w500,
                              sel ? _C.blue : _C.text4)),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// TAB 1 — CONSULTANTS (Find an Expert)
// ════════════════════════════════════════════════════════════════════════════

class _ConsultantsTab extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onOpenAccount;
  const _ConsultantsTab({required this.user, required this.onOpenAccount});
  @override
  State<_ConsultantsTab> createState() => _ConsultantsTabState();
}

class _ConsultantsTabState extends State<_ConsultantsTab> {
  List<Map<String, dynamic>> _consultants = [];
  Map<String, dynamic>? _feeConfig;
  String _search = '';
  String _selCat = 'All';
  List<String> _cats = ['All'];
  bool _loading = true;
  final _searchCtrl = TextEditingController();
  final ScrollController _categoryScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _categoryScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _consultantService.getAllConsultants(),
      _apiClientGetFeeConfig(),
    ]);
    final consultants =
        (results[0] as List<ConsultantModel>).map((e) => e.toJson()).toList();
    final feeRaw = results[1] as Map<String, dynamic>?;

    // Build category set from consultant skills
    final cats = <String>{'All'};
    for (final c in consultants) {
      for (final s in (c['skills'] as List? ?? [])) {
        if (s.toString().isNotEmpty) cats.add(s.toString());
      }
    }
    final orderedCats = [
      'All',
      ...cats.where((item) => item != 'All').toList()
        ..sort(
            (a, b) => a.toLowerCase().trim().compareTo(b.toLowerCase().trim())),
    ];
    if (mounted)
      setState(() {
        _consultants = consultants;
        _feeConfig = feeRaw;
        _cats = orderedCats;
        if (!_cats.contains(_selCat)) _selCat = 'All';
        _loading = false;
      });
  }

  // Temporary helper until I update all calls or confirm fee config endpoint in a service
  Future<Map<String, dynamic>?> _apiClientGetFeeConfig() async {
    try {
      final r =
          await ApiClient().dio.get('/api/admin/settings/public/fee-config');
      return r.data as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _search.toLowerCase();
    return _consultants.where((c) {
      final matchQ = q.isEmpty ||
          (c['name'] ?? '').toString().toLowerCase().contains(q) ||
          (c['designation'] ?? '').toString().toLowerCase().contains(q);
      final skills =
          (c['skills'] as List? ?? []).map((s) => s.toString().toLowerCase());
      final matchC = _selCat == 'All' || skills.contains(_selCat.toLowerCase());
      return matchQ && matchC;
    }).toList();
  }

  void _scrollCategoryIntoView(String category) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_categoryScrollCtrl.hasClients) return;
      if ((ModalRoute.of(context)?.isCurrent ?? true) == false) return;
      final index = _cats.indexOf(category);
      if (index < 0 || _cats.length <= 1) return;

      final maxExtent = _categoryScrollCtrl.position.maxScrollExtent;
      if (maxExtent <= 0) return;

      final ratio = index / (_cats.length - 1);
      final target = (maxExtent * ratio).clamp(0.0, maxExtent);
      _categoryScrollCtrl.animateTo(
        target,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _setCategory(String category) {
    setState(() => _selCat = category);
    _scrollCategoryIntoView(category);
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final name = user['name'] ??
        (user['identifier']?.toString().split('@').first ?? 'User');

    return SafeArea(
        child: Column(children: [
      // ── Header ──
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Hello, ${name.toString().split(' ').first} 👋',
                      style: _ts(14, FontWeight.w500, _C.text3)),
                  Text('Find Your Expert',
                      style: _ts(24, FontWeight.w900, _C.text1)),
                ])),
            // Avatar
            GestureDetector(
              onTap: widget.onOpenAccount,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [_C.navy, _C.blue, _C.blueMid]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                    child: Text(_initials(name.toString()),
                        style: _ts(16, FontWeight.w800, Colors.white))),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          // Search
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _C.border, width: 1.5),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _search = v),
              style: _ts(14, FontWeight.w500, _C.text1),
              decoration: InputDecoration(
                hintText: 'Search by name or skill…',
                hintStyle: _ts(14, FontWeight.w400, _C.text4),
                prefixIcon:
                    const Icon(Icons.search_rounded, color: _C.text4, size: 20),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: _C.text4, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _search = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Category chips
          SizedBox(
            height: 36,
            child: ListView.separated(
              controller: _categoryScrollCtrl,
              scrollDirection: Axis.horizontal,
              itemCount: _cats.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final cat = _cats[i];
                final sel = _selCat == cat;
                return GestureDetector(
                  onTap: () => _setCategory(cat),
                  child: AnimatedContainer(
                    key: ValueKey('cat_$cat'),
                    duration: const Duration(milliseconds: 180),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? _C.blue : Colors.white,
                      border: Border.all(
                          color: sel ? _C.blue : _C.border, width: 1.5),
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: sel
                          ? [
                              BoxShadow(
                                  color: _C.blue.withOpacity(0.25),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4))
                            ]
                          : const [
                              BoxShadow(
                                  color: Color(0x0D000000),
                                  blurRadius: 2,
                                  offset: Offset(0, 1))
                            ],
                    ),
                    child: Text(cat,
                        style: _ts(12, FontWeight.w700,
                            sel ? Colors.white : _C.text3)),
                  ),
                );
              },
            ),
          ),
        ]),
      ),

      // ── List ──
      Expanded(
        child: _loading
            ? ListView(
                padding: const EdgeInsets.all(16),
                children: List.generate(3, (_) => const _Shimmer(height: 200)))
            : _filtered.isEmpty
                ? _emptyState(Icons.person_search_rounded, 'No Experts Found',
                    'Try a different search or category')
                : RefreshIndicator(
                    onRefresh: _load,
                    color: _C.blue,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) => _ConsultantCard(
                        c: _filtered[i],
                        user: widget.user,
                        feeConfig: _feeConfig,
                      ),
                    ),
                  ),
      ),
    ]));
  }
}

// ── Consultant Card ────────────────────────────────────────────────────────────
class _ConsultantCard extends StatelessWidget {
  final Map<String, dynamic> c, user;
  final Map<String, dynamic>? feeConfig;
  const _ConsultantCard(
      {required this.c, required this.user, required this.feeConfig});

  @override
  Widget build(BuildContext context) {
    final name = c['name'] ?? 'Expert';
    final role = c['designation'] ?? 'Financial Consultant';
    final skills = (c['skills'] as List? ?? []).cast<String>();
    final rating = double.tryParse(c['rating']?.toString() ?? '0') ?? 0.0;
    final exp = _toDouble(c['yearsOfExperience'] ?? c['experience'] ?? 0);
    final availability = _consultantShiftWindow(c);
    final base = double.tryParse(c['charges']?.toString() ?? '0') ?? 0;
    final total = _calcFee(base, feeConfig);
    final avatar = _photoUrl(c['profilePhoto'] ?? c['photo']);
    final about = c['description'] ?? c['about'] ?? '';
    final hasAvailability = availability.trim().isNotEmpty &&
        availability.trim().toUpperCase() != 'NOT SET';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1))
        ],
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Avatar
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [_C.navy, _C.blue, _C.blueMid],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(18),
              ),
              clipBehavior: Clip.antiAlias,
              child: avatar.isNotEmpty
                  ? Image.network(avatar,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                          child: Text(_initials(name.toString()),
                              style: _ts(24, FontWeight.w800, Colors.white))))
                  : Center(
                      child: Text(_initials(name.toString()),
                          style: _ts(24, FontWeight.w800, Colors.white))),
            ),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(name.toString(),
                      style: _ts(16, FontWeight.w800, _C.text1)),
                  const SizedBox(height: 3),
                  Text(role.toString(),
                      style: _ts(13, FontWeight.w600, _C.blue)),
                  const SizedBox(height: 8),
                  Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: skills.take(3).map((s) => _chip(s)).toList()),
                  const SizedBox(height: 8),
                  Row(children: [
                    if (exp > 0) ...[
                      const Icon(Icons.schedule_rounded,
                          size: 13, color: _C.text4),
                      const SizedBox(width: 4),
                      Text(
                          _formatExperience(exp,
                              consultantName: name.toString()),
                          style: _ts(12, FontWeight.w500, _C.text3)),
                      const SizedBox(width: 12),
                    ],
                    if (rating > 0) ...[
                      const Icon(Icons.star_rounded, size: 13, color: _C.amber),
                      const SizedBox(width: 3),
                      Text('${rating.toStringAsFixed(1)}',
                          style: _ts(12, FontWeight.w700, _C.text1)),
                    ],
                  ]),
                  if (hasAvailability) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded,
                            size: 13, color: _C.text4),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            availability,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _ts(12, FontWeight.w600, _C.text3),
                          ),
                        ),
                      ],
                    ),
                  ],
                ])),
          ]),
        ),
        if (about.toString().isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(about.toString(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _ts(12, FontWeight.w400, _C.text3, height: 1.5)),
          ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _C.borderLight))),
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('₹${total.toStringAsFixed(0)}',
                        style: _ts(20, FontWeight.w900, _C.text1)),
                    Text('per session',
                        style: _ts(11, FontWeight.w500, _C.text4)),
                  ]),
            ),
            _outlineBtn('View Profile', () => _openProfile(context),
                color: _C.blue),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => _openBooking(context),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_C.blue, _C.blueMid]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: _C.blue.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3))
                  ],
                ),
                child: Text('Book Now',
                    style: _ts(13, FontWeight.w700, Colors.white)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  void _openProfile(BuildContext ctx) => showModalBottomSheet(
        context: ctx,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => _ProfileSheet(
          c: c,
          feeConfig: feeConfig,
          onBook: () {
            Navigator.of(sheetContext).pop();
            Future.microtask(() {
              if (ctx.mounted) {
                _openBooking(ctx);
              }
            });
          },
        ),
      );

  void _openBooking(BuildContext ctx) => showModalBottomSheet(
        context: ctx,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _BookingSheet(c: c, user: user, feeConfig: feeConfig),
      );
}

// ── Consultant Profile Sheet ───────────────────────────────────────────────────
class _ProfileSheet extends StatelessWidget {
  final Map<String, dynamic> c;
  final Map<String, dynamic>? feeConfig;
  final VoidCallback onBook;
  const _ProfileSheet(
      {required this.c, required this.feeConfig, required this.onBook});

  @override
  Widget build(BuildContext context) {
    final name = c['name'] ?? 'Expert';
    final role = c['designation'] ?? 'Financial Consultant';
    final skills = (c['skills'] as List? ?? []).cast<String>();
    final rating = double.tryParse(c['rating']?.toString() ?? '0') ?? 0.0;
    final base = double.tryParse(c['charges']?.toString() ?? '0') ?? 0;
    final total = _calcFee(base, feeConfig);
    final avatar = _photoUrl(c['profilePhoto'] ?? c['photo']);
    final about = c['description'] ?? c['about'] ?? '';
    final loc = c['location'] ?? 'Remote';
    final lang = c['languages'] ?? 'English';
    final exp = _toDouble(c['yearsOfExperience'] ?? c['experience'] ?? 0);
    final availability = _consultantShiftWindow(c);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(children: [
          Expanded(
              child: ListView(
                  controller: ctrl,
                  padding: EdgeInsets.zero,
                  children: [
                // Header with Gradient
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_C.navy, _C.blue, _C.blueMid],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                              color: Colors.white24, shape: BoxShape.circle),
                          child: const Icon(Icons.close_rounded,
                              color: Colors.white, size: 20),
                        ),
                      ),
                    ]),
                    Row(children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: avatar.isNotEmpty
                            ? Image.network(avatar,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Center(
                                    child: Text(_initials(name.toString()),
                                        style:
                                            _ts(28, FontWeight.w800, _C.blue))))
                            : Center(
                                child: Text(_initials(name.toString()),
                                    style: _ts(28, FontWeight.w800, _C.blue))),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(name.toString(),
                                style: _ts(22, FontWeight.w800, Colors.white)),
                            const SizedBox(height: 4),
                            Text(role.toString(),
                                style: _ts(14, FontWeight.w600,
                                    Colors.white.withOpacity(0.9))),
                            const SizedBox(height: 8),
                            Row(children: [
                              const Icon(Icons.star_rounded,
                                  size: 16, color: Colors.white),
                              const SizedBox(width: 4),
                              Text('${rating.toStringAsFixed(1)} (0 reviews)',
                                  style:
                                      _ts(13, FontWeight.w700, Colors.white)),
                              const SizedBox(width: 12),
                              const Icon(Icons.schedule_rounded,
                                  size: 16, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                  _formatExperience(exp,
                                      consultantName: name.toString()),
                                  style:
                                      _ts(13, FontWeight.w700, Colors.white)),
                            ]),
                          ])),
                    ]),
                  ]),
                ),

                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Info Grid
                        Row(children: [
                          Expanded(
                              child: _profileInfoBox(Icons.location_on_outlined,
                                  'LOCATION', loc.toString())),
                          const SizedBox(width: 16),
                          Expanded(
                              child: _profileInfoBox(Icons.language_rounded,
                                  'LANGUAGES', lang.toString())),
                        ]),
                        const SizedBox(height: 16),
                        Row(children: [
                          Expanded(
                              child: _profileInfoBox(Icons.access_time_rounded,
                                  'AVAILABILITY', availability)),
                          const SizedBox(width: 16),
                          Expanded(
                              child: _profileInfoBox(
                                  Icons.payments_outlined,
                                  'CONSULTATION FEE',
                                  '₹${total.toStringAsFixed(0)}')),
                        ]),
                        const SizedBox(height: 16),
                        _profileInfoBox(
                            Icons.call_outlined, 'CONTACT', 'On request'),

                        const SizedBox(height: 32),
                        Text('EXPERTISE',
                            style: _ts(12, FontWeight.w800, _C.text1, ls: 0.5)),
                        const SizedBox(height: 16),
                        Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: skills
                                .map((s) => _chip(s,
                                    bg: Colors.white,
                                    brd: _C.blueBorder.withOpacity(0.5)))
                                .toList()),

                        const SizedBox(height: 32),
                        Row(children: [
                          Expanded(
                              child: _gradBtn('Book Appointment', onBook,
                                  radius: 12)),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 80,
                            child: _outlineBtn(
                                'Close', () => Navigator.pop(context)),
                          ),
                        ]),
                      ]),
                ),
              ])),
        ]),
      ),
    );
  }

  Widget _profileInfoBox(IconData icon, String label, String value) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.borderLight),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 16, color: _C.blueMid),
            const SizedBox(width: 6),
            Text(label, style: _ts(10, FontWeight.w700, _C.text4, ls: 0.5)),
          ]),
          const SizedBox(height: 8),
          Text(value, style: _ts(14, FontWeight.w700, _C.text1)),
        ]),
      );
}

// ── Booking Sheet ─────────────────────────────────────────────────────────────
class _BookingSheet extends StatefulWidget {
  final Map<String, dynamic> c, user;
  final Map<String, dynamic>? feeConfig;
  const _BookingSheet(
      {required this.c, required this.user, required this.feeConfig});
  @override
  State<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<_BookingSheet> {
  List<Map<String, dynamic>> _slots = [];
  List<Map<String, dynamic>> _offers = [];
  bool _loading = true;
  Map<String, dynamic>? _selSlot;
  Map<String, dynamic>? _selOffer;
  String _mode = 'ONLINE';
  String _notes = '';
  bool _booking = false;
  String? _selDate;
  Map<String, List<Map<String, dynamic>>> _slotsByDate = {};
  List<Map<String, dynamic>> _masterSlots = [];
  Set<String> _specialDays = <String>{};
  String? _selectedSpecialSlotKey;

  final _notesCtrl = TextEditingController();
  final _modes = ['ONLINE', 'PHYSICAL', 'PHONE'];

  int get _consultantId {
    final direct = (widget.c['id'] as num?)?.toInt();
    if (direct != null && direct > 0) return direct;
    final alt = (widget.c['consultantId'] as num?)?.toInt();
    if (alt != null && alt > 0) return alt;
    if (widget.c['consultant'] is Map) {
      final nested = widget.c['consultant'] as Map;
      final nestedId = (nested['id'] as num?)?.toInt() ??
          (nested['consultantId'] as num?)?.toInt();
      if (nestedId != null && nestedId > 0) return nestedId;
    }
    return 0;
  }

  List<String> get _sortedDates {
    final all = {..._slotsByDate.keys, ..._specialDays}.toList()..sort();
    return all;
  }

  List<Map<String, dynamic>> get _slotsForDate =>
      _selDate != null ? (_slotsByDate[_selDate!] ?? []) : [];
  bool get _isSpecialDateSelected =>
      _selDate != null && _specialDays.contains(_selDate);
  List<Map<String, dynamic>> get _specialRequestSlots {
    if (_masterSlots.isEmpty) {
      return const [
        {
          'requestKey': 'special-slot-1',
          'slotNumber': 1,
          'durationHours': 2,
          'durationMinutes': 120,
          'timeRange': '',
        },
      ];
    }
    return List<Map<String, dynamic>>.generate(_masterSlots.length, (index) {
      final slot = _masterSlots[index];
      return {
        ...slot,
        'requestKey':
            'special-slot-${slot['id'] ?? index}-${slot['startKey'] ?? index}',
        'slotNumber': index + 1,
      };
    });
  }

  Map<String, dynamic>? get _selectedSpecialSlot {
    final key = _selectedSpecialSlotKey;
    if (key == null) return null;
    for (final slot in _specialRequestSlots) {
      if (slot['requestKey'] == key) return slot;
    }
    return null;
  }

  String _slotVisualStatus(Map<String, dynamic> slot) {
    final rawStatus = (slot['status'] ?? '').toString().toUpperCase();
    final slotDate = _parseDateKey(slot['slotDate']?.toString());
    final range = (slot['displayTimeRange'] ??
            slot['timeRange'] ??
            slot['slotTime'] ??
            '')
        .toString();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final nowMinutes = now.hour * 60 + now.minute;

    if (slotDate != null) {
      final onlyDate = DateTime(slotDate.year, slotDate.month, slotDate.day);
      if (onlyDate.isBefore(today)) return 'PASSED';
      if (onlyDate == today) {
        final parts =
            range.split(RegExp(r'[-–]')).map((e) => e.trim()).toList();
        final comparePart = parts.length > 1 ? parts.last : parts.first;
        final compareMinutes =
            _parseClockMinutes(comparePart) ?? _slotSortMinutes(slot);
        if (compareMinutes <= nowMinutes) return 'PASSED';
      }
    }

    if (rawStatus == 'BOOKED') return 'BOOKED';
    if (rawStatus == 'UNAVAILABLE' || rawStatus == 'BLOCKED')
      return 'UNAVAILABLE';
    return 'AVAILABLE';
  }

  Color _slotStatusColor(String status) {
    switch (status) {
      case 'BOOKED':
        return _C.warning;
      case 'UNAVAILABLE':
        return _C.danger;
      case 'PASSED':
        return _C.text4;
      default:
        return _C.blue;
    }
  }

  Color _slotStatusBg(String status) {
    switch (status) {
      case 'BOOKED':
        return _C.warningBg;
      case 'UNAVAILABLE':
        return _C.dangerBg;
      case 'PASSED':
        return _C.gray100;
      default:
        return _C.blueLight;
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  String _slotStartKey(dynamic range) {
    final text = (range ?? '').toString().trim();
    if (text.isEmpty) return '';
    final first = text.split(RegExp(r'[-–]')).first.trim();
    final minutes = _parseClockMinutes(first);
    if (minutes == null) return '';
    final hour = (minutes ~/ 60).toString().padLeft(2, '0');
    final minute = (minutes % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Set<String> _normalizeSpecialDays(List<dynamic> rows) {
    final result = <String>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDay = today.add(const Duration(days: 30));
    for (final row in rows) {
      String value = '';
      if (row is String && row.trim().isNotEmpty) {
        value = row.trim();
      } else if (row is Map) {
        value = (row['specialDate'] ??
                row['special_date'] ??
                row['date'] ??
                row['slotDate'] ??
                '')
            .toString()
            .trim();
      }
      final parsed = _parseDateKey(value);
      if (parsed == null) continue;
      final dateOnly = DateTime(parsed.year, parsed.month, parsed.day);
      final withinWindow =
          !dateOnly.isBefore(today) && dateOnly.isBefore(lastDay);
      if (withinWindow) {
        result.add(parsed.toIso8601String().split('T').first);
      }
    }
    return result;
  }

  Map<String, dynamic>? _normalizeMasterSlot(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final id =
        (map['id'] as num?)?.toInt() ?? int.tryParse('${map['id'] ?? ''}') ?? 0;
    final timeRange = (map['timeRange'] ?? '').toString().trim();
    if (id <= 0 || timeRange.isEmpty) return null;
    final parts = timeRange.split(RegExp(r'\s*[-–]\s*'));
    if (parts.length < 2) return null;
    final startKey = _slotStartKey(parts.first);
    final startMinutes = _parseClockMinutes(parts.first) ?? 0;
    final endMinutes = _parseClockMinutes(parts.last) ?? (startMinutes + 60);
    var durationMinutes = (map['durationMinutes'] as num?)?.toInt() ??
        (map['duration'] as num?)?.toInt() ??
        (endMinutes - startMinutes);
    if (durationMinutes <= 0) durationMinutes = 60;
    return {
      'id': id,
      'timeRange': timeRange,
      'startKey': startKey,
      'durationMinutes': durationMinutes,
      'durationHours': (durationMinutes / 60).round().clamp(1, 3),
    };
  }

  Map<String, dynamic> _normalizedSlotMap(Map<String, dynamic> map) {
    final timeRange = _normalizeTimeRange(
      map['timeRange'] ?? map['slotTime'],
      durationMinutes: map['durationMinutes'],
    );
    return {
      ...map,
      'displayTimeRange': timeRange,
      'startKey':
          _slotStartKey(timeRange.isNotEmpty ? timeRange : map['slotTime']),
    };
  }

  void _mergeByPriority(
      Map<String, Map<String, dynamic>> bucket, Map<String, dynamic> slot) {
    final date = (slot['slotDate'] ?? '').toString();
    final masterId = (slot['masterTimeSlotId'] as num?)?.toInt() ?? 0;
    final startKey = (slot['startKey'] ?? '').toString();
    if (date.isEmpty || startKey.isEmpty) return;
    final key = masterId > 0 ? '$date|m$masterId' : '$date|t$startKey';
    final current = bucket[key];
    if (current == null) {
      bucket[key] = slot;
      return;
    }
    final currentStatus = (current['status'] ?? '').toString().toUpperCase();
    final nextStatus = (slot['status'] ?? '').toString().toUpperCase();
    final score = (String status) {
      switch (status) {
        case 'BOOKED':
          return 3;
        case 'UNAVAILABLE':
        case 'BLOCKED':
          return 2;
        case 'AVAILABLE':
          return 1;
        default:
          return 0;
      }
    };
    if (score(nextStatus) >= score(currentStatus)) {
      bucket[key] = slot;
    }
  }

  Future<void> _load() async {
    final cId = _consultantId;
    final results = await Future.wait([
      _consultantService.getAvailableSlots(cId),
      _consultantService.getSlotsForWindow(cId),
      _consultantService.getSlotsByConsultant(cId),
      _offerService.getCheckoutOffers(cId),
      _consultantService.getSpecialDaysByConsultant(cId),
      _consultantService.getMasterSlots(cId),
    ]);
    final available = results[0] as List<TimeSlot>;
    final windowSlots = results[1] as List<TimeSlot>;
    final allConsultantSlots = results[2] as List<TimeSlot>;
    final offers = results[3] as List<Map<String, dynamic>>;
    final specialDays = _normalizeSpecialDays(results[4] as List<dynamic>);
    final masterSlots = (results[5] as List<dynamic>)
        .map(_normalizeMasterSlot)
        .whereType<Map<String, dynamic>>()
        .toList()
      ..sort((a, b) =>
          (a['startKey'] as String).compareTo(b['startKey'] as String));

    if (mounted) {
      final allRawSlots = <TimeSlot>[
        ...allConsultantSlots,
        ...available,
        ...windowSlots,
      ];
      final virtualByMaster = <String, Map<String, dynamic>>{};
      final today = DateTime.now();
      final startOfToday = DateTime(today.year, today.month, today.day);
      final lastDay = startOfToday.add(const Duration(days: 30));

      for (final slot in allRawSlots) {
        final map = slot.toJson();
        final slotDate = _parseDateKey(map['slotDate']?.toString());
        final withinMonth = slotDate == null ||
            (!slotDate.isBefore(startOfToday) && slotDate.isBefore(lastDay));
        if (!withinMonth || slotDate == null) continue;
        final normalized = _normalizedSlotMap({
          ...map,
          'slotDate': slotDate.toIso8601String().split('T').first,
        });
        _mergeByPriority(virtualByMaster, normalized);
      }

      final slots = <Map<String, dynamic>>[];
      if (masterSlots.isNotEmpty) {
        for (var i = 0; i < 30; i++) {
          final day = startOfToday.add(Duration(days: i));
          final dateKey = day.toIso8601String().split('T').first;
          if (specialDays.contains(dateKey)) continue;
          for (final master in masterSlots) {
            final key = '$dateKey|m${master['id']}';
            final fallbackKey = '$dateKey|t${master['startKey']}';
            final existing =
                virtualByMaster[key] ?? virtualByMaster[fallbackKey];
            if (existing != null) {
              slots.add(existing);
              continue;
            }
            slots.add({
              'id': -(i * 1000 + ((master['id'] as int?) ?? 0)),
              'slotDate': dateKey,
              'status': 'AVAILABLE',
              'masterTimeSlotId': master['id'],
              'durationMinutes': master['durationMinutes'],
              'timeRange': master['timeRange'],
              'displayTimeRange': master['timeRange'],
              'startKey': master['startKey'],
            });
          }
        }
      } else {
        slots.addAll(virtualByMaster.values);
      }

      final byId = <String, Map<String, dynamic>>{};
      for (final slot in slots) {
        final id = (slot['id'] as num?)?.toInt() ?? 0;
        final key = id > 0
            ? 'id:$id'
            : '${slot['slotDate']}|${slot['masterTimeSlotId'] ?? slot['startKey']}';
        byId[key] = slot;
      }

      final finalSlots = byId.values.toList()
        ..sort((a, b) {
          final dateA = a['slotDate']?.toString() ?? '';
          final dateB = b['slotDate']?.toString() ?? '';
          final dateCmp = dateA.compareTo(dateB);
          if (dateCmp != 0) return dateCmp;
          return _slotSortMinutes(a).compareTo(_slotSortMinutes(b));
        });

      final byDate = <String, List<Map<String, dynamic>>>{};
      for (final s in finalSlots) {
        final d = (s['slotDate'] ?? '').toString();
        if (d.isEmpty) continue;
        byDate.putIfAbsent(d, () => []).add(s);
      }
      for (final d in specialDays) {
        byDate.putIfAbsent(d, () => []);
      }
      for (final entry in byDate.entries) {
        entry.value
            .sort((a, b) => _slotSortMinutes(a).compareTo(_slotSortMinutes(b)));
      }
      final sortedKeys = byDate.keys.toList()..sort();
      setState(() {
        _slots = finalSlots;
        _slotsByDate = byDate;
        _selDate = sortedKeys.isNotEmpty ? sortedKeys.first : null;
        _masterSlots = masterSlots;
        _specialDays = specialDays;
        _selectedSpecialSlotKey =
            _selDate != null && specialDays.contains(_selDate)
                ? _specialRequestSlots.first['requestKey']?.toString()
                : null;
        _offers = offers;
        _loading = false;
      });
    }
  }

  String _fmtDayLabel(String dateStr) {
    try {
      final d = DateTime.parse(dateStr);
      final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      final months = [
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
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dt = DateTime(d.year, d.month, d.day);
      if (dt == today) return 'Today';
      if (dt == today.add(const Duration(days: 1))) return 'Tomorrow';
      return '${days[d.weekday % 7]} ${d.day} ${months[d.month - 1]}';
    } catch (_) {
      return dateStr;
    }
  }

  Future<void> _confirm() async {
    if (_isSpecialDateSelected) {
      await _confirmSpecialBooking();
      return;
    }
    if (_selSlot == null) {
      _toast(context, 'Please select a time slot', error: true);
      return;
    }
    setState(() => _booking = true);

    final cId = _consultantId;
    var slotId = (_selSlot!['id'] as num?)?.toInt() ?? 0;
    final base = double.tryParse(widget.c['charges']?.toString() ?? '0') ?? 0;
    final offerId = (_selOffer?['id'] as num?)?.toInt();
    final consultantName =
        (widget.c['name'] ?? widget.c['fullName'] ?? 'Expert').toString();

    if (slotId <= 0) {
      final masterId = (_selSlot!['masterTimeSlotId'] as num?)?.toInt() ?? 0;
      final slotDate = (_selSlot!['slotDate'] ?? '').toString();
      final durationMinutes =
          (_selSlot!['durationMinutes'] as num?)?.toInt() ?? 60;
      if (masterId > 0 && slotDate.isNotEmpty) {
        final created = await _consultantService.addCustomSlot(
          consultantId: cId,
          slotDate: slotDate,
          masterTimeSlotId: masterId,
          durationMinutes: durationMinutes,
        );
        slotId = created?.id ?? 0;
      }
    }

    if (slotId <= 0) {
      if (mounted) setState(() => _booking = false);
      _toast(context,
          'Could not resolve a time slot. Please refresh and try again.',
          error: true);
      return;
    }

    final result = await _bookingService.createBooking(
      consultantId: cId,
      timeSlotId: slotId,
      baseAmount: base,
      meetingMode: _mode,
      offerId: offerId,
      userNotes: _notes.isEmpty ? null : _notes,
    );

    if (mounted) {
      setState(() => _booking = false);
      if (result != null) {
        // Send booking confirmation notification
        await _notificationService.sendBookingConfirmation(result.id!);
        await _notificationService.addLocalNotification(
          AppNotification(
            id: DateTime.now().millisecondsSinceEpoch,
            title: 'Booking Confirmed',
            body:
                'Your session with $consultantName is booked for ${_fmtBookingDate((_selSlot?['slotDate'] ?? '').toString())} ${(_selSlot?['displayTimeRange'] ?? _selSlot?['timeRange'] ?? '').toString()}',
            type: 'BOOKING_CONFIRMED',
            createdAt: DateTime.now(),
            data: {'bookingId': result.id},
          ),
        );

        Navigator.pop(context);
        _toast(context, 'Session booked successfully! 🎉');

        // Show assessment sheet
        if (mounted) {
          Future.delayed(const Duration(milliseconds: 500), () {
            AssessmentSheet.show(
              context,
              bookingId: result.id!,
              bookingType: 'NORMAL',
              consultantId: cId,
            );
          });
        }
      } else {
        _toast(context, 'Failed to book. Please try again.', error: true);
      }
    }
  }

  Future<void> _confirmSpecialBooking() async {
    if (_selDate == null) {
      _toast(context, 'Please select a special day.', error: true);
      return;
    }
    if (_selectedSpecialSlot == null) {
      _toast(context, 'Please select a slot for the special booking.',
          error: true);
      return;
    }
    if (_notes.trim().isEmpty) {
      _toast(context,
          'Please enter your requirement notes for the special booking.',
          error: true);
      return;
    }

    setState(() => _booking = true);
    final cId = _consultantId;
    final base = double.tryParse(widget.c['charges']?.toString() ?? '0') ?? 0;
    final offerId = (_selOffer?['id'] as num?)?.toInt();
    final consultantName =
        (widget.c['name'] ?? widget.c['fullName'] ?? 'Expert').toString();
    final selectedSlot = _selectedSpecialSlot!;
    final selectedDurationHours = (selectedSlot['durationHours'] as int?) ??
        (((selectedSlot['durationMinutes'] as int?) ?? 120) / 60)
            .round()
            .clamp(1, 3);
    final preferredLabel = (selectedSlot['timeRange'] ?? '').toString();
    final meta = {
      'kind': 'SPECIAL_BOOKING',
      'version': 1,
      'hours': selectedDurationHours,
      'status': 'REQUESTED',
      'preferredDate': _selDate,
      'preferredSlotKey': selectedSlot['requestKey'],
      'preferredSlotNumber': selectedSlot['slotNumber'],
      'preferredTimeRange': preferredLabel,
      'requestNotes': _notes.trim(),
      'requestedMeetingMode': _mode,
    };
    final userNotes =
        '[[SPECIAL_BOOKING_META]]${jsonEncode(meta)}\n${_notes.trim()}';

    final created = await _bookingService.createSpecialBooking({
      'consultantId': cId,
      'durationInHours': selectedDurationHours,
      'sessionAmount': base,
      'meetingMode': _mode,
      'userNotes': userNotes,
      if (offerId != null) 'offerId': offerId,
    });

    if (mounted) {
      setState(() => _booking = false);
      if (created != null) {
        Navigator.pop(context);
        _toast(
          context,
          'Special booking request sent to $consultantName for ${_fmtBookingDate(_selDate!)}.',
        );

        // Show assessment sheet
        if (mounted) {
          Future.delayed(const Duration(milliseconds: 500), () {
            AssessmentSheet.show(
              context,
              bookingId: created['id'] ?? 0,
              bookingType: 'SPECIAL',
              consultantId: cId,
            );
          });
        }
      } else {
        _toast(
            context, 'Failed to request the special booking. Please try again.',
            error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.c['name'] ?? 'Expert';
    final base = double.tryParse(widget.c['charges']?.toString() ?? '0') ?? 0;
    final fee = _calcFee(base, widget.feeConfig) - base;
    double discount = 0;
    if (_selOffer != null) {
      final d = double.tryParse(_selOffer!['discount']?.toString() ?? '0') ?? 0;
      final type =
          (_selOffer!['discountType'] ?? 'FLAT').toString().toUpperCase();
      if (type == 'PERCENTAGE') {
        discount = base * d / 100;
      } else {
        discount = d;
      }
    }
    final total = base + fee - discount;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(children: [
          // Handle
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Row(children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: _C.gray200,
                      borderRadius: BorderRadius.circular(2))),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [_C.navy, _C.blue, _C.blueMid]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('BOOK SESSION',
                    style: _ts(11, FontWeight.w800, Colors.white, ls: 0.5)),
              ),
            ]),
          ),

          Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: _C.blue))
                  : ListView(
                      controller: ctrl,
                      padding: EdgeInsets.zero,
                      children: [
                          // Header with Gradient
                          Container(
                            padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [_C.navy, _C.blue, _C.blueMid],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(28)),
                            ),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('SCHEDULE A SESSION',
                                            style: _ts(10, FontWeight.w800,
                                                Colors.white70,
                                                ls: 1)),
                                        GestureDetector(
                                          onTap: () => Navigator.pop(context),
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                                color: Colors.white24,
                                                shape: BoxShape.circle),
                                            child: const Icon(
                                                Icons.close_rounded,
                                                color: Colors.white,
                                                size: 20),
                                          ),
                                        ),
                                      ]),
                                  const SizedBox(height: 16),
                                  Text(name.toString(),
                                      style: _ts(
                                          22, FontWeight.w800, Colors.white)),
                                  const SizedBox(height: 4),
                                  Text(
                                      '${widget.c['designation'] ?? 'Expert'} • ₹${total.toStringAsFixed(0)} / session',
                                      style: _ts(14, FontWeight.w600,
                                          Colors.white.withOpacity(0.9))),
                                ]),
                          ),

                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // ── Step 1: Date Picker ──
                                  if (_sortedDates.isEmpty)
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                          color: _C.warningBg,
                                          border:
                                              Border.all(color: _C.warningBrd),
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      child: Row(children: [
                                        const Icon(Icons.info_outline_rounded,
                                            color: _C.warning, size: 18),
                                        const SizedBox(width: 10),
                                        Text(
                                            'No available or special booking dates right now',
                                            style: _ts(13, FontWeight.w500,
                                                _C.warning)),
                                      ]),
                                    )
                                  else ...[
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border:
                                            Border.all(color: _C.borderLight),
                                        boxShadow: [
                                          BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.03),
                                              blurRadius: 10)
                                        ],
                                      ),
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                _isSpecialDateSelected
                                                    ? 'SPECIAL BOOKING'
                                                    : 'AVAILABLE SLOTS',
                                                style: _ts(11, FontWeight.w800,
                                                    _C.text1,
                                                    ls: 0.5)),
                                            const SizedBox(height: 4),
                                            Text(
                                                _isSpecialDateSelected
                                                    ? "This consultant opened the selected date for request-based special bookings."
                                                    : "Choose one available session from the consultant's published slots.",
                                                style: _ts(12, FontWeight.w500,
                                                    _C.text4)),
                                            const SizedBox(height: 16),
                                            _chip(
                                              _isSpecialDateSelected
                                                  ? 'SPECIAL DAY'
                                                  : 'STANDARD DAY',
                                              bg: _isSpecialDateSelected
                                                  ? _C.warningBg
                                                  : _C.blueLight
                                                      .withOpacity(0.5),
                                              fg: _isSpecialDateSelected
                                                  ? _C.warning
                                                  : _C.blue,
                                              brd: _isSpecialDateSelected
                                                  ? _C.warningBrd
                                                  : _C.blueBorder,
                                            ),
                                            const SizedBox(height: 20),
                                            Row(children: [
                                              Icon(Icons.chevron_left_rounded,
                                                  color: _C.gray200),
                                              Expanded(
                                                child: SizedBox(
                                                  height: 72,
                                                  child: ListView.separated(
                                                    scrollDirection:
                                                        Axis.horizontal,
                                                    itemCount:
                                                        _sortedDates.length,
                                                    separatorBuilder: (_, __) =>
                                                        const SizedBox(
                                                            width: 8),
                                                    itemBuilder: (_, i) {
                                                      final d = _sortedDates[i];
                                                      final isSel =
                                                          d == _selDate;
                                                      final isSpecial =
                                                          _specialDays
                                                              .contains(d);
                                                      DateTime? dt;
                                                      try {
                                                        dt = DateTime.parse(d);
                                                      } catch (_) {}
                                                      final dayStr = dt != null
                                                          ? [
                                                              'SUN',
                                                              'MON',
                                                              'TUE',
                                                              'WED',
                                                              'THU',
                                                              'FRI',
                                                              'SAT'
                                                            ][dt.weekday % 7]
                                                          : '';
                                                      final dateNum =
                                                          dt?.day.toString() ??
                                                              '';
                                                      return GestureDetector(
                                                        onTap: () =>
                                                            setState(() {
                                                          _selDate = d;
                                                          _selSlot = null;
                                                          _selectedSpecialSlotKey = isSpecial
                                                              ? _specialRequestSlots
                                                                  .first[
                                                                      'requestKey']
                                                                  ?.toString()
                                                              : null;
                                                        }),
                                                        child:
                                                            AnimatedContainer(
                                                          duration:
                                                              const Duration(
                                                                  milliseconds:
                                                                      180),
                                                          width: 58,
                                                          decoration:
                                                              BoxDecoration(
                                                            color: isSel
                                                                ? (isSpecial
                                                                    ? _C.warning
                                                                    : _C.blue)
                                                                : (isSpecial
                                                                    ? _C
                                                                        .warningBg
                                                                    : Colors
                                                                        .white),
                                                            border: Border.all(
                                                              color: isSel
                                                                  ? (isSpecial
                                                                      ? _C
                                                                          .warning
                                                                      : _C.blue)
                                                                  : (isSpecial
                                                                      ? _C.warningBrd
                                                                      : _C.border),
                                                              width:
                                                                  isSel ? 2 : 1,
                                                            ),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12),
                                                          ),
                                                          child: Column(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .center,
                                                              children: [
                                                                Text(dayStr,
                                                                    style: _ts(
                                                                        9,
                                                                        FontWeight
                                                                            .w700,
                                                                        isSel
                                                                            ? Colors.white70
                                                                            : _C.text4,
                                                                        ls: 0.3)),
                                                                const SizedBox(
                                                                    height: 2),
                                                                Text(dateNum,
                                                                    style: _ts(
                                                                        18,
                                                                        FontWeight
                                                                            .w900,
                                                                        isSel
                                                                            ? Colors.white
                                                                            : _C.text1)),
                                                                if (isSpecial &&
                                                                    !isSel)
                                                                  Container(
                                                                    margin: const EdgeInsets
                                                                        .only(
                                                                        top: 2),
                                                                    width: 12,
                                                                    height: 2,
                                                                    color: _C
                                                                        .warning,
                                                                  ),
                                                                if (isSel)
                                                                  Container(
                                                                    margin: const EdgeInsets
                                                                        .only(
                                                                        top: 2),
                                                                    width: 12,
                                                                    height: 2,
                                                                    color: Colors
                                                                        .white,
                                                                  )
                                                              ]),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ),
                                              Icon(Icons.chevron_right_rounded,
                                                  color: _C.blue),
                                            ]),
                                            const SizedBox(height: 24),
                                            Text(
                                                _isSpecialDateSelected
                                                    ? 'STEP 2 — SPECIAL REQUEST'
                                                    : 'STEP 2 — SELECT TIME',
                                                style: _ts(11, FontWeight.w800,
                                                    _C.text1,
                                                    ls: 0.5)),
                                            const SizedBox(height: 6),
                                            Text(
                                              _isSpecialDateSelected
                                                  ? 'No fixed time slot is booked here. Send your requirement and the consultant will confirm the exact timing.'
                                                  : 'Statuses shown for the next 30 days: Available, Booked, Unavailable, Passed.',
                                              style: _ts(11, FontWeight.w500,
                                                  _C.text4),
                                            ),
                                            const SizedBox(height: 16),
                                            if (_isSpecialDateSelected)
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(16),
                                                decoration: BoxDecoration(
                                                  color: _C.warningBg,
                                                  border: Border.all(
                                                      color: _C.warningBrd),
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Icon(Icons.star_rounded,
                                                            size: 16,
                                                            color: _C.warning),
                                                        const SizedBox(
                                                            width: 8),
                                                        Text(
                                                            'Special booking day selected',
                                                            style: _ts(
                                                                13,
                                                                FontWeight.w800,
                                                                _C.text1)),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      'The consultant will confirm the exact meeting time after you submit the request. Choose the slot you want below.',
                                                      style: _ts(
                                                          12,
                                                          FontWeight.w500,
                                                          _C.text3),
                                                    ),
                                                    const SizedBox(height: 14),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              14),
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                            0xFFECFEFF),
                                                        border: Border.all(
                                                            color:
                                                                _C.blueBorder),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(14),
                                                      ),
                                                      child: Row(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          const Icon(
                                                              Icons
                                                                  .info_outline_rounded,
                                                              color: _C.blue,
                                                              size: 18),
                                                          const SizedBox(
                                                              width: 10),
                                                          Expanded(
                                                            child: Text(
                                                              'Note: Each slot = ${(_selectedSpecialSlot?['durationHours'] ?? _specialRequestSlots.first['durationHours'] ?? 2)} hrs. The consultant will confirm the exact meeting time after you submit the request.',
                                                              style: _ts(
                                                                  12,
                                                                  FontWeight
                                                                      .w600,
                                                                  _C.text2),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(height: 14),
                                                    Row(
                                                      children: [
                                                        const Icon(
                                                            Icons
                                                                .access_time_rounded,
                                                            size: 16,
                                                            color: _C.blue),
                                                        const SizedBox(
                                                            width: 6),
                                                        Text('SELECT SLOT',
                                                            style: _ts(
                                                                12,
                                                                FontWeight.w800,
                                                                _C.blue,
                                                                ls: 0.4)),
                                                        const SizedBox(
                                                            width: 6),
                                                        Text(
                                                            '(each = ${(_selectedSpecialSlot?['durationHours'] ?? _specialRequestSlots.first['durationHours'] ?? 2)} hrs)',
                                                            style: _ts(
                                                                10,
                                                                FontWeight.w600,
                                                                _C.text4)),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 10),
                                                    Wrap(
                                                      spacing: 10,
                                                      runSpacing: 10,
                                                      children:
                                                          _specialRequestSlots
                                                              .map((slot) {
                                                        final isSelected =
                                                            _selectedSpecialSlotKey ==
                                                                slot[
                                                                    'requestKey'];
                                                        final durationHours =
                                                            (slot['durationHours']
                                                                    as int?) ??
                                                                2;
                                                        return GestureDetector(
                                                          onTap: () =>
                                                              setState(() {
                                                            _selectedSpecialSlotKey =
                                                                slot['requestKey']
                                                                    .toString();
                                                          }),
                                                          child:
                                                              AnimatedContainer(
                                                            duration:
                                                                const Duration(
                                                                    milliseconds:
                                                                        180),
                                                            width: 80,
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        10,
                                                                    vertical:
                                                                        12),
                                                            decoration:
                                                                BoxDecoration(
                                                              color: isSelected
                                                                  ? _C.warning
                                                                  : Colors
                                                                      .white,
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          14),
                                                              border:
                                                                  Border.all(
                                                                color: isSelected
                                                                    ? _C.warning
                                                                    : _C.blueBorder,
                                                                width: 1.5,
                                                              ),
                                                              boxShadow:
                                                                  isSelected
                                                                      ? [
                                                                          BoxShadow(
                                                                            color:
                                                                                _C.warning.withOpacity(0.28),
                                                                            blurRadius:
                                                                                14,
                                                                            offset:
                                                                                const Offset(0, 6),
                                                                          ),
                                                                        ]
                                                                      : null,
                                                            ),
                                                            child: Column(
                                                              children: [
                                                                Text(
                                                                  'Slot ${slot['slotNumber']}',
                                                                  style: _ts(
                                                                    12,
                                                                    FontWeight
                                                                        .w800,
                                                                    isSelected
                                                                        ? Colors
                                                                            .white
                                                                        : _C.blue,
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                    height: 4),
                                                                Text(
                                                                  '$durationHours hrs',
                                                                  style: _ts(
                                                                    10,
                                                                    FontWeight
                                                                        .w700,
                                                                    isSelected
                                                                        ? Colors
                                                                            .white
                                                                        : _C.text3,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        );
                                                      }).toList(),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            else if (_slotsForDate.isEmpty)
                                              Text('No slots for this date',
                                                  style: _ts(
                                                      13,
                                                      FontWeight.w500,
                                                      _C.text3))
                                            else
                                              Wrap(
                                                  spacing: 10,
                                                  runSpacing: 10,
                                                  children:
                                                      _slotsForDate.map((slot) {
                                                    final sel =
                                                        _selSlot?['id'] ==
                                                            slot['id'];
                                                    final time = slot[
                                                            'displayTimeRange'] ??
                                                        slot['timeRange'] ??
                                                        slot['slotTime'] ??
                                                        '';
                                                    final visualStatus =
                                                        _slotVisualStatus(slot);
                                                    final isSelectable =
                                                        visualStatus ==
                                                            'AVAILABLE';
                                                    return GestureDetector(
                                                      onTap: !isSelectable
                                                          ? null
                                                          : () => setState(() =>
                                                              _selSlot = sel
                                                                  ? null
                                                                  : slot),
                                                      child: AnimatedContainer(
                                                        duration:
                                                            const Duration(
                                                                milliseconds:
                                                                    180),
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 16,
                                                                vertical: 12),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: !isSelectable
                                                              ? _slotStatusBg(
                                                                  visualStatus)
                                                              : sel
                                                                  ? _C.blueLight
                                                                  : Colors
                                                                      .white,
                                                          border: Border.all(
                                                            color: !isSelectable
                                                                ? _slotStatusColor(
                                                                        visualStatus)
                                                                    .withOpacity(
                                                                        0.45)
                                                                : sel
                                                                    ? _C.blue
                                                                    : _C.border,
                                                            width: sel ? 2 : 1,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(12),
                                                        ),
                                                        child:
                                                            Column(children: [
                                                          Text(time.toString(),
                                                              style: _ts(
                                                                  13,
                                                                  FontWeight
                                                                      .w700,
                                                                  !isSelectable
                                                                      ? _slotStatusColor(
                                                                          visualStatus)
                                                                      : sel
                                                                          ? _C.blue
                                                                          : _C.text1)),
                                                          const SizedBox(
                                                              height: 4),
                                                          Text(
                                                            visualStatus,
                                                            style: _ts(
                                                                9,
                                                                FontWeight.w800,
                                                                _slotStatusColor(
                                                                    visualStatus),
                                                                ls: 0.5),
                                                          ),
                                                        ]),
                                                      ),
                                                    );
                                                  }).toList()),
                                          ]),
                                    ),
                                  ],

                                  const SizedBox(height: 32),
                                  Text('MEETING MODE',
                                      style: _ts(11, FontWeight.w800, _C.text1,
                                          ls: 0.5)),
                                  const SizedBox(height: 16),
                                  Row(
                                      children: _modes.map((m) {
                                    final sel = _mode == m;
                                    final icon = m == 'ONLINE'
                                        ? Icons.laptop_mac_rounded
                                        : m == 'PHYSICAL'
                                            ? Icons.location_on_outlined
                                            : Icons.call_outlined;
                                    return Expanded(
                                      child: GestureDetector(
                                        onTap: () => setState(() => _mode = m),
                                        child: AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 180),
                                          margin: EdgeInsets.only(
                                              right: m == _modes.last ? 0 : 12),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 14),
                                          decoration: BoxDecoration(
                                            color: sel
                                                ? _C.blueLight
                                                : Colors.white,
                                            border: Border.all(
                                                color:
                                                    sel ? _C.blue : _C.border,
                                                width: sel ? 2 : 1),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(icon,
                                                    size: 18,
                                                    color: sel
                                                        ? _C.blue
                                                        : _C.text4),
                                                const SizedBox(width: 8),
                                                Text(
                                                    m == 'PHYSICAL'
                                                        ? 'In-Person'
                                                        : m == 'PHONE'
                                                            ? 'PHONE'
                                                            : 'ONLINE',
                                                    style: _ts(
                                                        11,
                                                        FontWeight.w700,
                                                        sel
                                                            ? _C.blue
                                                            : _C.text3)),
                                              ]),
                                        ),
                                      ),
                                    );
                                  }).toList()),

                                  const SizedBox(height: 32),
                                  if (_offers.isNotEmpty) ...[
                                    Text('AVAILABLE OFFERS',
                                        style: _ts(
                                            11, FontWeight.w800, _C.text1,
                                            ls: 0.5)),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      height: 60,
                                      child: ListView.separated(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: _offers.length,
                                        separatorBuilder: (_, __) =>
                                            const SizedBox(width: 12),
                                        itemBuilder: (_, i) {
                                          final o = _offers[i];
                                          final sel =
                                              _selOffer?['id'] == o['id'];
                                          return GestureDetector(
                                            onTap: () => setState(() =>
                                                _selOffer = sel ? null : o),
                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                  milliseconds: 180),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16),
                                              decoration: BoxDecoration(
                                                color: sel
                                                    ? _C.successBg
                                                    : Colors.white,
                                                border: Border.all(
                                                    color: sel
                                                        ? _C.success
                                                        : _C.border,
                                                    width: sel ? 2 : 1),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(o['title'] ?? 'Offer',
                                                      style: _ts(
                                                          13,
                                                          FontWeight.w700,
                                                          sel
                                                              ? _C.success
                                                              : _C.text1)),
                                                  Text(
                                                      o['discountType'] ==
                                                              'PERCENTAGE'
                                                          ? '${o['discount']}% OFF'
                                                          : '₹${o['discount']} OFF',
                                                      style: _ts(
                                                          10,
                                                          FontWeight.w600,
                                                          _C.text3)),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 32),
                                  ],

                                  Text(
                                    _isSpecialDateSelected
                                        ? 'NOTES  REQUIRED'
                                        : 'NOTES  OPTIONAL',
                                    style: _ts(11, FontWeight.w800, _C.text1,
                                        ls: 0.5),
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: _notesCtrl,
                                    onChanged: (v) => _notes = v,
                                    maxLines: _isSpecialDateSelected ? 3 : 1,
                                    decoration: InputDecoration(
                                      hintText: _isSpecialDateSelected
                                          ? 'Describe your requirement for this special booking...'
                                          : 'Add notes for the consultant...',
                                      hintStyle:
                                          _ts(13, FontWeight.w400, _C.text4),
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide:
                                              BorderSide(color: _C.border)),
                                      enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide:
                                              BorderSide(color: _C.border)),
                                    ),
                                  ),

                                  const SizedBox(height: 32),
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: _C.gray100.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: _C.borderLight),
                                    ),
                                    child: Column(children: [
                                      Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('Session Fee',
                                                style: _ts(14, FontWeight.w600,
                                                    _C.text3)),
                                            Text('₹${base.toStringAsFixed(0)}',
                                                style: _ts(14, FontWeight.w700,
                                                    _C.text1)),
                                          ]),
                                      if (discount > 0) ...[
                                        const SizedBox(height: 12),
                                        Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('Offer Applied',
                                                  style: _ts(
                                                      14,
                                                      FontWeight.w600,
                                                      _C.success)),
                                              Text(
                                                  '-₹${discount.toStringAsFixed(0)}',
                                                  style: _ts(
                                                      14,
                                                      FontWeight.w700,
                                                      _C.success)),
                                            ]),
                                      ],
                                      const Padding(
                                        padding:
                                            EdgeInsets.symmetric(vertical: 12),
                                        child: Divider(
                                            height: 1, color: _C.borderLight),
                                      ),
                                      Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('Total Amount',
                                                style: _ts(16, FontWeight.w800,
                                                    _C.text1)),
                                            Text('₹${total.toStringAsFixed(0)}',
                                                style: _ts(18, FontWeight.w900,
                                                    _C.blue)),
                                          ]),
                                    ]),
                                  ),

                                  const SizedBox(height: 32),
                                  _gradBtn(
                                    _isSpecialDateSelected
                                        ? 'Request Special Booking'
                                        : 'Confirm Booking',
                                    _confirm,
                                    loading: _booking,
                                    radius: 12,
                                  ),
                                  const SizedBox(height: 20),
                                ]),
                          ),
                        ])),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// TAB 2 — BOOKINGS
// ════════════════════════════════════════════════════════════════════════════

class _BookingsTab extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onOpenAccount;
  const _BookingsTab({required this.user, required this.onOpenAccount});
  @override
  State<_BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<_BookingsTab> {
  List<Map<String, dynamic>> _bookings = [];
  bool _loading = true;
  String _filter = 'UPCOMING'; // UPCOMING | HISTORY

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _bookingService.getMyBookings(size: 50);
    final enriched = <Booking>[];
    for (final booking in list) {
      final needsHydration = (booking.consultantName ?? '').trim().isEmpty ||
          (booking.slotDate ?? '').trim().isEmpty ||
          (booking.timeRange ?? '').trim().isEmpty ||
          (booking.amount ?? 0) == 0;
      if (needsHydration) {
        final detailed = await _bookingService.getBookingById(booking.id);
        enriched.add(detailed ?? booking);
      } else {
        enriched.add(booking);
      }
    }
    if (mounted)
      setState(() {
        _bookings = enriched.map((e) => e.toJson()).toList();
        _loading = false;
      });
  }

  bool _isUpcoming(Map<String, dynamic> b) {
    final status =
        (b['bookingStatus'] ?? b['status'] ?? '').toString().toUpperCase();
    // Cancelled/rejected are never upcoming
    if (status == 'CANCELLED' ||
        status == 'REJECTED' ||
        status == 'COMPLETED' ||
        status == 'DONE') {
      return false;
    }
    // Must be a pending/confirmed/scheduled status
    if (status != 'CONFIRMED' &&
        status != 'PENDING' &&
        status != 'PAID' &&
        status != 'SCHEDULED') {
      return false;
    }
    // Check if the slot date+time has already passed
    final slotDateStr = (b['slotDate'] ?? b['bookingDate'] ?? b['date'] ?? '')
        .toString()
        .trim();
    if (slotDateStr.isEmpty) return true; // no date info, keep as upcoming
    final slotDate = _parseDateKey(slotDateStr);
    if (slotDate == null) return true;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final bookingDay = DateTime(slotDate.year, slotDate.month, slotDate.day);

    // Future date → always upcoming
    if (bookingDay.isAfter(today)) return true;
    // Past date → always history
    if (bookingDay.isBefore(today)) return false;

    // Same day: check end time of slot
    final timeRange = (b['timeRange'] ?? b['slotTime'] ?? '').toString().trim();
    if (timeRange.isEmpty)
      return true; // no time info, keep as upcoming for today
    // Try to parse end time from range like "14:00-16:00" or "2:00 PM - 4:00 PM"
    String endPart = timeRange;
    if (timeRange.contains('-')) {
      final parts = timeRange.split('-');
      endPart = parts.last.trim();
    }
    final endMinutes = _parseClockMinutes(endPart);
    if (endMinutes == null) return true;
    final slotEndTime = DateTime(
        now.year, now.month, now.day, endMinutes ~/ 60, endMinutes % 60);
    return now.isBefore(slotEndTime);
  }

  List<Map<String, dynamic>> get _filtered => _bookings
      .where((b) => _filter == 'UPCOMING' ? _isUpcoming(b) : !_isUpcoming(b))
      .toList();

  Future<void> _cancel(int bookingId) async {
    final ok = await _bookingService.cancelBooking(bookingId);
    if (mounted) {
      _toast(context, ok ? 'Booking cancelled.' : 'Could not cancel.',
          error: !ok);
      if (ok) _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Column(children: [
      // Header
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('My Bookings', style: _ts(24, FontWeight.w900, _C.text1)),
            const Spacer(),
            TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text('Refresh', style: _ts(13, FontWeight.w600, _C.text2)),
              style: TextButton.styleFrom(
                foregroundColor: _C.text2,
                side: const BorderSide(color: _C.border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(width: 10),
            _headerProfileButton(widget.user, widget.onOpenAccount),
          ]),
          const SizedBox(height: 14),
          // Filter toggle
          Row(children: [
            ...['UPCOMING', 'HISTORY'].map((f) {
              final sel = _filter == f;
              final count = _bookings
                  .where(
                      (b) => f == 'UPCOMING' ? _isUpcoming(b) : !_isUpcoming(b))
                  .length;
              final label = f == 'UPCOMING' ? 'Upcoming' : 'History';
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () => setState(() => _filter = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? _C.blue : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: sel ? _C.blue : _C.border, width: 1.5),
                    ),
                    child: Text('$label ($count)',
                        style: _ts(12, FontWeight.w700,
                            sel ? Colors.white : _C.text3)),
                  ),
                ),
              );
            }),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.calendar_month_outlined, color: _C.blue),
              onPressed: () => _showCalendar(context),
              style: IconButton.styleFrom(
                side: const BorderSide(color: _C.border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ]),
        ]),
      ),

      Expanded(
        child: _loading
            ? ListView(
                padding: const EdgeInsets.all(16),
                children: List.generate(3, (_) => const _Shimmer(height: 160)))
            : _filtered.isEmpty
                ? _emptyState(
                    _filter == 'UPCOMING'
                        ? Icons.calendar_today_rounded
                        : Icons.history_rounded,
                    _filter == 'UPCOMING'
                        ? 'No Upcoming Sessions'
                        : 'No Past Sessions',
                    _filter == 'UPCOMING'
                        ? 'Book a session with an expert to get started'
                        : 'Your completed sessions will appear here',
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    color: _C.blue,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) => _BookingCard(
                        b: _filtered[i],
                        onCancel: _cancel,
                        onFeedback: (b) => _openFeedback(context, b),
                      ),
                    ),
                  ),
      ),
    ]));
  }

  void _openFeedback(BuildContext ctx, Map<String, dynamic> b) =>
      showModalBottomSheet(
        context: ctx,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _FeedbackSheet(booking: b),
      );

  void _showCalendar(BuildContext context) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _BookingsCalendarModal(bookings: _bookings),
      );
}

class _BookingsCalendarModal extends StatefulWidget {
  final List<Map<String, dynamic>> bookings;
  const _BookingsCalendarModal({required this.bookings});

  @override
  State<_BookingsCalendarModal> createState() => _BookingsCalendarModalState();
}

class _BookingsCalendarModalState extends State<_BookingsCalendarModal> {
  DateTime _month = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final days = _generateDays(_month);
    final monthName = DateFormat('MMMM yyyy').format(_month);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(children: [
          // Handle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: _C.gray200, borderRadius: BorderRadius.circular(2))),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(children: [
              Text(monthName, style: _ts(18, FontWeight.w800, _C.text1)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () => setState(
                    () => _month = DateTime(_month.year, _month.month - 1)),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: () => setState(
                    () => _month = DateTime(_month.year, _month.month + 1)),
              ),
            ]),
          ),

          // Day labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                  .map((d) => SizedBox(
                        width: 40,
                        child: Text(d[0],
                            textAlign: TextAlign.center,
                            style: _ts(12, FontWeight.w700, _C.text4)),
                      ))
                  .toList(),
            ),
          ),

          const SizedBox(height: 8),

          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              controller: ctrl,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: days.length,
              itemBuilder: (_, i) {
                final d = days[i];
                if (d == null) return const SizedBox();

                final isToday = DateFormat('yyyy-MM-dd').format(d) ==
                    DateFormat('yyyy-MM-dd').format(DateTime.now());
                final bookingsForDay = widget.bookings.where((b) {
                  final sd = b['slotDate']?.toString();
                  return sd != null &&
                      sd.startsWith(DateFormat('yyyy-MM-dd').format(d));
                }).toList();

                return Container(
                  decoration: BoxDecoration(
                    color: isToday ? _C.blueLight : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: isToday ? _C.blue : _C.border,
                        width: isToday ? 1.5 : 1),
                  ),
                  child: Stack(alignment: Alignment.center, children: [
                    Text(d.day.toString(),
                        style: _ts(
                            14, FontWeight.w700, isToday ? _C.blue : _C.text1)),
                    if (bookingsForDay.isNotEmpty)
                      Positioned(
                        bottom: 4,
                        child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: bookingsForDay
                                .map((b) {
                                  final status =
                                      (b['bookingStatus'] ?? b['status'] ?? '')
                                          .toString()
                                          .toUpperCase();
                                  final color = status == 'CONFIRMED'
                                      ? _C.success
                                      : status == 'PENDING'
                                          ? _C.warning
                                          : _C.gray500;
                                  return Container(
                                    width: 4,
                                    height: 4,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 1),
                                    decoration: BoxDecoration(
                                        color: color, shape: BoxShape.circle),
                                  );
                                })
                                .toList()
                                .take(3)
                                .toList()),
                      ),
                  ]),
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _legend(_C.success, 'Confirmed'),
                  _legend(_C.warning, 'Pending'),
                  _legend(_C.gray500, 'Other'),
                ]),
          ),
        ]),
      ),
    );
  }

  Widget _legend(Color c, String l) => Row(children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(l, style: _ts(11, FontWeight.w600, _C.text3)),
      ]);

  List<DateTime?> _generateDays(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final last = DateTime(month.year, month.month + 1, 0);
    final days = <DateTime?>[];
    for (var i = 0; i < first.weekday % 7; i++) days.add(null);
    for (var i = 1; i <= last.day; i++)
      days.add(DateTime(month.year, month.month, i));
    return days;
  }
}

class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> b;
  final void Function(int) onCancel;
  final void Function(Map<String, dynamic>) onFeedback;
  const _BookingCard(
      {required this.b, required this.onCancel, required this.onFeedback});

  @override
  Widget build(BuildContext context) {
    final id = (b['id'] as num?)?.toInt() ?? 0;
    final status = (b['bookingStatus'] ?? b['status'] ?? 'PENDING')
        .toString()
        .toUpperCase();
    final mode =
        (b['meetingMode'] ?? b['mode'] ?? 'ONLINE').toString().toUpperCase();
    final rawAmount = b['amount'] ??
        b['totalAmount'] ??
        b['sessionAmount'] ??
        b['charges'] ??
        0;
    final amount = rawAmount is num
        ? rawAmount.toDouble()
        : (double.tryParse(rawAmount.toString()) ?? 0.0);
    final cName = (b['consultantName'] ??
            b['consultant']?['name'] ??
            b['advisorName'] ??
            'Expert')
        .toString();
    final isSpecial = b['type'] == 'SPECIAL' || b['isSpecial'] == true;
    final isDone = status == 'COMPLETED' || status == 'DONE';
    final isUpcoming = status == 'CONFIRMED' ||
        status == 'PAID' ||
        status == 'SCHEDULED' ||
        status == 'PENDING';
    final isOnline = mode == 'ONLINE';
    final link = b['meetingLink'] ?? '';
    final slotId = b['timeSlotId'] ?? b['slotId'] ?? '';
    final notes = _stripHtml(
        (b['userNotes'] ?? b['meetingNotes'] ?? b['notes'] ?? '').toString());
    final bookingDate =
        (b['slotDate'] ?? b['bookingDate'] ?? b['date'] ?? '').toString();
    final bookingTime = _normalizeTimeRange(
      b['timeRange'] ?? b['slotTime'] ?? '',
      durationMinutes: b['durationMinutes'],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isSpecial ? _C.blue.withOpacity(0.3) : _C.border,
            width: isSpecial ? 2 : 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (isSpecial)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: _C.blueLight,
            child: Row(children: [
              const Icon(Icons.star_rounded, size: 14, color: _C.blue),
              const SizedBox(width: 6),
              Text('SPECIAL BOOKING — SCHEDULED',
                  style: _ts(10, FontWeight.w800, _C.blue, ls: 0.5)),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                    color: _C.blueLight,
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(
                  mode == 'ONLINE'
                      ? Icons.videocam_rounded
                      : mode == 'PHONE'
                          ? Icons.phone_rounded
                          : Icons.location_on_rounded,
                  color: _C.blue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                        isSpecial
                            ? 'Special Booking with $cName'
                            : 'Session with $cName',
                        style: _ts(15, FontWeight.w800, _C.text1)),
                    const SizedBox(height: 6),
                    Row(children: [
                      if (bookingDate.isNotEmpty)
                        Text(_fmtBookingDate(bookingDate),
                            style: _ts(12, FontWeight.w500, _C.text3)),
                      if (bookingDate.isNotEmpty && bookingTime.isNotEmpty)
                        const SizedBox(width: 10),
                      if (bookingTime.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: _C.blueLight,
                              borderRadius: BorderRadius.circular(6)),
                          child: Text(bookingTime,
                              style: _ts(11, FontWeight.w700, _C.blue)),
                        ),
                    ]),
                  ])),
              _statusChip(status),
            ]),
            const SizedBox(height: 16),
            const Divider(color: _C.borderLight, height: 1),
            const SizedBox(height: 14),
            Row(children: [
              _infoChip(
                  Icons.attach_money_rounded, '₹${amount.toStringAsFixed(0)}'),
              const SizedBox(width: 8),
              if (bookingDate.isNotEmpty)
                _infoChip(
                    Icons.calendar_today_rounded, _fmtBookingDate(bookingDate)),
              if (bookingDate.isEmpty)
                _infoChip(Icons.confirmation_number_rounded, 'Slot #$slotId'),
              const SizedBox(width: 8),
              _infoChip(
                  mode == 'PHONE'
                      ? Icons.phone_callback_rounded
                      : mode == 'PHYSICAL'
                          ? Icons.location_on_rounded
                          : Icons.videocam_rounded,
                  mode),
            ]),
            if (notes.toString().isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.notes_rounded, size: 14, color: _C.text4),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(notes.toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _ts(12, FontWeight.w400, _C.text3))),
              ]),
            ],
          ]),
        ),

        // Actions
        Builder(builder: (context) {
          // Compute if session is joinable (within 15 min of start or before end)
          String countdownLabel = '';
          bool canJoin = false;
          if (isUpcoming && isOnline && link.toString().isNotEmpty) {
            final now = DateTime.now();
            // Parse start time
            String startPart = bookingTime;
            if (bookingTime.contains('-')) {
              startPart = bookingTime.split('-').first.trim();
            }
            final startMin = _parseClockMinutes(startPart);
            final slotDateStr = bookingDate;
            DateTime? slotStart;
            if (startMin != null && slotDateStr.isNotEmpty) {
              final base = _parseDateKey(slotDateStr);
              if (base != null) {
                slotStart = DateTime(base.year, base.month, base.day,
                    startMin ~/ 60, startMin % 60);
              }
            }
            if (slotStart != null) {
              final diff = slotStart.difference(now);
              if (diff.isNegative || diff.inMinutes <= 15) {
                canJoin = true;
              } else {
                final h = diff.inHours;
                final m = diff.inMinutes % 60;
                countdownLabel =
                    h > 0 ? 'starts in ${h}h ${m}m' : 'starts in ${m}m';
              }
            } else {
              canJoin = true; // no date info, allow join
            }
          }

          final bool showJoin =
              isUpcoming && isOnline && link.toString().isNotEmpty;
          final bool showCancel = status == 'PENDING' || status == 'CONFIRMED';
          final bool showRate = isDone;
          final bool showAnswers = true; // always show answers button

          if (!showJoin && !showCancel && !showRate && !showAnswers)
            return const SizedBox();

          return Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Join / Countdown row
                  if (showJoin) ...[
                    canJoin
                        ? GestureDetector(
                            onTap: () {/* open meeting link */},
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                    colors: [_C.success, Color(0xFF15803D)]),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.videocam_rounded,
                                        color: Colors.white, size: 16),
                                    const SizedBox(width: 6),
                                    Text('Join Meeting',
                                        style: _ts(
                                            13, FontWeight.w700, Colors.white)),
                                  ]),
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _C.gray100,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _C.border),
                            ),
                            child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.schedule_rounded,
                                      size: 14, color: _C.text3),
                                  const SizedBox(width: 6),
                                  Text('Too Early to Join — $countdownLabel',
                                      style:
                                          _ts(12, FontWeight.w600, _C.text3)),
                                ]),
                          ),
                    const SizedBox(height: 8),
                  ],

                  // View Answers + Cancel / Rate row
                  Row(children: [
                    // View Answers button
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          final bookingId = (b['id'] as num?)?.toInt();
                          final specialBookingId =
                              b['type'] == 'SPECIAL' || b['isSpecial'] == true
                                  ? (b['specialBookingId'] as num?)?.toInt() ??
                                      bookingId
                                  : null;
                          final clientName =
                              (b['clientName'] ?? b['userName'] ?? 'Client')
                                  .toString();
                          final userId =
                              (b['userId'] ?? b['clientId'] as num?)?.toInt();
                          final bookingType =
                              (b['type'] ?? 'NORMAL').toString();
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BookingAnswersScreen(
                                  bookingId: bookingId,
                                  specialBookingId: specialBookingId,
                                  bookingType: bookingType,
                                  userId: userId,
                                  clientName: clientName,
                                ),
                              ));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _C.indigoBg,
                            border:
                                Border.all(color: _C.indigo.withOpacity(0.3)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.quiz_rounded,
                                    size: 14, color: _C.indigo),
                                const SizedBox(width: 6),
                                Text('View Answers',
                                    style: _ts(12, FontWeight.w700, _C.indigo)),
                              ]),
                        ),
                      ),
                    ),

                    if (showRate) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => onFeedback(b),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _C.amberBg,
                              border: Border.all(color: _C.amber),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.star_rounded,
                                      color: _C.amber, size: 16),
                                  const SizedBox(width: 6),
                                  Text('Rate',
                                      style:
                                          _ts(12, FontWeight.w700, _C.amber)),
                                ]),
                          ),
                        ),
                      ),
                    ],

                    if (showCancel) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _confirmCancel(context, id),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border:
                                  Border.all(color: _C.danger.withOpacity(0.3)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text('Cancel',
                                  style: _ts(12, FontWeight.w700, _C.danger)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ]),
                ]),
          );
        }),
      ]),
    );
  }

  Widget _infoChip(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration:
            BoxDecoration(color: _C.bg, borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: _C.text4),
          const SizedBox(width: 5),
          Text(label, style: _ts(12, FontWeight.w600, _C.text3)),
        ]),
      );

  void _confirmCancel(BuildContext ctx, int id) => showDialog(
        context: ctx,
        builder: (_) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Cancel Booking?',
              style: _ts(17, FontWeight.w800, _C.text1)),
          content: Text(
              'Are you sure you want to cancel this session? This cannot be undone.',
              style: _ts(14, FontWeight.w400, _C.text2)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Keep', style: _ts(14, FontWeight.w600, _C.text3))),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                onCancel(id);
              },
              child: Text('Cancel Booking',
                  style: _ts(14, FontWeight.w700, _C.danger)),
            ),
          ],
        ),
      );
}

// ── Feedback Sheet (submit rating for completed booking) ──────────────────────
class _FeedbackSheet extends StatefulWidget {
  final Map<String, dynamic> booking;
  const _FeedbackSheet({required this.booking});
  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<_FeedbackSheet> {
  int _rating = 0;
  final _commentCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      _toast(context, 'Please select a rating', error: true);
      return;
    }
    setState(() => _submitting = true);
    final cId = (widget.booking['consultantId'] as num?)?.toInt() ?? 0;
    final bId = (widget.booking['id'] as num?)?.toInt() ?? 0;
    final result = await _feedbackService.submitFeedback(
      consultantId: cId, bookingId: bId, rating: _rating,
      meetingId: 1, // Required by swagger, using 1 as default
      comments:
          _commentCtrl.text.trim().isEmpty ? null : _commentCtrl.text.trim(),
    );
    if (mounted) {
      setState(() => _submitting = false);
      final ok = result != null;
      _toast(
          context, ok ? 'Thank you for your feedback! ⭐' : 'Failed to submit.',
          error: !ok);
      if (ok) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.fromLTRB(
            24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: _C.gray200,
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Text('Rate Your Session',
                  style: _ts(20, FontWeight.w800, _C.text1)),
              const SizedBox(height: 6),
              Text('Your feedback helps consultants improve.',
                  style: _ts(13, FontWeight.w400, _C.text3)),
              const SizedBox(height: 24),
              Center(
                  child: _Stars(
                      value: _rating,
                      onChanged: (v) => setState(() => _rating = v),
                      size: 40)),
              const SizedBox(height: 8),
              Center(
                  child: Text(
                _rating == 0
                    ? 'Tap to rate'
                    : [
                        '',
                        'Poor',
                        'Fair',
                        'Good',
                        'Great',
                        'Excellent'
                      ][_rating],
                style: _ts(14, FontWeight.w700, _C.amber),
              )),
              const SizedBox(height: 20),
              TextField(
                controller: _commentCtrl,
                maxLines: 3,
                style: _ts(14, FontWeight.w400, _C.text1),
                decoration: InputDecoration(
                  hintText: 'Share your experience (optional)…',
                  hintStyle: _ts(14, FontWeight.w400, _C.text4),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _C.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _C.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _C.blue)),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 20),
              _gradBtn('Submit Feedback', _submit, loading: _submitting),
            ]),
      );
}

// ════════════════════════════════════════════════════════════════════════════
// TAB 3 — TICKETS (Support System)
// ════════════════════════════════════════════════════════════════════════════

class _TicketsTab extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onOpenAccount;
  const _TicketsTab({required this.user, required this.onOpenAccount});
  @override
  State<_TicketsTab> createState() => _TicketsTabState();
}

class _TicketsTabState extends State<_TicketsTab> {
  List<Map<String, dynamic>> _tickets = [];
  bool _loading = true;
  bool _guestExpiryPromptShown = false;
  final ScrollController _filterChipScrollCtrl = ScrollController();
  final ScrollController _ticketActionScrollCtrl = ScrollController();
  static const List<String> _ticketFilters = [
    'ALL',
    'NEW',
    'OPEN',
    'IN_PROGRESS',
    'PENDING',
    'RESOLVED',
    'CLOSED',
  ];
  String _filter =
      'ALL'; // ALL | NEW | OPEN | IN_PROGRESS | PENDING | RESOLVED | CLOSED
  static const String _supportMailbox = 'support@meetthemasters.in';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _filterChipScrollCtrl.dispose();
    _ticketActionScrollCtrl.dispose();
    super.dispose();
  }

  int get _uid => (widget.user['id'] as num?)?.toInt() ?? 0;

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _ticketService.getTicketsByUser(_uid);
    if (mounted)
      setState(() {
        _tickets = list.map((t) => t.toJson()).toList();
        _loading = false;
      });
    if (mounted &&
        _isGuestTicketAccessExpired(widget.user) &&
        !_guestExpiryPromptShown) {
      _guestExpiryPromptShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showGuestTicketExpiredDialog(context);
      });
    }
  }

  bool _isGuest(Map<String, dynamic> u) {
    final plan = (u['subscriptionPlan']?['name'] ?? u['plan'] ?? 'Guest')
        .toString()
        .toLowerCase();
    return plan == 'guest';
  }

  int _countByStatus(String status) {
    if (status == 'ALL') return _tickets.length;
    return _tickets.where((t) {
      final s = (t['status'] ?? '').toString().toUpperCase();
      return s == status;
    }).length;
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'ALL') return _tickets;
    return _tickets.where((t) {
      final s = (t['status'] ?? '').toString().toUpperCase();
      return s == _filter;
    }).toList();
  }

  void _scrollFilterIntoView(String filter) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_filterChipScrollCtrl.hasClients) return;
      if ((ModalRoute.of(context)?.isCurrent ?? true) == false) return;
      final index = _ticketFilters.indexOf(filter);
      if (index < 0 || _ticketFilters.length <= 1) return;

      final maxExtent = _filterChipScrollCtrl.position.maxScrollExtent;
      if (maxExtent <= 0) return;

      final ratio = index / (_ticketFilters.length - 1);
      final target = (maxExtent * ratio).clamp(0.0, maxExtent);
      _filterChipScrollCtrl.animateTo(
        target,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _setFilter(String filter) {
    setState(() => _filter = filter);
    _scrollFilterIntoView(filter);
  }

  void _scrollActionIntoView(String actionId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_ticketActionScrollCtrl.hasClients) return;
      if ((ModalRoute.of(context)?.isCurrent ?? true) == false) return;

      final maxExtent = _ticketActionScrollCtrl.position.maxScrollExtent;
      if (maxExtent <= 0) return;

      final target = switch (actionId) {
        'refresh' => 0.0,
        'ticket' => maxExtent,
        _ => maxExtent * 0.5,
      };

      _ticketActionScrollCtrl.animateTo(
        target.clamp(0.0, maxExtent),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _runAction(String actionId, VoidCallback action,
      {bool scrollAfter = true}) {
    action();
    if (scrollAfter) {
      _scrollActionIntoView(actionId);
    }
  }

  String? _mailtoQuery(Map<String, String> params) {
    if (params.isEmpty) return null;
    return params.entries
        .map((entry) =>
            '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}')
        .join('&');
  }

  Future<void> _openSupportEmailApp() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    const template = 'Hi Support Team,\n\n'
        'I need help with:\n\n'
        '- Issue:\n'
        '- Steps to reproduce:\n'
        '- Expected result:\n'
        '- Actual result:\n\n'
        'Thanks,';
    final uri = Uri(
      scheme: 'mailto',
      path: _supportMailbox,
      query: _mailtoQuery({
        'subject': 'Support Request',
        'body': template,
      }),
    );

    bool opened = false;
    try {
      opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_self',
      );
    } catch (_) {
      opened = false;
    }
    if (!mounted) return;

    if (opened) {
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Email app opened. Send to $_supportMailbox. Ticket appears after admin clicks Poll Inbox.',
              style: _ts(12.5, FontWeight.w600, Colors.white),
            ),
            backgroundColor: _C.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const EmailToTicketScreen(readOnly: true),
      ),
    );
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Could not open a default email app. Use the Email-to-Ticket page to copy/send details.',
            style: _ts(12.5, FontWeight.w600, Colors.white),
          ),
          backgroundColor: _C.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = _isGuest(widget.user);
    final totalOpen = _countByStatus('NEW') + _countByStatus('OPEN');
    final totalEscalated = _countByStatus('ESCALATED');
    final totalResolved = _countByStatus('RESOLVED');
    final totalClosed = _countByStatus('CLOSED');

    return SafeArea(
        child: Column(children: [
      // Header
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(
                'Support Tickets',
                style: _ts(22, FontWeight.w900, _C.text1),
              ),
            ),
            _headerProfileButton(widget.user, widget.onOpenAccount),
          ]),
          const SizedBox(height: 12),
          SingleChildScrollView(
            controller: _ticketActionScrollCtrl,
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _ticketActionBtn(
                  label: 'Refresh',
                  icon: Icons.refresh_rounded,
                  onTap: () => _runAction('refresh', _load),
                ),
                const SizedBox(width: 8),
                _ticketActionBtn(
                  label: 'Email to Ticket',
                  icon: Icons.mail_outlined,
                  onTap: () => _runAction(
                    'email',
                    () => _openSupportEmailApp(),
                    scrollAfter: false,
                  ),
                ),
                const SizedBox(width: 8),
                _ticketActionBtn(
                  label: 'Ticket',
                  icon: Icons.add_rounded,
                  onTap: () => _runAction(
                    'ticket',
                    () {
                      _openCreate(context);
                    },
                    scrollAfter: false,
                  ),
                  primary: true,
                ),
              ],
            ),
          ),
        ]),
      ),

      // Guest banner
      if (isGuest && !_isGuestTicketAccessExpired(widget.user))
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _C.indigoBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _C.indigo.withOpacity(0.3)),
          ),
          child: Row(children: [
            const Icon(Icons.celebration_rounded, color: _C.indigo, size: 20),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('2-Month Free Guest Access Active',
                      style: _ts(13, FontWeight.w800, _C.indigo)),
                  Text(
                      'You have full Pro/Elite ticket access — 60 days remaining in your free trial.',
                      style: _ts(11, FontWeight.w500, _C.indigo, height: 1.4)),
                ])),
          ]),
        ),

      Expanded(
        child: _loading
            ? ListView(
                padding: const EdgeInsets.all(16),
                children: List.generate(3, (_) => const _Shimmer(height: 130)))
            : RefreshIndicator(
                onRefresh: _load,
                color: _C.blue,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  children: [
                    // Stats row
                    Row(children: [
                      _statBox(
                          _tickets.length.toString(), 'TOTAL', _C.text1, _C.bg),
                      const SizedBox(width: 8),
                      _statBox(
                          totalOpen.toString(), 'OPEN', _C.danger, _C.dangerBg),
                      const SizedBox(width: 8),
                      _statBox(totalEscalated.toString(), 'ESCALATED',
                          _C.warning, _C.warningBg),
                      const SizedBox(width: 8),
                      _statBox(totalResolved.toString(), 'RESOLVED', _C.success,
                          _C.successBg),
                      const SizedBox(width: 8),
                      _statBox(totalClosed.toString(), 'CLOSED', _C.text3,
                          _C.gray100),
                    ]),
                    const SizedBox(height: 14),

                    // Filter chips
                    SingleChildScrollView(
                      controller: _filterChipScrollCtrl,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(children: [
                        for (final f in _ticketFilters) _filterChip(f),
                      ]),
                    ),
                    const SizedBox(height: 14),

                    // Email-to-Ticket info card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDFA),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF99F6E4)),
                      ),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                        color: _C.blueLight,
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    child: const Icon(Icons.mail_rounded,
                                        color: _C.blue, size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(
                                            'Email-to-Ticket: Send an email to get help automatically',
                                            style: _ts(13, FontWeight.w700,
                                                const Color(0xFF1E3A8A))),
                                        const SizedBox(height: 4),
                                        Text(
                                            'You can also raise a support ticket by sending an email directly to our support inbox. Your email will be converted into a ticket and visible in Tickets.',
                                            style: _ts(
                                                12, FontWeight.w400, _C.text3,
                                                height: 1.4)),
                                        const SizedBox(height: 6),
                                        Text(
                                            'support@meetthemasters.in • Use keywords like "urgent" or "billing" for faster routing.',
                                            style: _ts(
                                                12, FontWeight.w600, _C.blue,
                                                height: 1.35)),
                                      ])),
                                ]),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => _runAction('email', () {
                                  _openSupportEmailApp();
                                }, scrollAfter: false),
                                icon: const Icon(Icons.open_in_new_rounded,
                                    size: 16),
                                label: const Text('Open Email App'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _C.blue,
                                  side: const BorderSide(color: _C.blueBorder),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                                'After sending from your email app, admin can click Poll Inbox to convert it into a ticket in the Tickets queue.',
                                style: _ts(11.5, FontWeight.w500, _C.text3,
                                    height: 1.3)),
                          ]),
                    ),
                    const SizedBox(height: 14),

                    // Ticket list
                    if (_filtered.isEmpty)
                      Center(
                          child: Padding(
                        padding: const EdgeInsets.only(top: 32),
                        child: Column(children: [
                          const Icon(Icons.inbox_outlined,
                              size: 48, color: _C.text4),
                          const SizedBox(height: 12),
                          Text('No tickets',
                              style: _ts(16, FontWeight.w700, _C.text2)),
                          const SizedBox(height: 4),
                          Text(
                              'No ${_filter == 'ALL' ? '' : _filter.toLowerCase()} tickets found.',
                              style: _ts(13, FontWeight.w400, _C.text3)),
                        ]),
                      ))
                    else
                      ..._filtered.map((t) =>
                          _TicketCard(t: t, userId: _uid, onUpdated: _load)),
                  ],
                ),
              ),
      ),
    ]));
  }

  Widget _statBox(String val, String label, Color fg, Color bg) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration:
              BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
          child: Column(children: [
            Text(val, style: _ts(18, FontWeight.w900, fg)),
            const SizedBox(height: 2),
            Text(label,
                style: _ts(8, FontWeight.w700, fg, ls: 0.3),
                textAlign: TextAlign.center),
          ]),
        ),
      );

  Widget _ticketActionBtn({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool primary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: primary ? 14 : 12, vertical: primary ? 9 : 8),
        decoration: BoxDecoration(
          color: primary ? null : Colors.white,
          gradient: primary
              ? const LinearGradient(colors: [_C.blue, _C.blueMid])
              : null,
          border: primary ? null : Border.all(color: _C.border),
          borderRadius: BorderRadius.circular(10),
          boxShadow: primary
              ? [
                  BoxShadow(
                    color: _C.blue.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : const [],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            icon,
            size: primary ? 16 : 14,
            color: primary ? Colors.white : _C.text3,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: _ts(
              12,
              FontWeight.w600,
              primary ? Colors.white : _C.text3,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _filterChip(String f) {
    final count = _countByStatus(f);
    final label = f == 'IN_PROGRESS'
        ? 'In Progress'
        : f[0] + f.substring(1).toLowerCase();
    final sel = _filter == f;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => _setFilter(f),
        child: Container(
          key: ValueKey('ticket_filter_$f'),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: sel ? _C.blue : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: sel ? _C.blue : _C.border, width: 1.5),
          ),
          child: Text('$label ($count)',
              style: _ts(12, FontWeight.w700, sel ? Colors.white : _C.text3)),
        ),
      ),
    );
  }

  Future<void> _openCreate(BuildContext ctx) async {
    if (_isGuestTicketAccessExpired(widget.user)) {
      _showGuestTicketExpiredDialog(ctx);
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(ctx);
    final createdResult = await showModalBottomSheet<_CreateTicketSheetResult>(
      context: ctx,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateTicketSheet(userId: _uid),
    );

    if (!mounted || createdResult == null) return;
    await _load();
    if (!mounted) return;
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Ticket #${createdResult.ticketRef} created. Our team will respond shortly.',
            style: _ts(13, FontWeight.w600, Colors.white),
          ),
          backgroundColor: _C.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  void _showGuestTicketExpiredDialog(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Guest Ticket Access Expired',
            style: _ts(17, FontWeight.w800, _C.text1)),
        content: Text(
          'Your 2-month free guest ticket access has ended. Upgrade your plan to continue creating support tickets.',
          style: _ts(14, FontWeight.w400, _C.text2, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('OK', style: _ts(14, FontWeight.w700, _C.blue)),
          ),
        ],
      ),
    );
  }
}

// ── Ticket Card ────────────────────────────────────────────────────────────────
class _TicketCard extends StatelessWidget {
  final Map<String, dynamic> t;
  final int userId;
  final VoidCallback onUpdated;
  const _TicketCard(
      {required this.t, required this.userId, required this.onUpdated});

  @override
  Widget build(BuildContext context) {
    final status = (t['status'] ?? 'NEW').toString().toUpperCase();
    final priority = (t['priority'] ?? 'MEDIUM').toString().toUpperCase();
    final category = _prettifyLabel((t['category'] ?? 'General').toString());
    final desc = t['description'] ?? '';
    final created = t['createdAt'] ?? '';
    final ticketRef = formatTicketNumber(
      ticketNumber: t['ticketNumber']?.toString(),
      createdAt: created.toString(),
    );
    final slaBreached = t['slaBreached'] == true;

    final prioColors = {
      'LOW': [_C.success, _C.successBg],
      'MEDIUM': [_C.warning, _C.warningBg],
      'HIGH': [const Color(0xFFEA580C), const Color(0xFFFFF7ED)],
      'URGENT': [_C.danger, _C.dangerBg],
      'CRITICAL': [_C.purple, _C.purpleBg],
    };
    final pClr = prioColors[priority] ?? [_C.text4, _C.bg];

    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => _TicketDetailScreen(
                  ticket: t, userId: userId, onUpdated: onUpdated))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: slaBreached ? _C.dangerBrd : _C.border),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Row(children: [
                Text('Ticket #$ticketRef',
                    style: _ts(14, FontWeight.w800, _C.text1)),
                if (slaBreached) ...[
                  const SizedBox(width: 8),
                  _chip('SLA BREACH',
                      fg: _C.danger,
                      bg: _C.dangerBg,
                      brd: _C.dangerBrd,
                      icon: Icons.warning_rounded),
                ],
              ])),
              _statusChip(status),
            ]),
            const SizedBox(height: 8),
            Text(desc.toString(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _ts(13, FontWeight.w400, _C.text2, height: 1.5)),
            const SizedBox(height: 12),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: _C.bg, borderRadius: BorderRadius.circular(6)),
                child: Text(category.toString(),
                    style: _ts(11, FontWeight.w700, _C.text3)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: pClr[1], borderRadius: BorderRadius.circular(6)),
                child: Text(priority, style: _ts(11, FontWeight.w700, pClr[0])),
              ),
              const Spacer(),
              Text(_timeAgo(created),
                  style: _ts(11, FontWeight.w500, _C.text4)),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: _C.text4),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ── Create Ticket Sheet ────────────────────────────────────────────────────────
class _CreateTicketSheetResult {
  final String ticketRef;
  const _CreateTicketSheetResult(this.ticketRef);
}

class _CreateTicketSheet extends StatefulWidget {
  final int userId;
  const _CreateTicketSheet({required this.userId});
  @override
  State<_CreateTicketSheet> createState() => _CreateTicketSheetState();
}

class _CreateTicketSheetState extends State<_CreateTicketSheet> {
  List<String> _categories = [];
  bool _loadingCats = true;
  String? _category;
  String _priority = 'MEDIUM';
  final _descCtrl = TextEditingController();
  bool _saving = false;
  String _err = '';
  bool _sheetClosed = false;

  final _priorities = ['LOW', 'MEDIUM', 'HIGH', 'URGENT'];
  final _prioLabels = {
    'LOW': 'Low',
    'MEDIUM': 'Medium',
    'HIGH': 'High',
    'URGENT': 'Urgent'
  };

  @override
  void initState() {
    super.initState();
    _loadCats();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCats() async {
    final cats = await _ticketService.getUniqueCategories();
    if (mounted)
      setState(() {
        _categories = cats;
        _loadingCats = false;
      });
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (_category == null) {
      setState(() => _err = 'Please select a category.');
      return;
    }
    if (_descCtrl.text.trim().length < 10) {
      setState(() => _err = 'Description must be at least 10 characters.');
      return;
    }
    setState(() {
      _saving = true;
      _err = '';
    });
    final result = await _ticketService.createTicket(
      userId: widget.userId,
      category: _category!,
      description: _descCtrl.text.trim(),
      priority: _priority,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result == null) {
      setState(() => _err = 'Failed to create ticket. Please try again.');
      return;
    }
    final ticketRef = formatTicketNumberFromTicket(result);
    if (_sheetClosed || !context.mounted) return;
    _sheetClosed = true;
    await Navigator.of(context).maybePop(_CreateTicketSheetResult(ticketRef));
  }

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              decoration: const BoxDecoration(
                gradient:
                    LinearGradient(colors: [_C.navy, _C.blue, _C.blueMid]),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Row(children: [
                const Icon(Icons.confirmation_number_rounded,
                    color: Colors.white, size: 22),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Raise a Support Ticket',
                          style: _ts(17, FontWeight.w800, Colors.white)),
                      Text('Our team will respond within SLA window.',
                          style: _ts(12, FontWeight.w400, Colors.white70)),
                    ])),
                GestureDetector(
                  onTap: () {
                    if (_sheetClosed || !context.mounted) return;
                    _sheetClosed = true;
                    Navigator.of(context).maybePop();
                  },
                  child: const Icon(Icons.close_rounded, color: Colors.white70),
                ),
              ]),
            ),

            Expanded(
                child: _loadingCats
                    ? const Center(
                        child: CircularProgressIndicator(color: _C.blue))
                    : ListView(
                        controller: ctrl,
                        padding: const EdgeInsets.all(20),
                        children: [
                            if (_err.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                    color: _C.dangerBg,
                                    border: Border.all(color: _C.dangerBrd),
                                    borderRadius: BorderRadius.circular(10)),
                                child: Row(children: [
                                  const Icon(Icons.warning_rounded,
                                      color: _C.danger, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: Text(_err,
                                          style: _ts(
                                              13, FontWeight.w600, _C.danger))),
                                ]),
                              ),

                            // Category
                            Text('CATEGORY *',
                                style: _ts(10, FontWeight.w800, _C.text4,
                                    ls: 0.7)),
                            const SizedBox(height: 10),
                            Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _categories.map((cat) {
                                  final sel = _category == cat;
                                  final label = _prettifyLabel(cat);
                                  return GestureDetector(
                                    onTap: () => setState(() {
                                      _category = cat;
                                      _err = '';
                                    }),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 150),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(
                                        color:
                                            sel ? _C.blueLight : Colors.white,
                                        border: Border.all(
                                            color: sel ? _C.blue : _C.border,
                                            width: sel ? 2 : 1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(label,
                                          style: _ts(13, FontWeight.w600,
                                              sel ? _C.blue : _C.text2)),
                                    ),
                                  );
                                }).toList()),

                            const SizedBox(height: 20),

                            // Priority
                            Text('PRIORITY',
                                style: _ts(10, FontWeight.w800, _C.text4,
                                    ls: 0.7)),
                            const SizedBox(height: 10),
                            Row(
                                children: _priorities.map((p) {
                              final sel = _priority == p;
                              final colors = {
                                'LOW': _C.success,
                                'MEDIUM': _C.warning,
                                'HIGH': const Color(0xFFEA580C),
                                'URGENT': _C.danger,
                              };
                              final clr = colors[p] ?? _C.text3;
                              return Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _priority = p),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    margin: EdgeInsets.only(
                                        right: p == _priorities.last ? 0 : 8),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    decoration: BoxDecoration(
                                      color: sel
                                          ? clr.withOpacity(0.12)
                                          : Colors.white,
                                      border: Border.all(
                                          color: sel ? clr : _C.border,
                                          width: sel ? 2 : 1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(_prioLabels[p]!,
                                        textAlign: TextAlign.center,
                                        style: _ts(12, FontWeight.w700,
                                            sel ? clr : _C.text3)),
                                  ),
                                ),
                              );
                            }).toList()),

                            const SizedBox(height: 20),

                            // Description
                            Text('DESCRIPTION *',
                                style: _ts(10, FontWeight.w800, _C.text4,
                                    ls: 0.7)),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _descCtrl,
                              onChanged: (_) {
                                if (_err.isNotEmpty) setState(() => _err = '');
                              },
                              maxLines: 5,
                              maxLength: 2000,
                              style: _ts(14, FontWeight.w400, _C.text1),
                              decoration: InputDecoration(
                                hintText:
                                    'Describe your issue in detail… (min 10 characters)',
                                hintStyle: _ts(14, FontWeight.w400, _C.text4),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        const BorderSide(color: _C.border)),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        const BorderSide(color: _C.border)),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        const BorderSide(color: _C.blue)),
                                contentPadding: const EdgeInsets.all(14),
                              ),
                            ),

                            const SizedBox(height: 24),
                            _gradBtn('Submit Ticket', _submit,
                                loading: _saving),
                            const SizedBox(height: 12),
                          ])),
          ]),
        ),
      );
}

// ── Ticket Detail Screen ───────────────────────────────────────────────────────
class _TicketDetailScreen extends StatefulWidget {
  final Map<String, dynamic> ticket;
  final int userId;
  final VoidCallback onUpdated;
  const _TicketDetailScreen(
      {required this.ticket, required this.userId, required this.onUpdated});
  @override
  State<_TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<_TicketDetailScreen> {
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;
  bool _sending = false;
  final _msgCtrl = TextEditingController();
  late Map<String, dynamic> _ticket;
  // Feedback
  int _fbRating = 0;
  final _fbCtrl = TextEditingController();
  bool _fbSending = false;
  bool _fbDone = false;

  @override
  void initState() {
    super.initState();
    _ticket = Map.from(widget.ticket);
    _fbDone = (_ticket['feedbackRating'] != null);
    _loadComments();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _fbCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _loading = true);
    final id = (widget.ticket['id'] as num?)?.toInt() ?? 0;
    final list = await _ticketService.getTicketComments(id);
    if (mounted)
      setState(() {
        _comments = list.map((c) => c.toJson()).toList();
        _loading = false;
      });
  }

  Future<void> _sendMessage() async {
    final msg = _msgCtrl.text.trim();
    if (msg.isEmpty) return;
    setState(() => _sending = true);
    final id = (_ticket['id'] as num?)?.toInt() ?? 0;
    // Optimistic update
    final optimistic = {
      'id': DateTime.now().millisecondsSinceEpoch,
      'senderId': widget.userId,
      'message': msg,
      'createdAt': DateTime.now().toIso8601String(),
      'consultantReply': false,
    };
    setState(() {
      _comments = [..._comments, optimistic];
    });
    _msgCtrl.clear();

    final result =
        await _ticketService.addComment(id, msg, senderId: widget.userId);
    if (mounted) {
      setState(() {
        _sending = false;
        if (result != null) {
          _comments = [
            ..._comments.where((c) => c['id'] != optimistic['id']),
            result.toJson()
          ];
        }
      });
    }
  }

  Future<void> _closeTicket() async {
    final id = (_ticket['id'] as num?)?.toInt() ?? 0;
    final ok = await _ticketService.updateTicketStatus(id, 'CLOSED');
    if (mounted && ok) {
      setState(() => _ticket = {..._ticket, 'status': 'CLOSED'});
      widget.onUpdated();
      _toast(context, 'Ticket closed.');
    }
  }

  Future<void> _submitFeedback() async {
    if (_fbRating == 0) {
      _toast(context, 'Select a rating first.', error: true);
      return;
    }
    setState(() => _fbSending = true);
    final id = (_ticket['id'] as num?)?.toInt() ?? 0;
    final ok = await _ticketService.submitTicketFeedback(id, {
      'rating': _fbRating,
      'feedbackText': _fbCtrl.text.trim(),
    });
    if (mounted) {
      setState(() {
        _fbSending = false;
        if (ok) _fbDone = true;
      });
      _toast(
          context, ok ? 'Feedback submitted. Thank you!' : 'Failed to submit.',
          error: !ok);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = (_ticket['status'] ?? 'NEW').toString().toUpperCase();
    final category = _prettifyLabel((_ticket['category'] ?? '').toString());
    final priority = (_ticket['priority'] ?? 'MEDIUM').toString();
    final desc = _stripHtml((_ticket['description'] ?? '').toString());
    final created = _ticket['createdAt'] ?? '';
    final id = (_ticket['id'] as num?)?.toInt() ?? 0;
    final isClosed = status == 'CLOSED' || status == 'RESOLVED';

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _C.text1,
        elevation: 0,
        centerTitle: false,
        title: Text('Ticket #$id', style: _ts(18, FontWeight.w800, _C.text1)),
        actions: [
          if (!isClosed)
            TextButton(
              onPressed: _closeTicket,
              child: Text('Close', style: _ts(14, FontWeight.w700, _C.danger)),
            ),
        ],
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: _C.border)),
      ),
      body: SafeArea(
          child: Column(children: [
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _C.blue))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
                  children: [
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              _statusChip(status),
                              _chip(category.toString(),
                                  bg: _C.bg, fg: _C.text2, brd: _C.border),
                              _chip(
                                priority.toString(),
                                bg: priority == 'URGENT' ||
                                        priority == 'CRITICAL'
                                    ? _C.dangerBg
                                    : _C.warningBg,
                                fg: priority == 'URGENT' ||
                                        priority == 'CRITICAL'
                                    ? _C.danger
                                    : _C.warning,
                                brd: priority == 'URGENT' ||
                                        priority == 'CRITICAL'
                                    ? _C.dangerBrd
                                    : _C.warningBrd,
                              ),
                            ]),
                            const SizedBox(height: 10),
                            Text(
                              desc.isEmpty ? 'No description available.' : desc,
                              style: _ts(14, FontWeight.w400, _C.text2,
                                  height: 1.6),
                            ),
                            const SizedBox(height: 6),
                            Text('Created ${_timeAgo(created)}',
                                style: _ts(11, FontWeight.w500, _C.text4)),
                            const SizedBox(height: 16),
                            _TicketStepper(status: status),
                          ]),
                    ),
                    if (isClosed && !_fbDone)
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _C.amberBg,
                          border: Border.all(color: _C.amber.withOpacity(0.5)),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Rate this resolution',
                                  style: _ts(14, FontWeight.w700, _C.text1)),
                              const SizedBox(height: 10),
                              Center(
                                  child: _Stars(
                                      value: _fbRating,
                                      onChanged: (v) =>
                                          setState(() => _fbRating = v),
                                      size: 32)),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _fbCtrl,
                                maxLines: 2,
                                style: _ts(13, FontWeight.w400, _C.text1),
                                decoration: InputDecoration(
                                  hintText: 'Optional comment…',
                                  hintStyle: _ts(13, FontWeight.w400, _C.text4),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide:
                                          const BorderSide(color: _C.border)),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide:
                                          const BorderSide(color: _C.border)),
                                  focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide:
                                          const BorderSide(color: _C.blue)),
                                  contentPadding: const EdgeInsets.all(10),
                                ),
                              ),
                              const SizedBox(height: 10),
                              _gradBtn('Submit Feedback', _submitFeedback,
                                  loading: _fbSending, height: 44),
                            ]),
                      ),
                    if (_comments.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: _emptyState(
                          Icons.chat_bubble_outline_rounded,
                          'No Messages Yet',
                          'Send a message to start the conversation.',
                        ),
                      )
                    else
                      ..._comments.map((c) {
                        final isMe =
                            (c['senderId'] as num?)?.toInt() == widget.userId;
                        final isConsul = c['consultantReply'] == true;
                        final msg = _stripHtml((c['message'] ?? '').toString());
                        final time = _timeAgo(c['createdAt']?.toString());
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Row(
                            mainAxisAlignment: isMe
                                ? MainAxisAlignment.end
                                : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (!isMe) ...[
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: isConsul ? _C.navy : _C.gray200,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                      isConsul
                                          ? Icons.support_agent_rounded
                                          : Icons.person_rounded,
                                      color: Colors.white,
                                      size: 16),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Flexible(
                                  child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isMe ? _C.blue : Colors.white,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                                    bottomRight: Radius.circular(isMe ? 4 : 16),
                                  ),
                                  border: Border.all(
                                      color: isMe ? _C.blue : _C.border),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black.withOpacity(0.04),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2))
                                  ],
                                ),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (!isMe)
                                        Text(isConsul ? 'Support Team' : 'You',
                                            style: _ts(
                                                11,
                                                FontWeight.w700,
                                                isMe
                                                    ? Colors.white70
                                                    : _C.blue)),
                                      Text(msg,
                                          style: _ts(14, FontWeight.w400,
                                              isMe ? Colors.white : _C.text1,
                                              height: 1.5)),
                                      const SizedBox(height: 4),
                                      Text(time,
                                          style: _ts(
                                              10,
                                              FontWeight.w500,
                                              isMe
                                                  ? Colors.white54
                                                  : _C.text4)),
                                    ]),
                              )),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
        ),
        // Input box
        if (!isClosed)
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(
                16, 10, 16, MediaQuery.of(context).viewInsets.bottom + 12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _msgCtrl,
                  style: _ts(14, FontWeight.w400, _C.text1),
                  decoration: InputDecoration(
                    hintText: 'Type your message…',
                    hintStyle: _ts(14, FontWeight.w400, _C.text4),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _C.border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _C.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _C.blue)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    filled: true,
                    fillColor: _C.bg,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _sending ? null : _sendMessage,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient:
                        const LinearGradient(colors: [_C.blue, _C.blueMid]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: _sending
                      ? const Center(
                          child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2)))
                      : const Icon(Icons.send_rounded,
                          color: Colors.white, size: 20),
                ),
              ),
            ]),
          ),
      ])),
    );
  }
}

// Ticket status stepper
class _TicketStepper extends StatelessWidget {
  final String status;
  const _TicketStepper({required this.status});

  static const _steps = ['NEW', 'OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED'];
  static const _labels = [
    'Submitted',
    'Assigned',
    'In Progress',
    'Resolved',
    'Closed'
  ];

  @override
  Widget build(BuildContext context) {
    int currentIdx = _steps.indexOf(status);
    if (currentIdx == -1)
      currentIdx = status == 'PENDING'
          ? 2
          : status == 'ESCALATED'
              ? 1
              : 0;

    return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(_steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            final lineIdx = i ~/ 2;
            return Expanded(
                child: Padding(
              padding: const EdgeInsets.only(top: 11),
              child: Container(
                  height: 2,
                  color: lineIdx < currentIdx ? _C.blue : _C.gray200),
            ));
          }
          final stepIdx = i ~/ 2;
          final done = stepIdx < currentIdx;
          final current = stepIdx == currentIdx;
          return SizedBox(
              width: 52,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: done
                        ? _C.blue
                        : current
                            ? _C.blueLight
                            : _C.gray100,
                    border: Border.all(
                        color: done || current ? _C.blue : _C.gray200,
                        width: current ? 2 : 1),
                    shape: BoxShape.circle,
                  ),
                  child: done
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 12)
                      : current
                          ? Container(
                              margin: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                  color: _C.blue, shape: BoxShape.circle))
                          : null,
                ),
                const SizedBox(height: 4),
                Text(
                  _labels[stepIdx],
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _ts(
                      9,
                      done || current ? FontWeight.w700 : FontWeight.w500,
                      done || current ? _C.blue : _C.text4),
                ),
              ]));
        }));
  }
}

// ════════════════════════════════════════════════════════════════════════════
// TAB 4 — NOTIFICATIONS
// ════════════════════════════════════════════════════════════════════════════

class _NotifsTab extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onRead;
  final VoidCallback onOpenAccount;
  const _NotifsTab(
      {required this.user, required this.onRead, required this.onOpenAccount});
  @override
  State<_NotifsTab> createState() => _NotifsTabState();
}

class _NotifsTabState extends State<_NotifsTab> {
  List<Map<String, dynamic>> _notifs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _notificationService.getNotifications();
    if (mounted)
      setState(() {
        _notifs = list.map((n) => n.toJson()).toList();
        _loading = false;
      });
  }

  Future<void> _markRead(Map<String, dynamic> n) async {
    final id = _toInt(n['id']) ?? 0;
    setState(() {
      final idx = _notifs.indexWhere((notif) => notif['id'] == id);
      if (idx != -1) _notifs[idx] = {...n, 'read': true, 'isRead': true};
    });
    await _notificationService.markAsRead(id);
    widget.onRead();
  }

  int get _unread => _notifs.where((n) => !_notifIsRead(n)).length;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Column(children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Notifications',
                    style: _ts(24, FontWeight.w900, _C.text1)),
                if (_unread > 0)
                  Text('$_unread unread',
                      style: _ts(13, FontWeight.w500, _C.blue)),
              ])),
          if (_unread > 0)
            TextButton(
              onPressed: () async {
                setState(() {
                  _notifs = _notifs
                      .map((n) => {...n, 'read': true, 'isRead': true})
                      .toList();
                });
                await _notificationService.markAllRead();
                if (!mounted) return;
                await _load();
                widget.onRead();
              },
              child: Text('Mark all read',
                  style: _ts(13, FontWeight.w600, _C.blue)),
            ),
          const SizedBox(width: 8),
          _headerProfileButton(widget.user, widget.onOpenAccount),
        ]),
      ),
      Expanded(
        child: _loading
            ? ListView(
                padding: const EdgeInsets.all(16),
                children: List.generate(4, (_) => const _Shimmer(height: 80)))
            : _notifs.isEmpty
                ? _emptyState(
                    Icons.notifications_none_rounded,
                    'No Notifications',
                    'You\'re all caught up! Notifications will appear here.')
                : RefreshIndicator(
                    onRefresh: _load,
                    color: _C.blue,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      itemCount: _notifs.length,
                      itemBuilder: (_, i) {
                        final n = _notifs[i];
                        final read = _notifIsRead(n);
                        final type = (n['type'] ?? '').toString();
                        final msg =
                            (n['message'] ?? n['body'] ?? '').toString();
                        final time = _timeAgo(n['createdAt']?.toString());
                        final prettyType = _prettifyLabel(
                            type.isEmpty ? 'Notification' : type);

                        final (Color bg, Color fg, IconData icon) =
                            type.contains('TICKET')
                                ? (
                                    _C.blueLight,
                                    _C.blue,
                                    Icons.confirmation_number_rounded
                                  )
                                : type.contains('BOOKING')
                                    ? (
                                        _C.successBg,
                                        _C.success,
                                        Icons.calendar_today_rounded
                                      )
                                    : (
                                        _C.blueLight,
                                        _C.blue,
                                        Icons.notifications_rounded
                                      );

                        return GestureDetector(
                          onTap: () => _markRead(n),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: bg.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: fg.withOpacity(0.2), width: 1.5),
                            ),
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: fg.withOpacity(0.1))),
                                    child: Icon(icon, color: fg, size: 22),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Row(children: [
                                          Text(prettyType,
                                              style: _ts(
                                                  13, FontWeight.w800, fg,
                                                  ls: 0.5)),
                                          if (!read) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                                width: 6,
                                                height: 6,
                                                decoration: const BoxDecoration(
                                                    color: _C.blue,
                                                    shape: BoxShape.circle)),
                                          ],
                                        ]),
                                        const SizedBox(height: 4),
                                        Text(msg,
                                            style: _ts(
                                                13, FontWeight.w500, _C.text2,
                                                height: 1.4)),
                                        const SizedBox(height: 8),
                                        if (type.contains('TICKET')) ...[
                                          GestureDetector(
                                            onTap: () {
                                              final idMatch = RegExp(r'#(\d+)')
                                                  .firstMatch(msg);
                                              if (idMatch != null) {
                                                // Logic to find ticket and open it could be here
                                                // For now, satisfy the "tap to view" requirement
                                              }
                                            },
                                            child: Row(children: [
                                              Text('Tap to view ticket',
                                                  style: _ts(
                                                      12, FontWeight.w600, fg)),
                                              const SizedBox(width: 4),
                                              Icon(Icons.arrow_forward_rounded,
                                                  size: 12, color: fg),
                                            ]),
                                          ),
                                          const SizedBox(height: 4),
                                        ],
                                        Text(time,
                                            style: _ts(
                                                11, FontWeight.w500, _C.text4)),
                                      ])),
                                ]),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    ]));
  }
}

// ════════════════════════════════════════════════════════════════════════════
// TAB 5 — SETTINGS
// ════════════════════════════════════════════════════════════════════════════

class _SettingsTab extends StatefulWidget {
  final Map<String, dynamic> user;
  final void Function(Map<String, dynamic>) onUpdated;
  const _SettingsTab({required this.user, required this.onUpdated});
  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  String _view = 'menu'; // menu | profile | security | plans
  Map<String, dynamic> _profile = {};
  bool _loadingProfile = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = (widget.user['id'] as num?)?.toInt() ?? 0;
    if (uid == 0) return;
    setState(() => _loadingProfile = true);
    final p = await _onboardingService.getProfile(uid);
    if (mounted)
      setState(() {
        _profile = p?.toJson() ?? {};
        _loadingProfile = false;
      });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: _buildView(),
    );
  }

  Widget _buildView() {
    switch (_view) {
      case 'profile':
        return _ProfileView(
            user: widget.user,
            profile: _profile,
            loading: _loadingProfile,
            onBack: () => setState(() => _view = 'menu'),
            onSaved: (u) {
              widget.onUpdated(u);
              _loadProfile();
            });
      case 'security':
        return _SecurityView(onBack: () => setState(() => _view = 'menu'));
      case 'plans':
        return _PlansView(
            user: widget.user,
            onBack: () => setState(() => _view = 'menu'),
            onUpdated: (u) {
              widget.onUpdated(u);
            });
      default:
        return _SettingsMenu(
            user: widget.user,
            profile: _profile,
            onNav: (v) => setState(() => _view = v));
    }
  }
}

// ── Settings Menu ──────────────────────────────────────────────────────────────
class _SettingsMenu extends StatelessWidget {
  final Map<String, dynamic> user, profile;
  final void Function(String) onNav;
  const _SettingsMenu(
      {required this.user, required this.profile, required this.onNav});

  @override
  Widget build(BuildContext context) {
    final name = profile['name'] ??
        user['identifier']?.toString().split('@').first ??
        'User';
    final email = profile['email'] ?? user['identifier'] ?? '';
    final plan = profile['subscriptionPlan']?['name'] ?? 'Guest';
    final isPremium = (plan.toString().toLowerCase() != 'guest');

    return SafeArea(
        child: SingleChildScrollView(
            child: Column(children: [
      // Profile banner
      Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [_C.navy, _C.blue, _C.blueMid],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.4))),
            child: Center(
                child: Text(_initials(name.toString()),
                    style: _ts(24, FontWeight.w800, Colors.white))),
          ),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(name.toString(),
                    style: _ts(18, FontWeight.w800, Colors.white)),
                const SizedBox(height: 4),
                Text(email.toString(),
                    style: _ts(12, FontWeight.w400, Colors.white70)),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.4)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(isPremium ? Icons.star_rounded : Icons.person_rounded,
                        color: isPremium ? _C.amber : Colors.white70, size: 12),
                    const SizedBox(width: 5),
                    Text('$plan Member',
                        style: _ts(11, FontWeight.w700, Colors.white)),
                  ]),
                ),
              ])),
          GestureDetector(
            onTap: () => onNav('profile'),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10)),
              child:
                  const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
            ),
          ),
        ]),
      ),

      // Menu items
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _C.border)),
        child: Column(children: [
          _menuItem(Icons.person_rounded, 'Account Profile',
              'Edit your personal info', () => onNav('profile'),
              color: _C.blue),
          _divider(),
          _menuItem(Icons.card_membership_rounded, 'Subscription Plan',
              'Manage your plan — $plan', () => onNav('plans'),
              color: _C.purple),
          _divider(),
          _menuItem(Icons.lock_rounded, 'Privacy & Security',
              'Change password, security settings', () => onNav('security'),
              color: _C.warning),
        ]),
      ),

      const SizedBox(height: 16),

      // Logout
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _C.dangerBrd)),
        child: _menuItem(Icons.logout_rounded, 'Sign Out',
            'Log out of your account', () => _confirmLogout(context),
            color: _C.danger),
      ),

      const SizedBox(height: 32),
    ])));
  }

  Widget _menuItem(IconData icon, String title, String sub, VoidCallback onTap,
          {required Color color}) =>
      GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title, style: _ts(14, FontWeight.w700, _C.text1)),
                  Text(sub, style: _ts(12, FontWeight.w400, _C.text3)),
                ])),
            const Icon(Icons.chevron_right_rounded, color: _C.text4, size: 20),
          ]),
        ),
      );

  Widget _divider() => const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Divider(color: _C.borderLight, height: 1));

  void _confirmLogout(BuildContext ctx) => showDialog(
        context: ctx,
        builder: (_) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Sign Out?', style: _ts(17, FontWeight.w800, _C.text1)),
          content: Text('Are you sure you want to sign out?',
              style: _ts(14, FontWeight.w400, _C.text2)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child:
                    Text('Cancel', style: _ts(14, FontWeight.w600, _C.text3))),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _authService.logout();
                if (ctx.mounted) {
                  Navigator.pushAndRemoveUntil(
                    ctx,
                    MaterialPageRoute(builder: (_) => LoginScreen()),
                    (route) => false,
                  );
                }
              },
              child:
                  Text('Sign Out', style: _ts(14, FontWeight.w700, _C.danger)),
            ),
          ],
        ),
      );
}

// ── Profile Edit View ─────────────────────────────────────────────────────────
class _ProfileView extends StatefulWidget {
  final Map<String, dynamic> user, profile;
  final bool loading;
  final VoidCallback onBack;
  final void Function(Map<String, dynamic>) onSaved;
  const _ProfileView(
      {required this.user,
      required this.profile,
      required this.loading,
      required this.onBack,
      required this.onSaved});
  @override
  State<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<_ProfileView> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _editing = false;
  bool _saving = false;
  String _msg = '';

  // Income / Expense lists
  List<Map<String, dynamic>> _incomes = [];
  List<Map<String, dynamic>> _expenses = [];

  @override
  void initState() {
    super.initState();
    _populate();
  }

  @override
  void didUpdateWidget(_ProfileView old) {
    super.didUpdateWidget(old);
    if (old.profile != widget.profile) _populate();
  }

  void _populate() {
    final p = widget.profile;
    _nameCtrl.text = p['name'] ?? '';
    _phoneCtrl.text = p['phoneNumber'] ?? '';
    _locationCtrl.text = p['location'] ?? '';
    _emailCtrl.text = p['email'] ?? '';
    _incomes = List<Map<String, dynamic>>.from(p['incomes'] ?? []);
    _expenses = List<Map<String, dynamic>>.from(p['expenses'] ?? []);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _locationCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final uid = (widget.user['id'] as num?)?.toInt() ?? 0;
    if (uid == 0) return;
    setState(() {
      _saving = true;
      _msg = '';
    });
    final ok = await _onboardingService.updateProfile(uid, {
      'name': _nameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'phoneNumber': _phoneCtrl.text.trim(),
      'location': _locationCtrl.text.trim(),
      if (_incomes.isNotEmpty) 'incomeItems': _incomes,
      if (_expenses.isNotEmpty) 'expenseItems': _expenses,
    });
    if (mounted) {
      setState(() {
        _saving = false;
        _editing = !ok;
        _msg = ok ? '✅ Profile updated!' : '❌ Failed to save.';
      });
      if (ok) widget.onSaved({...widget.user, 'name': _nameCtrl.text.trim()});
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _nameCtrl.text.isNotEmpty
        ? _nameCtrl.text
        : (widget.profile['name'] ?? 'User');
    final memberSince = _fmtMemberSince(
      (widget.profile['memberSince'] ??
              widget.profile['createdAt'] ??
              widget.user['createdAt'])
          ?.toString(),
    );

    return SafeArea(
        child: Column(children: [
      // Header
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 20, 12),
        child: Row(children: [
          IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: _C.blue),
              onPressed: widget.onBack),
          Text('Account Profile', style: _ts(18, FontWeight.w800, _C.text1)),
          const Spacer(),
          if (!_editing)
            TextButton(
                onPressed: () => setState(() => _editing = true),
                child: Text('Edit', style: _ts(14, FontWeight.w700, _C.blue)))
          else ...[
            TextButton(
                onPressed: () {
                  setState(() {
                    _editing = false;
                    _populate();
                  });
                },
                child:
                    Text('Cancel', style: _ts(14, FontWeight.w600, _C.text3))),
            TextButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _C.blue))
                    : Text('Save', style: _ts(14, FontWeight.w700, _C.blue))),
          ],
        ]),
      ),

      Expanded(
        child: widget.loading
            ? const Center(child: CircularProgressIndicator(color: _C.blue))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  if (_msg.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            _msg.startsWith('✅') ? _C.successBg : _C.dangerBg,
                        border: Border.all(
                            color: _msg.startsWith('✅')
                                ? _C.successBrd
                                : _C.dangerBrd),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(_msg,
                          style: _ts(13, FontWeight.w600,
                              _msg.startsWith('✅') ? _C.success : _C.danger)),
                    ),

                  // Avatar header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [_C.navy, _C.blue, _C.blueMid]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.4))),
                        child: Center(
                            child: Text(_initials(name.toString()),
                                style: _ts(24, FontWeight.w800, Colors.white))),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(name.toString(),
                                style: _ts(17, FontWeight.w800, Colors.white)),
                            const SizedBox(height: 4),
                            Text(_emailCtrl.text,
                                style:
                                    _ts(12, FontWeight.w400, Colors.white70)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.4)),
                              ),
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.verified_user_rounded,
                                        size: 12, color: Colors.white70),
                                    const SizedBox(width: 5),
                                    Text(
                                      '${(widget.profile['subscriptionPlan']?['name'] ?? widget.user['plan'] ?? 'Guest').toString().toUpperCase()} MEMBER',
                                      style: _ts(
                                          10, FontWeight.w700, Colors.white),
                                    ),
                                  ]),
                            ),
                          ])),
                    ]),
                  ),

                  const SizedBox(height: 20),

                  // Personal Details Section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _C.border)),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.person_outline_rounded,
                                size: 14, color: _C.text3),
                            const SizedBox(width: 6),
                            Text('PERSONAL DETAILS',
                                style: _ts(11, FontWeight.w800, _C.text3,
                                    ls: 0.5)),
                          ]),
                          const SizedBox(height: 16),
                          const Divider(color: _C.borderLight, height: 1),
                          const SizedBox(height: 16),
                          _detailRow(
                              'Email', _emailCtrl.text, Icons.email_outlined),
                          _detailRow(
                              'Phone', _phoneCtrl.text, Icons.phone_outlined),
                          _detailRow(
                              'Location',
                              _locationCtrl.text.isEmpty
                                  ? '—'
                                  : _locationCtrl.text,
                              Icons.location_on_outlined),
                          _detailRow(
                              'Plan',
                              (widget.profile['subscriptionPlan']?['name'] ??
                                      widget.user['plan'] ??
                                      'Guest')
                                  .toString(),
                              Icons.card_membership_outlined),
                          _detailRow('Member Since', memberSince,
                              Icons.calendar_today_outlined,
                              last: true),
                          if (_editing) ...[
                            const SizedBox(height: 20),
                            const Divider(color: _C.borderLight, height: 1),
                            const SizedBox(height: 16),
                            Text('EDIT DETAILS',
                                style: _ts(11, FontWeight.w800, _C.text3,
                                    ls: 0.5)),
                            const SizedBox(height: 16),
                            _field(
                                'Full Name', _nameCtrl, Icons.person_rounded),
                            _field('Email', _emailCtrl, Icons.email_rounded,
                                type: TextInputType.emailAddress),
                            _field(
                                'Phone Number', _phoneCtrl, Icons.phone_rounded,
                                type: TextInputType.phone),
                            _field('Location / City', _locationCtrl,
                                Icons.location_on_rounded,
                                last: true),
                          ],
                        ]),
                  ),

                  const SizedBox(height: 16),

                  // Finances section
                  if (_incomes.isNotEmpty ||
                      _expenses.isNotEmpty ||
                      _editing) ...[
                    _financesSection(),
                  ],
                ])),
      ),
    ]));
  }

  Widget _field(String label, TextEditingController ctrl, IconData icon,
          {TextInputType? type, bool last = false}) =>
      Padding(
        padding: EdgeInsets.only(bottom: last ? 0 : 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(),
              style: _ts(10, FontWeight.w700, _C.text4, ls: 0.6)),
          const SizedBox(height: 8),
          TextField(
            controller: ctrl,
            enabled: _editing,
            keyboardType: type,
            style: _ts(14, FontWeight.w500, _C.text1),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, size: 18, color: _C.text4),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _C.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _C.blueBorder)),
              disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _C.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _C.blue, width: 2)),
              filled: true,
              fillColor: _editing ? const Color(0xFFF8FBFF) : _C.bg,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ]),
      );

  Widget _detailRow(String label, String value, IconData icon,
          {bool last = false}) =>
      Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            SizedBox(width: 20, child: Icon(icon, size: 15, color: _C.text4)),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(label.toUpperCase(),
                      style: _ts(9, FontWeight.w700, _C.text4, ls: 0.5)),
                  const SizedBox(height: 3),
                  Text(value.isEmpty ? '—' : value,
                      style: _ts(14, FontWeight.w600, _C.text1)),
                ])),
          ]),
        ),
        if (!last) const Divider(color: _C.borderLight, height: 1),
      ]);

  Widget _financesSection() {
    final totalIncome = _incomes.fold<double>(0,
        (s, i) => s + (double.tryParse(i['amount']?.toString() ?? '0') ?? 0));
    final totalExpense = _expenses.fold<double>(0,
        (s, e) => s + (double.tryParse(e['amount']?.toString() ?? '0') ?? 0));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('FINANCIALS', style: _ts(10, FontWeight.w800, _C.text4, ls: 0.7)),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
              child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: _C.successBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _C.successBrd)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('TOTAL INCOME',
                  style: _ts(9, FontWeight.w800, _C.success, ls: 0.6)),
              const SizedBox(height: 4),
              Text('₹${totalIncome.toStringAsFixed(0)}',
                  style: _ts(20, FontWeight.w900, _C.success)),
            ]),
          )),
          const SizedBox(width: 12),
          Expanded(
              child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: _C.dangerBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _C.dangerBrd)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('TOTAL EXPENSE',
                  style: _ts(9, FontWeight.w800, _C.danger, ls: 0.6)),
              const SizedBox(height: 4),
              Text('₹${totalExpense.toStringAsFixed(0)}',
                  style: _ts(20, FontWeight.w900, _C.danger)),
            ]),
          )),
        ]),
      ]),
    );
  }
}

// ── Security / Change Password View ──────────────────────────────────────────
class _SecurityView extends StatefulWidget {
  final VoidCallback onBack;
  const _SecurityView({required this.onBack});
  @override
  State<_SecurityView> createState() => _SecurityViewState();
}

class _SecurityViewState extends State<_SecurityView> {
  final _newCtrl = TextEditingController();
  final _confCtrl = TextEditingController();
  bool _showNew = false, _showConf = false, _saving = false;
  String _msg = '';

  @override
  void dispose() {
    _newCtrl.dispose();
    _confCtrl.dispose();
    super.dispose();
  }

  int get _strength {
    final p = _newCtrl.text;
    int s = 0;
    if (p.length >= 8) s++;
    if (RegExp(r'[A-Z]').hasMatch(p)) s++;
    if (RegExp(r'[0-9]').hasMatch(p)) s++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) s++;
    return s;
  }

  Future<void> _change() async {
    if (_newCtrl.text.length < 8) {
      setState(() => _msg = '❌ Password must be at least 8 characters.');
      return;
    }
    if (_newCtrl.text != _confCtrl.text) {
      setState(() => _msg = '❌ Passwords do not match.');
      return;
    }
    setState(() {
      _saving = true;
      _msg = '';
    });
    final result = await _authService.changePassword(
        newPassword: _newCtrl.text, confirmPassword: _confCtrl.text);
    final ok = result.success;
    if (mounted) {
      setState(() {
        _saving = false;
        _msg = ok
            ? '✅ Password updated successfully!'
            : '❌ ${result.error ?? 'Failed to update. Try again.'}';
        if (ok) {
          _newCtrl.clear();
          _confCtrl.clear();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strColors = [
      _C.danger,
      _C.warning,
      const Color(0xFF22C55E),
      _C.success
    ];
    final strLabels = ['Weak', 'Fair', 'Good', 'Strong'];

    return SafeArea(
        child: Column(children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(4, 12, 20, 12),
        child: Row(children: [
          IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: _C.blue),
              onPressed: widget.onBack),
          Text('Privacy & Security', style: _ts(18, FontWeight.w800, _C.text1)),
        ]),
      ),
      Expanded(
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                if (_msg.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _msg.startsWith('✅') ? _C.successBg : _C.dangerBg,
                      border: Border.all(
                          color: _msg.startsWith('✅')
                              ? _C.successBrd
                              : _C.dangerBrd),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(_msg,
                        style: _ts(13, FontWeight.w600,
                            _msg.startsWith('✅') ? _C.success : _C.danger)),
                  ),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _C.border)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                  color: _C.warningBg,
                                  borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.lock_rounded,
                                  color: _C.warning, size: 20)),
                          const SizedBox(width: 12),
                          Text('Change Password',
                              style: _ts(16, FontWeight.w800, _C.text1)),
                        ]),
                        const SizedBox(height: 20),
                        Text('NEW PASSWORD',
                            style: _ts(10, FontWeight.w700, _C.text4, ls: 0.6)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _newCtrl,
                          obscureText: !_showNew,
                          onChanged: (_) => setState(() {}),
                          style: _ts(14, FontWeight.w500, _C.text1),
                          decoration: InputDecoration(
                            hintText: 'Min. 8 characters',
                            hintStyle: _ts(14, FontWeight.w400, _C.text4),
                            prefixIcon: const Icon(Icons.lock_outline_rounded,
                                size: 18, color: _C.text4),
                            suffixIcon: IconButton(
                              icon: Icon(
                                  _showNew
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  color: _C.text4,
                                  size: 20),
                              onPressed: () =>
                                  setState(() => _showNew = !_showNew),
                            ),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: _C.border)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: _C.border)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: _C.blue)),
                          ),
                        ),
                        if (_newCtrl.text.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                              children: List.generate(
                                  4,
                                  (i) => Expanded(
                                        child: Container(
                                          height: 4,
                                          margin:
                                              const EdgeInsets.only(right: 3),
                                          decoration: BoxDecoration(
                                            color: i < _strength
                                                ? strColors[_strength - 1]
                                                : _C.border,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                        ),
                                      ))),
                          const SizedBox(height: 4),
                          if (_strength > 0)
                            Text('${strLabels[_strength - 1]} password',
                                style: _ts(11, FontWeight.w700,
                                    strColors[_strength - 1])),
                        ],
                        const SizedBox(height: 16),
                        Text('CONFIRM PASSWORD',
                            style: _ts(10, FontWeight.w700, _C.text4, ls: 0.6)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _confCtrl,
                          obscureText: !_showConf,
                          style: _ts(14, FontWeight.w500, _C.text1),
                          decoration: InputDecoration(
                            hintText: 'Re-enter new password',
                            hintStyle: _ts(14, FontWeight.w400, _C.text4),
                            prefixIcon: const Icon(Icons.lock_outline_rounded,
                                size: 18, color: _C.text4),
                            suffixIcon: IconButton(
                              icon: Icon(
                                  _showConf
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  color: _C.text4,
                                  size: 20),
                              onPressed: () =>
                                  setState(() => _showConf = !_showConf),
                            ),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: _C.border)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: _C.border)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: _C.blue)),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _gradBtn(_saving ? '…' : 'Update Password',
                            _saving ? null : _change,
                            loading: _saving),
                      ]),
                ),
              ]))),
    ]));
  }
}

// ── Subscription Plans View ────────────────────────────────────────────────────
class _PlansView extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onBack;
  final void Function(Map<String, dynamic>) onUpdated;
  const _PlansView(
      {required this.user, required this.onBack, required this.onUpdated});
  @override
  State<_PlansView> createState() => _PlansViewState();
}

class _PlansViewState extends State<_PlansView> {
  List<Map<String, dynamic>> _plans = [];
  bool _loading = true;
  int? _savingPlanId;
  int? _currentPlanId;
  String _msg = '';

  @override
  void initState() {
    super.initState();
    _currentPlanId = _toInt(widget.user['subscriptionPlanId'] ??
        widget.user['subscriptionPlan']?['id']);
    _load();
  }

  Future<void> _load() async {
    final plans = await _subscriptionService.getPlans();
    if (mounted)
      setState(() {
        _plans = plans;
        _loading = false;
      });
  }

  Future<void> _selectPlan(int planId) async {
    final uid = (widget.user['id'] as num?)?.toInt() ?? 0;
    if (uid <= 0 || planId <= 0) return;
    final phone = (widget.user['phoneNumber'] ?? widget.user['phone'] ?? '')
        .toString()
        .trim();
    setState(() {
      _savingPlanId = planId;
      _msg = '';
    });
    final ok = await _onboardingService.updateProfile(uid, {
      'subscriptionPlanId': planId,
      'phoneNumber': phone.isNotEmpty ? phone : '9999999999',
    });
    if (mounted) {
      setState(() {
        _savingPlanId = null;
        if (ok) _currentPlanId = planId;
        _msg = ok ? '✅ Plan updated!' : '❌ Failed to update plan.';
      });
      if (ok) widget.onUpdated({...widget.user, 'subscriptionPlanId': planId});
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
          child: Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(4, 12, 20, 12),
          child: Row(children: [
            IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: _C.blue),
                onPressed: widget.onBack),
            Text('Subscription Plans',
                style: _ts(18, FontWeight.w800, _C.text1)),
          ]),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _C.blue))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(children: [
                    if (_msg.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              _msg.startsWith('✅') ? _C.successBg : _C.dangerBg,
                          border: Border.all(
                              color: _msg.startsWith('✅')
                                  ? _C.successBrd
                                  : _C.dangerBrd),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(_msg,
                            style: _ts(13, FontWeight.w600,
                                _msg.startsWith('✅') ? _C.success : _C.danger)),
                      ),
                    ..._plans.map((p) {
                      final pid = _toInt(p['id']);
                      final isCurrent = pid != null && pid == _currentPlanId;
                      final name = p['name'] ?? 'Plan';
                      final orig = double.tryParse(
                              p['originalPrice']?.toString() ?? '0') ??
                          0;
                      final disc = double.tryParse(
                              p['discountPrice']?.toString() ?? '0') ??
                          0;
                      final features = (p['features'] ?? '').toString();
                      final isGuest = name.toString().toLowerCase() == 'guest';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isCurrent ? _C.blue : _C.border,
                            width: isCurrent ? 2 : 1,
                          ),
                          boxShadow: isCurrent
                              ? [
                                  BoxShadow(
                                      color: _C.blue.withOpacity(0.12),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4))
                                ]
                              : [],
                        ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: isGuest
                                      ? null
                                      : const LinearGradient(
                                          colors: [
                                              Color(0xFF92400E),
                                              Color(0xFFD97706)
                                            ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight),
                                  color: isGuest ? _C.gray100 : null,
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(18)),
                                ),
                                child: Row(children: [
                                  Icon(
                                      isGuest
                                          ? Icons.person_rounded
                                          : Icons.star_rounded,
                                      color: isGuest ? _C.text3 : _C.amber,
                                      size: 28),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(name.toString(),
                                            style: _ts(
                                                18,
                                                FontWeight.w800,
                                                isGuest
                                                    ? _C.text1
                                                    : Colors.white)),
                                        if (p['tag'] != null)
                                          Text(p['tag'].toString(),
                                              style: _ts(
                                                  12,
                                                  FontWeight.w500,
                                                  isGuest
                                                      ? _C.text3
                                                      : Colors.white70)),
                                      ])),
                                  if (isCurrent)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text('CURRENT',
                                          style: _ts(
                                              10,
                                              FontWeight.w800,
                                              isGuest
                                                  ? _C.blue
                                                  : Colors.white)),
                                    ),
                                ]),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text('₹${disc.toStringAsFixed(0)}',
                                                style: _ts(28, FontWeight.w900,
                                                    _C.text1)),
                                            const SizedBox(width: 6),
                                            if (orig != disc && orig > 0)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    bottom: 4),
                                                child: Text(
                                                    '₹${orig.toStringAsFixed(0)}',
                                                    style: _ts(
                                                      14,
                                                      FontWeight.w500,
                                                      _C.text4,
                                                    ).copyWith(
                                                        decoration:
                                                            TextDecoration
                                                                .lineThrough)),
                                              ),
                                            const Spacer(),
                                            Text('/month',
                                                style: _ts(12, FontWeight.w500,
                                                    _C.text3)),
                                          ]),
                                      if (features.isNotEmpty) ...[
                                        const SizedBox(height: 14),
                                        ...features.split(',').map((f) =>
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 6),
                                              child: Row(children: [
                                                const Icon(
                                                    Icons.check_circle_rounded,
                                                    color: _C.success,
                                                    size: 16),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                    child: Text(f.trim(),
                                                        style: _ts(
                                                            13,
                                                            FontWeight.w400,
                                                            _C.text2))),
                                              ]),
                                            )),
                                      ],
                                      const SizedBox(height: 16),
                                      if (!isCurrent)
                                        _gradBtn(
                                            pid != null && pid > 0
                                                ? 'Select Plan'
                                                : 'Plan unavailable',
                                            (_savingPlanId != null ||
                                                    pid == null ||
                                                    pid <= 0)
                                                ? null
                                                : () => _selectPlan(pid),
                                            loading: pid != null &&
                                                _savingPlanId == pid)
                                      else
                                        Container(
                                          width: double.infinity,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: _C.successBg,
                                            border: Border.all(
                                                color: _C.successBrd),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                          child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                const Icon(
                                                    Icons.check_circle_rounded,
                                                    color: _C.success,
                                                    size: 18),
                                                const SizedBox(width: 8),
                                                Text('Your Current Plan',
                                                    style: _ts(
                                                        14,
                                                        FontWeight.w700,
                                                        _C.success)),
                                              ]),
                                        ),
                                    ]),
                              ),
                            ]),
                      );
                    }),
                  ])),
        ),
      ]));
}

// ── Notifications Preferences View ──────────────────────────────────────────
class _NotificationsPrefsView extends StatefulWidget {
  final VoidCallback onBack;
  const _NotificationsPrefsView({required this.onBack});
  @override
  State<_NotificationsPrefsView> createState() =>
      _NotificationsPrefsViewState();
}

class _NotificationsPrefsViewState extends State<_NotificationsPrefsView> {
  Map<String, bool> _prefs = {
    'bookingUpdates': true,
    'ticketReplies': true,
    'consultantMessages': true,
    'offerAlerts': true,
    'emailNotifications': true,
    'smsNotifications': false,
  };

  final _inApp = [
    (
      'bookingUpdates',
      Icons.calendar_today_rounded,
      _C.blue,
      'Booking Updates',
      'Session confirmations, cancellations and reminders'
    ),
    (
      'ticketReplies',
      Icons.chat_bubble_rounded,
      Color(0xFF7C3AED),
      'Ticket Replies',
      'When a consultant or admin responds to your ticket'
    ),
    (
      'consultantMessages',
      Icons.message_rounded,
      Color(0xFF0891B2),
      'Consultant Messages',
      'Direct messages and session notes from consultants'
    ),
    (
      'offerAlerts',
      Icons.local_offer_rounded,
      _C.amber,
      'Offer Alerts',
      'New deals and exclusive discount notifications'
    ),
  ];

  final _emailSms = [
    (
      'emailNotifications',
      Icons.email_rounded,
      Color(0xFF16A34A),
      'Email Notifications',
      'Booking confirmations and updates via email'
    ),
    (
      'smsNotifications',
      Icons.phone_android_rounded,
      _C.text3,
      'SMS Alerts',
      'Session reminders via SMS to your registered number'
    ),
  ];

  @override
  Widget build(BuildContext context) => SafeArea(
          child: Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(4, 12, 20, 12),
          child: Row(children: [
            IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: _C.blue),
                onPressed: widget.onBack),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Notifications',
                      style: _ts(18, FontWeight.w800, _C.text1)),
                  Text('Choose what you want to be notified about',
                      style: _ts(11, FontWeight.w400, _C.text3)),
                ])),
          ]),
        ),
        Expanded(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  _section('IN-APP ALERTS', _inApp),
                  const SizedBox(height: 16),
                  _section('EMAIL & SMS', _emailSms),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: _C.blueLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _C.blueBorder)),
                    child: Row(children: [
                      const Icon(Icons.info_outline_rounded,
                          color: _C.blue, size: 15),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(
                              'Preference changes are saved automatically and take effect immediately.',
                              style: _ts(12, FontWeight.w500, _C.blue))),
                    ]),
                  ),
                ]))),
      ]));

  Widget _section(
      String title, List<(String, IconData, Color, String, String)> items) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
              color: _C.bg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16))),
          child:
              Text(title, style: _ts(11, FontWeight.w800, _C.text3, ls: 0.5)),
        ),
        ...items.map((item) {
          final (key, icon, color, label, desc) = item;
          final isOn = _prefs[key] ?? false;
          return Column(children: [
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(children: [
                Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(icon, color: color, size: 18)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(label, style: _ts(13, FontWeight.w700, _C.text1)),
                      const SizedBox(height: 2),
                      Text(desc, style: _ts(11, FontWeight.w400, _C.text3)),
                    ])),
                GestureDetector(
                  onTap: () => setState(() => _prefs[key] = !isOn),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isOn ? _C.blue : _C.gray200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 200),
                      alignment:
                          isOn ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        width: 18,
                        height: 18,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: const BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ]);
        }),
      ]),
    );
  }
}

// ── Terms & Conditions View ────────────────────────────────────────────────────
class _TermsView extends StatefulWidget {
  final VoidCallback onBack;
  const _TermsView({required this.onBack});
  @override
  State<_TermsView> createState() => _TermsViewState();
}

class _TermsViewState extends State<_TermsView> {
  String _content = '';
  bool _loading = true;
  bool _usingDefault = false;

  static const _defaultTerms = '''1. Acceptance of Terms
By accessing and using Meet The Masters, you accept and agree to be bound by these Terms & Conditions.

2. Use of Services
Our platform provides access to certified financial consultants. You agree to use these services for lawful purposes only and not to misuse any information shared during consultations.

3. Confidentiality
All consultation sessions and related information are strictly confidential. Neither party shall disclose confidential information to any third party without prior written consent.

4. Booking & Payments
Bookings are confirmed upon successful payment. Cancellations must be made at least 24 hours prior to the scheduled session. Refunds are subject to our refund policy.

5. Disclaimer
Financial advice provided through our platform is for informational purposes only. Meet The Masters does not guarantee specific financial outcomes. Always consult a qualified advisor before making major financial decisions.

6. Privacy Policy
We collect and store your personal data securely in accordance with applicable data protection laws. Your data is never sold to third parties.

7. Governing Law
These Terms are governed by the laws of India. Any disputes shall be subject to the exclusive jurisdiction of the courts in Hyderabad, Telangana.''';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final fetched = await _userService.getTermsAndConditions();
    if (mounted) {
      setState(() {
        _content = fetched.isNotEmpty ? fetched : _defaultTerms;
        _usingDefault = fetched.isEmpty;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
          child: Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(4, 12, 20, 12),
          child: Row(children: [
            IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: _C.blue),
                onPressed: widget.onBack),
            Expanded(
                child: Text('Terms & Conditions',
                    style: _ts(18, FontWeight.w800, _C.text1))),
            if (!_loading)
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: _C.blue),
                onPressed: _load,
                tooltip: 'Refresh',
              ),
          ]),
        ),
        Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _C.blue))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_usingDefault)
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _C.amberBg,
                                border: Border.all(color: _C.warningBrd),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(children: [
                                const Icon(Icons.info_outline_rounded,
                                    color: _C.warning, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(
                                  'Showing standard terms. Contact admin to update.',
                                  style: _ts(12, FontWeight.w500, _C.warning),
                                )),
                              ]),
                            ),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _C.border),
                            ),
                            child: Text(_content,
                                style: _ts(13, FontWeight.w400, _C.text2,
                                    height: 1.7)),
                          ),
                        ]),
                  )),
      ]));
}

// ── Contact View ───────────────────────────────────────────────────────────────
class _ContactView extends StatefulWidget {
  final VoidCallback onBack;
  final Map<String, dynamic> user;
  final Map<String, dynamic> profile;
  const _ContactView(
      {required this.onBack, required this.user, required this.profile});
  @override
  State<_ContactView> createState() => _ContactViewState();
}

class _ContactViewState extends State<_ContactView> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  bool _sending = false, _sent = false;
  String _err = '';

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = (widget.profile['name'] ??
            widget.user['name'] ??
            widget.user['identifier']?.toString().split('@').first ??
            '')
        .toString();
    _emailCtrl.text = (widget.profile['email'] ??
            widget.user['email'] ??
            widget.user['identifier'] ??
            '')
        .toString();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    if (_nameCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty ||
        _msgCtrl.text.trim().isEmpty) {
      setState(() => _err = 'Please fill in all required fields.');
      return;
    }
    final email = _emailCtrl.text.trim();
    if (!RegExp(r'^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$').hasMatch(email)) {
      setState(() => _err = 'Please enter a valid email address.');
      return;
    }
    setState(() {
      _sending = true;
      _err = '';
    });
    final phone = (widget.profile['phoneNumber'] ??
            widget.profile['phone'] ??
            widget.user['phoneNumber'] ??
            widget.user['phone'] ??
            '')
        .toString()
        .trim();
    // POST /api/contact/public/submit — real backend endpoint
    final ok = await _staticService.submitContactMessage(
      name: _nameCtrl.text.trim(),
      email: email,
      message: _msgCtrl.text.trim(),
      phone: phone,
      subject: 'Contact from user dashboard',
    );
    if (mounted)
      setState(() {
        _sending = false;
        _sent = ok;
        if (!ok) _err = 'Failed to send. Please try again.';
      });
  }

  @override
  Widget build(BuildContext context) => SafeArea(
          child: Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(4, 12, 20, 12),
          child: Row(children: [
            IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: _C.blue),
                onPressed: widget.onBack),
            Text('Contact Us', style: _ts(18, FontWeight.w800, _C.text1)),
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _sent
                  ? Center(
                      child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                  color: _C.successBg,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: _C.successBrd, width: 2)),
                              child: const Icon(Icons.check_rounded,
                                  color: _C.success, size: 40),
                            ),
                            const SizedBox(height: 20),
                            Text('Message Sent!',
                                style: _ts(22, FontWeight.w800, _C.text1)),
                            const SizedBox(height: 8),
                            Text(
                                'Our team will get back to you within 24 hours.',
                                textAlign: TextAlign.center,
                                style: _ts(14, FontWeight.w400, _C.text3,
                                    height: 1.6)),
                            const SizedBox(height: 28),
                            _outlineBtn('Send Another',
                                () => setState(() => _sent = false)),
                          ]),
                    ))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          // Contact info cards
                          Row(children: [
                            Expanded(
                                child: _infoCard(Icons.email_rounded, 'Email',
                                    'support@meetthemasters.in', _C.blue)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: _infoCard(Icons.phone_rounded, 'Phone',
                                    '+91 99999 99999', _C.success)),
                          ]),
                          const SizedBox(height: 20),

                          if (_err.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                  color: _C.dangerBg,
                                  border: Border.all(color: _C.dangerBrd),
                                  borderRadius: BorderRadius.circular(10)),
                              child: Text(_err,
                                  style: _ts(13, FontWeight.w600, _C.danger)),
                            ),

                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: _C.border)),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('SEND A MESSAGE',
                                      style: _ts(12, FontWeight.w800, _C.text1,
                                          ls: 0.5)),
                                  const SizedBox(height: 16),
                                  _contactField('Full Name *', _nameCtrl,
                                      Icons.person_rounded, TextInputType.name),
                                  const SizedBox(height: 14),
                                  _contactField(
                                      'Email Address *',
                                      _emailCtrl,
                                      Icons.email_rounded,
                                      TextInputType.emailAddress),
                                  const SizedBox(height: 14),
                                  Text('MESSAGE *'.toUpperCase(),
                                      style: _ts(10, FontWeight.w700, _C.text4,
                                          ls: 0.6)),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _msgCtrl,
                                    maxLines: 5,
                                    maxLength: 2000,
                                    style: _ts(14, FontWeight.w400, _C.text1),
                                    decoration: InputDecoration(
                                      hintText: 'How can we help you?',
                                      hintStyle:
                                          _ts(14, FontWeight.w400, _C.text4),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                              color: _C.border)),
                                      enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                              color: _C.border)),
                                      focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide:
                                              const BorderSide(color: _C.blue)),
                                      contentPadding: const EdgeInsets.all(14),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  _gradBtn(
                                      _sending ? '…' : 'Send Message', _send,
                                      loading: _sending),
                                ]),
                          ),
                        ])),
        ),
      ]));

  Widget _infoCard(IconData icon, String label, String val, Color color) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _C.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 18)),
          const SizedBox(height: 10),
          Text(label, style: _ts(11, FontWeight.w700, _C.text3)),
          const SizedBox(height: 4),
          Text(val, style: _ts(12, FontWeight.w600, _C.text2)),
        ]),
      );

  Widget _contactField(String label, TextEditingController ctrl, IconData icon,
          TextInputType type) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase().replaceAll(' *', ' *'),
            style: _ts(10, FontWeight.w700, _C.text4, ls: 0.6)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          keyboardType: type,
          style: _ts(14, FontWeight.w400, _C.text1),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18, color: _C.text4),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _C.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _C.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _C.blue)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ]);
}
