// lib/admin_tickets_tab.dart
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// ADMIN TICKETS TAB â€” 100% web-parity, 100% dynamic
//
// Key fixes vs old code:
// â€¢ Escalated count = status=="ESCALATED" OR t.escalated==true (both checked)
// â€¢ 7 KPI stat boxes matching web exactly (Total/Open/Overdue/Escalated/
//   Resolved/ResolvedToday/Closed)  each with web-exact colours
// â€¢ Email-to-Ticket banner: HEALTHY/DOWN/CHECKING badge + Check + Poll Inbox
// â€¢ Auto-Responder collapsible panel (GET/POST /api/admin/settings/auto-responder)
// â€¢ Status filter chips include ESCALATED count (checks both flag & status)
// â€¢ Background 15-second polling
// â€¢ Infinite scroll pagination
// â€¢ Create Ticket FAB
// â€¢ CSV Export
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:finadvise/api_client.dart';
import 'package:finadvise/models/models.dart';
import 'package:finadvise/services/consultant_service.dart';
import 'package:finadvise/services/email_to_ticket_service.dart';
import 'package:finadvise/services/ticket_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'ticket_detail_screen.dart';

// â”€â”€â”€ helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

final _dio = ApiClient().dio;

void _toast(BuildContext ctx, String msg, {bool error = false}) {
  ScaffoldMessenger.of(ctx)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(
          error
              ? Icons.error_outline_rounded
              : Icons.check_circle_outline_rounded,
          color: Colors.white,
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(
            child:
                Text(msg, style: const TextStyle(fontWeight: FontWeight.w500))),
      ]),
      backgroundColor:
          error ? const Color(0xFFDC2626) : const Color(0xFF059669),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      duration: Duration(seconds: error ? 4 : 2),
    ));
}

List<dynamic> _arr(dynamic raw,
    {List<String> keys = const [
      'content',
      'data',
      'items',
      'tickets',
      'users',
      'categories'
    ]}) {
  if (raw is List) return raw;
  if (raw is Map) {
    for (final k in keys) {
      if (raw[k] is List) return raw[k] as List;
    }
  }
  return const [];
}

int? _toInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('${v ?? ''}');
}

String _normTs(String s) => (s.endsWith('Z') || s.contains('+')) ? s : '${s}Z';

String _apiErrorMessage(Object error,
    {String fallback = 'Something went wrong'}) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      final msg = data['message'] ?? data['error'] ?? data['detail'];
      if (msg != null && '$msg'.trim().isNotEmpty) {
        return '$msg'.trim();
      }
    } else if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }
    final message = error.message;
    if (message != null && message.trim().isNotEmpty) {
      return message.trim();
    }
  }
  return fallback;
}

// â”€â”€â”€ SLA â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

const _slaMap = {
  'LOW': 72,
  'MEDIUM': 24,
  'HIGH': 8,
  'URGENT': 4,
  'CRITICAL': 2
};

/// Returns true if ticket is overdue (same logic as web: SLA_HOURS_LOCAL check
/// PLUS backend slaBreached flag PLUS local calculation from createdAt).
bool _isOverdue(Ticket t) {
  if (['RESOLVED', 'CLOSED'].contains(t.status.toUpperCase())) return false;
  if (t.slaBreached) return true;
  if (t.createdAt == null || t.createdAt!.isEmpty) return false;
  try {
    final h = _slaMap[t.priority.toUpperCase()] ?? 24;
    final created = DateTime.parse(_normTs(t.createdAt!));
    return DateTime.now().difference(created).inHours >= h;
  } catch (_) {
    return false;
  }
}

/// Returns true if this ticket should appear in the ESCALATED filter.
/// Matches web: status=="ESCALATED" || isEscalated==true
bool _isEscalated(Ticket t) =>
    t.status.toUpperCase() == 'ESCALATED' || t.escalated;

class _SlaLabel {
  final bool breached, warning;
  final String label;
  const _SlaLabel(
      {required this.breached, required this.warning, required this.label});
}

_SlaLabel? _slaLabel(Ticket t) {
  if (['RESOLVED', 'CLOSED'].contains(t.status.toUpperCase())) return null;
  if (t.slaBreached)
    return const _SlaLabel(
        breached: true, warning: false, label: 'SLA BREACHED');
  if (t.createdAt == null || t.createdAt!.isEmpty) return null;
  try {
    final h = _slaMap[t.priority.toUpperCase()] ?? 24;
    final created = DateTime.parse(_normTs(t.createdAt!));
    final deadline = created.add(Duration(hours: h));
    final minsLeft = deadline.difference(DateTime.now()).inMinutes;
    if (minsLeft < 0)
      return const _SlaLabel(
          breached: true, warning: false, label: 'SLA BREACHED');
    if (minsLeft < 60)
      return _SlaLabel(
          breached: false, warning: true, label: '${minsLeft}m left');
    if (minsLeft < 240)
      return _SlaLabel(
          breached: false,
          warning: true,
          label: '${(minsLeft / 60).ceil()}h left');
    return null;
  } catch (_) {
    return null;
  }
}

// â”€â”€â”€ colour config (web-exact) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

