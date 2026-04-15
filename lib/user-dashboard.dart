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
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ════════════════════════════════════════════════════════════════════════════
// DESIGN SYSTEM — Colors, Text Styles, Common Widgets
// ════════════════════════════════════════════════════════════════════════════

class _C {
  // Brand
  static const navy        = Color(0xFF1E3A5F);
  static const blue        = Color(0xFF2563EB);
  static const blueDeep    = Color(0xFF1D4ED8);
  static const blueMid     = Color(0xFF3B82F6);
  static const blueLight   = Color(0xFFEFF6FF);
  static const blueBorder  = Color(0xFFBFDBFE);
  // Background
  static const bg          = Color(0xFFF8FAFC);
  static const bgDark      = Color(0xFFF1F5F9);
  static const surface     = Colors.white;
  // Borders
  static const border      = Color(0xFFE2E8F0);
  static const borderLight = Color(0xFFF1F5F9);
  // Text
  static const text1       = Color(0xFF0F172A);
  static const text2       = Color(0xFF334155);
  static const text3       = Color(0xFF64748B);
  static const text4       = Color(0xFF94A3B8);
  // Status
  static const success     = Color(0xFF16A34A);
  static const successBg   = Color(0xFFF0FDF4);
  static const successBrd  = Color(0xFF86EFAC);
  static const warning     = Color(0xFFD97706);
  static const warningBg   = Color(0xFFFFFBEB);
  static const warningBrd  = Color(0xFFFCD34D);
  static const danger      = Color(0xFFDC2626);
  static const dangerBg    = Color(0xFFFEF2F2);
  static const dangerBrd   = Color(0xFFFECACA);
  static const amber       = Color(0xFFF59E0B);
  static const amberBg     = Color(0xFFFEF3C7);
  static const purple      = Color(0xFF7C3AED);
  static const purpleBg    = Color(0xFFF5F3FF);
  static const indigo      = Color(0xFF6366F1);
  static const indigoBg    = Color(0xFFEEF2FF);
  // Gray
  static const gray50      = Color(0xFFF8FAFC);
  static const gray100     = Color(0xFFF1F5F9);
  static const gray200     = Color(0xFFE2E8F0);
  static const gray500     = Color(0xFF64748B);
}

TextStyle _ts(double sz, FontWeight w, Color c, {double ls = 0, double? height}) =>
    GoogleFonts.inter(fontSize: sz, fontWeight: w, color: c, letterSpacing: ls, height: height);

// ════════════════════════════════════════════════════════════════════════════
// API CLIENT — Swagger spec exact endpoints
// ════════════════════════════════════════════════════════════════════════════

class _Api {
  static const _base = 'http://52.55.178.31:8081/api';
  static final _storage = const FlutterSecureStorage();

  static final _dio = Dio(BaseOptions(
    baseUrl: _base,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
  ));

  static bool _interceptorAdded = false;

  /// Call once after login with JWT token
  static Future<void> init(String token) async {
    _dio.options.headers['Authorization'] = 'Bearer $token';
    if (!_interceptorAdded) {
      _interceptorAdded = true;
      _dio.interceptors.add(InterceptorsWrapper(
        onRequest: (opts, handler) async {
          // FIX: Changed 'fin_token' to 'jwt_token' to match login screen
          final t = await _storage.read(key: 'jwt_token');
          if (t != null) opts.headers['Authorization'] = 'Bearer $t';
          handler.next(opts);
        },
        onError: (e, handler) {
          debugPrint('[API ERROR] ${e.requestOptions.path}: ${e.message}');
          handler.next(e);
        },
      ));
    }
  }

