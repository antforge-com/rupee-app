// lib/features/admin/admin_tickets_tab.dart
// ════════════════════════════════════════════════════════════════════════════
// ADMIN TICKETS TAB — Full web-parity implementation
// ✔ Status filter chips (ALL / NEW / OPEN / IN_PROGRESS / PENDING / RESOLVED / CLOSED / ESCALATED)
// ✔ Priority dropdown filter
// ✔ KPI stats row  (Total · Open/Active · Overdue SLA · Escalated · Resolved · Resolved Today · Closed)
// ✔ SLA breach visual highlight (red left accent border + red tint)
// ✔ Email-to-Ticket active banner
// ✔ Create Ticket FAB  (user · category · priority · consultant · description)
// ✔ Infinite-scroll pagination  +  background 15-second polling
// ✔ Real CSV export via share_plus
// ✔ Ticket detail navigation  →  TicketDetailScreen
// ✔ Dynamic responsive card layout
// ════════════════════════════════════════════════════════════════════════════

// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:finadvise/admin_missing_features.dart'
    show EscalatedTicketsScreen, SlaBreachedScreen;
import 'package:finadvise/api_client.dart';
import 'package:finadvise/app_theme.dart';
import 'package:finadvise/models/models.dart';
import 'package:finadvise/services/consultant_service.dart';
import 'package:finadvise/services/ticket_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'ticket_detail_screen.dart';

// ─── Shared helpers ───────────────────────────────────────────────────────────

final Dio _dio = ApiClient().dio;

void _snack(BuildContext ctx, String msg,
    {bool error = false, IconData? icon}) {
  ScaffoldMessenger.of(ctx)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(
            icon ??
                (error
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded),
            color: Colors.white,
            size: 18),
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

InputDecoration _inp(String label,
        {IconData? icon, String? hint, Widget? suffix}) =>
    InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null
          ? Icon(icon, size: 19, color: AppColors.textSecondary)
          : null,
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.surfaceVariant,
      labelStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.primaryLight, width: 2)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDC2626))),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );

int? _toInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('${v ?? ''}');
}

List<dynamic> _extractArray(
  dynamic raw, {
  List<String> keys = const [
    'content',
    'data',
    'items',
    'tickets',
    'users',
    'categories'
  ],
}) {
  if (raw is List) return raw;
  if (raw is Map) {
    for (final key in keys) {
      final value = raw[key];
      if (value is List) return value;
    }
  }
  return const [];
}

// ─── SLA helpers ─────────────────────────────────────────────────────────────

const _slaHours = {
  'LOW': 72,
  'MEDIUM': 24,
  'HIGH': 8,
  'URGENT': 4,
  'CRITICAL': 2
};

class _SlaInfo {
  final bool breached, warning;
  final String label;
  const _SlaInfo(
      {required this.breached, required this.warning, required this.label});
}

_SlaInfo? _calcSla(Ticket t) {
  if (t.createdAt == null || t.createdAt!.isEmpty) return null;
  if (['RESOLVED', 'CLOSED'].contains(t.status.toUpperCase())) return null;
  try {
    final created = DateTime.parse(t.createdAt!);
    final slaH = _slaHours[t.priority.toUpperCase()] ?? 24;
    final deadline = created.add(Duration(hours: slaH));
    final minsLeft = deadline.difference(DateTime.now()).inMinutes;
    if (minsLeft < 0)
      return const _SlaInfo(
          breached: true, warning: false, label: 'SLA BREACHED');
    if (minsLeft < 60)
      return _SlaInfo(
          breached: false, warning: true, label: '${minsLeft}m left');
    if (minsLeft < 240)
      return _SlaInfo(
          breached: false,
          warning: true,
          label: '${(minsLeft / 60).ceil()}h left');
    return null;
  } catch (_) {
    return null;
  }
}

bool _isOverdue(Ticket t) => _calcSla(t)?.breached == true;

// ─── Status / priority config ─────────────────────────────────────────────────

