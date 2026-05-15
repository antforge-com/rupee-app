// lib/ticket_detail_screen.dart
// ════════════════════════════════════════════════════════════════════════════
// TICKET DETAIL SCREEN — Pixel-perfect web parity
//
// Matches AdminPage.tsx TicketDetailPanel exactly:
//   • Teal gradient header (#0F766E→#134E4A) with TICKET NUMBER label
//   • Status chip, priority chip (clickable dropdown), date chip, Assign btn
//   • SLA breach strip (red, "Overdue by X min")
//   • Conversation tab: progress stepper + Change Status chips +
//     Change Priority chips + Description block + conversation thread +
//     Reply to Customer box + Internal Notes (yellow) +
//     Escalate Ticket section (orange) + Danger Zone (red)
//   • Details tab: same as above without chat thread
//   • Auto-Responder message shows as first 🤖 bubble in thread
//
// Model fields used (from actual models.dart in zip):
//   TicketNote  → .content,    .authorName,  .createdAt
//   TicketComment → .message,  .authorName,  .isConsultantReply, .createdAt
//   Ticket      → .escalated (bool flag),  .slaBreached (bool flag)
// ════════════════════════════════════════════════════════════════════════════

// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:finadvise/models/models.dart';
import 'package:finadvise/services/admin_service.dart';
import 'package:finadvise/services/ticket_service.dart';
import 'package:finadvise/shared/ticket_number_formatter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

// ─── Timestamp helpers ────────────────────────────────────────────────────────

DateTime? _parseServerDateTime(dynamic raw) {
  final value = raw?.toString().trim() ?? '';
  if (value.isEmpty) return null;
  final hasTimezone =
      value.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(value);
  final parsed = DateTime.tryParse(hasTimezone ? value : '${value}Z');
  if (parsed != null) return parsed.toLocal();
  return DateTime.tryParse(value)?.toLocal();
}

String _fmtDate(dynamic d) {
  final parsed = _parseServerDateTime(d);
  if (parsed != null) return DateFormat('dd MMM yyyy').format(parsed);
  final raw = d?.toString().trim() ?? '';
  if (raw.isEmpty) return '--';
  return raw.length >= 10 ? raw.substring(0, 10) : raw;
}

String _fmtTime(dynamic d) {
  final parsed = _parseServerDateTime(d);
  if (parsed == null) return '';
  return '${DateFormat('hh:mm a').format(parsed)} IST';
}

String _fmtDT(dynamic d) {
  final parsed = _parseServerDateTime(d);
  if (parsed != null) {
    return '${DateFormat('dd MMM yyyy, hh:mm a').format(parsed)} IST';
  }
  return d?.toString() ?? '--';
}

// ─── SLA ─────────────────────────────────────────────────────────────────────

const _slaMap = {
  'LOW': 72,
  'MEDIUM': 24,
  'HIGH': 8,
  'URGENT': 4,
  'CRITICAL': 2
};

class _Sla {
  final bool breached;
  final int overdueMin;
  final String label;
  const _Sla(this.breached, this.overdueMin, this.label);
}

_Sla? _calcSla(
    String? createdAt, String status, String priority, bool backendBreached) {
  if (['RESOLVED', 'CLOSED'].contains(status.toUpperCase())) return null;
  if (backendBreached) return const _Sla(true, 0, 'SLA BREACHED');
  if (createdAt == null || createdAt.isEmpty) return null;
  try {
    final h = _slaMap[priority.toUpperCase()] ?? 24;
    final created = _parseServerDateTime(createdAt);
    if (created == null) return null;
    final deadline = created.add(Duration(hours: h));
    final minsLeft = deadline.difference(DateTime.now()).inMinutes;
    if (minsLeft >= 0) return null;
    return _Sla(true, -minsLeft, 'SLA BREACHED – $priority – ${h}h window');
  } catch (_) {
    return null;
  }
}

// ─── Colour config (web-exact) ────────────────────────────────────────────────

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
  'LOW': [Color(0xFF16A34A), Color(0xFFF0FDF4), Color(0xFF86EFAC), 'Low'],
  'MEDIUM': [Color(0xFFD97706), Color(0xFFFFFBEB), Color(0xFFFCD34D), 'Medium'],
  'HIGH': [Color(0xFFEA580C), Color(0xFFFFF7ED), Color(0xFFFED7AA), 'High'],
  'URGENT': [Color(0xFFDC2626), Color(0xFFFEF2F2), Color(0xFFFCA5A5), 'Urgent'],
  'CRITICAL': [
    Color(0xFF7C3AED),
    Color(0xFFF5F3FF),
    Color(0xFFDDD6FE),
    'Critical'
  ],
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
Color _pbg(String p) =>
    (_pCfg[p.toUpperCase()]?[1] as Color?) ?? const Color(0xFFF1F5F9);
Color _pbd(String p) =>
    (_pCfg[p.toUpperCase()]?[2] as Color?) ?? const Color(0xFFCBD5E1);
String _pl(String p) => (_pCfg[p.toUpperCase()]?[3] as String?) ?? p;

// ─── Progress stepper steps (web-exact) ──────────────────────────────────────

const _steps = [
  ['NEW', 'Submitted'],
  ['OPEN', 'Assigned'],
  ['IN_PROGRESS', 'Pending'],
  ['RESOLVED', 'Resolved'],
  ['CLOSED', 'Closed'],
];
const _stepIcons = [
  Icons.send_rounded,
  Icons.person_outline_rounded,
  Icons.settings_outlined,
  Icons.check_circle_outline_rounded,
  Icons.lock_outline_rounded,
];
int _stepIdx(String s) {
  final i = _steps.indexWhere((e) => e[0] == s.toUpperCase());
  return i < 0 ? 0 : i;
}