  static List<Map<String, dynamic>> _asList(dynamic d) {
    if (d == null) return [];
    if (d is List) return d.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    if (d is Map) {
      final content = d['content'] ?? d['data'] ?? d['items'] ?? d['bookings'];
      if (content is List) return content.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  static Map<String, dynamic> _asMap(dynamic d) =>
      d is Map ? Map<String, dynamic>.from(d) : {};

  // ── Auth / User ──────────────────────────────────────────────────────────
  /// GET /api/users/me
  static Future<Map<String, dynamic>?> getMe() async {
    try { final r = await _dio.get('/users/me'); return _asMap(r.data); }
    catch (_) { return null; }
  }

  /// PUT /api/users/change-password  body: { newPassword, confirmPassword }
  static Future<bool> changePassword(String newPass) async {
    try {
      await _dio.put('/users/change-password', data: {'newPassword': newPass, 'confirmPassword': newPass});
      return true;
    } catch (_) { return false; }
  }

  // ── Onboarding / Profile ─────────────────────────────────────────────────
  /// GET /api/onboarding/{id}
  static Future<Map<String, dynamic>?> getOnboarding(int userId) async {
    try { final r = await _dio.get('/onboarding/$userId'); return _asMap(r.data); }
    catch (_) { return null; }
  }

  /// PUT /api/onboarding/{id}  multipart: data (JSON) + optional file
  static Future<bool> updateOnboarding(int userId, Map<String, dynamic> body) async {
    try {
      final fd = FormData.fromMap({
        'data': jsonEncode(body),
      });
      await _dio.put('/onboarding/$userId',
          data: fd, options: Options(contentType: 'multipart/form-data'));
      return true;
    } catch (_) { return false; }
  }

  // ── Subscription Plans ───────────────────────────────────────────────────
  /// GET /api/subscription-plans
  static Future<List<Map<String, dynamic>>> getPlans() async {
    try { final r = await _dio.get('/subscription-plans'); return _asList(r.data); }
    catch (_) { return []; }
  }

  // ── Fee Config ───────────────────────────────────────────────────────────
  /// GET /api/admin/settings/public/fee-config  (public endpoint)
  static Future<Map<String, dynamic>?> getFeeConfig() async {
    try { final r = await _dio.get('/admin/settings/public/fee-config'); return _asMap(r.data); }
    catch (_) { return null; }
  }

  // ── Consultants ──────────────────────────────────────────────────────────
  /// GET /api/consultants
  static Future<List<Map<String, dynamic>>> getConsultants() async {
    try { final r = await _dio.get('/consultants'); return _asList(r.data); }
    catch (_) { return []; }
  }

  /// GET /api/consultants/{id}
  static Future<Map<String, dynamic>?> getConsultant(int id) async {
    try { final r = await _dio.get('/consultants/$id'); return _asMap(r.data); }
    catch (_) { return null; }
  }

  // ── Offers ───────────────────────────────────────────────────────────────
  /// GET /api/offers/checkout?consultantId=X
  static Future<List<Map<String, dynamic>>> getCheckoutOffers(int consultantId) async {
    try {
      final r = await _dio.get('/offers/checkout', queryParameters: {'consultantId': consultantId});
      return _asList(r.data);
    } catch (_) { return []; }
  }

  // ── Timeslots ────────────────────────────────────────────────────────────
  /// GET /api/timeslots/consultant/{id}/available
  static Future<List<Map<String, dynamic>>> getAvailableSlots(int consultantId) async {
    try { final r = await _dio.get('/timeslots/consultant/$consultantId/available'); return _asList(r.data); }
    catch (_) { return []; }
  }

  /// GET /api/consultants/{id}/master-timeslots
  static Future<List<Map<String, dynamic>>> getMasterSlots(int consultantId) async {
    try { final r = await _dio.get('/consultants/$consultantId/master-timeslots'); return _asList(r.data); }
    catch (_) { return []; }
  }

  // ── Bookings ─────────────────────────────────────────────────────────────
  /// GET /api/bookings/me  (paginated — page 0, size 50)
  static Future<List<Map<String, dynamic>>> getMyBookings() async {
    try {
      final r = await _dio.get('/bookings/me', queryParameters: {'page': 0, 'size': 50});
      return _asList(r.data);
    } catch (_) { return []; }
  }

  /// POST /api/bookings  body: BookingRequest
  /// REQUIRED: consultantId, timeSlotId, baseAmount, meetingMode
  static Future<Map<String, dynamic>?> createBooking({
    required int consultantId,
    required int timeSlotId,
    required double baseAmount,
    required String meetingMode,
    int? offerId,
    String? userNotes,
  }) async {
    try {
      final r = await _dio.post('/bookings', data: {
        'consultantId': consultantId,
        'timeSlotId'  : timeSlotId,
        'baseAmount'  : baseAmount,
        'meetingMode' : meetingMode,
        if (offerId != null)                         'offerId'  : offerId,
        if (userNotes != null && userNotes.isNotEmpty) 'userNotes': userNotes,
      });
      return _asMap(r.data);
    } catch (_) { return null; }
  }

  /// POST /api/bookings/bulk  body: BulkBookingRequest (exactly 2 slots)
  static Future<Map<String, dynamic>?> createBulkBooking({
    required int consultantId,
    required List<int> timeSlotIds,
    required double baseAmountPerSlot,
    required String meetingMode,
    int? offerId,
    String? userNotes,
  }) async {
    try {
      final r = await _dio.post('/bookings/bulk', data: {
        'consultantId'     : consultantId,
        'timeSlotIds'      : timeSlotIds,
        'baseAmountPerSlot': baseAmountPerSlot,
        'meetingMode'      : meetingMode,
        if (offerId != null)                         'offerId'  : offerId,
        if (userNotes != null && userNotes.isNotEmpty) 'userNotes': userNotes,
      });
      return _asMap(r.data);
    } catch (_) { return null; }
  }

  /// PATCH /api/bookings/{id}/cancel  — FIX: NOT DELETE
  static Future<bool> cancelBooking(int id) async {
    try { await _dio.patch('/bookings/$id/cancel'); return true; }
    catch (_) { return false; }
  }

  /// POST /api/notifications/booking-confirmation
  static Future<void> sendBookingConfirmation(int bookingId, Map<String, dynamic> extra) async {
    try {
      await _dio.post('/notifications/booking-confirmation',
          data: {'bookingId': bookingId, ...extra});
    } catch (_) {}
  }

  // ── Tickets ──────────────────────────────────────────────────────────────
  /// GET /api/tickets/user/{userId}
  static Future<List<Map<String, dynamic>>> getMyTickets(int userId) async {
    try {
      final r = await _dio.get('/tickets/user/$userId',
          queryParameters: {'page': 0, 'size': 50, 'sortBy': 'createdAt'});
      return _asList(r.data);
    } catch (_) { return []; }
  }

  /// GET /api/admin/config/categories  (admin-configured ticket categories)
  static Future<List<String>> getTicketCategories() async {
    try {
      final r = await _dio.get('/admin/config/categories');
      final list = _asList(r.data);
      return list
          .where((c) => c['active'] != false)
          .map((c) => c['name']?.toString() ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
    } catch (_) {
      // Fallback: unique categories from existing tickets
      try {
        final r2 = await _dio.get('/tickets/unique-categories');
        return (r2.data as List?)?.map((e) => e.toString()).toList() ?? [];
      } catch (_) {
        return ['Billing', 'Technical', 'Account', 'Investment', 'KYC', 'Consultation', 'General', 'Other'];
      }
    }
  }

  /// POST /api/tickets  multipart: ticketData + optional file
  static Future<Map<String, dynamic>?> createTicket({
    required int userId,
    required String category,
    required String description,
    String priority = 'MEDIUM',
  }) async {
    try {
      final ticketData = {
        'userId'     : userId,
        'category'   : category,
        'description': description,
        'priority'   : priority,
      };
      final fd = FormData.fromMap({'ticketData': jsonEncode(ticketData)});
      final r = await _dio.post('/tickets', data: fd,
          options: Options(contentType: 'multipart/form-data'));
      return _asMap(r.data);
    } catch (_) { return null; }
  }

  /// GET /api/tickets/{ticketId}/comments
  static Future<List<Map<String, dynamic>>> getTicketComments(int ticketId) async {
    try { final r = await _dio.get('/tickets/$ticketId/comments'); return _asList(r.data); }
    catch (_) { return []; }
  }

  /// POST /api/tickets/comments  body: {ticketId, senderId, message, isConsultantReply}
  static Future<Map<String, dynamic>?> addComment({
    required int ticketId,
    required int senderId,
    required String message,
  }) async {
    try {
      final r = await _dio.post('/tickets/comments', data: {
        'ticketId'         : ticketId,
        'senderId'         : senderId,
        'message'          : message,
        'isConsultantReply': false,
      });
      return _asMap(r.data);
    } catch (_) { return null; }
  }

  /// PATCH /api/tickets/{id}/status?status=VALUE  — FIX: query param not body
  static Future<bool> updateTicketStatus(int id, String status) async {
    try {
      await _dio.patch('/tickets/$id/status', queryParameters: {'status': status});
      return true;
    } catch (_) { return false; }
  }

  /// POST /api/tickets/{id}/feedback  body: map
  static Future<bool> submitTicketFeedback(int id, int rating, String text) async {
    try {
      await _dio.post('/tickets/$id/feedback', data: {'rating': rating, 'feedbackText': text});
      return true;
    } catch (_) { return false; }
  }

  // ── Feedbacks ────────────────────────────────────────────────────────────
  /// POST /api/feedbacks  body: FeedbackRequest
  /// REQUIRED: consultantId, meetingId (min:1), bookingId, rating (1-5)
  static Future<bool> submitFeedback({
    required int consultantId,
    required int bookingId,
    required int rating,
    String? comments,
    int meetingId = 1,
  }) async {
    try {
      await _dio.post('/feedbacks', data: {
        'consultantId': consultantId,
        'bookingId'   : bookingId,
        'meetingId'   : meetingId,
        'rating'      : rating,
        if (comments != null && comments.isNotEmpty) 'comments': comments,
      });
      return true;
    } catch (_) { return false; }
  }

  /// GET /api/feedbacks/booking/{bookingId}
  static Future<Map<String, dynamic>?> getFeedbackByBooking(int bookingId) async {
    try { final r = await _dio.get('/feedbacks/booking/$bookingId'); return _asMap(r.data); }
    catch (_) { return null; }
  }

  // ── Notifications ────────────────────────────────────────────────────────
  /// GET /api/notifications  (unread — swagger: array)
  static Future<List<Map<String, dynamic>>> getNotifications() async {
    try { final r = await _dio.get('/notifications'); return _asList(r.data); }
    catch (_) { return []; }
  }

  /// PUT /api/notifications/{id}/read  — FIX: id is int64
  static Future<void> markNotifRead(int id) async {
    try { await _dio.put('/notifications/$id/read'); }
    catch (_) {}
  }

  // ── Contact ──────────────────────────────────────────────────────────────
  /// POST /api/contact/public/submit  — real backend endpoint
  static Future<bool> submitContact({
    required String name,
    required String email,
    required String message,
  }) async {
    try {
      await _dio.post('/contact/public/submit', data: {
        'name': name, 'email': email, 'message': message,
      });
      return true;
    } catch (_) { return false; }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// HELPERS
// ════════════════════════════════════════════════════════════════════════════

String _initials(String? name) {
  if (name == null || name.trim().isEmpty) return 'U';
  return name.trim().split(' ').take(2)
      .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
      .join();
}

String _photoUrl(String? path) {
  if (path == null || path.isEmpty) return '';
  if (path.startsWith('http')) return path;
  return 'http://52.55.178.31:8081${path.startsWith('/') ? '' : '/'}$path';
}

String _fmtDate(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  try {
    final d = DateTime.parse(iso);
    return DateFormat('dd MMM yyyy').format(d);
  } catch (_) { return iso.split('T').first; }
}

String _fmtDateTime(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  try {
    final d = DateTime.parse(iso);
    return DateFormat('dd MMM yyyy, hh:mm a').format(d);
  } catch (_) { return iso; }
}

String _timeAgo(String? iso) {
  if (iso == null) return '';
  try {
    final d = DateTime.parse(iso);
    final diff = DateTime.now().difference(d);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24) return '${diff.inHours}h ago';
    if (diff.inDays    < 7)  return '${diff.inDays}d ago';
    return _fmtDate(iso);
  } catch (_) { return ''; }
}

double _calcFee(double base, Map<String, dynamic>? cfg) {
  if (cfg == null) return base;
  final type = (cfg['feeType'] ?? 'FLAT').toString().toUpperCase();
  final val  = double.tryParse(cfg['feeValue']?.toString() ?? '0') ?? 0;
  return type == 'PERCENTAGE' ? base + (base * val / 100) : base + val;
}

// ════════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ════════════════════════════════════════════════════════════════════════════

Widget _gradBtn(String label, VoidCallback? onTap, {
  bool loading = false, bool danger = false,
  double radius = 14, double height = 52, EdgeInsets? padding,
}) {
  final colors = danger
      ? [_C.danger, const Color(0xFFB91C1C)]
      : [_C.blue, _C.blueDeep];
  return GestureDetector(
    onTap: loading ? null : onTap,
    child: Container(
      width: double.infinity, height: height,
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: loading ? [_C.text4, _C.text4] : colors),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: loading ? [] : [
          BoxShadow(color: colors.first.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Center(child: loading
        ? const SizedBox(width: 20, height: 20,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
        : Text(label, style: _ts(15, FontWeight.w700, Colors.white))),
    ),
  );
}

Widget _outlineBtn(String label, VoidCallback? onTap, {Color? color}) => OutlinedButton(
  onPressed: onTap,
  style: OutlinedButton.styleFrom(
    side: BorderSide(color: color ?? _C.border, width: 1.5),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
  ),
  child: Text(label, style: _ts(13, FontWeight.w600, color ?? _C.text3)),
);

Widget _chip(String label, {Color? bg, Color? fg, Color? brd, IconData? icon}) => Container(
  padding: EdgeInsets.symmetric(horizontal: icon != null ? 8 : 10, vertical: 4),
  decoration: BoxDecoration(
    color: bg ?? _C.blueLight,
    border: Border.all(color: brd ?? _C.blueBorder),
    borderRadius: BorderRadius.circular(20),
  ),
  child: Row(mainAxisSize: MainAxisSize.min, children: [
    if (icon != null) ...[Icon(icon, size: 11, color: fg ?? _C.blue), const SizedBox(width: 4)],
    Text(label, style: _ts(11, FontWeight.w700, fg ?? _C.blue)),
  ]),
);

// Status chip with color config
Widget _statusChip(String status) {
  final s = status.toUpperCase();
  final Map<String, List<Color>> cfg = {
    'NEW'        : [_C.indigo,   _C.indigoBg,  const Color(0xFFC7D2FE)],
    'OPEN'       : [_C.blue,     _C.blueLight, _C.blueBorder],
    'IN_PROGRESS': [_C.warning,  _C.warningBg, _C.warningBrd],
    'PENDING'    : [_C.warning,  _C.warningBg, _C.warningBrd],
    'RESOLVED'   : [_C.success,  _C.successBg, _C.successBrd],
    'CLOSED'     : [_C.gray500,  _C.gray100,   _C.gray200],
    'ESCALATED'  : [_C.danger,   _C.dangerBg,  _C.dangerBrd],
    'CONFIRMED'  : [_C.success,  _C.successBg, _C.successBrd],
    'COMPLETED'  : [_C.gray500,  _C.gray100,   _C.gray200],
    'CANCELLED'  : [_C.danger,   _C.dangerBg,  _C.dangerBrd],
    'AVAILABLE'  : [_C.success,  _C.successBg, _C.successBrd],
    'BOOKED'     : [_C.warning,  _C.warningBg, _C.warningBrd],
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
    children: List.generate(5, (i) => GestureDetector(
      onTap: onChanged != null ? () => onChanged!(i + 1) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Icon(
          i < value ? Icons.star_rounded : Icons.star_outline_rounded,
          color: _C.amber, size: size,
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
  @override State<_Shimmer> createState() => _ShimmerState();
}
class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;
  @override void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _a = Tween(begin: 0.25, end: 0.65).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(
    animation: _a,
    builder: (_, __) => Container(
      height: widget.height, width: widget.width,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _C.border.withOpacity(_a.value),
        borderRadius: BorderRadius.circular(widget.radius),
      ),
    ),
  );
}

// Section Header
Widget _sectionHeader(String title, {String? action, VoidCallback? onAction}) => Row(
  children: [
    Text(title, style: _ts(11, FontWeight.w800, _C.text3, ls: 0.7)),
    const Spacer(),
    if (action != null) GestureDetector(
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
        width: 80, height: 80,
        decoration: BoxDecoration(color: _C.blueLight, borderRadius: BorderRadius.circular(24)),
        child: Icon(icon, size: 36, color: _C.blue),
      ),
      const SizedBox(height: 20),
      Text(title, style: _ts(17, FontWeight.w700, _C.text1), textAlign: TextAlign.center),
      const SizedBox(height: 8),
      Text(sub, style: _ts(13, FontWeight.w400, _C.text3), textAlign: TextAlign.center),
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
    // FIX: Changed 'fin_token' to 'jwt_token' here as well
    final token = widget.token ?? await const FlutterSecureStorage().read(key: 'jwt_token') ?? '';
    if (token.isNotEmpty) await _Api.init(token);

    final me = await _Api.getMe();
    if (mounted) {
      setState(() {
        _user = me ?? {};
        _booting = false;
      });
      _startNotifPoll();
    }
  }

  void _startNotifPoll() {
    _fetchUnread();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchUnread());
  }

  Future<void> _fetchUnread() async {
    final list = await _Api.getNotifications();
    if (mounted) {
      setState(() => _unread = list.where((n) => n['read'] == false).length);
    }
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
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: _C.bg,
        body: IndexedStack(
          index: _tab,
          children: [
            _ConsultantsTab(user: _user),
            _BookingsTab(user: _user),
            _TicketsTab(user: _user),
            _NotifsTab(user: _user, onRead: () => setState(() => _unread = 0)),
            _SettingsTab(user: _user, onUpdated: (u) => setState(() => _user = u)),
          ],
        ),
        bottomNavigationBar: _BottomNav(
          current: _tab,
          unread : _unread,
          onTap  : (i) => setState(() => _tab = i),
        ),
      ),
    );
  }
}

// ── Bottom Navigation Bar ─────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int current, unread;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.current, required this.unread, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.search_rounded,              'Experts'),
      (Icons.calendar_month_rounded,      'Bookings'),
      (Icons.confirmation_number_rounded, 'Tickets'),
      (Icons.notifications_rounded,       'Updates'),
      (Icons.manage_accounts_rounded,     'Account'),
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
              final sel  = current == i;
              final icon = items[i].$1;
              final lbl  = items[i].$2;
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
                          child: Icon(icon, size: 22, color: sel ? _C.blue : _C.text4),
                        ),
                        if (hasBadge) Positioned(
                          top: 2, right: 2,
                          child: Container(
                            width: 8, height: 8,
                            decoration: const BoxDecoration(color: _C.danger, shape: BoxShape.circle),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 2),
                      Text(lbl, style: _ts(10, sel ? FontWeight.w700 : FontWeight.w500,
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
  const _ConsultantsTab({required this.user});
  @override State<_ConsultantsTab> createState() => _ConsultantsTabState();
}

class _ConsultantsTabState extends State<_ConsultantsTab> {
  List<Map<String, dynamic>> _consultants = [];
  Map<String, dynamic>? _feeConfig;
  String _search = '';
  String _selCat = 'All';
  List<String> _cats = ['All'];
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _Api.getConsultants(),
      _Api.getFeeConfig(),
    ]);
    final consultants = results[0] as List<Map<String, dynamic>>;
    final feeRaw      = results[1] as Map<String, dynamic>?;

    // Build category set from consultant skills
    final cats = <String>{'All'};
    for (final c in consultants) {
      for (final s in (c['skills'] as List? ?? [])) {
        if (s.toString().isNotEmpty) cats.add(s.toString());
      }
    }
    if (mounted) setState(() {
      _consultants = consultants;
      _feeConfig   = feeRaw;
      _cats        = cats.toList();
      _loading     = false;
    });
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _search.toLowerCase();
    return _consultants.where((c) {
      final matchQ = q.isEmpty
          || (c['name'] ?? '').toString().toLowerCase().contains(q)
          || (c['designation'] ?? '').toString().toLowerCase().contains(q);
      final skills = (c['skills'] as List? ?? []).map((s) => s.toString().toLowerCase());
      final matchC = _selCat == 'All' || skills.contains(_selCat.toLowerCase());
      return matchQ && matchC;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final name = user['name'] ?? (user['identifier']?.toString().split('@').first ?? 'User');

    return SafeArea(child: Column(children: [
      // ── Header ──
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Hello, ${name.toString().split(' ').first} 👋',
                  style: _ts(14, FontWeight.w500, _C.text3)),
              Text('Find Your Expert', style: _ts(24, FontWeight.w900, _C.text1)),
            ])),
            // Avatar
            GestureDetector(
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_C.navy, _C.blue]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(child: Text(_initials(name.toString()),
                    style: _ts(16, FontWeight.w800, Colors.white))),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          // Search
          Container(
            decoration: BoxDecoration(
              color: _C.bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _C.border),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _search = v),
              style: _ts(14, FontWeight.w500, _C.text1),
              decoration: InputDecoration(
                hintText: 'Search by name or skill…',
                hintStyle: _ts(14, FontWeight.w400, _C.text4),
                prefixIcon: const Icon(Icons.search_rounded, color: _C.text4, size: 20),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, color: _C.text4, size: 18),
                        onPressed: () { _searchCtrl.clear(); setState(() => _search = ''); },
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
              scrollDirection: Axis.horizontal,
              itemCount: _cats.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final cat = _cats[i];
                final sel = _selCat == cat;
                return GestureDetector(
                  onTap: () => setState(() => _selCat = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color  : sel ? _C.blue : Colors.white,
                      border : Border.all(color: sel ? _C.blue : _C.border),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(cat, style: _ts(12, FontWeight.w700, sel ? Colors.white : _C.text3)),
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
          ? ListView(padding: const EdgeInsets.all(16),
              children: List.generate(3, (_) => const _Shimmer(height: 200)))
          : _filtered.isEmpty
              ? _emptyState(Icons.person_search_rounded, 'No Experts Found',
                  'Try a different search or category')
              : RefreshIndicator(
                  onRefresh: _load, color: _C.blue,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) => _ConsultantCard(
                      c        : _filtered[i],
                      user     : widget.user,
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
  const _ConsultantCard({required this.c, required this.user, required this.feeConfig});

  @override
  Widget build(BuildContext context) {
    final name   = c['name'] ?? 'Expert';
    final role   = c['designation'] ?? 'Financial Consultant';
    final skills = (c['skills'] as List? ?? []).cast<String>();
    final rating = double.tryParse(c['rating']?.toString() ?? '0') ?? 0.0;
    final exp    = (c['yearsOfExperience'] ?? c['experience'] ?? 0);
    final base   = double.tryParse(c['charges']?.toString() ?? '0') ?? 0;
    final total  = _calcFee(base, feeConfig);
    final avatar = _photoUrl(c['profilePhoto'] ?? c['photo']);
    final about  = c['description'] ?? c['about'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Avatar
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [_C.navy, _C.blue], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(18),
              ),
              clipBehavior: Clip.antiAlias,
              child: avatar.isNotEmpty
                ? Image.network(avatar, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(child: Text(_initials(name.toString()),
                        style: _ts(24, FontWeight.w800, Colors.white))))
                : Center(child: Text(_initials(name.toString()),
                    style: _ts(24, FontWeight.w800, Colors.white))),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name.toString(), style: _ts(16, FontWeight.w800, _C.text1)),
              const SizedBox(height: 3),
              Text(role.toString(), style: _ts(13, FontWeight.w600, _C.blue)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 4,
                  children: skills.take(3).map((s) => _chip(s)).toList()),
              const SizedBox(height: 8),
              Row(children: [
                if ((exp ?? 0) > 0) ...[
                  const Icon(Icons.schedule_rounded, size: 13, color: _C.text4),
                  const SizedBox(width: 4),
                  Text('${exp}+ yrs', style: _ts(12, FontWeight.w500, _C.text3)),
                  const SizedBox(width: 12),
                ],
                if (rating > 0) ...[
                  const Icon(Icons.star_rounded, size: 13, color: _C.amber),
                  const SizedBox(width: 3),
                  Text('${rating.toStringAsFixed(1)}',
                      style: _ts(12, FontWeight.w700, _C.text1)),
                ],
              ]),
            ])),
          ]),
        ),

        if (about.toString().isNotEmpty) Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(about.toString(), maxLines: 2, overflow: TextOverflow.ellipsis,
              style: _ts(12, FontWeight.w400, _C.text3, height: 1.5)),
        ),

        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: _C.borderLight))),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('₹${total.toStringAsFixed(0)}',
                  style: _ts(20, FontWeight.w900, _C.text1)),
              Text('per session', style: _ts(11, FontWeight.w500, _C.text4)),
            ]),
            const Spacer(),
            _outlineBtn('  Profile  ',
                () => _openProfile(context)),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => _openBooking(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_C.blue, _C.blueDeep]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: _C.blue.withOpacity(0.3),
                      blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: Text('Book Now', style: _ts(13, FontWeight.w700, Colors.white)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  void _openProfile(BuildContext ctx) => showModalBottomSheet(
    context: ctx, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (_) => _ProfileSheet(c: c, feeConfig: feeConfig,
        onBook: () { Navigator.pop(ctx); _openBooking(ctx); }),
  );

  void _openBooking(BuildContext ctx) => showModalBottomSheet(
    context: ctx, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (_) => _BookingSheet(c: c, user: user, feeConfig: feeConfig),
  );
}