const _statusConfig = {
  'NEW': {'color': Color(0xFF7C3AED), 'bg': Color(0xFFF5F3FF), 'label': 'New'},
  'OPEN': {
    'color': Color(0xFF0891B2),
    'bg': Color(0xFFECFEFF),
    'label': 'Open'
  },
  'IN_PROGRESS': {
    'color': Color(0xFFD97706),
    'bg': Color(0xFFFFFBEB),
    'label': 'In Progress'
  },
  'PENDING': {
    'color': Color(0xFFF59E0B),
    'bg': Color(0xFFFFFBEB),
    'label': 'Pending'
  },
  'RESOLVED': {
    'color': Color(0xFF16A34A),
    'bg': Color(0xFFF0FDF4),
    'label': 'Resolved'
  },
  'CLOSED': {
    'color': Color(0xFF64748B),
    'bg': Color(0xFFF1F5F9),
    'label': 'Closed'
  },
  'ESCALATED': {
    'color': Color(0xFFDC2626),
    'bg': Color(0xFFFEF2F2),
    'label': 'Escalated'
  },
};

Color _statusColor(String s) =>
    (_statusConfig[s.toUpperCase()]?['color'] as Color?) ??
    const Color(0xFF64748B);
Color _statusBg(String s) =>
    (_statusConfig[s.toUpperCase()]?['bg'] as Color?) ??
    const Color(0xFFF1F5F9);
String _statusLabel(String s) =>
    (_statusConfig[s.toUpperCase()]?['label'] as String?) ?? s;

const _priorityConfig = {
  'LOW': {'color': Color(0xFF16A34A), 'label': 'Low'},
  'MEDIUM': {'color': Color(0xFF0891B2), 'label': 'Medium'},
  'HIGH': {'color': Color(0xFFD97706), 'label': 'High'},
  'URGENT': {'color': Color(0xFFF97316), 'label': 'Urgent'},
  'CRITICAL': {'color': Color(0xFFDC2626), 'label': 'Critical'},
};

Color _priorityColor(String p) =>
    (_priorityConfig[p.toUpperCase()]?['color'] as Color?) ??
    const Color(0xFF64748B);

// ════════════════════════════════════════════════════════════════════════════
// MAIN WIDGET
// ════════════════════════════════════════════════════════════════════════════

class AdminTicketsTab extends StatefulWidget {
  const AdminTicketsTab({super.key});
  @override
  State<AdminTicketsTab> createState() => _AdminTicketsTabState();
}

class _AdminTicketsTabState extends State<AdminTicketsTab> {
  final _ticketService = TicketService();
  final _consultantService = ConsultantService();

  List<Ticket> _all = [];
  List<Ticket> _filtered = [];
  List<ConsultantModel> _consultants = [];

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

  // ─── Computed KPI counts ──────────────────────────────────────────────────

  int get _total => _all.length;
  int get _openCount => _all
      .where((t) => ['NEW', 'OPEN', 'IN_PROGRESS', 'PENDING']
          .contains(t.status.toUpperCase()))
      .length;
  int get _overdueCount => _all.where(_isOverdue).length;
  int get _escalatedCount =>
      _all.where((t) => t.status.toUpperCase() == 'ESCALATED').length;
  int get _resolvedCount =>
      _all.where((t) => t.status.toUpperCase() == 'RESOLVED').length;
  int get _closedCount =>
      _all.where((t) => t.status.toUpperCase() == 'CLOSED').length;
  int get _resolvedTodayCount {
    final today = DateTime.now();
    return _all.where((t) {
      if (t.status.toUpperCase() != 'RESOLVED') return false;
      if (t.updatedAt == null || t.updatedAt!.isEmpty) return false;
      try {
        final d = DateTime.parse(t.updatedAt!).toLocal();
        return d.year == today.year &&
            d.month == today.month &&
            d.day == today.day;
      } catch (_) {
        return false;
      }
    }).length;
  }

  // Status chip counts
  Map<String, int> get _statusCounts => {
        'ALL': _all.length,
        for (final s in _statuses.skip(1))
          s: _all.where((t) => t.status.toUpperCase() == s).length,
      };

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _loadData(reset: true);
    _pollTimer = Timer.periodic(const Duration(seconds: 15),
        (_) => _loadData(reset: true, silent: true));
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