const _sCfg = {
  'NEW': [Color(0xFF6366F1), Color(0xFFEEF2FF), Color(0xFFC7D2FE), 'New'],
  'OPEN': [Color(0xFF0F766E), Color(0xFFECFEFF), Color(0xFF99F6E4), 'Open'],
  'IN_PROGRESS': [
    Color(0xFFD97706),
    Color(0xFFFFFBEB),
    Color(0xFFFCD34D),
    'In Progress'
  ],
  'PENDING': [
    Color(0xFFD97706),
    Color(0xFFFFFBEB),
    Color(0xFFFCD34D),
    'Pending'
  ],
  'RESOLVED': [
    Color(0xFF16A34A),
    Color(0xFFF0FDF4),
    Color(0xFF86EFAC),
    'Resolved'
  ],
  'CLOSED': [Color(0xFF64748B), Color(0xFFF1F5F9), Color(0xFFCBD5E1), 'Closed'],
  'ESCALATED': [
    Color(0xFFDC2626),
    Color(0xFFFEF2F2),
    Color(0xFFFCA5A5),
    'Escalated'
  ],
};

const _pCfg = {
  'LOW': [Color(0xFF16A34A), 'Low'],
  'MEDIUM': [Color(0xFFD97706), 'Medium'],
  'HIGH': [Color(0xFFEA580C), 'High'],
  'URGENT': [Color(0xFFDC2626), 'Urgent'],
  'CRITICAL': [Color(0xFF7C3AED), 'Critical'],
};

Color _sc(String s) =>
    (_sCfg[s.toUpperCase()]?[0] as Color?) ?? const Color(0xFF64748B);
Color _sbg(String s) =>
    (_sCfg[s.toUpperCase()]?[1] as Color?) ?? const Color(0xFFF1F5F9);
Color _sbd(String s) =>
    (_sCfg[s.toUpperCase()]?[2] as Color?) ?? const Color(0xFFCBD5E1);
String _sl(String s) => (_sCfg[s.toUpperCase()]?[3] as String?) ?? s;
Color _pc(String p) =>
    (_pCfg[p.toUpperCase()]?[0] as Color?) ?? const Color(0xFF64748B);
String _pl(String p) => (_pCfg[p.toUpperCase()]?[1] as String?) ?? p;

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// MAIN WIDGET
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class AdminTicketsTab extends StatefulWidget {
  const AdminTicketsTab({super.key});
  @override
  State<AdminTicketsTab> createState() => _AdminTicketsTabState();
}

class _AdminTicketsTabState extends State<AdminTicketsTab> {
  final _svc = TicketService();
  final _consultSvc = ConsultantService();
  final _emailSvc = EmailToTicketService();

  List<Ticket> _all = [];
  List<Ticket> _visible = [];
  List<ConsultantModel> _consultants = [];
  Map<int, String> _userNames = {};
  Map<int, String> _consultantNames = {};

  bool _loading = true;
  bool _loadingMore = false;
  int _page = 0;
  bool _hasMore = true;
  static const _pageSize = 20;

  String _search = '';
  String _statusFilter = 'ALL';
  String _priorityFilter = 'ALL';

  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  Timer? _pollTimer;

  // Email-to-Ticket
  String _emailStatus = 'checking'; // checking | ok | down
  bool _polling = false;

  static const _statuses = [
    'ALL',
    'NEW',
    'OPEN',
    'IN_PROGRESS',
    'PENDING',
    'RESOLVED',
    'CLOSED',
    'ESCALATED'
  ];
  static const _priorities = [
    'ALL',
    'LOW',
    'MEDIUM',
    'HIGH',
    'URGENT',
    'CRITICAL'
  ];

  // â”€â”€â”€ KPI computed (web-exact formulas) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  int get _total => _all.length;
  int get _openCount => _all
      .where((t) => ['NEW', 'OPEN', 'IN_PROGRESS', 'PENDING']
          .contains(t.status.toUpperCase()))
      .length;
  int get _overdueCount => _all.where(_isOverdue).length;

  /// Web: status=="ESCALATED" || isEscalated==true
  int get _escalatedCount => _all.where(_isEscalated).length;
  int get _resolvedCount =>
      _all.where((t) => t.status.toUpperCase() == 'RESOLVED').length;
  int get _closedCount =>
      _all.where((t) => t.status.toUpperCase() == 'CLOSED').length;
  int get _resolvedToday {
    final now = DateTime.now();
    return _all.where((t) {
      if (t.status.toUpperCase() != 'RESOLVED') return false;
      if (t.updatedAt == null || t.updatedAt!.isEmpty) return false;
      try {
        final d = DateTime.parse(_normTs(t.updatedAt!)).toLocal();
        return d.year == now.year && d.month == now.month && d.day == now.day;
      } catch (_) {
        return false;
      }
    }).length;
  }

  /// Status chip counts â€” ESCALATED uses the combined flag check
  Map<String, int> get _chipCounts => {
        'ALL': _all.length,
        'NEW': _all.where((t) => t.status.toUpperCase() == 'NEW').length,
        'OPEN': _all.where((t) => t.status.toUpperCase() == 'OPEN').length,
        'IN_PROGRESS':
            _all.where((t) => t.status.toUpperCase() == 'IN_PROGRESS').length,
        'PENDING':
            _all.where((t) => t.status.toUpperCase() == 'PENDING').length,
        'RESOLVED':
            _all.where((t) => t.status.toUpperCase() == 'RESOLVED').length,
        'CLOSED': _all.where((t) => t.status.toUpperCase() == 'CLOSED').length,
        'ESCALATED': _escalatedCount,
      };