// ── Consultant Profile Sheet ───────────────────────────────────────────────────
class _ProfileSheet extends StatelessWidget {
  final Map<String, dynamic> c;
  final Map<String, dynamic>? feeConfig;
  final VoidCallback onBook;
  const _ProfileSheet({required this.c, required this.feeConfig, required this.onBook});

  @override
  Widget build(BuildContext context) {
    final name   = c['name'] ?? 'Expert';
    final role   = c['designation'] ?? '';
    final skills = (c['skills'] as List? ?? []).cast<String>();
    final rating = double.tryParse(c['rating']?.toString() ?? '0') ?? 0.0;
    final base   = double.tryParse(c['charges']?.toString() ?? '0') ?? 0;
    final total  = _calcFee(base, feeConfig);
    final avatar = _photoUrl(c['profilePhoto'] ?? c['photo']);
    final about  = c['description'] ?? c['about'] ?? '';
    final email  = c['email'] ?? '';
    final exp    = c['yearsOfExperience'] ?? 0;

    return DraggableScrollableSheet(
      initialChildSize: 0.85, maxChildSize: 0.95, minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(
              color: _C.gray200, borderRadius: BorderRadius.circular(2))),
          Expanded(child: ListView(controller: ctrl, padding: const EdgeInsets.all(24), children: [
            // Profile header
            Row(children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_C.navy, _C.blue]),
                  borderRadius: BorderRadius.circular(22),
                ),
                clipBehavior: Clip.antiAlias,
                child: avatar.isNotEmpty
                  ? Image.network(avatar, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(child: Text(_initials(name.toString()),
                          style: _ts(28, FontWeight.w800, Colors.white))))
                  : Center(child: Text(_initials(name.toString()),
                      style: _ts(28, FontWeight.w800, Colors.white))),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name.toString(), style: _ts(20, FontWeight.w800, _C.text1)),
                const SizedBox(height: 4),
                Text(role.toString(), style: _ts(14, FontWeight.w600, _C.blue)),
                const SizedBox(height: 6),
                if (rating > 0) Row(children: [
                  ...List.generate(5, (i) => Icon(
                    i < rating.floor() ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: _C.amber, size: 16,
                  )),
                  const SizedBox(width: 6),
                  Text('${rating.toStringAsFixed(1)}',
                      style: _ts(13, FontWeight.w700, _C.text1)),
                ]),
              ])),
            ]),

            const SizedBox(height: 24),
            // Skills
            if (skills.isNotEmpty) ...[
              Text('EXPERTISE', style: _ts(10, FontWeight.w800, _C.text4, ls: 0.8)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8,
                  children: skills.map((s) => _chip(s)).toList()),
              const SizedBox(height: 20),
            ],

            // About
            if (about.toString().isNotEmpty) ...[
              Text('ABOUT', style: _ts(10, FontWeight.w800, _C.text4, ls: 0.8)),
              const SizedBox(height: 8),
              Text(about.toString(), style: _ts(14, FontWeight.w400, _C.text2, height: 1.7)),
              const SizedBox(height: 20),
            ],

            // Details
            Text('DETAILS', style: _ts(10, FontWeight.w800, _C.text4, ls: 0.8)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: _C.bg,
                  borderRadius: BorderRadius.circular(16), border: Border.all(color: _C.border)),
              child: Column(children: [
                if (exp != null && exp != 0)
                  _infoRow(Icons.schedule_rounded, 'EXPERIENCE', '$exp+ years'),
                if (email.toString().isNotEmpty)
                  _infoRow(Icons.email_rounded, 'EMAIL', email.toString()),
                _infoRow(Icons.payments_rounded, 'FEE PER SESSION',
                    '₹${total.toStringAsFixed(0)}'),
              ]),
            ),

            const SizedBox(height: 28),
            _gradBtn('Book a Session', onBook),
            const SizedBox(height: 12),
          ])),
        ]),
      ),
    );
  }
}

// ── Booking Sheet ─────────────────────────────────────────────────────────────
class _BookingSheet extends StatefulWidget {
  final Map<String, dynamic> c, user;
  final Map<String, dynamic>? feeConfig;
  const _BookingSheet({required this.c, required this.user, required this.feeConfig});
  @override State<_BookingSheet> createState() => _BookingSheetState();
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