  Future<void> _loadData({bool reset = false, bool silent = false}) async {
    if (reset) {
      if (!silent)
        setState(() {
          _loading = true;
          _page = 0;
          _hasMore = true;
          _all = [];
        });
      else {
        _page = 0;
        _hasMore = true;
      }
    } else {
      if (_loadingMore) return;
      setState(() => _loadingMore = true);
    }

    try {
      final results = await Future.wait([
        _ticketService.getAllTickets(page: reset ? 0 : _page, size: _pageSize, useAnalytics: true),
        if (reset)
          _consultantService.getAllConsultants()
        else
          Future.value(_consultants),
      ]);

      final tickets = results[0] as List<Ticket>;
      bool hasMore = tickets.length == _pageSize;
      if (!reset) _page++; else _page = 1;

      if (mounted) {
        setState(() {
          if (reset) {
            _all = tickets;
            _consultants = results[1] as List<ConsultantModel>;
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
        _filtered = _all.where((t) {
          final q = _search.toLowerCase();
          final matchSearch = q.isEmpty ||
              (t.description ?? '').toLowerCase().contains(q) ||
              t.category.toLowerCase().contains(q) ||
              t.id.toString().contains(q) ||
              (t.userName ?? '').toLowerCase().contains(q) ||
              t.status.toLowerCase().contains(q) ||
              t.priority.toLowerCase().contains(q);
          final matchStatus =
              _statusFilter == 'ALL' || t.status.toUpperCase() == _statusFilter;
          final matchPriority = _priorityFilter == 'ALL' ||
              t.priority.toUpperCase() == _priorityFilter;
          return matchSearch && matchStatus && matchPriority;
        }).toList();
      });

  Future<void> _exportCsv() async {
    try {
      final list = _filtered.isEmpty ? _all : _filtered;
      final sb = StringBuffer(
          'ID,Category,Status,Priority,Description,User,Created\n');
      for (final t in list) {
        sb.writeln(
            '${t.id},"${t.category}","${t.status}","${t.priority}","${(t.description ?? '').replaceAll('"', "'")}","${t.userName ?? ''}","${t.createdAt ?? ''}"');
      }
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/tickets_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv');
      await file.writeAsString(sb.toString());
      await Share.shareXFiles([XFile(file.path)], subject: 'Tickets Export');
    } catch (e) {
      if (mounted) _snack(context, 'Export failed: $e', error: true);
    }
  }

  Future<void> _openCreateTicketSheet() async {
    List<Map<String, dynamic>> users = [];
    final categories = <String>{};
    try {
      final usersRes = await _dio.get('/api/users');
      final rawUsers = usersRes.data;
      users = _extractArray(rawUsers,
              keys: const ['content', 'data', 'items', 'users'])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {}
    try {
      final catsRes = await _dio.get('/api/admin/config/categories');
      final rawCats = _extractArray(catsRes.data,
              keys: const ['content', 'data', 'items', 'categories'])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      for (final cat in rawCats) {
        final name = (cat['name'] ?? '').toString().trim();
        if (name.isNotEmpty) categories.add(name);
      }
    } catch (_) {}
    categories.addAll(await _ticketService.getUniqueCategories());
    if (!mounted) return;

    final descCtrl = TextEditingController();
    final customCatCtrl = TextEditingController();
    int? userId;
    String? category = categories.isNotEmpty ? categories.first : null;
    int? consultantId;
    String priority = 'MEDIUM';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => Padding(
          padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Expanded(
                        child: Text('Create Ticket',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800))),
                    IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx)),
                  ]),
                  const SizedBox(height: 14),

                  // User selector
                  DropdownButtonFormField<int>(
                    value: userId,
                    decoration:
                        _inp('User *', icon: Icons.person_outline_rounded),
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
                                overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (v) => ss(() => userId = v),
                  ),
                  const SizedBox(height: 10),

                  // Category
                  if (categories.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: category,
                      decoration:
                          _inp('Category', icon: Icons.label_outline_rounded),
                      items: categories
                          .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) => ss(() => category = v),
                    ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: customCatCtrl,
                    decoration: _inp('Custom category (optional)',
                        icon: Icons.edit_outlined),
                  ),
                  const SizedBox(height: 10),

                  // Priority
                  DropdownButtonFormField<String>(
                    value: priority,
                    decoration: _inp('Priority', icon: Icons.flag_outlined),
                    items: _priorities
                        .where((p) => p != 'ALL')
                        .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                        .toList(),
                    onChanged: (v) => ss(() => priority = v ?? 'MEDIUM'),
                  ),
                  const SizedBox(height: 10),

                  // Consultant
                  DropdownButtonFormField<int?>(
                    value: consultantId,
                    decoration: _inp('Assign consultant (optional)',
                        icon: Icons.support_agent_outlined),
                    items: [
                      const DropdownMenuItem<int?>(
                          value: null, child: Text('Unassigned')),
                      ..._consultants.map((c) => DropdownMenuItem<int?>(
                          value: c.id, child: Text(c.name))),
                    ],
                    onChanged: (v) => ss(() => consultantId = v),
                  ),
                  const SizedBox(height: 10),

                  // Description
                  TextField(
                    controller: descCtrl,
                    maxLines: 4,
                    decoration:
                        _inp('Description *', icon: Icons.description_outlined),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: () async {
                        final resolvedCat = customCatCtrl.text.trim().isNotEmpty
                            ? customCatCtrl.text.trim()
                            : (category ?? '').trim();
                        if (userId == null) {
                          _snack(ctx, 'Select a user', error: true);
                          return;
                        }
                        if (resolvedCat.isEmpty) {
                          _snack(ctx, 'Select or enter a category',
                              error: true);
                          return;
                        }
                        if (descCtrl.text.trim().isEmpty) {
                          _snack(ctx, 'Description is required', error: true);
                          return;
                        }
                        final created = await _ticketService.createTicket(
                            userId: userId!,
                            category: resolvedCat,
                            description: descCtrl.text.trim(),
                            priority: priority,
                            consultantId: consultantId);
                        if (created == null) {
                          if (mounted)
                            _snack(ctx, 'Ticket creation failed', error: true);
                          return;
                        }
                        if (!mounted) return;
                        Navigator.pop(ctx);
                        _snack(context, 'Ticket #${created.id} created!',
                            icon: Icons.confirmation_number_outlined);
                        _loadData(reset: true);
                      },
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryLight,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      child: const Text('Create Ticket',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ]),
          ),
        ),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateTicketSheet,
        backgroundColor: AppColors.primaryLight,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('New Ticket',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: Column(children: [
        // ── Email-to-ticket banner ─────────────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFFECFEFF), Color(0xFFF0FDF4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            border: Border.all(color: const Color(0xFFA5F3FC)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.mail_outline_rounded,
                  size: 16, color: AppColors.primaryLight),
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('Email-to-Ticket is Active',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E3A8A))),
                  Text(
                      'Emails to support@meetthemasters.in auto-convert to tickets.',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF475569))),
                ])),
          ]),
        ),

        // ── KPI Stats row ─────────────────────────────────────────────────
        if (!_loading) _buildKpiRow(),

        // ── Search + filter bar ───────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          color: AppColors.surface,
          child: Column(children: [
            // Search + action buttons
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) {
                    _search = v;
                    _applyFilters();
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by ID, category, user, status…',
                    hintStyle: const TextStyle(
                        fontSize: 13, color: AppColors.textMuted),
                    prefixIcon: const Icon(Icons.search_rounded,
                        size: 18, color: AppColors.textMuted),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 17),
                            onPressed: () {
                              _searchCtrl.clear();
                              _search = '';
                              _applyFilters();
                            })
                        : null,
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _iconBtn(
                  Icons.download_rounded, const Color(0xFF059669), _exportCsv,
                  tooltip: 'Export CSV'),
              const SizedBox(width: 6),
              _iconBtn(
                Icons.timer_off_rounded,
                const Color(0xFFDC2626),
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SlaBreachedScreen()),
                ),
                tooltip: 'SLA Breached',
              ),
              const SizedBox(width: 6),
              _iconBtn(
                Icons.escalator_warning_rounded,
                const Color(0xFFF97316),
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const EscalatedTicketsScreen()),
                ),
                tooltip: 'Escalated Tickets',
              ),
              const SizedBox(width: 6),
              _iconBtn(Icons.refresh_rounded, AppColors.primaryLight,
                  () => _loadData(reset: true),
                  tooltip: 'Refresh'),
            ]),
            const SizedBox(height: 10),

            // Priority dropdown
            Row(children: [
              Expanded(
                  child: _dropDown(_priorities, _priorityFilter, (v) {
                setState(() => _priorityFilter = v!);
                _applyFilters();
              })),
            ]),
            const SizedBox(height: 10),
          ]),
        ),

        // ── Status filter chips ────────────────────────────────────────────
        _buildStatusChips(),

        // ── Result count bar ──────────────────────────────────────────────
        if (!_loading)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: AppColors.surfaceVariant,
            child: Row(children: [
              Text(
                '${_filtered.length} ticket${_filtered.length != 1 ? 's' : ''}',
                style:
                    AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700),
              ),
              if (_search.isNotEmpty)
                Text(' matching "$_search"',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
              if (_hasMore)
                const Text(' · scroll for more',
                    style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
            ]),
          ),

        // ── Ticket list ───────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filtered.isEmpty
                  ? Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                          Icon(Icons.inbox_outlined,
                              size: 60,
                              color:
                                  AppColors.textMuted.withValues(alpha: 0.5)),
                          const SizedBox(height: 14),
                          const Text('No tickets found',
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary)),
                          const SizedBox(height: 6),
                          const Text('Try adjusting your search or filters.',
                              style: TextStyle(
                                  color: AppColors.textMuted, fontSize: 12)),
                        ]))
                  : RefreshIndicator(
                      onRefresh: () => _loadData(reset: true),
                      child: ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                        itemCount: _filtered.length + (_loadingMore ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (i == _filtered.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          return _TicketCard(
                            ticket: _filtered[i],
                            consultants: _consultants,
                            onRefresh: () => _loadData(reset: true),
                          );
                        },
                      ),
                    ),
        ),
      ]),
    );
  }

  // ─── KPI row ───────────────────────────────────────────────────────────────

  Widget _buildKpiRow() {
    final items = [
      _KpiData(
          'Total', _total, const Color(0xFF0F766E), const Color(0xFFECFEFF)),
      _KpiData('Active', _openCount, const Color(0xFFD97706),
          const Color(0xFFFFFBEB)),
      _KpiData('Overdue', _overdueCount, const Color(0xFFDC2626),
          const Color(0xFFFEF2F2)),
      _KpiData('Escalated', _escalatedCount, const Color(0xFFDC2626),
          const Color(0xFFFEF2F2)),
      _KpiData('Resolved', _resolvedCount, const Color(0xFF16A34A),
          const Color(0xFFF0FDF4)),
      _KpiData('Today', _resolvedTodayCount, const Color(0xFF16A34A),
          const Color(0xFFF0FDF4)),
      _KpiData('Closed', _closedCount, const Color(0xFF64748B),
          const Color(0xFFF1F5F9)),
    ];
    return Container(
      height: 78,
      color: AppColors.surface,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => _KpiCard(data: items[i]),
      ),
    );
  }

  // ─── Status filter chips ──────────────────────────────────────────────────

  Widget _buildStatusChips() {
    return Container(
      height: 42,
      color: AppColors.surface,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
        itemCount: _statuses.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final s = _statuses[i];
          final isActive = _statusFilter == s;
          final color = s == 'ALL' ? AppColors.primaryLight : _statusColor(s);
          final cnt = _statusCounts[s] ?? 0;
          return GestureDetector(
            onTap: () {
              setState(() => _statusFilter = s);
              _applyFilters();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isActive ? color : Colors.transparent,
                border: Border.all(color: isActive ? color : AppColors.border),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (isActive && s != 'ALL')
                  Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 5),
                      decoration: BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle)),
                Text(
                  s == 'ALL' ? 'All' : _statusLabel(s),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive ? Colors.white : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.white.withValues(alpha: 0.25)
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$cnt',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: isActive ? Colors.white : AppColors.textMuted,
                    ),
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _dropDown(List<String> items, String val, ValueChanged<String?> onC) =>
      Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(10),
            color: AppColors.surface),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: val,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
            items: items
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: onC,
          ),
        ),
      );

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap,
          {String? tooltip}) =>
      Tooltip(
        message: tooltip ?? '',
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: 0.3))),
            child: Icon(icon, color: color, size: 19),
          ),
        ),
      );
}