  String _titleize(String raw) {
    final parts =
        raw.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    return parts
        .map((p) =>
            '${p.substring(0, 1).toUpperCase()}${p.substring(1).toLowerCase()}')
        .join(' ');
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
      if (cleaned.isNotEmpty) return _titleize(cleaned);
    }
    return text;
  }

  bool _isGenericLabel(String raw, String prefix) {
    final text = raw.trim().toLowerCase();
    if (text.isEmpty) return true;
    final p = prefix.toLowerCase();
    return text == p || text.startsWith('$p #');
  }

  void _rebuildConsultantLookup() {
    _consultantNames = {
      for (final c in _consultants)
        if (_normalizeName(c.name).isNotEmpty) c.id: _normalizeName(c.name),
    };
  }

  String _displayUserName(Ticket ticket) {
    final direct = _normalizeName(ticket.userName ?? '');
    if (direct.isNotEmpty && !_isGenericLabel(direct, 'user')) return direct;
    final id = ticket.userId;
    if (id != null && _userNames[id]?.trim().isNotEmpty == true) {
      return _userNames[id]!.trim();
    }
    if (direct.isNotEmpty) return direct;
    return id != null ? 'User #$id' : 'User';
  }

  String _displayConsultantName(Ticket ticket) {
    final direct = _normalizeName(ticket.consultantName ?? '');
    if (direct.isNotEmpty &&
        !_isGenericLabel(direct, 'consultant') &&
        direct.toLowerCase() != 'unassigned') {
      return direct;
    }
    final id = ticket.consultantId;
    if (id != null && _consultantNames[id]?.trim().isNotEmpty == true) {
      return _consultantNames[id]!.trim();
    }
    if (direct.isNotEmpty) return direct;
    return id != null ? 'Consultant #$id' : 'Unassigned';
  }

  String _ticketNumber(Ticket ticket) {
    final idPart = ticket.id.toString().padLeft(2, '0');
    if (ticket.createdAt?.isNotEmpty != true) return '#$idPart';
    try {
      final dt = DateTime.parse(_normTs(ticket.createdAt!)).toLocal();
      return '${DateFormat('MM/dd').format(dt)}/$idPart';
    } catch (_) {
      return '#$idPart';
    }
  }

  String _ticketCreatedText(Ticket ticket) {
    if (ticket.createdAt?.isNotEmpty != true) return '--';
    try {
      final created = DateTime.parse(_normTs(ticket.createdAt!)).toLocal();
      final label = DateFormat('d MMM').format(created);
      if (['RESOLVED', 'CLOSED'].contains(ticket.status.toUpperCase())) {
        return label;
      }
      final openHours = DateTime.now().difference(created).inHours;
      return '$label\n${openHours}h open';
    } catch (_) {
      return _fmtDate(ticket.createdAt);
    }
  }

  String _fmtDate(String? raw) {
    if (raw == null || raw.isEmpty) return '--';
    try {
      final dt = DateTime.parse(_normTs(raw)).toLocal();
      return DateFormat('d MMM yyyy').format(dt);
    } catch (_) {
      return raw;
    }
  }

  Future<Map<int, String>> _fetchUserLookup() async {
    final out = <int, String>{};
    try {
      final response = await _dio.get('/api/users');
      final rows = _arr(
        response.data,
        keys: const ['content', 'data', 'items', 'users'],
      );
      for (final row in rows.whereType<Map>()) {
        final map = Map<String, dynamic>.from(row);
        final id = _toInt(map['id'] ?? map['userId']);
        if (id == null) continue;
        final raw = (map['name'] ??
                map['fullName'] ??
                map['displayName'] ??
                map['identifier'] ??
                map['email'] ??
                '')
            .toString();
        final name = _normalizeName(raw);
        if (name.isNotEmpty) {
          out[id] = name;
        }
      }
    } catch (_) {}
    return out;
  }

  // â”€â”€â”€ lifecycle â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _loadData(reset: true);
    _checkEmail();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _loadData(reset: true, silent: true),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent - 200 &&
        _hasMore &&
        !_loadingMore) {
      _loadData();
    }
  }

  // â”€â”€â”€ Email-to-Ticket â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _checkEmail() async {
    if (mounted) setState(() => _emailStatus = 'checking');
    try {
      final result = await _emailSvc.getHealthStatus();
      if (!result.ok) {
        if (mounted) setState(() => _emailStatus = 'down');
        return;
      }
      final normalized = result.message.toUpperCase();
      final down = normalized.contains('DOWN') ||
          normalized.contains('OFFLINE') ||
          normalized.contains('FAIL');
      if (mounted) setState(() => _emailStatus = down ? 'down' : 'ok');
    } catch (_) {
      if (mounted) setState(() => _emailStatus = 'down');
    }
  }

  Future<void> _pollInbox() async {
    if (_polling) return;
    setState(() => _polling = true);

    try {
      final result = await _emailSvc.triggerPolling();
      if (!mounted) return;
      if (!result.ok) {
        _toast(context, result.message, error: true);
        return;
      }
      setState(() => _emailStatus = 'ok');
      _toast(context, result.message);
      _loadData(reset: true);
      _checkEmail();
    } finally {
      if (mounted) setState(() => _polling = false);
    }
  }

  // â”€â”€â”€ Data loading â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _loadData({bool reset = false, bool silent = false}) async {
    if (reset) {
      if (!silent) {
        setState(() {
          _loading = true;
          _page = 0;
          _hasMore = true;
          _all = [];
        });
      } else {
        _page = 0;
        _hasMore = true;
      }
    } else {
      if (_loadingMore) return;
      setState(() => _loadingMore = true);
    }

    try {
      final results = await Future.wait<dynamic>([
        _svc.getAllTickets(
          page: reset ? 0 : _page,
          size: _pageSize,
          useAnalytics: false,
        ),
        if (reset)
          _consultSvc.getAllConsultants()
        else
          Future.value(_consultants),
        if (reset) _fetchUserLookup() else Future.value(_userNames),
      ]);

      final tickets = results[0] as List<Ticket>;
      final hasMore = tickets.length == _pageSize;
      if (!reset)
        _page++;
      else
        _page = 1;

      if (mounted) {
        setState(() {
          if (reset) {
            _all = tickets;
            _consultants = results[1] as List<ConsultantModel>;
            _userNames = Map<int, String>.from(results[2] as Map<int, String>);
            _rebuildConsultantLookup();
          } else {
            _all.addAll(tickets);
          }
          _hasMore = hasMore;
          _loading = false;
          _loadingMore = false;
          _applyFilters();
        });
      }
    } catch (_) {
      if (mounted && !silent) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _applyFilters() => setState(() {
        _visible = _all.where((t) {
          final q = _search.toLowerCase();
          final userName = _displayUserName(t).toLowerCase();
          final consultantName = _displayConsultantName(t).toLowerCase();
          final matchSearch = q.isEmpty ||
              t.id.toString().contains(q) ||
              t.category.toLowerCase().contains(q) ||
              (t.description ?? '').toLowerCase().contains(q) ||
              userName.contains(q) ||
              consultantName.contains(q) ||
              t.status.toLowerCase().contains(q) ||
              t.priority.toLowerCase().contains(q);

          // ESCALATED filter: status OR flag
          final matchStatus = _statusFilter == 'ALL'
              ? true
              : _statusFilter == 'ESCALATED'
                  ? _isEscalated(t)
                  : t.status.toUpperCase() == _statusFilter;

          final matchPriority = _priorityFilter == 'ALL' ||
              t.priority.toUpperCase() == _priorityFilter;

          return matchSearch && matchStatus && matchPriority;
        }).toList();
      });

  // â”€â”€â”€ Export â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _shareTextFile({
    required String fileName,
    required String content,
    required String mimeType,
    String? subject,
  }) async {
    final xFile = XFile.fromData(
      utf8.encode(content),
      mimeType: mimeType,
    );
    await SharePlus.instance.share(
      ShareParams(
        files: [xFile],
        fileNameOverrides: [fileName],
        subject: subject,
        downloadFallbackEnabled: true,
      ),
    );
  }

  Future<void> _export() async {
    try {
      final list = _visible.isNotEmpty ? _visible : _all;
      final sb = StringBuffer(
          'ID,Category,Status,Priority,Description,User,AssignedTo,Created\n');
      for (final t in list) {
        sb.writeln(
          '${t.id},"${t.category}","${t.status}","${t.priority}",'
          '"${(t.description ?? '').replaceAll('"', "'")}",'
          '"${_displayUserName(t)}","${_displayConsultantName(t)}","${t.createdAt ?? ''}"',
        );
      }
      await _shareTextFile(
        fileName:
            'tickets_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
        content: sb.toString(),
        mimeType: 'text/csv',
        subject: 'Tickets Export',
      );
    } catch (_) {
      if (mounted) _toast(context, 'Export failed', error: true);
    }
  }

  Future<void> _exportTicket(Ticket ticket, {required String format}) async {
    try {
      final lower = format.toLowerCase();
      final userName = _displayUserName(ticket);
      final consultantName = _displayConsultantName(ticket);
      final ticketNo = _ticketNumber(ticket).replaceAll('/', '_');

      if (lower == 'xls') {
        final csv = StringBuffer(
            'Ticket Number,Category,User,Consultant,Status,Priority,Created,Description\n');
        csv.writeln(
          '"${_ticketNumber(ticket)}","${ticket.category}","$userName","$consultantName","${ticket.status}","${ticket.priority}","${ticket.createdAt ?? ''}","${(ticket.description ?? '').replaceAll('"', "'")}"',
        );
        await _shareTextFile(
          fileName: 'ticket_$ticketNo.csv',
          content: csv.toString(),
          mimeType: 'text/csv',
          subject: 'Ticket ${_ticketNumber(ticket)} (XLS)',
        );
        return;
      }

      final txt = StringBuffer()
        ..writeln('Ticket Number: ${_ticketNumber(ticket)}')
        ..writeln('Category: ${ticket.category}')
        ..writeln('User: $userName')
        ..writeln('Consultant: $consultantName')
        ..writeln('Status: ${ticket.status}')
        ..writeln('Priority: ${ticket.priority}')
        ..writeln('Created: ${ticket.createdAt ?? '--'}')
        ..writeln('Description: ${ticket.description ?? '--'}');
      await _shareTextFile(
        fileName: 'ticket_$ticketNo.txt',
        content: txt.toString(),
        mimeType: 'text/plain',
        subject: 'Ticket ${_ticketNumber(ticket)} (PDF)',
      );
    } catch (_) {
      if (mounted) _toast(context, 'Ticket export failed', error: true);
    }
  }

  Ticket _ticketWithDisplayNames(Ticket ticket) => Ticket(
        id: ticket.id,
        category: ticket.category,
        description: ticket.description,
        status: ticket.status,
        priority: ticket.priority,
        userId: ticket.userId,
        userName: _displayUserName(ticket),
        consultantId: ticket.consultantId,
        consultantName: _displayConsultantName(ticket),
        createdAt: ticket.createdAt,
        updatedAt: ticket.updatedAt,
        slaRespondBy: ticket.slaRespondBy,
        slaResolveBy: ticket.slaResolveBy,
        slaBreached: ticket.slaBreached,
        escalated: ticket.escalated,
        slaHours: ticket.slaHours,
        comments: ticket.comments,
      );

  Future<void> _openTicket(Ticket ticket) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TicketDetailScreen(
          ticket: _ticketWithDisplayNames(ticket),
          consultants: _consultants,
          role: 'ADMIN',
        ),
      ),
    );
    if (mounted) {
      _loadData(reset: true);
    }
  }

  // â”€â”€â”€ Create ticket â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _openCreate() async {
    List<Map<String, dynamic>> users = [];
    final cats = <String>{};
    try {
      final r = await _dio.get('/api/users');
      users = _arr(r.data, keys: const ['content', 'data', 'items', 'users'])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {}
    try {
      final r = await _dio.get('/api/admin/config/categories');
      for (final c in _arr(r.data,
              keys: const ['content', 'data', 'items', 'categories'])
          .whereType<Map>()) {
        final n = (c['name'] ?? '').toString().trim();
        if (n.isNotEmpty) cats.add(n);
      }
    } catch (_) {}
    cats.addAll(await _svc.getUniqueCategories());
    if (!mounted) return;

    final descCtrl = TextEditingController();
    final customCtrl = TextEditingController();
    int? userId;
    String? cat = cats.isNotEmpty ? cats.first : null;
    int? consultantId;
    String priority = 'MEDIUM';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
          builder: (ctx, ss) => Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Expanded(
                              child: Text('Create Ticket',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800))),
                          IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => Navigator.pop(ctx)),
                        ]),
                        const SizedBox(height: 14),
                        _dd<int>(
                          'User *',
                          Icons.person_outline_rounded,
                          userId,
                          items: users
                              .where((u) => _toInt(u['id']) != null)
                              .map((u) => DropdownMenuItem<int>(
                                  value: _toInt(u['id'])!,
                                  child: Text(
                                    (u['identifier'] ??
                                            u['name'] ??
                                            u['email'] ??
                                            'User')
                                        .toString(),
                                    overflow: TextOverflow.ellipsis,
                                  )))
                              .toList(),
                          onChanged: (v) => ss(() => userId = v),
                        ),
                        const SizedBox(height: 10),
                        if (cats.isNotEmpty)
                          _dd<String>(
                            'Category',
                            Icons.label_outline_rounded,
                            cat,
                            items: cats
                                .map((c) =>
                                    DropdownMenuItem(value: c, child: Text(c)))
                                .toList(),
                            onChanged: (v) => ss(() => cat = v),
                          ),
                        const SizedBox(height: 10),
                        _tf('Custom category (opt.)', Icons.edit_outlined,
                            customCtrl),
                        const SizedBox(height: 10),
                        _dd<String>(
                          'Priority',
                          Icons.flag_outlined,
                          priority,
                          items: _priorities
                              .where((p) => p != 'ALL')
                              .map((p) => DropdownMenuItem(
                                  value: p, child: Text(_pl(p))))
                              .toList(),
                          onChanged: (v) => ss(() => priority = v ?? 'MEDIUM'),
                        ),
                        const SizedBox(height: 10),
                        _dd<int?>(
                          'Consultant (opt.)',
                          Icons.support_agent_outlined,
                          consultantId,
                          items: [
                            const DropdownMenuItem<int?>(
                                value: null, child: Text('Unassigned')),
                            ..._consultants.map((c) => DropdownMenuItem<int?>(
                                value: c.id, child: Text(c.name))),
                          ],
                          onChanged: (v) => ss(() => consultantId = v),
                        ),
                        const SizedBox(height: 10),
                        _tf('Description *', Icons.description_outlined,
                            descCtrl,
                            maxLines: 4),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF0F766E)),
                            onPressed: () async {
                              final resolvedCat =
                                  customCtrl.text.trim().isNotEmpty
                                      ? customCtrl.text.trim()
                                      : (cat ?? '').trim();
                              if (userId == null) {
                                _toast(ctx, 'Select a user', error: true);
                                return;
                              }
                              if (resolvedCat.isEmpty) {
                                _toast(ctx, 'Enter a category', error: true);
                                return;
                              }
                              if (descCtrl.text.trim().isEmpty) {
                                _toast(ctx, 'Enter description', error: true);
                                return;
                              }
                              final t = await _svc.createTicket(
                                userId: userId!,
                                category: resolvedCat,
                                description: descCtrl.text.trim(),
                                priority: priority,
                                consultantId: consultantId,
                              );
                              if (t == null) {
                                if (mounted)
                                  _toast(ctx, 'Creation failed', error: true);
                                return;
                              }
                              Navigator.pop(ctx);
                              _toast(context, 'Ticket #${t.id} created');
                              _loadData(reset: true);
                            },
                            child: const Text('Create Ticket',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 15)),
                          ),
                        ),
                      ]),
                ),
              )),
    );
  }

  Widget _dd<T>(
    String label,
    IconData icon,
    T? value, {
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) =>
      DropdownButtonFormField<T>(
        value: value,
        decoration: _inp(label, icon: icon),
        items: items,
        onChanged: onChanged,
      );

  Widget _tf(String label, IconData icon, TextEditingController ctrl,
          {int maxLines = 1}) =>
      TextField(
          controller: ctrl,
          maxLines: maxLines,
          decoration: _inp(label, icon: icon));

  InputDecoration _inp(String label, {IconData? icon}) => InputDecoration(
        labelText: label,
        prefixIcon: icon != null
            ? Icon(icon, size: 19, color: const Color(0xFF64748B))
            : null,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF0F766E), width: 2)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // BUILD
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0F766E)))
          : RefreshIndicator(
              color: const Color(0xFF0F766E),
              onRefresh: () => _loadData(reset: true),
              child: CustomScrollView(
                controller: _scrollCtrl,
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        _buildEmailBanner(),
                        _buildHeader(),
                        _buildKpiRow(),
                        _buildSearchRow(),
                        _buildStatusChips(),
                      ],
                    ),
                  ),
                  if (_visible.isEmpty)
                    SliverToBoxAdapter(child: _buildEmpty())
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) {
                            final ticket = _visible[i];
                            return _TicketCard(
                              ticket: ticket,
                              consultants: _consultants,
                              userDisplayName: _displayUserName(ticket),
                              consultantDisplayName:
                                  _displayConsultantName(ticket),
                              onRefresh: () => _loadData(reset: true),
                            );
                          },
                          childCount: _visible.length,
                        ),
                      ),
                    ),
                  if (_loadingMore)
                    SliverToBoxAdapter(child: _buildLoadMoreIndicator()),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                ],
              ),
            ),
    );
  }

  Widget _buildEmailBanner() {
    final isDown = _emailStatus == 'down';
    final isChecking = _emailStatus == 'checking';
    final accent = isDown
        ? const Color(0xFFDC2626)
        : isChecking
            ? const Color(0xFFD97706)
            : const Color(0xFF0F766E);
    final bg = isDown
        ? const Color(0xFFFEF2F2)
        : isChecking
            ? const Color(0xFFFFFBEB)
            : const Color(0xFFF0FDFA);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (_, constraints) {
                final compact = constraints.maxWidth < 640;
                final title = isChecking
                    ? 'Checking Email-to-Ticket'
                    : isDown
                        ? 'Email-to-Ticket is Unavailable'
                        : 'Email-to-Ticket is Active';
                final subtitle = isChecking
                    ? 'Checking mailbox integration health.'
                    : isDown
                        ? 'Mailbox integration is unreachable or taking too long to respond.'
                        : 'Inbound support emails processed by the mailbox integration.';
                final info = Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.mail_outline_rounded,
                          size: 18, color: accent),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E3A8A)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: const TextStyle(
                                fontSize: 12.5, color: Color(0xFF475569)),
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                final statusChip = Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: accent.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    isChecking ? 'CHECKING' : (isDown ? 'DOWN' : 'HEALTHY'),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: accent),
                  ),
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      info,
                      const SizedBox(height: 10),
                      statusChip,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: info),
                    const SizedBox(width: 12),
                    statusChip,
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _checkEmail,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: accent.withValues(alpha: 0.45)),
                    foregroundColor: accent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  ),
                  child: const Text('Check',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                FilledButton(
                  onPressed: _polling ? null : _pollInbox,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  ),
                  child: _polling
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Poll Inbox',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: LayoutBuilder(
          builder: (_, constraints) {
            final compact = constraints.maxWidth < 840;
            final titleBlock = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Support Tickets',
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 2),
                Text('$_total total',
                    style: const TextStyle(
                        fontSize: 14, color: Color(0xFF64748B))),
              ],
            );

            final actions = _buildHeaderActions();

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  titleBlock,
                  const SizedBox(height: 10),
                  actions,
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: titleBlock),
                const SizedBox(width: 12),
                actions,
              ],
            );
          },
        ),
      );

  Widget _buildHeaderActions() => Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.end,
        children: [
          FilledButton.icon(
            onPressed: _openCreate,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New Ticket'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          OutlinedButton.icon(
            onPressed: _export,
            icon: const Icon(Icons.download_rounded, size: 16),
            label: Text('Export ($_total)'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF334155),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _loadData(reset: true),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Refresh'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0F766E),
              side: const BorderSide(color: Color(0xFF99F6E4)),
              backgroundColor: const Color(0xFFF0FDFA),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      );

  Widget _buildKpiRow() {
    final cards = <Map<String, dynamic>>[
      {
        'value': _total,
        'label': 'Total',
        'color': const Color(0xFF0F766E),
        'bg': const Color(0xFFE6FFFA),
        'bd': const Color(0xFF99F6E4),
      },
      {
        'value': _openCount,
        'label': 'Open / Active',
        'color': const Color(0xFFD97706),
        'bg': const Color(0xFFFFFBEB),
        'bd': const Color(0xFFFDE68A),
      },
      {
        'value': _overdueCount,
        'label': 'Overdue (SLA)',
        'color': const Color(0xFFDC2626),
        'bg': const Color(0xFFFEF2F2),
        'bd': const Color(0xFFFECACA),
      },
      {
        'value': _escalatedCount,
        'label': 'Escalated',
        'color': const Color(0xFFDC2626),
        'bg': const Color(0xFFFFF1F2),
        'bd': const Color(0xFFFDA4AF),
      },
      {
        'value': _resolvedCount,
        'label': 'Resolved',
        'color': const Color(0xFF16A34A),
        'bg': const Color(0xFFF0FDF4),
        'bd': const Color(0xFFBBF7D0),
      },
      {
        'value': _resolvedToday,
        'label': 'Resolved Today',
        'color': const Color(0xFF16A34A),
        'bg': const Color(0xFFF0FDF4),
        'bd': const Color(0xFFBBF7D0),
      },
      {
        'value': _closedCount,
        'label': 'Closed',
        'color': const Color(0xFF64748B),
        'bg': const Color(0xFFF1F5F9),
        'bd': const Color(0xFFCBD5E1),
      },
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: LayoutBuilder(
        builder: (_, constraints) {
          if (constraints.maxWidth < 900) {
            return SizedBox(
              height: 98,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: cards.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) => SizedBox(
                  width: 136,
                  child: _kpiCard(
                    value: cards[i]['value'] as int,
                    label: cards[i]['label'] as String,
                    color: cards[i]['color'] as Color,
                    background: cards[i]['bg'] as Color,
                    border: cards[i]['bd'] as Color,
                  ),
                ),
              ),
            );
          }

          final gap = 10.0;
          final width = (constraints.maxWidth - (gap * (cards.length - 1))) /
              cards.length;
          return Row(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                SizedBox(
                  width: width,
                  child: _kpiCard(
                    value: cards[i]['value'] as int,
                    label: cards[i]['label'] as String,
                    color: cards[i]['color'] as Color,
                    background: cards[i]['bg'] as Color,
                    border: cards[i]['bd'] as Color,
                  ),
                ),
                if (i < cards.length - 1) SizedBox(width: gap),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _kpiCard({
    required int value,
    required String label,
    required Color color,
    required Color background,
    required Color border,
  }) =>
      Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$value',
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w900, color: color),
            ),
            const SizedBox(height: 2),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _buildSearchRow() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: LayoutBuilder(
          builder: (_, constraints) {
            final compact = constraints.maxWidth < 620;

            final searchField = TextField(
              controller: _searchCtrl,
              onChanged: (v) {
                _search = v;
                _applyFilters();
              },
              decoration: InputDecoration(
                hintText: 'Search by ID, title, user, status, priority...',
                hintStyle:
                    const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: Color(0xFF94A3B8), size: 18),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: Color(0xFF0F766E), width: 1.5)),
              ),
            );

            final priorityDropdown = Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0))),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _priorityFilter,
                  style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF374151),
                      fontWeight: FontWeight.w600),
                  items: _priorities
                      .map((p) => DropdownMenuItem(
                          value: p,
                          child: Text(p == 'ALL' ? 'All Priorities' : _pl(p))))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _priorityFilter = v);
                      _applyFilters();
                    }
                  },
                ),
              ),
            );

            if (compact) {
              return Column(
                children: [
                  searchField,
                  const SizedBox(height: 8),
                  SizedBox(width: double.infinity, child: priorityDropdown),
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: searchField),
                const SizedBox(width: 8),
                priorityDropdown,
              ],
            );
          },
        ),
      );
  Widget _buildStatusChips() => SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          itemCount: _statuses.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final s = _statuses[i];
            final active = _statusFilter == s;
            final count = _chipCounts[s] ?? 0;
            final color = s == 'ALL' ? const Color(0xFF0F766E) : _sc(s);
            final bg = s == 'ALL' ? const Color(0xFF0F766E) : _sbg(s);
            final border = s == 'ALL' ? const Color(0xFF0F766E) : _sbd(s);

            return GestureDetector(
              onTap: () {
                setState(() => _statusFilter = s);
                _applyFilters();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                decoration: BoxDecoration(
                  color: active ? bg : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: active ? border : const Color(0xFFE2E8F0),
                      width: active ? 1.5 : 1),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(s == 'ALL' ? 'All' : _sl(s),
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              active ? FontWeight.w700 : FontWeight.w500,
                          color: active
                              ? (s == 'ALL' ? Colors.white : color)
                              : const Color(0xFF64748B))),
                  const SizedBox(width: 5),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: active
                          ? (s == 'ALL'
                              ? Colors.white.withValues(alpha: 0.3)
                              : color.withValues(alpha: 0.15))
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('$count',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: active
                                ? (s == 'ALL' ? Colors.white : color)
                                : const Color(0xFF64748B))),
                  ),
                ]),
              ),
            );
          },
        ),
      );

  Widget _buildEmpty() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Column(children: [
          Icon(Icons.inbox_outlined, size: 48, color: Color(0xFFCBD5E1)),
          SizedBox(height: 12),
          Text('No tickets found',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
        ]),
      );

  Widget _buildLoadMoreIndicator() => const Padding(
        padding: EdgeInsets.all(16),
        child:
            Center(child: CircularProgressIndicator(color: Color(0xFF0F766E))),
      );
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// TICKET CARD
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class _ColHeader extends StatelessWidget {
  final double width;
  final String label;

  const _ColHeader({
    required this.width,
    required this.label,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      );
}

class _TicketCard extends StatelessWidget {
  final Ticket ticket;
  final List<ConsultantModel> consultants;
  final String userDisplayName;
  final String consultantDisplayName;
  final VoidCallback onRefresh;

  const _TicketCard({
    required this.ticket,
    required this.consultants,
    required this.userDisplayName,
    required this.consultantDisplayName,
    required this.onRefresh,
  });

  String _fmtDate(dynamic d) {
    if (d == null) return '';
    try {
      final s = d.toString();
      final n = (s.endsWith('Z') || s.contains('+')) ? s : '${s}Z';
      return DateFormat('d MMM yy').format(DateTime.parse(n).toLocal());
    } catch (_) {
      return d.toString().length >= 10
          ? d.toString().substring(0, 10)
          : d.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sla = _slaLabel(ticket);
    final overdue = sla?.breached == true;
    final warning = sla?.warning == true;
    final escalated = _isEscalated(ticket);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: BorderSide(
          color: (overdue || escalated)
              ? const Color(0xFFFECACA)
              : const Color(0xFFE2E8F0),
        ),
      ),
      color: (overdue || escalated) ? const Color(0xFFFFF8F8) : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => TicketDetailScreen(
                    ticket: Ticket(
                      id: ticket.id,
                      category: ticket.category,
                      description: ticket.description,
                      status: ticket.status,
                      priority: ticket.priority,
                      userId: ticket.userId,
                      userName: userDisplayName,
                      consultantId: ticket.consultantId,
                      consultantName: consultantDisplayName,
                      createdAt: ticket.createdAt,
                      updatedAt: ticket.updatedAt,
                      slaRespondBy: ticket.slaRespondBy,
                      slaResolveBy: ticket.slaResolveBy,
                      slaBreached: ticket.slaBreached,
                      escalated: ticket.escalated,
                      slaHours: ticket.slaHours,
                      comments: ticket.comments,
                    ),
                    consultants: consultants,
                    role: 'ADMIN',
                  )),
        ).then((_) => onRefresh()),
        child: Row(children: [
          // Left accent border
          Container(
            width: 4,
            constraints: const BoxConstraints(minHeight: 80),
            decoration: BoxDecoration(
              color: (overdue || escalated)
                  ? const Color(0xFFDC2626)
                  : warning
                      ? const Color(0xFFF59E0B)
                      : Colors.transparent,
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(13)),
            ),
          ),
          Expanded(
              child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 14, 14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Row 1: id + title + status
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Row(children: [
                        Text('#${ticket.id}',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: overdue
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF94A3B8),
                                fontFamily: 'monospace')),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            ticket.category.isEmpty
                                ? 'General'
                                : ticket.category,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F766E)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ]),
                      if (ticket.description?.isNotEmpty == true) ...[
                        const SizedBox(height: 3),
                        Text(ticket.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                                height: 1.4)),
                      ],
                    ])),
                const SizedBox(width: 8),
                // Status chip
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _sbg(ticket.status),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _sbd(ticket.status)),
                  ),
                  child: Text(_sl(ticket.status),
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _sc(ticket.status))),
                ),
              ]),

              // SLA badge
              if (sla != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: overdue
                        ? const Color(0xFFFEE2E2)
                        : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                        overdue ? Icons.timer_off_rounded : Icons.timer_rounded,
                        size: 11,
                        color: overdue
                            ? const Color(0xFFDC2626)
                            : const Color(0xFFF59E0B)),
                    const SizedBox(width: 4),
                    Text(sla.label,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: overdue
                                ? const Color(0xFFDC2626)
                                : const Color(0xFFF59E0B))),
                  ]),
                ),
              ],

              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 8),

              LayoutBuilder(
                builder: (_, constraints) {
                  if (constraints.maxWidth < 380) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.person_outline_rounded,
                              size: 13, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              userDisplayName,
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xFF64748B)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ]),
                        const SizedBox(height: 4),
                        Text(
                          consultantDisplayName,
                          style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF475569),
                              fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    );
                  }

                  return Row(children: [
                    const Icon(Icons.person_outline_rounded,
                        size: 13, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        userDisplayName,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF64748B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        consultantDisplayName,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF475569),
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]);
                },
              ),
              const SizedBox(height: 7),
              Row(children: [
                Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, color: _pc(ticket.priority))),
                const SizedBox(width: 4),
                Text(_pl(ticket.priority),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _pc(ticket.priority))),
                if (ticket.createdAt?.isNotEmpty == true) ...[
                  const SizedBox(width: 10),
                  const Icon(Icons.access_time_rounded,
                      size: 11, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 3),
                  Text(_fmtDate(ticket.createdAt),
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF94A3B8))),
                ],
                const Spacer(),
                const Icon(Icons.arrow_forward_rounded,
                    size: 14, color: Color(0xFF0F766E)),
              ]),
            ]),
          )),
        ]),
      ),
    );
  }
}