  final _notesCtrl = TextEditingController();
  final _modes = ['ONLINE', 'PHYSICAL', 'PHONE'];
  final _modeIcons = {
    'ONLINE'  : Icons.videocam_rounded,
    'PHYSICAL': Icons.location_on_rounded,
    'PHONE'   : Icons.phone_rounded,
  };

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _notesCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    final cId = (widget.c['id'] as num?)?.toInt() ?? 0;
    final results = await Future.wait([
      _Api.getAvailableSlots(cId),
      _Api.getCheckoutOffers(cId),
    ]);
    if (mounted) setState(() {
      _slots  = results[0] as List<Map<String, dynamic>>;
      _offers = results[1] as List<Map<String, dynamic>>;
      _loading = false;
    });
  }

  Future<void> _confirm() async {
    if (_selSlot == null) {
      _toast(context, 'Please select a time slot', error: true);
      return;
    }
    setState(() => _booking = true);

    final cId      = (widget.c['id'] as num?)?.toInt() ?? 0;
    final slotId   = (_selSlot!['id'] as num?)?.toInt() ?? 0;
    final base     = double.tryParse(widget.c['charges']?.toString() ?? '0') ?? 0;
    final offerId  = (_selOffer?['id'] as num?)?.toInt();

    final result = await _Api.createBooking(
      consultantId: cId,
      timeSlotId  : slotId,
      baseAmount  : base,
      meetingMode : _mode,
      offerId     : offerId,
      userNotes   : _notes.isEmpty ? null : _notes,
    );

    if (mounted) {
      setState(() => _booking = false);
      if (result != null) {
        // Send booking confirmation notification
        await _Api.sendBookingConfirmation((result['id'] as num?)?.toInt() ?? 0, {
          'consultantName': widget.c['name'],
          'meetingMode'   : _mode,
        });
        Navigator.pop(context);
        _toast(context, 'Session booked successfully! 🎉');
      } else {
        _toast(context, 'Failed to book. Please try again.', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name  = widget.c['name'] ?? 'Expert';
    final base  = double.tryParse(widget.c['charges']?.toString() ?? '0') ?? 0;
    final total = _calcFee(base, widget.feeConfig);

    return DraggableScrollableSheet(
      initialChildSize: 0.9, maxChildSize: 0.95, minChildSize: 0.5,
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
              Container(width: 40, height: 4, decoration: BoxDecoration(
                  color: _C.gray200, borderRadius: BorderRadius.circular(2))),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_C.navy, _C.blue]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('BOOK SESSION', style: _ts(11, FontWeight.w800, Colors.white, ls: 0.5)),
              ),
            ]),
          ),

          Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator(color: _C.blue))
            : ListView(controller: ctrl, padding: const EdgeInsets.all(24), children: [
                // Consultant mini header
                Row(children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(gradient: const LinearGradient(colors: [_C.navy, _C.blue]),
                        borderRadius: BorderRadius.circular(14)),
                    child: Center(child: Text(_initials(name.toString()),
                        style: _ts(18, FontWeight.w800, Colors.white))),
                  ),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name.toString(), style: _ts(16, FontWeight.w800, _C.text1)),
                    Text(widget.c['designation'] ?? '', style: _ts(13, FontWeight.w500, _C.text3)),
                  ]),
                ]),

                const SizedBox(height: 24),

                // ── Slot Selection ──
                Text('SELECT TIME SLOT', style: _ts(10, FontWeight.w800, _C.text4, ls: 0.8)),
                const SizedBox(height: 12),
                if (_slots.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: _C.warningBg, border: Border.all(color: _C.warningBrd),
                        borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      const Icon(Icons.info_outline_rounded, color: _C.warning, size: 18),
                      const SizedBox(width: 10),
                      Text('No available slots right now', style: _ts(13, FontWeight.w500, _C.warning)),
                    ]),
                  )
                else
                  Wrap(spacing: 10, runSpacing: 10, children: _slots.map((slot) {
                    final sel  = _selSlot?['id'] == slot['id'];
                    final time = slot['timeRange'] ?? slot['slotTime'] ?? '';
                    final date = slot['slotDate'] ?? '';
                    return GestureDetector(
                      onTap: () => setState(() => _selSlot = slot),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color : sel ? _C.blueLight : Colors.white,
                          border: Border.all(color: sel ? _C.blue : _C.border, width: sel ? 2 : 1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(time.toString(), style: _ts(13, FontWeight.w700,
                              sel ? _C.blue : _C.text1)),
                          if (date.toString().isNotEmpty)
                            Text(date.toString(), style: _ts(11, FontWeight.w500,
                                sel ? _C.blue : _C.text3)),
                        ]),
                      ),
                    );
                  }).toList()),

                const SizedBox(height: 24),

                // ── Meeting Mode ──
                Text('MEETING MODE', style: _ts(10, FontWeight.w800, _C.text4, ls: 0.8)),
                const SizedBox(height: 12),
                Row(children: _modes.map((m) {
                  final sel = _mode == m;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _mode = m),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: EdgeInsets.only(right: m == _modes.last ? 0 : 8),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color : sel ? _C.blueLight : Colors.white,
                          border: Border.all(color: sel ? _C.blue : _C.border, width: sel ? 2 : 1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(children: [
                          Icon(_modeIcons[m]!, size: 20,
                              color: sel ? _C.blue : _C.text4),
                          const SizedBox(height: 4),
                          Text(m, style: _ts(11, FontWeight.w700,
                              sel ? _C.blue : _C.text3)),
                        ]),
                      ),
                    ),
                  );
                }).toList()),

                // ── Offers ──
                if (_offers.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text('AVAILABLE OFFERS', style: _ts(10, FontWeight.w800, _C.text4, ls: 0.8)),
                  const SizedBox(height: 12),
                  ..._offers.map((o) {
                    final sel = _selOffer?['id'] == o['id'];
                    return GestureDetector(
                      onTap: () => setState(() => _selOffer = sel ? null : o),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color : sel ? _C.amberBg : Colors.white,
                          border: Border.all(color: sel ? _C.amber : _C.border, width: sel ? 2 : 1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(children: [
                          Icon(Icons.local_offer_rounded, size: 18,
                              color: sel ? _C.amber : _C.text4),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(o['title'] ?? 'Offer',
                                style: _ts(13, FontWeight.w700, _C.text1)),
                            if ((o['discount'] ?? '').toString().isNotEmpty)
                              Text(o['discount'].toString(),
                                  style: _ts(12, FontWeight.w600, _C.amber)),
                          ])),
                          if (sel) const Icon(Icons.check_circle_rounded,
                              color: _C.amber, size: 20),
                        ]),
                      ),
                    );
                  }),
                ],

                // ── Notes ──
                const SizedBox(height: 24),
                Text('NOTES (OPTIONAL)', style: _ts(10, FontWeight.w800, _C.text4, ls: 0.8)),
                const SizedBox(height: 10),
                TextField(
                  controller: _notesCtrl,
                  onChanged: (v) => _notes = v,
                  maxLines: 3,
                  style: _ts(14, FontWeight.w400, _C.text1),
                  decoration: InputDecoration(
                    hintText: 'Any specific topics or concerns…',
                    hintStyle: _ts(14, FontWeight.w400, _C.text4),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _C.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _C.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _C.blue)),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),

                // ── Price Summary ──
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _C.blueLight, border: Border.all(color: _C.blueBorder),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Base fee', style: _ts(13, FontWeight.w500, _C.text3)),
                      Text('₹${base.toStringAsFixed(0)}', style: _ts(13, FontWeight.w600, _C.text2)),
                    ]),
                    if (total != base) ...[
                      const SizedBox(height: 6),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('Platform fee', style: _ts(13, FontWeight.w500, _C.text3)),
                        Text('+₹${(total - base).toStringAsFixed(0)}',
                            style: _ts(13, FontWeight.w600, _C.warning)),
                      ]),
                    ],
                    const Divider(height: 16),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Total', style: _ts(14, FontWeight.w700, _C.text1)),
                      Text('₹${total.toStringAsFixed(0)}',
                          style: _ts(18, FontWeight.w900, _C.blue)),
                    ]),
                  ]),
                ),

                const SizedBox(height: 28),
                _gradBtn('Confirm Booking', _confirm, loading: _booking),
                const SizedBox(height: 12),
              ],
            ),
          ),
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
  const _BookingsTab({required this.user});
  @override State<_BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<_BookingsTab> {
  List<Map<String, dynamic>> _bookings = [];
  bool _loading = true;
  String _filter = 'UPCOMING'; // UPCOMING | HISTORY

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _Api.getMyBookings();
    if (mounted) setState(() { _bookings = list; _loading = false; });
  }

  bool _isUpcoming(Map<String, dynamic> b) {
    final status = (b['bookingStatus'] ?? b['status'] ?? '').toString().toUpperCase();
    return status == 'CONFIRMED' || status == 'PENDING';
  }

  List<Map<String, dynamic>> get _filtered =>
      _bookings.where((b) => _filter == 'UPCOMING' ? _isUpcoming(b) : !_isUpcoming(b)).toList();

  Future<void> _cancel(int bookingId) async {
    final ok = await _Api.cancelBooking(bookingId);
    if (mounted) {
      _toast(context, ok ? 'Booking cancelled.' : 'Could not cancel.', error: !ok);
      if (ok) _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(child: Column(children: [
      // Header
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('My Bookings', style: _ts(24, FontWeight.w900, _C.text1)),
          const SizedBox(height: 14),
          // Filter toggle
          Container(
            decoration: BoxDecoration(color: _C.bg, borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.all(4),
            child: Row(children: ['UPCOMING', 'HISTORY'].map((f) {
              final sel = _filter == f;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _filter = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: sel ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: sel ? [BoxShadow(color: Colors.black.withOpacity(0.06),
                          blurRadius: 8)] : [],
                    ),
                    child: Text(f, textAlign: TextAlign.center,
                        style: _ts(13, FontWeight.w700, sel ? _C.text1 : _C.text4)),
                  ),
                ),
              );
            }).toList()),
          ),
          const SizedBox(height: 14),
        ]),
      ),

      Expanded(child: _loading
        ? ListView(padding: const EdgeInsets.all(16),
            children: List.generate(3, (_) => const _Shimmer(height: 160)))
        : _filtered.isEmpty
            ? _emptyState(
                _filter == 'UPCOMING' ? Icons.calendar_today_rounded : Icons.history_rounded,
                _filter == 'UPCOMING' ? 'No Upcoming Sessions' : 'No Past Sessions',
                _filter == 'UPCOMING'
                    ? 'Book a session with an expert to get started'
                    : 'Your completed sessions will appear here',
              )
            : RefreshIndicator(
                onRefresh: _load, color: _C.blue,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) => _BookingCard(
                    b      : _filtered[i],
                    onCancel: _cancel,
                    onFeedback: (b) => _openFeedback(context, b),
                  ),
                ),
              ),
      ),
    ]));
  }

  void _openFeedback(BuildContext ctx, Map<String, dynamic> b) => showModalBottomSheet(
    context: ctx, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (_) => _FeedbackSheet(booking: b),
  );
}

class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> b;
  final void Function(int) onCancel;
  final void Function(Map<String, dynamic>) onFeedback;
  const _BookingCard({required this.b, required this.onCancel, required this.onFeedback});

  @override
  Widget build(BuildContext context) {
    final id        = (b['id'] as num?)?.toInt() ?? 0;
    final status    = (b['bookingStatus'] ?? b['status'] ?? 'PENDING').toString().toUpperCase();
    final mode      = (b['meetingMode'] ?? 'ONLINE').toString();
    final amount    = double.tryParse(b['totalAmount']?.toString() ?? b['amount']?.toString() ?? '0') ?? 0;
    final link      = b['meetingLink'] ?? '';
    final notes     = b['meetingNotes'] ?? b['userNotes'] ?? '';
    final slotId    = (b['timeSlotId'] as num?)?.toInt() ?? 0;
    final cId       = (b['consultantId'] as num?)?.toInt() ?? 0;
    final isUpcoming = status == 'CONFIRMED' || status == 'PENDING';
    final isDone    = status == 'COMPLETED';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isUpcoming ? [_C.navy, _C.blue] : [_C.gray200, _C.gray500],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  mode == 'ONLINE' ? Icons.videocam_rounded
                    : mode == 'PHONE' ? Icons.phone_rounded
                    : Icons.location_on_rounded,
                  color: Colors.white, size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Booking #$id', style: _ts(15, FontWeight.w800, _C.text1)),
                Text('Consultant #$cId · $mode', style: _ts(12, FontWeight.w500, _C.text3)),
              ])),
              _statusChip(status),
            ]),

            const SizedBox(height: 14),

            // Divider
            const Divider(color: _C.borderLight, height: 1),
            const SizedBox(height: 14),

            Row(children: [
              _infoChip(Icons.attach_money_rounded, '₹${amount.toStringAsFixed(0)}'),
              const SizedBox(width: 10),
              _infoChip(Icons.confirmation_number_rounded, 'Slot #$slotId'),
            ]),

            if (notes.toString().isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.notes_rounded, size: 14, color: _C.text4),
                const SizedBox(width: 6),
                Expanded(child: Text(notes.toString(),
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: _ts(12, FontWeight.w400, _C.text3))),
              ]),
            ],
          ]),
        ),

        // Actions
        if (isUpcoming || isDone || link.toString().isNotEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Row(children: [
              if (link.toString().isNotEmpty && isUpcoming) Expanded(
                child: GestureDetector(
                  onTap: () {/* open Jitsi link */},
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_C.success, Color(0xFF15803D)]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.videocam_rounded, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text('Join Meeting', style: _ts(13, FontWeight.w700, Colors.white)),
                    ]),
                  ),
                ),
              ),
              if (link.toString().isNotEmpty && isUpcoming) const SizedBox(width: 10),
              if (isUpcoming) Expanded(
                child: OutlinedButton(
                  onPressed: () => _confirmCancel(context, id),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _C.dangerBrd),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: Text('Cancel', style: _ts(13, FontWeight.w700, _C.danger)),
                ),
              ),
              if (isDone) Expanded(
                child: GestureDetector(
                  onTap: () => onFeedback(b),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _C.amberBg,
                      border: Border.all(color: _C.amber),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.star_rounded, color: _C.amber, size: 16),
                      const SizedBox(width: 6),
                      Text('Rate Session', style: _ts(13, FontWeight.w700, _C.amber)),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
      ]),
    );
  }

  Widget _infoChip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: _C.bg, borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: _C.text4),
      const SizedBox(width: 5),
      Text(label, style: _ts(12, FontWeight.w600, _C.text3)),
    ]),
  );

  void _confirmCancel(BuildContext ctx, int id) => showDialog(
    context: ctx,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Cancel Booking?', style: _ts(17, FontWeight.w800, _C.text1)),
      content: Text('Are you sure you want to cancel this session? This cannot be undone.',
          style: _ts(14, FontWeight.w400, _C.text2)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
            child: Text('Keep', style: _ts(14, FontWeight.w600, _C.text3))),
        TextButton(
          onPressed: () { Navigator.pop(ctx); onCancel(id); },
          child: Text('Cancel Booking', style: _ts(14, FontWeight.w700, _C.danger)),
        ),
      ],
    ),
  );
}