// ─── KPI card ─────────────────────────────────────────────────────────────────

class _KpiData {
  final String label;
  final int value;
  final Color color, bg;
  const _KpiData(this.label, this.value, this.color, this.bg);
}

class _KpiCard extends StatelessWidget {
  final _KpiData data;
  const _KpiCard({required this.data});
  @override
  Widget build(BuildContext context) => Container(
        width: 72,
        decoration: BoxDecoration(
          color: data.bg,
          border: Border.all(color: data.color.withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('${data.value}',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: data.color)),
          const SizedBox(height: 2),
          Text(data.label,
              style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B)),
              textAlign: TextAlign.center),
        ]),
      );
}

// ─── Ticket Card ──────────────────────────────────────────────────────────────

class _TicketCard extends StatelessWidget {
  final Ticket ticket;
  final List<ConsultantModel> consultants;
  final VoidCallback onRefresh;
  const _TicketCard(
      {required this.ticket,
      required this.consultants,
      required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final sla = _calcSla(ticket);
    final overdue = sla?.breached == true;
    final warning = sla?.warning == true;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: BorderSide(
            color: overdue ? const Color(0xFFFECACA) : AppColors.border),
      ),
      color: overdue ? const Color(0xFFFFF8F8) : AppColors.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TicketDetailScreen(
                ticket: ticket,
                consultants: consultants,
                role: 'ADMIN',
              ),
            )).then((_) => onRefresh()),
        child: Row(children: [
          // SLA accent left border
          Container(
            width: 4,
            height: double.infinity,
            constraints: const BoxConstraints(minHeight: 80),
            decoration: BoxDecoration(
              color: overdue
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
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Row(children: [
                                  Text(
                                    '#${ticket.id}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: overdue
                                            ? const Color(0xFFDC2626)
                                            : AppColors.textMuted,
                                        fontFamily: 'monospace'),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                      child: Text(
                                    ticket.category.isEmpty
                                        ? 'General'
                                        : ticket.category,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary),
                                    overflow: TextOverflow.ellipsis,
                                  )),
                                ]),
                                const SizedBox(height: 4),
                                Text(
                                  (ticket.description?.isEmpty ?? true)
                                      ? 'No description provided.'
                                      : ticket.description!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                      height: 1.4),
                                ),
                              ])),
                          const SizedBox(width: 8),
                          // Status badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _statusBg(ticket.status),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: _statusColor(ticket.status)
                                      .withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              _statusLabel(ticket.status),
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: _statusColor(ticket.status)),
                            ),
                          ),
                        ]),

                    // SLA badge
                    if (sla != null) ...[
                      const SizedBox(height: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: overdue
                              ? const Color(0xFFFEE2E2)
                              : const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(
                              overdue
                                  ? Icons.timer_off_rounded
                                  : Icons.timer_rounded,
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
                    const Divider(height: 1, color: AppColors.border),
                    const SizedBox(height: 10),

                    // Footer row
                    Row(children: [
                      const Icon(Icons.person_outline_rounded,
                          size: 13, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                          child: Text(
                        (ticket.userName?.isEmpty ?? true)
                            ? 'User'
                            : ticket.userName!,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      )),
                      Icon(Icons.flag_outlined,
                          size: 13, color: _priorityColor(ticket.priority)),
                      const SizedBox(width: 4),
                      Text(
                        ticket.priority,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _priorityColor(ticket.priority)),
                      ),
                      if (ticket.createdAt != null &&
                          ticket.createdAt!.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        const Icon(Icons.access_time_rounded,
                            size: 12, color: AppColors.textMuted),
                        const SizedBox(width: 3),
                        Text(
                          _fmtDate(ticket.createdAt),
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.textMuted),
                        ),
                      ],
                    ]),
                  ]),
            ),
          ),
        ]),
      ),
    );
  }

  String _fmtDate(dynamic d) {
    if (d == null) return '';
    try {
      return DateFormat('d MMM yy')
          .format(DateTime.parse(d.toString()).toLocal());
    } catch (_) {
      return d.toString().substring(0, 10);
    }
  }
}