// ─── Toast ────────────────────────────────────────────────────────────────────

void _toast(BuildContext ctx, String msg, {bool ok = true}) {
  ScaffoldMessenger.of(ctx)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(ok ? Icons.check_rounded : Icons.close_rounded,
            color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Expanded(
            child:
                Text(msg, style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
      backgroundColor: ok ? const Color(0xFF0F172A) : const Color(0xFF7F1D1D),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      duration: Duration(seconds: ok ? 2 : 4),
    ));
}

// ════════════════════════════════════════════════════════════════════════════
// SCREEN
// ════════════════════════════════════════════════════════════════════════════

class TicketDetailScreen extends StatefulWidget {
  final Ticket ticket;
  final List<ConsultantModel> consultants;
  final String role; // 'ADMIN' | 'CONSULTANT' | 'USER'

  const TicketDetailScreen({
    super.key,
    required this.ticket,
    this.consultants = const [],
    this.role = 'ADMIN',
  });

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen>
    with SingleTickerProviderStateMixin {
  final _svc = TicketService();
  final _adminSvc = AdminService();
  late TabController _tab;
  final _replyCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _replyFocusNode = FocusNode();
  final _noteFocusNode = FocusNode();

  late Ticket _t;
  String _status = '';
  String _priority = '';
  List<TicketComment> _comments = [];
  List<TicketNote> _notes = [];
  String _autoRespMsg = ''; // From GET /api/admin/settings/auto-responder

  bool _loadingThread = true;
  bool _loadingNotes = true;
  bool _sending = false;
  bool _postingNote = false;
  bool _updStatus = false;
  bool _updPriority = false;
  bool _escalating = false;
  bool _deleting = false;
  bool _showPrioDrop = false;

  @override
  void initState() {
    super.initState();
    _t = widget.ticket;
    _status = _t.status.toUpperCase();
    _priority = _t.priority.toUpperCase();
    _tab = TabController(length: 1, vsync: this);
    _loadComments();
    _loadNotes();
    _loadAutoResponder();
  }

  @override
  void dispose() {
    _tab.dispose();
    _replyCtrl.dispose();
    _noteCtrl.dispose();
    _scrollCtrl.dispose();
    _replyFocusNode.dispose();
    _noteFocusNode.dispose();
    super.dispose();
  }

  // ─── Loaders ─────────────────────────────────────────────────────────────

  Future<void> _loadComments() async {
    setState(() => _loadingThread = true);
    final r = await _svc.getTicketComments(_t.id);
    if (mounted)
      setState(() {
        _comments = r;
        _loadingThread = false;
      });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients && _scrollCtrl.position.maxScrollExtent > 0) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  Future<void> _loadNotes() async {
    setState(() => _loadingNotes = true);
    final r = await _svc.getNotes(_t.id);
    if (mounted)
      setState(() {
        _notes = r;
        _loadingNotes = false;
      });
  }

  Future<void> _loadAutoResponder() async {
    try {
      final data = await _adminSvc.getAutoResponder();
      if (data != null && data['enabled'] == true && mounted) {
        setState(() => _autoRespMsg = data['message']?.toString() ?? '');
      }
    } catch (_) {}
  }

  Future<void> _refreshTicket() async {
    final u = await _svc.getTicketById(_t.id);
    if (u != null && mounted) {
      setState(() {
        _t = u;
        _status = u.status.toUpperCase();
        _priority = u.priority.toUpperCase();
      });
    }
  }

  String _normMsg(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  bool _looksLikeAutoResponderText(String raw) {
    final msg = _normMsg(raw);
    if (msg.isEmpty) return false;
    if (msg.startsWith('auto-response:') || msg.startsWith('auto response:')) {
      return true;
    }
    if (_autoRespMsg.isEmpty) return false;
    final auto = _normMsg(_autoRespMsg);
    if (auto.isEmpty) return false;
    return msg.contains(auto) || auto.contains(msg);
  }

  List<TicketComment> _dedupedComments() {
    final autoResponderComments =
        _comments.where((c) => _looksLikeAutoResponderText(c.message)).toList();
    TicketComment? preferredAutoResponder;
    if (autoResponderComments.where((c) => c.isConsultantReply).isNotEmpty) {
      preferredAutoResponder =
          autoResponderComments.firstWhere((c) => c.isConsultantReply);
    } else if (_autoRespMsg.isEmpty && autoResponderComments.isNotEmpty) {
      preferredAutoResponder = autoResponderComments.first;
    }

    final seen = <String>{};
    final out = <TicketComment>[];

    for (final comment in _comments) {
      if (_looksLikeAutoResponderText(comment.message)) {
        continue;
      }
      final key = [
        _normMsg(comment.message),
        _normMsg(comment.authorName ?? ''),
        _normMsg(comment.createdAt ?? ''),
        comment.isConsultantReply ? 'agent' : 'customer',
      ].join('|');
      if (seen.contains(key)) continue;
      seen.add(key);
      out.add(comment);
    }

    if (preferredAutoResponder != null) {
      out.insert(0, preferredAutoResponder);
    }

    return out;
  }

  bool _shouldShowInjectedAutoResponder(List<TicketComment> comments) {
    if (_autoRespMsg.isEmpty) return false;
    return !comments
        .any((comment) => _looksLikeAutoResponderText(comment.message));
  }

  int _conversationCount(List<TicketComment> comments) =>
      comments.length + (_shouldShowInjectedAutoResponder(comments) ? 1 : 0);

  // ─── Actions ─────────────────────────────────────────────────────────────

  Future<void> _sendReply() async {
    final msg = _replyCtrl.text.trim();
    if (msg.isEmpty) return;
    setState(() => _sending = true);
    try {
      final r = await _svc.addComment(_t.id, msg,
          senderId: _t.consultantId ?? 1,
          isConsultantReply: widget.role != 'USER');
      if (r != null) {
        _replyCtrl.clear();
        // Auto-advance status: NEW → OPEN (web does same)
        if (_status == 'NEW') await _changeStatus('OPEN', silent: true);
        await _loadComments();
        if (mounted) _toast(context, 'Reply sent — customer will be notified');
      } else {
        if (mounted) _toast(context, 'Failed to send reply', ok: false);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _postNote() async {
    final text = _noteCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _postingNote = true);
    try {
      // POST /api/tickets/{id}/notes  body: { authorId, noteText }
      final r = await _svc.addNote(_t.id,
          authorId: _t.consultantId ?? 1, noteText: text);
      if (r != null) {
        _noteCtrl.clear();
        await _loadNotes();
        if (mounted) _toast(context, 'Note saved');
      } else {
        if (mounted) _toast(context, 'Failed to save note', ok: false);
      }
    } finally {
      if (mounted) setState(() => _postingNote = false);
    }
  }

  Future<void> _changeStatus(String s, {bool silent = false}) async {
    if (_updStatus || _status == s) return;
    setState(() => _updStatus = true);
    try {
      final ok = await _svc.updateTicketStatus(_t.id, s);
      if (ok) {
        setState(() => _status = s);
        if (!silent && mounted) _toast(context, 'Status → ${_sl(s)}');
      } else {
        if (mounted) _toast(context, 'Status update failed', ok: false);
      }
    } finally {
      if (mounted) setState(() => _updStatus = false);
    }
  }

  Future<void> _changePriority(String p) async {
    if (_updPriority || _priority == p) return;
    if (['RESOLVED', 'CLOSED', 'ESCALATED'].contains(_status)) return;
    final prev = _priority;
    setState(() {
      _priority = p;
      _showPrioDrop = false;
      _updPriority = true;
    });
    try {
      final ok = await _svc.updateTicketPriority(_t.id, p);
      if (ok) {
        if (mounted) _toast(context, 'Priority → ${_pl(p)}');
      } else {
        setState(() => _priority = prev);
        if (mounted) _toast(context, 'Priority update failed', ok: false);
      }
    } finally {
      if (mounted) setState(() => _updPriority = false);
    }
  }

  Future<void> _escalate() async {
    if (_status == 'ESCALATED') return;
    setState(() => _escalating = true);
    try {
      final ok = await _svc.escalateTicket(
          _t.id, 'Customer requested urgent attention');
      if (ok) {
        setState(() => _status = 'ESCALATED');
        if (mounted) _toast(context, 'Ticket escalated');
      } else {
        if (mounted) _toast(context, 'Escalation failed', ok: false);
      }
    } finally {
      if (mounted) setState(() => _escalating = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Ticket $_displayId?',
            style: const TextStyle(
                fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
        content: const Text('This action cannot be undone.',
            style: TextStyle(fontSize: 13, color: Color(0xFF374151))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Ticket'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _deleting = true);
    final ok = await _svc.deleteTicket(_t.id);
    if (mounted) {
      setState(() => _deleting = false);
      if (ok) {
        _toast(context, 'Ticket deleted');
        Navigator.pop(context, true);
      } else {
        _toast(context, 'Delete failed', ok: false);
      }
    }
  }

  Future<void> _assignConsultant() async {
    if (['CLOSED', 'RESOLVED', 'ESCALATED'].contains(_status)) {
      _toast(context, 'Cannot reassign — ticket is ${_sl(_status)}', ok: false);
      return;
    }
    int? sel = _t.consultantId;
    final result = await showDialog<int?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
          builder: (ctx, ss) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                title: const Text('Assign Consultant',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                content: DropdownButtonFormField<int?>(
                  value: sel,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                        value: null, child: Text('Unassigned')),
                    ...widget.consultants.map((c) => DropdownMenuItem<int?>(
                        value: c.id, child: Text(c.name))),
                  ],
                  onChanged: (v) => ss(() => sel = v),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel')),
                  FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E)),
                    onPressed: () => Navigator.pop(ctx, sel),
                    child: const Text('Assign'),
                  ),
                ],
              )),
    );
    if (result == null) return;
    final selectedConsultant =
        widget.consultants.where((c) => c.id == result).toList();
    final selectedConsultantName =
        selectedConsultant.isNotEmpty ? selectedConsultant.first.name : null;
    final ok = await _svc.assignTicket(_t.id, result);
    if (ok) {
      await _refreshTicket();
      if (mounted && selectedConsultantName != null) {
        setState(() {
          _t = Ticket(
            id: _t.id,
            category: _t.category,
            description: _t.description,
            status: _t.status,
            priority: _t.priority,
            userId: _t.userId,
            userName: _t.userName,
            consultantId: result,
            consultantName: selectedConsultantName,
            createdAt: _t.createdAt,
            updatedAt: _t.updatedAt,
            slaRespondBy: _t.slaRespondBy,
            slaResolveBy: _t.slaResolveBy,
            slaBreached: _t.slaBreached,
            escalated: _t.escalated,
            slaHours: _t.slaHours,
            comments: _t.comments,
          );
        });
      }
      if (mounted) _toast(context, 'Consultant assigned');
    } else {
      if (mounted) _toast(context, 'Assignment failed', ok: false);
    }
  }

  Future<void> _export(String fmt) async {
    try {
      final dir = await getTemporaryDirectory();
      final txt = 'Ticket $_displayId\nCategory: ${_t.category}\n'
          'Status: ${_t.status}\nPriority: ${_t.priority}\n'
          'Description: ${_t.description ?? ''}\n'
          'User: $_userDisplayName\n'
          'Consultant: $_consultantDisplayName\n'
          'Created: ${_fmtDT(_t.createdAt)}\n';
      final fileToken = _displayId.replaceAll('/', '_');
      final file = File('${dir.path}/ticket_${fileToken}_${_t.id}.txt');
      await file.writeAsString(txt);
      await Share.shareXFiles([XFile(file.path)],
          subject: 'Ticket $_displayId');
    } catch (_) {
      if (mounted) _toast(context, 'Export failed', ok: false);
    }
  }

  // ─── Getters ─────────────────────────────────────────────────────────────

  String get _displayId => formatTicketNumber(createdAt: _t.createdAt);
  bool get _isTerminal => ['RESOLVED', 'CLOSED', 'ESCALATED'].contains(_status);

  String _prettyName(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '';
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

  String get _userDisplayName {
    final direct = _prettyName(_t.userName ?? '');
    if (direct.isNotEmpty && direct.toLowerCase() != 'user') return direct;
    return _t.userId != null ? 'User #${_t.userId}' : 'User';
  }

  String get _consultantDisplayName {
    final direct = _prettyName(_t.consultantName ?? '');
    if (direct.isNotEmpty &&
        direct.toLowerCase() != 'consultant' &&
        direct.toLowerCase() != 'unassigned') {
      return direct;
    }
    if (_t.consultantId != null) {
      final match = widget.consultants.where((c) => c.id == _t.consultantId);
      if (match.isNotEmpty && match.first.name.trim().isNotEmpty) {
        return match.first.name.trim();
      }
      return 'Consultant #${_t.consultantId}';
    }
    return 'Unassigned';
  }

  // ════════════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final sla = _calcSla(_t.createdAt, _status, _priority, _t.slaBreached);
    return GestureDetector(
      onTap: () => setState(() => _showPrioDrop = false),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        resizeToAvoidBottomInset: true,
        body: Column(children: [
          _buildHeader(),
          if (sla != null && sla.breached) _buildSlaStrip(sla),
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tab,
              labelColor: const Color(0xFF0F766E),
              unselectedLabelColor: const Color(0xFF94A3B8),
              indicatorColor: const Color(0xFF0F766E),
              indicatorWeight: 2.5,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              tabs: const [Tab(text: 'Conversation')],
            ),
          ),
          Expanded(
              child: TabBarView(
            controller: _tab,
            children: [_buildConvTab()],
          )),
        ]),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // HEADER  (teal gradient — web exact)
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildHeader() {
    final isTerminal = _isTerminal;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF134E4A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
          bottom: false,
          child: Column(children: [
            // Top row
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 8, 0),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('TICKET NUMBER $_displayId',
                          style: const TextStyle(
                              fontSize: 9,
                              color: Color(0xFF99F6E4),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2)),
                      Text(_t.category.isEmpty ? 'General' : _t.category,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text('$_userDisplayName - $_consultantDisplayName',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFFA5F3FC)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ])),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.download_outlined,
                      color: Colors.white, size: 20),
                  tooltip: 'Export',
                  onSelected: _export,
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'XLS', child: Text('Export XLS')),
                    PopupMenuItem(value: 'PDF', child: Text('Export PDF')),
                  ],
                ),
              ]),
            ),

            // Chips row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  // Status chip
                  _hChip(
                      _sl(_status), _sc(_status), _sbg(_status), _sbd(_status)),
                  const SizedBox(width: 6),

                  // Priority chip + dropdown
                  Stack(clipBehavior: Clip.none, children: [
                    GestureDetector(
                      onTap: () =>
                          setState(() => _showPrioDrop = !_showPrioDrop),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _pbg(_priority),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _pbd(_priority), width: 2),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.flag_outlined,
                              size: 11, color: _pc(_priority)),
                          const SizedBox(width: 4),
                          Text(_pl(_priority),
                              style: TextStyle(
                                  color: _pc(_priority),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                          if (!_isTerminal)
                            Icon(Icons.arrow_drop_down_rounded,
                                size: 14, color: _pc(_priority)),
                        ]),
                      ),
                    ),
                    if (_showPrioDrop && !isTerminal)
                      Positioned(
                        top: 34,
                        left: 0,
                        child: Material(
                          elevation: 8,
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.white,
                          child: Container(
                            width: 130,
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border:
                                    Border.all(color: const Color(0xFFE2E8F0))),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                'LOW',
                                'MEDIUM',
                                'HIGH',
                                'URGENT',
                                'CRITICAL'
                              ].map((p) {
                                final active = _priority == p;
                                return GestureDetector(
                                  onTap: () => _changePriority(p),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 9),
                                    decoration: BoxDecoration(
                                      color:
                                          active ? _pbg(p) : Colors.transparent,
                                      border: Border(
                                          left: BorderSide(
                                              color: active
                                                  ? _pc(p)
                                                  : Colors.transparent,
                                              width: 3)),
                                    ),
                                    child: Row(children: [
                                      Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: _pc(p))),
                                      const SizedBox(width: 8),
                                      Expanded(
                                          child: Text(_pl(p),
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: active
                                                      ? FontWeight.w800
                                                      : FontWeight.w600,
                                                  color: active
                                                      ? _pc(p)
                                                      : const Color(
                                                          0xFF374151)))),
                                      if (active)
                                        Icon(Icons.check_rounded,
                                            size: 12, color: _pc(p)),
                                    ]),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                  ]),
                  const SizedBox(width: 6),

                  // Date chip
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.calendar_month_outlined,
                          size: 12, color: Color(0xFFE0F2FE)),
                      const SizedBox(width: 4),
                      Text(_fmtDate(_t.createdAt),
                          style: const TextStyle(
                              color: Color(0xFFE0F2FE),
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ),
                  const SizedBox(width: 6),

                  // Assign consultant button
                  if (widget.role == 'ADMIN')
                    isTerminal
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15)),
                            ),
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.lock_outline_rounded,
                                  size: 12,
                                  color: _status == 'ESCALATED'
                                      ? const Color(0xFFFCA5A5)
                                      : Colors.white.withValues(alpha: 0.4)),
                              const SizedBox(width: 4),
                              Text(
                                '${_sl(_status)} - No Reassign',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _status == 'ESCALATED'
                                      ? const Color(0xFFFCA5A5)
                                      : Colors.white.withValues(alpha: 0.4),
                                ),
                              ),
                            ]),
                          )
                        : GestureDetector(
                            onTap: _assignConsultant,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3)),
                              ),
                              child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.person_add_outlined,
                                        size: 13, color: Colors.white),
                                    SizedBox(width: 5),
                                    Text('Assign Consultant',
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white)),
                                  ]),
                            ),
                          ),
                ]),
              ),
            ),
          ])),
    );
  }

  Widget _hChip(String label, Color color, Color bg, Color border) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border)),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      );

  // ─── SLA strip ───────────────────────────────────────────────────────────

  Widget _buildSlaStrip(_Sla sla) => Container(
        color: const Color(0xFFFEF2F2),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                  color: Color(0xFFDC2626), shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(sla.label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFDC2626),
                        fontSize: 12)),
                if (sla.overdueMin > 0)
                  Text('Overdue by ${sla.overdueMin} min',
                      style: const TextStyle(
                          color: Color(0xFF9B1C1C), fontSize: 11)),
              ])),
        ]),
      );

  // ════════════════════════════════════════════════════════════════════════
  // CONVERSATION TAB
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildConvTab() => Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollCtrl,
              padding: EdgeInsets.zero,
              children: [
                _buildStepper(),
                _div(),
                _buildStatusSection(),
                _div(),
                _buildPrioritySection(),
                _div(),
                _buildDescSection(),
                _div(),
                _buildThread(),
                const SizedBox(height: 8),
              ],
            ),
          ),
          _buildReplyBox(),
          _buildNotesBox(),
          _buildEscalateBox(),
          _buildDangerBox(),
        ],
      );

  // ── Thread ────────────────────────────────────────────────────────────────

  Widget _buildThread() {
    if (_loadingThread) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Row(children: [
              Icon(Icons.chat_bubble_outline_rounded,
                  size: 13, color: Color(0xFF64748B)),
              SizedBox(width: 6),
              Text('CONVERSATION',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.6)),
            ]),
            SizedBox(height: 16),
            Center(
                child: Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(color: Color(0xFF0F766E)),
            )),
          ],
        ),
      );
    }

    final comments = _dedupedComments();
    final showInjectedAutoResponder =
        _shouldShowInjectedAutoResponder(comments);
    final visibleCount = _conversationCount(comments);

    // Show the user's original issue description as the first chat bubble
    // so admins can see the full context without scrolling to the Description section.
    final desc = _t.description?.trim() ?? '';
    final descBubble = (desc.isNotEmpty && desc != 'No description provided.')
        ? _descriptionBubble(desc)
        : null;

    final bubbles = <Widget>[
      if (descBubble != null) descBubble,
      if (showInjectedAutoResponder) _autoRespBubble(),
      ...comments.map(_bubble),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.chat_bubble_outline_rounded,
                size: 13, color: Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text('CONVERSATION ($visibleCount)',
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.6)),
          ]),
          const SizedBox(height: 12),
          if (bubbles.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(children: [
                  Icon(Icons.chat_bubble_outline_rounded,
                      size: 40, color: Color(0xFFCBD5E1)),
                  SizedBox(height: 10),
                  Text('No messages yet.',
                      style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 13,
                          fontStyle: FontStyle.italic)),
                ]),
              ),
            )
          else
            ...bubbles,
        ],
      ),
    );
  }

  Widget _autoRespBubble() => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Text('Agent',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF475569))),
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                            color: const Color(0xFFECFEFF),
                            borderRadius: BorderRadius.circular(3)),
                        child: const Text('AGENT',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F766E))),
                      ),
                    ]),
                    const SizedBox(height: 3),
                    Container(
                      constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.76),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 13, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFEFF),
                        border: Border.all(color: const Color(0xFFA5F3FC)),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(4),
                        ),
                      ),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('🤖 ', style: TextStyle(fontSize: 14)),
                            Expanded(
                                child: Text('Auto-Response: $_autoRespMsg',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        height: 1.6,
                                        color: Color(0xFF0F172A)))),
                          ]),
                    ),
                  ])),
              const SizedBox(width: 10),
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                        colors: [Color(0xFF0F766E), Color(0xFF134E4A)])),
                alignment: Alignment.center,
                child: const Text('A',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              ),
            ]),
      );

  Widget _bubble(TicketComment c) {
    final isAgent = c.isConsultantReply;
    final name = (c.authorName?.isNotEmpty == true)
        ? c.authorName!
        : isAgent
            ? 'Agent'
            : _userDisplayName;
    final timeLabel = _fmtTime(c.createdAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isAgent ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isAgent) ...[
            _avatar(
                name,
                const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)])),
            const SizedBox(width: 10),
          ],
          Flexible(
              child: Column(
            crossAxisAlignment:
                isAgent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569))),
                const SizedBox(width: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: isAgent
                        ? const Color(0xFFECFEFF)
                        : const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(isAgent ? 'AGENT' : 'CUSTOMER',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: isAgent
                              ? const Color(0xFF0F766E)
                              : const Color(0xFFD97706))),
                ),
                if (timeLabel.isNotEmpty)
                  Text(' · $timeLabel',
                      style: const TextStyle(
                          fontSize: 9, color: Color(0xFF94A3B8))),
              ]),
              const SizedBox(height: 3),
              Container(
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.76),
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                decoration: BoxDecoration(
                  color: isAgent
                      ? const Color(0xFFECFEFF)
                      : const Color(0xFFFFF7ED),
                  border: Border.all(
                      color: isAgent
                          ? const Color(0xFFA5F3FC)
                          : const Color(0xFFFED7AA)),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(12),
                    topRight: const Radius.circular(12),
                    bottomLeft: Radius.circular(isAgent ? 12 : 4),
                    bottomRight: Radius.circular(isAgent ? 4 : 12),
                  ),
                ),
                child: Text(c.message,
                    style: TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: isAgent
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF92400E))),
              ),
            ],
          )),
          if (isAgent) ...[
            const SizedBox(width: 10),
            _avatar(
                name,
                const LinearGradient(
                    colors: [Color(0xFF0F766E), Color(0xFF134E4A)])),
          ],
        ],
      ),
    );
  }

  // ── Description bubble — shows the user's original issue in the chat thread ─

  // ── Strip HTML tags and decode common HTML entities ──────────────────────
  // Pure Dart — no external package required.
  String _stripHtml(String html) {
    // Replace block-level tags with newlines so paragraphs are preserved
    var text = html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<p[^>]*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<div[^>]*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</div>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '\n• ')
        .replaceAll(RegExp(r'<[^>]+>', caseSensitive: false),
            '') // strip remaining tags
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ');

    // Collapse 3+ consecutive newlines into 2 and trim
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    return text.isEmpty
        ? html
        : text; // fallback to original if stripping yields empty
  }

  Widget _descriptionBubble(String description) {
    final name = _userDisplayName.isNotEmpty ? _userDisplayName : 'Customer';
    // Strip HTML so raw tags like <br>, <div> are not shown to admin
    final cleanDesc = _stripHtml(description);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _avatar(
            name,
            const LinearGradient(
                colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569))),
                  const SizedBox(width: 5),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text('CUSTOMER',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFD97706))),
                  ),
                  const Text(' · Original Issue',
                      style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                ]),
                const SizedBox(height: 3),
                Container(
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.76),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    border: Border.all(color: const Color(0xFFFED7AA)),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                      bottomLeft: Radius.circular(4),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Text(cleanDesc,
                      style: const TextStyle(
                          fontSize: 13, height: 1.6, color: Color(0xFF92400E))),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(String name, Gradient gradient) => Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: gradient),
        alignment: Alignment.center,
        child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12)),
      );

  // ── Reply to Customer ─────────────────────────────────────────────────────

  Widget _buildReplyBox() => Container(
        padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            (MediaQuery.of(context).viewInsets.bottom > 0
                    ? MediaQuery.of(context).viewInsets.bottom
                    : MediaQuery.of(context).padding.bottom) +
                12),
        color: const Color(0xFFF8FAFC),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('REPLY TO CUSTOMER',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.6)),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
                child: TextField(
              controller: _replyCtrl,
              focusNode: _replyFocusNode,
              minLines: 2,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
              onTap: () {
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (_scrollCtrl.hasClients) {
                    _scrollCtrl.animateTo(
                      _scrollCtrl.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                });
              },
              decoration: const InputDecoration(
                hintText: 'Type your message...',
                hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.all(12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                    borderSide:
                        BorderSide(color: Color(0xFFA5F3FC), width: 1.5)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                    borderSide:
                        BorderSide(color: Color(0xFFA5F3FC), width: 1.5)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                    borderSide: BorderSide(color: Color(0xFF0F766E), width: 2)),
              ),
            )),
            const SizedBox(width: 8),
            SizedBox(
                height: 42,
                child: ElevatedButton(
                  onPressed: _sending ? null : _sendReply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _replyCtrl.text.trim().isEmpty
                        ? const Color(0xFFE2E8F0)
                        : const Color(0xFF0F766E),
                    foregroundColor: _replyCtrl.text.trim().isEmpty
                        ? const Color(0xFF94A3B8)
                        : Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: _sending
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, size: 18),
                )),
          ]),
        ]),
      );

  // ── Internal Notes (yellow) ───────────────────────────────────────────────

  Widget _buildNotesBox() => Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: const BoxDecoration(
          color: Color(0xFFFFFBEB),
          border: Border.symmetric(
              horizontal: BorderSide(color: Color(0xFFFEF9C3))),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: const [
            Icon(Icons.lock_outline_rounded,
                size: 12, color: Color(0xFF92400E)),
            SizedBox(width: 6),
            Text('INTERNAL NOTES',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF92400E),
                    letterSpacing: 0.6)),
            SizedBox(width: 6),
            Text('(never visible to user)',
                style: TextStyle(fontSize: 10, color: Color(0xFFB45309))),
          ]),
          if (_loadingNotes) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(color: Color(0xFFD97706)),
          ] else
            ...List.generate(
                _notes.length,
                (i) => Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_notes[i].content,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF1E293B),
                                    height: 1.55)),
                            const SizedBox(height: 4),
                            Text(
                                '${_notes[i].authorName ?? 'Agent'} · ${_fmtDT(_notes[i].createdAt)}',
                                style: const TextStyle(
                                    fontSize: 10, color: Color(0xFF92400E))),
                          ]),
                    )),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
                child: TextField(
              controller: _noteCtrl,
              focusNode: _noteFocusNode,
              minLines: 2,
              maxLines: 3,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Add a private note…',
                hintStyle: TextStyle(color: Color(0xFFC8974B), fontSize: 13),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.all(10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                    borderSide:
                        BorderSide(color: Color(0xFFFDE68A), width: 1.5)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                    borderSide:
                        BorderSide(color: Color(0xFFFDE68A), width: 1.5)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                    borderSide: BorderSide(color: Color(0xFFD97706), width: 2)),
              ),
            )),
            const SizedBox(width: 8),
            SizedBox(
                height: 42,
                child: ElevatedButton(
                  onPressed: _postingNote ? null : _postNote,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _noteCtrl.text.trim().isEmpty
                        ? const Color(0xFFF1F5F9)
                        : const Color(0xFFD97706),
                    foregroundColor: _noteCtrl.text.trim().isEmpty
                        ? const Color(0xFF94A3B8)
                        : Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: _postingNote
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Save',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                )),
          ]),
        ]),
      );

  // ── Escalate Ticket (orange bg) ───────────────────────────────────────────

  Widget _buildEscalateBox() {
    if (widget.role != 'ADMIN') return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(
        color: Color(0xFFFFF7ED),
        border: Border(bottom: BorderSide(color: Color(0xFFFED7AA))),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: const [
          Icon(Icons.warning_amber_rounded, size: 12, color: Color(0xFFDC2626)),
          SizedBox(width: 6),
          Text('ESCALATE TICKET',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF9A3412),
                  letterSpacing: 0.6)),
        ]),
        const SizedBox(height: 10),
        _status == 'ESCALATED'
            ? Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: const Row(children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 13, color: Color(0xFFB91C1C)),
                  SizedBox(width: 6),
                  Text('Already escalated',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFB91C1C))),
                ]))
            : Row(children: [
                Expanded(
                    child: RichText(
                        text: const TextSpan(
                  style: TextStyle(
                      fontSize: 12, color: Color(0xFF78350F), height: 1.5),
                  children: [
                    TextSpan(text: 'Marks as '),
                    TextSpan(
                        text: 'ESCALATED',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E293B))),
                    TextSpan(
                        text:
                            ' and triggers urgent SLA. Senior agents will be notified.'),
                  ],
                ))),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _escalating ? null : _escalate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                  child: _escalating
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Escalate',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ]),
      ]),
    );
  }

  // ── Danger Zone (red bg) ──────────────────────────────────────────────────

  Widget _buildDangerBox() {
    if (widget.role != 'ADMIN') return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      color: const Color(0xFFFEF2F2),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('DANGER ZONE',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFFB91C1C),
                letterSpacing: 0.6)),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _deleting ? null : _delete,
          icon: _deleting
              ? const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFFDC2626)))
              : const Icon(Icons.delete_outline_rounded,
                  size: 14, color: Color(0xFFDC2626)),
          label: Text(_deleting ? 'Deleting…' : 'Delete Ticket $_displayId',
              style: const TextStyle(
                  color: Color(0xFFDC2626),
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFFECACA), width: 1.5),
            backgroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
      ]),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // DETAILS TAB  (Stepper + Status + Priority + Description + Conv link)
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildDetailsTab() => SingleChildScrollView(
        child: Column(children: [
          _buildStepper(),
          _div(),
          _buildStatusSection(),
          _div(),
          _buildPrioritySection(),
          _div(),
          _buildDescSection(),
          _div(),
          _buildConvSummary(),
          const SizedBox(height: 24),
        ]),
      );

  Widget _div() => const Divider(height: 1, color: Color(0xFFF1F5F9));

  // ── Progress stepper ──────────────────────────────────────────────────────

  Widget _buildStepper() {
    final curIdx = _stepIdx(_status);
    final w = MediaQuery.of(context).size.width;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('PROGRESS',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
                letterSpacing: 0.6)),
        const SizedBox(height: 16),
        SizedBox(
            height: 60,
            child: Stack(children: [
              // Background track
              Positioned(
                  top: 14,
                  left: 15,
                  right: 15,
                  child: Container(height: 2, color: const Color(0xFFE2E8F0))),
              // Active track
              Positioned(
                top: 14,
                left: 15,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  height: 2,
                  color: const Color(0xFF0F766E),
                  width: curIdx == 0
                      ? 0
                      : (w - 32) * (curIdx / (_steps.length - 1)),
                ),
              ),
              // Circles + labels
              Row(
                  children: List.generate(_steps.length, (i) {
                final done = i < curIdx;
                final cur = i == curIdx;
                return Expanded(
                    child: Column(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done
                          ? const Color(0xFF0F766E)
                          : cur
                              ? const Color(0xFFECFEFF)
                              : const Color(0xFFF8FAFC),
                      border: Border.all(
                        color: done || cur
                            ? const Color(0xFF0F766E)
                            : const Color(0xFFCBD5E1),
                        width: 2,
                      ),
                      boxShadow: cur
                          ? [
                              const BoxShadow(
                                  color: Color(0x200F766E),
                                  blurRadius: 0,
                                  spreadRadius: 4)
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: done
                        ? const Icon(Icons.check_rounded,
                            size: 14, color: Colors.white)
                        : Icon(_stepIcons[i],
                            size: 13,
                            color: cur
                                ? const Color(0xFF0F766E)
                                : const Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 6),
                  Text((_steps[i][1]).toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          color: done || cur
                              ? const Color(0xFF115E59)
                              : const Color(0xFF94A3B8))),
                ]));
              })),
            ])),
        const SizedBox(height: 4),
      ]),
    );
  }

  // ── Change Status ─────────────────────────────────────────────────────────

  Widget _buildStatusSection() {
    const statuses = ['NEW', 'OPEN', 'PENDING', 'RESOLVED', 'CLOSED'];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      color: const Color(0xFFFAFAFA),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('CHANGE STATUS',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.6)),
          if (_updStatus)
            const Text(' · updating…',
                style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF0F766E),
                    fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 10),
        Wrap(
            spacing: 6,
            runSpacing: 6,
            children: statuses.map((s) {
              final active = _status == s;
              return GestureDetector(
                onTap: () => !active && !_updStatus ? _changeStatus(s) : null,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: active ? _sbg(s) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: active ? _sbd(s) : const Color(0xFFE2E8F0),
                        width: 1.5),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(_sl(s),
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: active ? _sc(s) : const Color(0xFF64748B))),
                    if (active) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.check_rounded, size: 10, color: _sc(s))
                    ],
                  ]),
                ),
              );
            }).toList()),
        const SizedBox(height: 8),
        const Row(children: [
          Icon(Icons.info_outline_rounded, size: 12, color: Color(0xFF94A3B8)),
          SizedBox(width: 5),
          Expanded(
              child: Text(
                  'Customer will receive an in-app notification when status changes.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))),
        ]),
      ]),
    );
  }

  // ── Change Priority ───────────────────────────────────────────────────────

  Widget _buildPrioritySection() {
    const priorities = ['LOW', 'MEDIUM', 'HIGH', 'URGENT', 'CRITICAL'];
    final locked = _isTerminal;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      color: const Color(0xFFFAFAFA),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('CHANGE PRIORITY',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.6)),
          if (_updPriority)
            const Text(' · updating…',
                style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFFD97706),
                    fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 10),
        Wrap(
            spacing: 6,
            runSpacing: 6,
            children: priorities.map((p) {
              final active = _priority == p;
              return Opacity(
                opacity: locked ? 0.5 : 1,
                child: GestureDetector(
                  onTap: () => !active && !locked && !_updPriority
                      ? _changePriority(p)
                      : null,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: active ? _pbg(p) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: active ? _pbd(p) : const Color(0xFFE2E8F0),
                          width: 1.5),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.flag_outlined,
                          size: 11, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text(_pl(p),
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color:
                                  active ? _pc(p) : const Color(0xFF64748B))),
                      if (active) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.check_rounded, size: 10, color: _pc(p))
                      ],
                    ]),
                  ),
                ),
              );
            }).toList()),
        const SizedBox(height: 8),
        const Row(children: [
          Icon(Icons.info_outline_rounded, size: 12, color: Color(0xFF94A3B8)),
          SizedBox(width: 5),
          Expanded(
              child: Text(
                  'Priority change is reflected immediately in the ticket list.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))),
        ]),
      ]),
    );
  }

  // ── Description ───────────────────────────────────────────────────────────

  Widget _buildDescSection() => Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('DESCRIPTION',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0.6)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.all(Radius.circular(10)),
              border: Border(
                left: BorderSide(color: Color(0xFFA5F3FC), width: 3),
                top: BorderSide(color: Color(0xFFF1F5F9)),
                right: BorderSide(color: Color(0xFFF1F5F9)),
                bottom: BorderSide(color: Color(0xFFF1F5F9)),
              ),
            ),
            child: Text(
              (_t.description?.isEmpty ?? true)
                  ? 'No description provided.'
                  : _stripHtml(_t.description!),
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF374151), height: 1.7),
            ),
          ),
        ]),
      );

  // ── Conversation summary link ─────────────────────────────────────────────

  Widget _buildConvSummary() => GestureDetector(
        onTap: () => _tab.animateTo(0),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(children: [
            const Icon(Icons.chat_bubble_outline_rounded,
                size: 13, color: Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text('CONVERSATION (${_conversationCount(_dedupedComments())})',
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.6)),
            const Spacer(),
            const Text('View →',
                style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF0F766E),
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}