// ── Feedback Sheet (submit rating for completed booking) ──────────────────────
class _FeedbackSheet extends StatefulWidget {
  final Map<String, dynamic> booking;
  const _FeedbackSheet({required this.booking});
  @override State<_FeedbackSheet> createState() => _FeedbackSheetState();
}
class _FeedbackSheetState extends State<_FeedbackSheet> {
  int _rating = 0;
  final _commentCtrl = TextEditingController();
  bool _submitting = false;

  @override void dispose() { _commentCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_rating == 0) { _toast(context, 'Please select a rating', error: true); return; }
    setState(() => _submitting = true);
    final cId  = (widget.booking['consultantId'] as num?)?.toInt() ?? 0;
    final bId  = (widget.booking['id'] as num?)?.toInt() ?? 0;
    final ok   = await _Api.submitFeedback(
      consultantId: cId, bookingId: bId, rating: _rating,
      comments: _commentCtrl.text.trim().isEmpty ? null : _commentCtrl.text.trim(),
    );
    if (mounted) {
      setState(() => _submitting = false);
      _toast(context, ok ? 'Thank you for your feedback! ⭐' : 'Failed to submit.', error: !ok);
      if (ok) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(child: Container(width: 40, height: 4,
          decoration: BoxDecoration(color: _C.gray200, borderRadius: BorderRadius.circular(2)))),
      const SizedBox(height: 20),
      Text('Rate Your Session', style: _ts(20, FontWeight.w800, _C.text1)),
      const SizedBox(height: 6),
      Text('Your feedback helps consultants improve.', style: _ts(13, FontWeight.w400, _C.text3)),
      const SizedBox(height: 24),
      Center(child: _Stars(value: _rating, onChanged: (v) => setState(() => _rating = v), size: 40)),
      const SizedBox(height: 8),
      Center(child: Text(
        _rating == 0 ? 'Tap to rate' : ['', 'Poor', 'Fair', 'Good', 'Great', 'Excellent'][_rating],
        style: _ts(14, FontWeight.w700, _C.amber),
      )),
      const SizedBox(height: 20),
      TextField(
        controller: _commentCtrl, maxLines: 3,
        style: _ts(14, FontWeight.w400, _C.text1),
        decoration: InputDecoration(
          hintText: 'Share your experience (optional)…',
          hintStyle: _ts(14, FontWeight.w400, _C.text4),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _C.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _C.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
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
  const _TicketsTab({required this.user});
  @override State<_TicketsTab> createState() => _TicketsTabState();
}

class _TicketsTabState extends State<_TicketsTab> {
  List<Map<String, dynamic>> _tickets = [];
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  int get _uid => (widget.user['id'] as num?)?.toInt() ?? 0;

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _Api.getMyTickets(_uid);
    if (mounted) setState(() { _tickets = list; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(child: Column(children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Support Tickets', style: _ts(24, FontWeight.w900, _C.text1)),
            Text('${_tickets.length} tickets', style: _ts(13, FontWeight.w500, _C.text3)),
          ])),
          GestureDetector(
            onTap: () => _openCreate(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_C.blue, _C.blueDeep]),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: _C.blue.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: Row(children: [
                const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Text('New Ticket', style: _ts(13, FontWeight.w700, Colors.white)),
              ]),
            ),
          ),
        ]),
      ),

      Expanded(child: _loading
        ? ListView(padding: const EdgeInsets.all(16),
            children: List.generate(3, (_) => const _Shimmer(height: 130)))
        : _tickets.isEmpty
            ? _emptyState(Icons.confirmation_number_rounded, 'No Support Tickets',
                'Have a question? Raise a ticket and our team will help.')
            : RefreshIndicator(
                onRefresh: _load, color: _C.blue,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  itemCount: _tickets.length,
                  itemBuilder: (_, i) => _TicketCard(
                    t: _tickets[i], userId: _uid,
                    onUpdated: _load,
                  ),
                ),
              ),
      ),
    ]));
  }

  void _openCreate(BuildContext ctx) => showModalBottomSheet(
    context: ctx, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (_) => _CreateTicketSheet(userId: _uid, onCreated: _load),
  );
}

// ── Ticket Card ────────────────────────────────────────────────────────────────
class _TicketCard extends StatelessWidget {
  final Map<String, dynamic> t;
  final int userId;
  final VoidCallback onUpdated;
  const _TicketCard({required this.t, required this.userId, required this.onUpdated});

  @override
  Widget build(BuildContext context) {
    final id       = (t['id'] as num?)?.toInt() ?? 0;
    final status   = (t['status'] ?? 'NEW').toString().toUpperCase();
    final priority = (t['priority'] ?? 'MEDIUM').toString().toUpperCase();
    final category = t['category'] ?? 'General';
    final desc     = t['description'] ?? '';
    final created  = t['createdAt'] ?? '';
    final slaBreached = t['slaBreached'] == true;

    final prioColors = {
      'LOW'     : [_C.success, _C.successBg],
      'MEDIUM'  : [_C.warning, _C.warningBg],
      'HIGH'    : [const Color(0xFFEA580C), const Color(0xFFFFF7ED)],
      'URGENT'  : [_C.danger, _C.dangerBg],
      'CRITICAL': [_C.purple, _C.purpleBg],
    };
    final pClr = prioColors[priority] ?? [_C.text4, _C.bg];

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => _TicketDetailScreen(ticket: t, userId: userId, onUpdated: onUpdated))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: slaBreached ? _C.dangerBrd : _C.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Row(children: [
                Text('Ticket #$id', style: _ts(14, FontWeight.w800, _C.text1)),
                if (slaBreached) ...[
                  const SizedBox(width: 8),
                  _chip('SLA BREACH', fg: _C.danger, bg: _C.dangerBg, brd: _C.dangerBrd,
                      icon: Icons.warning_rounded),
                ],
              ])),
              _statusChip(status),
            ]),
            const SizedBox(height: 8),
            Text(desc.toString(), maxLines: 2, overflow: TextOverflow.ellipsis,
                style: _ts(13, FontWeight.w400, _C.text2, height: 1.5)),
            const SizedBox(height: 12),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: _C.bg, borderRadius: BorderRadius.circular(6)),
                child: Text(category.toString(), style: _ts(11, FontWeight.w700, _C.text3)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: pClr[1], borderRadius: BorderRadius.circular(6)),
                child: Text(priority, style: _ts(11, FontWeight.w700, pClr[0])),
              ),
              const Spacer(),
              Text(_timeAgo(created), style: _ts(11, FontWeight.w500, _C.text4)),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, size: 18, color: _C.text4),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ── Create Ticket Sheet ────────────────────────────────────────────────────────
class _CreateTicketSheet extends StatefulWidget {
  final int userId;
  final VoidCallback onCreated;
  const _CreateTicketSheet({required this.userId, required this.onCreated});
  @override State<_CreateTicketSheet> createState() => _CreateTicketSheetState();
}
class _CreateTicketSheetState extends State<_CreateTicketSheet> {
  List<String> _categories = [];
  bool _loadingCats = true;
  String? _category;
  String _priority = 'MEDIUM';
  final _descCtrl = TextEditingController();
  bool _saving = false;
  String _err = '';

  final _priorities = ['LOW', 'MEDIUM', 'HIGH', 'URGENT'];
  final _prioLabels = {'LOW': 'Low', 'MEDIUM': 'Medium', 'HIGH': 'High', 'URGENT': 'Urgent'};

  @override
  void initState() { super.initState(); _loadCats(); }
  @override
  void dispose() { _descCtrl.dispose(); super.dispose(); }

  Future<void> _loadCats() async {
    final cats = await _Api.getTicketCategories();
    if (mounted) setState(() { _categories = cats; _loadingCats = false; });
  }

  Future<void> _submit() async {
    if (_category == null) { setState(() => _err = 'Please select a category.'); return; }
    if (_descCtrl.text.trim().length < 10) { setState(() => _err = 'Description must be at least 10 characters.'); return; }
    setState(() { _saving = true; _err = ''; });
    final result = await _Api.createTicket(
      userId     : widget.userId,
      category   : _category!,
      description: _descCtrl.text.trim(),
      priority   : _priority,
    );
    if (mounted) {
      setState(() => _saving = false);
      if (result != null) {
        Navigator.pop(context);
        widget.onCreated();
        _toast(context, 'Ticket #${result['id']} created. Our team will respond shortly.');
      } else {
        setState(() => _err = 'Failed to create ticket. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    initialChildSize: 0.85, maxChildSize: 0.95, minChildSize: 0.4,
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
            gradient: LinearGradient(colors: [_C.navy, _C.blue]),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Row(children: [
            const Icon(Icons.confirmation_number_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Raise a Support Ticket', style: _ts(17, FontWeight.w800, Colors.white)),
              Text('Our team will respond within SLA window.', style: _ts(12, FontWeight.w400, Colors.white70)),
            ])),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.close_rounded, color: Colors.white70),
            ),
          ]),
        ),

        Expanded(child: _loadingCats
          ? const Center(child: CircularProgressIndicator(color: _C.blue))
          : ListView(controller: ctrl, padding: const EdgeInsets.all(20), children: [
              if (_err.isNotEmpty) Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: _C.dangerBg, border: Border.all(color: _C.dangerBrd),
                    borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Icon(Icons.warning_rounded, color: _C.danger, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_err, style: _ts(13, FontWeight.w600, _C.danger))),
                ]),
              ),

              // Category
              Text('CATEGORY *', style: _ts(10, FontWeight.w800, _C.text4, ls: 0.7)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: _categories.map((cat) {
                final sel = _category == cat;
                return GestureDetector(
                  onTap: () => setState(() { _category = cat; _err = ''; }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color : sel ? _C.blueLight : Colors.white,
                      border: Border.all(color: sel ? _C.blue : _C.border, width: sel ? 2 : 1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(cat, style: _ts(13, FontWeight.w600, sel ? _C.blue : _C.text2)),
                  ),
                );
              }).toList()),

              const SizedBox(height: 20),

              // Priority
              Text('PRIORITY', style: _ts(10, FontWeight.w800, _C.text4, ls: 0.7)),
              const SizedBox(height: 10),
              Row(children: _priorities.map((p) {
                final sel = _priority == p;
                final colors = {
                  'LOW': _C.success, 'MEDIUM': _C.warning,
                  'HIGH': const Color(0xFFEA580C), 'URGENT': _C.danger,
                };
                final clr = colors[p] ?? _C.text3;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _priority = p),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: EdgeInsets.only(right: p == _priorities.last ? 0 : 8),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color : sel ? clr.withOpacity(0.12) : Colors.white,
                        border: Border.all(color: sel ? clr : _C.border, width: sel ? 2 : 1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(_prioLabels[p]!, textAlign: TextAlign.center,
                          style: _ts(12, FontWeight.w700, sel ? clr : _C.text3)),
                    ),
                  ),
                );
              }).toList()),

              const SizedBox(height: 20),

              // Description
              Text('DESCRIPTION *', style: _ts(10, FontWeight.w800, _C.text4, ls: 0.7)),
              const SizedBox(height: 10),
              TextField(
                controller: _descCtrl,
                onChanged: (_) { if (_err.isNotEmpty) setState(() => _err = ''); },
                maxLines: 5, maxLength: 2000,
                style: _ts(14, FontWeight.w400, _C.text1),
                decoration: InputDecoration(
                  hintText: 'Describe your issue in detail… (min 10 characters)',
                  hintStyle: _ts(14, FontWeight.w400, _C.text4),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _C.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _C.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _C.blue)),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),

              const SizedBox(height: 24),
              _gradBtn('Submit Ticket', _submit, loading: _saving),
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
  const _TicketDetailScreen({required this.ticket, required this.userId, required this.onUpdated});
  @override State<_TicketDetailScreen> createState() => _TicketDetailScreenState();
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
  void dispose() { _msgCtrl.dispose(); _fbCtrl.dispose(); super.dispose(); }

  Future<void> _loadComments() async {
    setState(() => _loading = true);
    final id = (widget.ticket['id'] as num?)?.toInt() ?? 0;
    final list = await _Api.getTicketComments(id);
    if (mounted) setState(() { _comments = list; _loading = false; });
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
    setState(() { _comments = [..._comments, optimistic]; });
    _msgCtrl.clear();

    final result = await _Api.addComment(ticketId: id, senderId: widget.userId, message: msg);
    if (mounted) {
      setState(() {
        _sending = false;
        if (result != null) {
          _comments = [..._comments.where((c) => c['id'] != optimistic['id']), result];
        }
      });
    }
  }

  Future<void> _closeTicket() async {
    final id = (_ticket['id'] as num?)?.toInt() ?? 0;
    final ok = await _Api.updateTicketStatus(id, 'CLOSED');
    if (mounted && ok) {
      setState(() => _ticket = {..._ticket, 'status': 'CLOSED'});
      widget.onUpdated();
      _toast(context, 'Ticket closed.');
    }
  }

  Future<void> _submitFeedback() async {
    if (_fbRating == 0) { _toast(context, 'Select a rating first.', error: true); return; }
    setState(() => _fbSending = true);
    final id = (_ticket['id'] as num?)?.toInt() ?? 0;
    final ok = await _Api.submitTicketFeedback(id, _fbRating, _fbCtrl.text.trim());
    if (mounted) {
      setState(() { _fbSending = false; if (ok) _fbDone = true; });
      _toast(context, ok ? 'Feedback submitted. Thank you!' : 'Failed to submit.', error: !ok);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status   = (_ticket['status'] ?? 'NEW').toString().toUpperCase();
    final category = _ticket['category'] ?? '';
    final priority = (_ticket['priority'] ?? 'MEDIUM').toString();
    final desc     = _ticket['description'] ?? '';
    final created  = _ticket['createdAt'] ?? '';
    final id       = (_ticket['id'] as num?)?.toInt() ?? 0;
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
          if (!isClosed) TextButton(
            onPressed: _closeTicket,
            child: Text('Close', style: _ts(14, FontWeight.w700, _C.danger)),
          ),
        ],
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: _C.border)),
      ),
      body: Column(children: [
        // Ticket info card
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _statusChip(status), const SizedBox(width: 8),
              _chip(category.toString(), bg: _C.bg, fg: _C.text2, brd: _C.border),
              const SizedBox(width: 8),
              _chip(priority.toString(),
                bg: priority == 'URGENT' || priority == 'CRITICAL' ? _C.dangerBg : _C.warningBg,
                fg: priority == 'URGENT' || priority == 'CRITICAL' ? _C.danger : _C.warning,
                brd: priority == 'URGENT' || priority == 'CRITICAL' ? _C.dangerBrd : _C.warningBrd,
              ),
            ]),
            const SizedBox(height: 10),
            Text(desc.toString(), style: _ts(14, FontWeight.w400, _C.text2, height: 1.6)),
            const SizedBox(height: 6),
            Text('Created ${_timeAgo(created)}', style: _ts(11, FontWeight.w500, _C.text4)),

            // Status stepper
            const SizedBox(height: 16),
            _TicketStepper(status: status),
          ]),
        ),

        // Feedback section (if resolved/closed and not yet given)
        if (isClosed && !_fbDone) Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _C.amberBg,
            border: Border.all(color: _C.amber.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Rate this resolution', style: _ts(14, FontWeight.w700, _C.text1)),
            const SizedBox(height: 10),
            Center(child: _Stars(value: _fbRating,
                onChanged: (v) => setState(() => _fbRating = v), size: 32)),
            const SizedBox(height: 10),
            TextField(
              controller: _fbCtrl, maxLines: 2,
              style: _ts(13, FontWeight.w400, _C.text1),
              decoration: InputDecoration(
                hintText: 'Optional comment…',
                hintStyle: _ts(13, FontWeight.w400, _C.text4),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _C.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _C.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _C.blue)),
                contentPadding: const EdgeInsets.all(10),
              ),
            ),
            const SizedBox(height: 10),
            _gradBtn('Submit Feedback', _submitFeedback, loading: _fbSending, height: 44),
          ]),
        ),

        // Comments thread
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator(color: _C.blue))
          : _comments.isEmpty
              ? _emptyState(Icons.chat_bubble_outline_rounded, 'No Messages Yet',
                  'Send a message to start the conversation.')
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _comments.length,
                  itemBuilder: (_, i) {
                    final c         = _comments[i];
                    final isMe      = (c['senderId'] as num?)?.toInt() == widget.userId;
                    final isConsul  = c['consultantReply'] == true;
                    final msg       = c['message'] ?? '';
                    final time      = _timeAgo(c['createdAt']?.toString());
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (!isMe) ...[
                            Container(
                              width: 32, height: 32,
                              decoration: BoxDecoration(
                                color: isConsul ? _C.navy : _C.gray200,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(isConsul ? Icons.support_agent_rounded : Icons.person_rounded,
                                  color: Colors.white, size: 16),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Flexible(child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isMe ? _C.blue : Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft   : const Radius.circular(16),
                                topRight  : const Radius.circular(16),
                                bottomLeft: Radius.circular(isMe ? 16 : 4),
                                bottomRight: Radius.circular(isMe ? 4 : 16),
                              ),
                              border: Border.all(color: isMe ? _C.blue : _C.border),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
                                  blurRadius: 6, offset: const Offset(0, 2))],
                            ),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              if (!isMe) Text(isConsul ? 'Support Team' : 'You',
                                  style: _ts(11, FontWeight.w700, isMe ? Colors.white70 : _C.blue)),
                              Text(msg.toString(),
                                  style: _ts(14, FontWeight.w400,
                                      isMe ? Colors.white : _C.text1, height: 1.5)),
                              const SizedBox(height: 4),
                              Text(time, style: _ts(10, FontWeight.w500,
                                  isMe ? Colors.white54 : _C.text4)),
                            ]),
                          )),
                        ],
                      ),
                    );
                  },
                ),
        ),

        // Input box
        if (!isClosed) Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).viewInsets.bottom + 12),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _msgCtrl,
                style: _ts(14, FontWeight.w400, _C.text1),
                decoration: InputDecoration(
                  hintText: 'Type your message…',
                  hintStyle: _ts(14, FontWeight.w400, _C.text4),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: _C.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: _C.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: _C.blue)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  filled: true, fillColor: _C.bg,
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _sending ? null : _sendMessage,
              child: Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_C.blue, _C.blueDeep]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: _sending
                  ? const Center(child: SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// Ticket status stepper
class _TicketStepper extends StatelessWidget {
  final String status;
  const _TicketStepper({required this.status});

  static const _steps = ['NEW', 'OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED'];
  static const _labels = ['Submitted', 'Assigned', 'In Progress', 'Resolved', 'Closed'];

  @override
  Widget build(BuildContext context) {
    int currentIdx = _steps.indexOf(status);
    if (currentIdx == -1) currentIdx = status == 'PENDING' ? 2 : status == 'ESCALATED' ? 1 : 0;

    return Row(children: List.generate(_steps.length * 2 - 1, (i) {
      if (i.isOdd) {
        final lineIdx = i ~/ 2;
        return Expanded(child: Container(height: 2,
            color: lineIdx < currentIdx ? _C.blue : _C.gray200));
      }
      final stepIdx = i ~/ 2;
      final done    = stepIdx < currentIdx;
      final current = stepIdx == currentIdx;
      return Column(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 24, height: 24,
          decoration: BoxDecoration(
            color : done ? _C.blue : current ? _C.blueLight : _C.gray100,
            border: Border.all(color: done || current ? _C.blue : _C.gray200, width: current ? 2 : 1),
            shape : BoxShape.circle,
          ),
          child: done
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 12)
            : current ? Container(margin: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: _C.blue, shape: BoxShape.circle))
            : null,
        ),
        const SizedBox(height: 4),
        Text(_labels[stepIdx], style: _ts(9, done || current ? FontWeight.w700 : FontWeight.w500,
            done || current ? _C.blue : _C.text4)),
      ]);
    }));
  }
}

// ════════════════════════════════════════════════════════════════════════════
// TAB 4 — NOTIFICATIONS
// ════════════════════════════════════════════════════════════════════════════

class _NotifsTab extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onRead;
  const _NotifsTab({required this.user, required this.onRead});
  @override State<_NotifsTab> createState() => _NotifsTabState();
}

class _NotifsTabState extends State<_NotifsTab> {
  List<Map<String, dynamic>> _notifs = [];
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _Api.getNotifications();
    if (mounted) setState(() { _notifs = list; _loading = false; });
  }

  Future<void> _markRead(Map<String, dynamic> n) async {
    final id = (n['id'] as num?)?.toInt() ?? 0;
    setState(() {
      final idx = _notifs.indexOf(n);
      if (idx != -1) _notifs[idx] = {...n, 'read': true};
    });
    await _Api.markNotifRead(id);
    widget.onRead();
  }

  int get _unread => _notifs.where((n) => n['read'] == false).length;

  @override
  Widget build(BuildContext context) {
    return SafeArea(child: Column(children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Notifications', style: _ts(24, FontWeight.w900, _C.text1)),
            if (_unread > 0) Text('$_unread unread', style: _ts(13, FontWeight.w500, _C.blue)),
          ])),
          if (_unread > 0) TextButton(
            onPressed: () async {
              for (final n in _notifs.where((n) => n['read'] == false)) {
                await _markRead(n);
              }
            },
            child: Text('Mark all read', style: _ts(13, FontWeight.w600, _C.blue)),
          ),
        ]),
      ),

      Expanded(child: _loading
        ? ListView(padding: const EdgeInsets.all(16),
            children: List.generate(4, (_) => const _Shimmer(height: 80)))
        : _notifs.isEmpty
            ? _emptyState(Icons.notifications_none_rounded, 'No Notifications',
                'You\'re all caught up! Notifications will appear here.')
            : RefreshIndicator(
                onRefresh: _load, color: _C.blue,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  itemCount: _notifs.length,
                  itemBuilder: (_, i) {
                    final n     = _notifs[i];
                    final read  = n['read'] == true;
                    final type  = (n['type'] ?? '').toString();
                    final msg   = n['message'] ?? '';
                    final time  = _timeAgo(n['createdAt']?.toString());

                    final (Color bg, Color fg, IconData icon) = type == 'ESCALATION'
                      ? (_C.dangerBg,   _C.danger,  Icons.warning_rounded)
                      : type == 'NEW_ASSIGNMENT'
                      ? (_C.amberBg,    _C.amber,   Icons.assignment_ind_rounded)
                      : (_C.blueLight,  _C.blue,    Icons.notifications_rounded);

                    return GestureDetector(
                      onTap: () => _markRead(n),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: read ? Colors.white : _C.blueLight.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: read ? _C.border : _C.blueBorder),
                        ),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
                            child: Icon(icon, color: fg, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(msg.toString(), style: _ts(13, read ? FontWeight.w400 : FontWeight.w600,
                                _C.text1, height: 1.5)),
                            const SizedBox(height: 4),
                            Text(time, style: _ts(11, FontWeight.w500, _C.text4)),
                          ])),
                          if (!read) Container(
                            width: 8, height: 8, margin: const EdgeInsets.only(top: 4),
                            decoration: const BoxDecoration(color: _C.blue, shape: BoxShape.circle),
                          ),
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
  @override State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  String _view = 'menu'; // menu | profile | security | plans | contact
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
    final p = await _Api.getOnboarding(uid);
    if (mounted) setState(() { _profile = p ?? {}; _loadingProfile = false; });
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
      case 'profile'  : return _ProfileView(
          user: widget.user, profile: _profile,
          loading: _loadingProfile,
          onBack: () => setState(() => _view = 'menu'),
          onSaved: (u) { widget.onUpdated(u); _loadProfile(); });
      case 'security' : return _SecurityView(onBack: () => setState(() => _view = 'menu'));
      case 'plans'    : return _PlansView(user: widget.user,
          onBack: () => setState(() => _view = 'menu'),
          onUpdated: (u) { widget.onUpdated(u); });
      case 'contact'  : return _ContactView(onBack: () => setState(() => _view = 'menu'));
      default: return _SettingsMenu(
          user: widget.user, profile: _profile,
          onNav: (v) => setState(() => _view = v));
    }
  }
}

// ── Settings Menu ──────────────────────────────────────────────────────────────
class _SettingsMenu extends StatelessWidget {
  final Map<String, dynamic> user, profile;
  final void Function(String) onNav;
  const _SettingsMenu({required this.user, required this.profile, required this.onNav});

  @override
  Widget build(BuildContext context) {
    final name  = profile['name'] ?? user['identifier']?.toString().split('@').first ?? 'User';
    final email = profile['email'] ?? user['identifier'] ?? '';
    final plan  = profile['subscriptionPlan']?['name'] ?? 'Guest';
    final isPremium = (plan.toString().toLowerCase() != 'guest');

    return SafeArea(child: SingleChildScrollView(child: Column(children: [
      // Profile banner
      Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_C.navy, _C.blue],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.4))),
            child: Center(child: Text(_initials(name.toString()),
                style: _ts(24, FontWeight.w800, Colors.white))),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name.toString(), style: _ts(18, FontWeight.w800, Colors.white)),
            const SizedBox(height: 4),
            Text(email.toString(), style: _ts(12, FontWeight.w400, Colors.white70)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.4)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(isPremium ? Icons.star_rounded : Icons.person_rounded,
                    color: isPremium ? _C.amber : Colors.white70, size: 12),
                const SizedBox(width: 5),
                Text('$plan Member', style: _ts(11, FontWeight.w700, Colors.white)),
              ]),
            ),
          ])),
          GestureDetector(
            onTap: () => onNav('profile'),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
            ),
          ),
        ]),
      ),

      // Menu items
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _C.border)),
        child: Column(children: [
          _menuItem(Icons.person_rounded, 'Account Profile', 'Edit your personal info',
              () => onNav('profile'), color: _C.blue),
          _divider(),
          _menuItem(Icons.card_membership_rounded, 'Subscription Plan',
              'Manage your plan — $plan', () => onNav('plans'), color: _C.purple),
          _divider(),
          _menuItem(Icons.lock_rounded, 'Privacy & Security', 'Change password, security settings',
              () => onNav('security'), color: _C.warning),
          _divider(),
          _menuItem(Icons.mail_rounded, 'Contact Us', 'Reach out to our support team',
              () => onNav('contact'), color: _C.success),
        ]),
      ),

      const SizedBox(height: 16),

      // Logout
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _C.dangerBrd)),
        child: _menuItem(Icons.logout_rounded, 'Sign Out', 'Log out of your account',
            () => _confirmLogout(context), color: _C.danger),
      ),

      const SizedBox(height: 32),
    ])));
  }

  Widget _menuItem(IconData icon, String title, String sub, VoidCallback onTap, {required Color color}) =>
    GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Sign Out?', style: _ts(17, FontWeight.w800, _C.text1)),
      content: Text('Are you sure you want to sign out?', style: _ts(14, FontWeight.w400, _C.text2)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: _ts(14, FontWeight.w600, _C.text3))),
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            // Navigate to login screen
          },
          child: Text('Sign Out', style: _ts(14, FontWeight.w700, _C.danger)),
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
  const _ProfileView({required this.user, required this.profile,
      required this.loading, required this.onBack, required this.onSaved});
  @override State<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<_ProfileView> {
  final _nameCtrl     = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _dobCtrl      = TextEditingController();
  bool _editing = false;
  bool _saving  = false;
  String _msg   = '';

  // Income / Expense lists
  List<Map<String, dynamic>> _incomes  = [];
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
    _nameCtrl.text     = p['name']        ?? '';
    _phoneCtrl.text    = p['phoneNumber'] ?? '';
    _locationCtrl.text = p['location']    ?? '';
    _emailCtrl.text    = p['email']       ?? '';
    _dobCtrl.text      = p['dob']         ?? '';
    _incomes  = List<Map<String, dynamic>>.from(p['incomes']  ?? []);
    _expenses = List<Map<String, dynamic>>.from(p['expenses'] ?? []);
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _phoneCtrl.dispose();
    _locationCtrl.dispose(); _emailCtrl.dispose(); _dobCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final uid = (widget.user['id'] as num?)?.toInt() ?? 0;
    if (uid == 0) return;
    setState(() { _saving = true; _msg = ''; });
    final ok = await _Api.updateOnboarding(uid, {
      'name'           : _nameCtrl.text.trim(),
      'email'          : _emailCtrl.text.trim(),
      'phoneNumber'    : _phoneCtrl.text.trim(),
      'location'       : _locationCtrl.text.trim(),
      if (_dobCtrl.text.isNotEmpty) 'dob': _dobCtrl.text.trim(),
      if (_incomes.isNotEmpty)  'incomeItems' : _incomes,
      if (_expenses.isNotEmpty) 'expenseItems': _expenses,
    });
    if (mounted) {
      setState(() { _saving = false; _editing = !ok; _msg = ok ? '✅ Profile updated!' : '❌ Failed to save.'; });
      if (ok) widget.onSaved({...widget.user, 'name': _nameCtrl.text.trim()});
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _nameCtrl.text.isNotEmpty
        ? _nameCtrl.text : (widget.profile['name'] ?? 'User');

    return SafeArea(child: Column(children: [
      // Header
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 20, 12),
        child: Row(children: [
          IconButton(icon: const Icon(Icons.arrow_back_rounded, color: _C.blue),
              onPressed: widget.onBack),
          Text('Account Profile', style: _ts(18, FontWeight.w800, _C.text1)),
          const Spacer(),
          if (!_editing)
            TextButton(onPressed: () => setState(() => _editing = true),
                child: Text('Edit', style: _ts(14, FontWeight.w700, _C.blue)))
          else ...[
            TextButton(onPressed: () { setState(() { _editing = false; _populate(); }); },
                child: Text('Cancel', style: _ts(14, FontWeight.w600, _C.text3))),
            TextButton(onPressed: _saving ? null : _save,
                child: _saving
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _C.blue))
                  : Text('Save', style: _ts(14, FontWeight.w700, _C.blue))),
          ],
        ]),
      ),

      Expanded(child: widget.loading
        ? const Center(child: CircularProgressIndicator(color: _C.blue))
        : SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
            if (_msg.isNotEmpty) Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _msg.startsWith('✅') ? _C.successBg : _C.dangerBg,
                border: Border.all(color: _msg.startsWith('✅') ? _C.successBrd : _C.dangerBrd),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(_msg, style: _ts(13, FontWeight.w600,
                  _msg.startsWith('✅') ? _C.success : _C.danger)),
            ),

            // Avatar header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_C.navy, _C.blue]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(0.4))),
                  child: Center(child: Text(_initials(name.toString()),
                      style: _ts(24, FontWeight.w800, Colors.white))),
                ),
                const SizedBox(width: 16),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name.toString(), style: _ts(17, FontWeight.w800, Colors.white)),
                  const SizedBox(height: 4),
                  Text(_emailCtrl.text, style: _ts(12, FontWeight.w400, Colors.white70)),
                ]),
              ]),
            ),

            const SizedBox(height: 20),

            // Fields
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _C.border)),
              child: Column(children: [
                _field('Full Name', _nameCtrl, Icons.person_rounded),
                _field('Email', _emailCtrl, Icons.email_rounded,
                    type: TextInputType.emailAddress),
                _field('Phone Number', _phoneCtrl, Icons.phone_rounded,
                    type: TextInputType.phone),
                _field('Location / City', _locationCtrl, Icons.location_on_rounded),
                _field('Date of Birth (YYYY-MM-DD)', _dobCtrl, Icons.cake_rounded,
                    last: true),
              ]),
            ),

            const SizedBox(height: 16),

            // Finances section
            if (_incomes.isNotEmpty || _expenses.isNotEmpty || _editing) ...[
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
        Text(label.toUpperCase(), style: _ts(10, FontWeight.w700, _C.text4, ls: 0.6)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl, enabled: _editing,
          keyboardType: type,
          style: _ts(14, FontWeight.w500, _C.text1),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18, color: _C.text4),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _C.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _C.blueBorder)),
            disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _C.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _C.blue, width: 2)),
            filled: true, fillColor: _editing ? const Color(0xFFF8FBFF) : _C.bg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ]),
    );

  Widget _financesSection() {
    final totalIncome  = _incomes.fold<double>(0, (s, i) => s + (double.tryParse(i['amount']?.toString() ?? '0') ?? 0));
    final totalExpense = _expenses.fold<double>(0, (s, e) => s + (double.tryParse(e['amount']?.toString() ?? '0') ?? 0));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('FINANCIALS', style: _ts(10, FontWeight.w800, _C.text4, ls: 0.7)),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: _C.successBg, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _C.successBrd)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('TOTAL INCOME', style: _ts(9, FontWeight.w800, _C.success, ls: 0.6)),
              const SizedBox(height: 4),
              Text('₹${totalIncome.toStringAsFixed(0)}',
                  style: _ts(20, FontWeight.w900, _C.success)),
            ]),
          )),
          const SizedBox(width: 12),
          Expanded(child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: _C.dangerBg, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _C.dangerBrd)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('TOTAL EXPENSE', style: _ts(9, FontWeight.w800, _C.danger, ls: 0.6)),
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
  @override State<_SecurityView> createState() => _SecurityViewState();
}
class _SecurityViewState extends State<_SecurityView> {
  final _newCtrl  = TextEditingController();
  final _confCtrl = TextEditingController();
  bool _showNew = false, _showConf = false, _saving = false;
  String _msg = '';

  @override void dispose() { _newCtrl.dispose(); _confCtrl.dispose(); super.dispose(); }

  int get _strength {
    final p = _newCtrl.text;
    int s = 0;
    if (p.length >= 8)                     s++;
    if (RegExp(r'[A-Z]').hasMatch(p))      s++;
    if (RegExp(r'[0-9]').hasMatch(p))      s++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) s++;
    return s;
  }

  Future<void> _change() async {
    if (_newCtrl.text.length < 8) {
      setState(() => _msg = '❌ Password must be at least 8 characters.'); return;
    }
    if (_newCtrl.text != _confCtrl.text) {
      setState(() => _msg = '❌ Passwords do not match.'); return;
    }
    setState(() { _saving = true; _msg = ''; });
    final ok = await _Api.changePassword(_newCtrl.text);
    if (mounted) {
      setState(() {
        _saving = false;
        _msg = ok ? '✅ Password updated successfully!' : '❌ Failed to update. Try again.';
        if (ok) { _newCtrl.clear(); _confCtrl.clear(); }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strColors = [_C.danger, _C.warning, const Color(0xFF22C55E), _C.success];
    final strLabels = ['Weak', 'Fair', 'Good', 'Strong'];

    return SafeArea(child: Column(children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(4, 12, 20, 12),
        child: Row(children: [
          IconButton(icon: const Icon(Icons.arrow_back_rounded, color: _C.blue),
              onPressed: widget.onBack),
          Text('Privacy & Security', style: _ts(18, FontWeight.w800, _C.text1)),
        ]),
      ),

      Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
        if (_msg.isNotEmpty) Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _msg.startsWith('✅') ? _C.successBg : _C.dangerBg,
            border: Border.all(color: _msg.startsWith('✅') ? _C.successBrd : _C.dangerBrd),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(_msg, style: _ts(13, FontWeight.w600,
              _msg.startsWith('✅') ? _C.success : _C.danger)),
        ),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _C.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 40, height: 40,
                  decoration: BoxDecoration(color: _C.warningBg, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.lock_rounded, color: _C.warning, size: 20)),
              const SizedBox(width: 12),
              Text('Change Password', style: _ts(16, FontWeight.w800, _C.text1)),
            ]),
            const SizedBox(height: 20),

            Text('NEW PASSWORD', style: _ts(10, FontWeight.w700, _C.text4, ls: 0.6)),
            const SizedBox(height: 8),
            TextField(
              controller: _newCtrl, obscureText: !_showNew,
              onChanged: (_) => setState(() {}),
              style: _ts(14, FontWeight.w500, _C.text1),
              decoration: InputDecoration(
                hintText: 'Min. 8 characters',
                hintStyle: _ts(14, FontWeight.w400, _C.text4),
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: _C.text4),
                suffixIcon: IconButton(
                  icon: Icon(_showNew ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      color: _C.text4, size: 20),
                  onPressed: () => setState(() => _showNew = !_showNew),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _C.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _C.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _C.blue)),
              ),
            ),

            if (_newCtrl.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(children: List.generate(4, (i) => Expanded(
                child: Container(
                  height: 4, margin: const EdgeInsets.only(right: 3),
                  decoration: BoxDecoration(
                    color: i < _strength ? strColors[_strength - 1] : _C.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ))),
              const SizedBox(height: 4),
              if (_strength > 0) Text('${strLabels[_strength - 1]} password',
                  style: _ts(11, FontWeight.w700, strColors[_strength - 1])),
            ],

            const SizedBox(height: 16),
            Text('CONFIRM PASSWORD', style: _ts(10, FontWeight.w700, _C.text4, ls: 0.6)),
            const SizedBox(height: 8),
            TextField(
              controller: _confCtrl, obscureText: !_showConf,
              style: _ts(14, FontWeight.w500, _C.text1),
              decoration: InputDecoration(
                hintText: 'Re-enter new password',
                hintStyle: _ts(14, FontWeight.w400, _C.text4),
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: _C.text4),
                suffixIcon: IconButton(
                  icon: Icon(_showConf ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      color: _C.text4, size: 20),
                  onPressed: () => setState(() => _showConf = !_showConf),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _C.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _C.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _C.blue)),
              ),
            ),

            const SizedBox(height: 24),
            _gradBtn(_saving ? '…' : 'Update Password', _saving ? null : _change, loading: _saving),
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
  const _PlansView({required this.user, required this.onBack, required this.onUpdated});
  @override State<_PlansView> createState() => _PlansViewState();
}
class _PlansViewState extends State<_PlansView> {
  List<Map<String, dynamic>> _plans = [];
  bool _loading = true, _saving = false;
  int? _currentPlanId;
  String _msg = '';

  @override
  void initState() {
    super.initState();
    _currentPlanId = (widget.user['subscriptionPlanId'] as num?)?.toInt();
    _load();
  }

  Future<void> _load() async {
    final plans = await _Api.getPlans();
    if (mounted) setState(() { _plans = plans; _loading = false; });
  }

  Future<void> _selectPlan(int planId) async {
    final uid = (widget.user['id'] as num?)?.toInt() ?? 0;
    setState(() { _saving = true; _msg = ''; });
    final ok = await _Api.updateOnboarding(uid, {
      'subscriptionPlanId': planId,
      'phoneNumber': widget.user['phone'] ?? '0000000000',
    });
    if (mounted) {
      setState(() { _saving = false; if (ok) _currentPlanId = planId; _msg = ok ? '✅ Plan updated!' : '❌ Failed to update plan.'; });
      if (ok) widget.onUpdated({...widget.user, 'subscriptionPlanId': planId});
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(child: Column(children: [
    Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(4, 12, 20, 12),
      child: Row(children: [
        IconButton(icon: const Icon(Icons.arrow_back_rounded, color: _C.blue), onPressed: widget.onBack),
        Text('Subscription Plans', style: _ts(18, FontWeight.w800, _C.text1)),
      ]),
    ),

    Expanded(child: _loading
      ? const Center(child: CircularProgressIndicator(color: _C.blue))
      : SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
          if (_msg.isNotEmpty) Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _msg.startsWith('✅') ? _C.successBg : _C.dangerBg,
              border: Border.all(color: _msg.startsWith('✅') ? _C.successBrd : _C.dangerBrd),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(_msg, style: _ts(13, FontWeight.w600,
                _msg.startsWith('✅') ? _C.success : _C.danger)),
          ),
          ..._plans.map((p) {
            final pid      = (p['id'] as num?)?.toInt() ?? 0;
            final isCurrent = pid == _currentPlanId;
            final name     = p['name'] ?? 'Plan';
            final orig     = double.tryParse(p['originalPrice']?.toString() ?? '0') ?? 0;
            final disc     = double.tryParse(p['discountPrice']?.toString() ?? '0') ?? 0;
            final features = (p['features'] ?? '').toString();
            final isGuest  = name.toString().toLowerCase() == 'guest';

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isCurrent ? _C.blue : _C.border,
                  width: isCurrent ? 2 : 1,
                ),
                boxShadow: isCurrent ? [BoxShadow(color: _C.blue.withOpacity(0.12),
                    blurRadius: 16, offset: const Offset(0, 4))] : [],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: isGuest ? null
                      : const LinearGradient(colors: [Color(0xFF92400E), Color(0xFFD97706)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight),
                    color: isGuest ? _C.gray100 : null,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  ),
                  child: Row(children: [
                    Icon(isGuest ? Icons.person_rounded : Icons.star_rounded,
                        color: isGuest ? _C.text3 : _C.amber, size: 28),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name.toString(), style: _ts(18, FontWeight.w800,
                          isGuest ? _C.text1 : Colors.white)),
                      if (p['tag'] != null) Text(p['tag'].toString(),
                          style: _ts(12, FontWeight.w500,
                              isGuest ? _C.text3 : Colors.white70)),
                    ])),
                    if (isCurrent) Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('CURRENT', style: _ts(10, FontWeight.w800,
                          isGuest ? _C.blue : Colors.white)),
                    ),
                  ]),
                ),

                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('₹${disc.toStringAsFixed(0)}',
                          style: _ts(28, FontWeight.w900, _C.text1)),
                      const SizedBox(width: 6),
                      if (orig != disc && orig > 0) Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('₹${orig.toStringAsFixed(0)}',
                            style: _ts(14, FontWeight.w500, _C.text4,).copyWith(
                              decoration: TextDecoration.lineThrough)),
                      ),
                      const Spacer(),
                      Text('/month', style: _ts(12, FontWeight.w500, _C.text3)),
                    ]),

                    if (features.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      ...features.split(',').map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(children: [
                          const Icon(Icons.check_circle_rounded, color: _C.success, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text(f.trim(), style: _ts(13, FontWeight.w400, _C.text2))),
                        ]),
                      )),
                    ],

                    const SizedBox(height: 16),
                    if (!isCurrent) _gradBtn('Select Plan',
                        _saving ? null : () => _selectPlan(pid),
                        loading: _saving)
                    else Container(
                      width: double.infinity, height: 48,
                      decoration: BoxDecoration(
                        color: _C.successBg,
                        border: Border.all(color: _C.successBrd),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.check_circle_rounded, color: _C.success, size: 18),
                        const SizedBox(width: 8),
                        Text('Your Current Plan', style: _ts(14, FontWeight.w700, _C.success)),
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

// ── Contact View ───────────────────────────────────────────────────────────────
class _ContactView extends StatefulWidget {
  final VoidCallback onBack;
  const _ContactView({required this.onBack});
  @override State<_ContactView> createState() => _ContactViewState();
}
class _ContactViewState extends State<_ContactView> {
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _msgCtrl   = TextEditingController();
  bool _sending = false, _sent = false;
  String _err = '';

  @override void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose(); _msgCtrl.dispose(); super.dispose();
  }

  Future<void> _send() async {
    if (_nameCtrl.text.trim().isEmpty || _emailCtrl.text.trim().isEmpty || _msgCtrl.text.trim().isEmpty) {
      setState(() => _err = 'Please fill in all required fields.'); return;
    }
    setState(() { _sending = true; _err = ''; });
    // POST /api/contact/public/submit — real backend endpoint
    final ok = await _Api.submitContact(
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      message: _msgCtrl.text.trim(),
    );
    if (mounted) setState(() { _sending = false; _sent = ok; if (!ok) _err = 'Failed to send. Please try again.'; });
  }

  @override
  Widget build(BuildContext context) => SafeArea(child: Column(children: [
    Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(4, 12, 20, 12),
      child: Row(children: [
        IconButton(icon: const Icon(Icons.arrow_back_rounded, color: _C.blue), onPressed: widget.onBack),
        Text('Contact Us', style: _ts(18, FontWeight.w800, _C.text1)),
      ]),
    ),

    Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: _sent
      ? Center(child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(color: _C.successBg, shape: BoxShape.circle,
                  border: Border.all(color: _C.successBrd, width: 2)),
              child: const Icon(Icons.check_rounded, color: _C.success, size: 40),
            ),
            const SizedBox(height: 20),
            Text('Message Sent!', style: _ts(22, FontWeight.w800, _C.text1)),
            const SizedBox(height: 8),
            Text('Our team will get back to you within 24 hours.',
                textAlign: TextAlign.center,
                style: _ts(14, FontWeight.w400, _C.text3, height: 1.6)),
            const SizedBox(height: 28),
            _outlineBtn('Send Another', () => setState(() => _sent = false)),
          ]),
        ))
      : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Contact info cards
          Row(children: [
            Expanded(child: _infoCard(Icons.email_rounded, 'Email',
                'support@meetthemasters.in', _C.blue)),
            const SizedBox(width: 12),
            Expanded(child: _infoCard(Icons.phone_rounded, 'Phone',
                '+91 99999 99999', _C.success)),
          ]),
          const SizedBox(height: 20),

          if (_err.isNotEmpty) Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _C.dangerBg, border: Border.all(color: _C.dangerBrd),
                borderRadius: BorderRadius.circular(10)),
            child: Text(_err, style: _ts(13, FontWeight.w600, _C.danger)),
          ),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _C.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('SEND A MESSAGE', style: _ts(12, FontWeight.w800, _C.text1, ls: 0.5)),
              const SizedBox(height: 16),
              _contactField('Full Name *', _nameCtrl, Icons.person_rounded, TextInputType.name),
              const SizedBox(height: 14),
              _contactField('Email Address *', _emailCtrl, Icons.email_rounded, TextInputType.emailAddress),
              const SizedBox(height: 14),
              Text('MESSAGE *'.toUpperCase(), style: _ts(10, FontWeight.w700, _C.text4, ls: 0.6)),
              const SizedBox(height: 8),
              TextField(
                controller: _msgCtrl, maxLines: 5, maxLength: 2000,
                style: _ts(14, FontWeight.w400, _C.text1),
                decoration: InputDecoration(
                  hintText: 'How can we help you?',
                  hintStyle: _ts(14, FontWeight.w400, _C.text4),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _C.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _C.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _C.blue)),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 20),
              _gradBtn(_sending ? '…' : 'Send Message', _send, loading: _sending),
            ]),
          ),
        ])),
    ),
  ]));

  Widget _infoCard(IconData icon, String label, String val, Color color) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 36, height: 36,
          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18)),
      const SizedBox(height: 10),
      Text(label, style: _ts(11, FontWeight.w700, _C.text3)),
      const SizedBox(height: 4),
      Text(val, style: _ts(12, FontWeight.w600, _C.text2)),
    ]),
  );

  Widget _contactField(String label, TextEditingController ctrl, IconData icon, TextInputType type) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase().replaceAll(' *', ' *'),
          style: _ts(10, FontWeight.w700, _C.text4, ls: 0.6)),
      const SizedBox(height: 8),
      TextField(
        controller: ctrl, keyboardType: type,
        style: _ts(14, FontWeight.w400, _C.text1),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 18, color: _C.text4),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _C.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _C.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _C.blue)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    ]);
}