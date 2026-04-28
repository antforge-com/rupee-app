// lib/features/admin/admin_analytics_tab.dart
// ════════════════════════════════════════════════════════════════════════════
// ADMIN ANALYTICS TAB — Full web-parity implementation
// ✔ Period toggle  (7 days / 30 days)
// ✔ KPI cards  (Total · Resolved · SLA Breaches · Avg Rating)
// ✔ Resolution-rate progress bar
// ✔ Pie chart  — Tickets by Status
// ✔ Bar chart  — Tickets by Priority
// ✔ Ticket Summary Chart — Daily/Weekly grouped bar (category · status · priority)
// ✔ Response Times  (Avg First Response · Avg Resolution)
// ✔ Agent Performance table  (Total · Solved · Avg Time)
// ✔ Category breakdown (horizontal bars)
// ✔ Background 20-second polling
// ════════════════════════════════════════════════════════════════════════════

// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:math';

import 'package:finadvise/app_theme.dart';
import 'package:finadvise/models/models.dart';
import 'package:finadvise/services/analytics_service.dart';
import 'package:finadvise/services/booking_service.dart';
import 'package:finadvise/shared_widgets.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

DateTime? _parseAnalyticsDate(dynamic value) {
  final raw = '${value ?? ''}'.trim();
  if (raw.isEmpty) return null;
  final normalized =
      (raw.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(raw))
          ? raw
          : '${raw}Z';
  return DateTime.tryParse(normalized)?.toLocal();
}

bool _isTicketInRange(Map<String, dynamic> ticket, String range) {
  final createdAt = _parseAnalyticsDate(ticket['createdAt']);
  if (createdAt == null) return true;
  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day);
  int days = 7;
  if (range.toUpperCase() == 'MONTHLY') {
    days = 30;
  } else if (range.toUpperCase() == 'YEARLY') {
    days = 365;
  }
  final cutoff = startOfToday.subtract(Duration(days: days - 1));
  return !createdAt.isBefore(cutoff);
}

// ─── Card decoration ──────────────────────────────────────────────────────────
BoxDecoration _card({Color? border, Color? bg}) => BoxDecoration(
      color: bg ?? AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: border ?? AppColors.border),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2)),
      ],
    );

// ─── Agent stat model ─────────────────────────────────────────────────────────
class _AgentStat {
  final String name;
  final int assigned, resolved, totalMins, resCount;
  const _AgentStat({
    required this.name,
    required this.assigned,
    required this.resolved,
    required this.totalMins,
    required this.resCount,
  });
}

// ─── Ticket summary model ─────────────────────────────────────────────────────
class _SummaryPoint {
  final String label;
  final Map<String, int> groups;
  const _SummaryPoint(this.label, this.groups);
}

// ════════════════════════════════════════════════════════════════════════════
// ADMIN ANALYTICS TAB
// ════════════════════════════════════════════════════════════════════════════

class AdminAnalyticsTab extends StatefulWidget {
  const AdminAnalyticsTab({super.key});
  @override
  State<AdminAnalyticsTab> createState() => _AdminAnalyticsTabState();
}

class _AdminAnalyticsTabState extends State<AdminAnalyticsTab> {
  final AnalyticsService _analyticsService = AnalyticsService();

  // FIX: correct type from AnalyticsService
  DashboardAnalytics? _data;
  bool _loading = true;
  String _range = 'WEEKLY'; // WEEKLY = 7 days, MONTHLY = 30 days
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _pollTimer =
        Timer.periodic(const Duration(seconds: 20), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      _data = await _analyticsService.getAnalyticsLegacy(period: _range);
    } catch (e) {
      debugPrint('Analytics load error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_data == null) {
      return const EmptyState(
          icon: Icons.analytics_outlined, title: 'No analytics data');
    }

    final d = _data!;
    final resRate =
        d.totalTickets > 0 ? (d.resolvedTickets * 100 / d.totalTickets) : 0.0;

    return RefreshIndicator(
      onRefresh: () => _load(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // ── Period toggle ────────────────────────────────────────────────
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Analytics', style: AppTextStyles.h3),
            Row(children: [
              _pill('WEEKLY', '7 Days'),
              const SizedBox(width: 8),
              _pill('MONTHLY', '30 Days'),
            ]),
          ]),
          const SizedBox(height: 16),

          // ── KPI Grid ─────────────────────────────────────────────────────
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.55,
            children: [
              StatCard(
                  title: 'Total Tickets',
                  value: '${d.totalTickets}',
                  icon: Icons.confirmation_number_rounded,
                  color: AppColors.primaryLight),
              StatCard(
                  title: 'Resolved',
                  value: '${d.resolvedTickets}',
                  icon: Icons.check_circle_outline_rounded,
                  color: const Color(0xFF059669)),
              StatCard(
                  title: 'SLA Breaches',
                  value: '${d.slaBreaches}',
                  icon: Icons.timer_off_rounded,
                  color: const Color(0xFFDC2626)),
              StatCard(
                  title: 'Avg Rating',
                  value: d.avgRating > 0 ? d.avgRating.toStringAsFixed(1) : '—',
                  icon: Icons.star_rounded,
                  color: const Color(0xFFF59E0B)),
            ],
          ),
          const SizedBox(height: 16),

          // ── Resolution Rate ───────────────────────────────────────────────
          if (d.totalTickets > 0) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _card(),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Resolution Rate', style: AppTextStyles.h4),
                          Text('${resRate.round()}%',
                              style: const TextStyle(
                                  color: Color(0xFF059669),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 22)),
                        ]),
                    const SizedBox(height: 4),
                    Text(
                      '${d.resolvedTickets} of ${d.totalTickets} tickets resolved',
                      style: AppTextStyles.caption,
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (d.resolvedTickets / d.totalTickets).clamp(0, 1),
                        backgroundColor:
                            const Color(0xFF059669).withValues(alpha: 0.1),
                        valueColor:
                            const AlwaysStoppedAnimation(Color(0xFF059669)),
                        minHeight: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Mini breakdown
                    Row(children: [
                      _miniStat(
                          'Open',
                          max(0, d.totalTickets - d.resolvedTickets),
                          const Color(0xFFD97706)),
                      const SizedBox(width: 16),
                      _miniStat(
                          'Breached', d.slaBreaches, const Color(0xFFDC2626)),
                      const SizedBox(width: 16),
                      _miniStat('Resolved', d.resolvedTickets,
                          const Color(0xFF059669)),
                    ]),
                  ]),
            ),
            const SizedBox(height: 16),
          ],

          // ── Ticket Summary Chart (Daily / Weekly grouped bars) ────────────
          _TicketSummaryChart(range: _range),
          const SizedBox(height: 16),

          // ── Tickets by Status Pie ─────────────────────────────────────────
          if (d.ticketsByStatus.isNotEmpty) ...[
            _ChartCard(
              title: 'Tickets by Status',
              legend: d.ticketsByStatus.entries
                  .map((e) => _LegendEntry(
                        label: e.key,
                        color: getStatusColor(e.key),
                        value: e.value,
                      ))
                  .toList(),
              child: SizedBox(
                height: 200,
                child: PieChart(PieChartData(
                  sections: d.ticketsByStatus.entries.map((e) {
                    final color = getStatusColor(e.key);
                    return PieChartSectionData(
                      value: e.value.toDouble(),
                      title: '${e.value}',
                      color: color,
                      radius: 62,
                      titleStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    );
                  }).toList(),
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                )),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Tickets by Priority Bar ───────────────────────────────────────
          if (d.ticketsByPriority.isNotEmpty) ...[
            _ChartCard(
              title: 'Tickets by Priority',
              child: SizedBox(
                height: 200,
                child: BarChart(BarChartData(
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) =>
                        const FlLine(color: AppColors.border, strokeWidth: 0.5),
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          final priorities = d.ticketsByPriority.keys.toList();
                          if (v.toInt() < priorities.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                priorities[v.toInt()].substring(0, 1),
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: getPriorityColor(
                                        priorities[v.toInt()])),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  barGroups: d.ticketsByPriority.entries
                      .toList()
                      .asMap()
                      .entries
                      .map((entry) {
                    final color = getPriorityColor(entry.value.key);
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.value.toDouble(),
                          color: color,
                          width: 32,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(8)),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: (d.ticketsByPriority.values.reduce(max))
                                .toDouble(),
                            color: color.withValues(alpha: 0.07),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                )),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Response Times ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _card(),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Response Times', style: AppTextStyles.h4),
              Text('Average across all tickets', style: AppTextStyles.caption),
              const SizedBox(height: 16),
              _TimeRow(
                  label: 'Avg First Response',
                  hours: d.avgResponseTime,
                  color: AppColors.info),
              const SizedBox(height: 12),
              _TimeRow(
                  label: 'Avg Resolution Time',
                  hours: d.avgResolutionTime,
                  color: const Color(0xFF059669)),
            ]),
          ),
          const SizedBox(height: 16),

          // ── Category breakdown ────────────────────────────────────────────
          _BookingsRevenueSection(range: _range),
          const SizedBox(height: 16),

          _CategoryBreakdown(range: _range),
          const SizedBox(height: 16),

          // ── Agent Performance ────────────────────────────────────────────
          _AgentPerformanceSection(range: _range),
        ],
      ),
    );
  }

  // ─── Period pill ──────────────────────────────────────────────────────────

  Widget _pill(String v, String label) => GestureDetector(
        onTap: () {
          setState(() => _range = v);
          _load();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color:
                _range == v ? AppColors.primaryLight : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: _range == v ? AppColors.primaryLight : AppColors.border),
          ),
          child: Text(label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _range == v ? Colors.white : AppColors.textSecondary,
              )),
        ),
      );

  Widget _miniStat(String label, int value, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text('$value $label',
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ],
      );
}

// ════════════════════════════════════════════════════════════════════════════
// TICKET SUMMARY CHART  (Daily / Weekly grouped bar — like TicketSummaryChart.tsx)
// ════════════════════════════════════════════════════════════════════════════

class _TicketSummaryChart extends StatefulWidget {
  final String range;
  const _TicketSummaryChart({required this.range});
  @override
  State<_TicketSummaryChart> createState() => _TicketSummaryChartState();
}

class _TicketSummaryChartState extends State<_TicketSummaryChart> {
  final AnalyticsService _analyticsService = AnalyticsService();
  List<dynamic> _rawTickets = [];
  bool _loading = true;
  String _groupBy = 'status'; // status | priority | category | consultant
  String _viewMode = 'daily'; // daily | weekly

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_TicketSummaryChart old) {
    super.didUpdateWidget(old);
    if (old.range != widget.range) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _analyticsService.getAnalyticsTicketsAll();
      if (mounted)
        setState(() {
          _rawTickets = items;
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_SummaryPoint> _buildData() {
    final now = DateTime.now();
    final isDaily = _viewMode == 'daily';
    final periods = isDaily
        ? List.generate(7, (i) {
            final d = DateTime(now.year, now.month, now.day - (6 - i));
            return (
              label: DateFormat('d MMM').format(d),
              start: d,
              end: DateTime(d.year, d.month, d.day, 23, 59, 59),
            );
          })
        : List.generate(8, (i) {
            final endD = DateTime(now.year, now.month, now.day - (i * 7));
            final startD = endD.subtract(const Duration(days: 6));
            return (
              label:
                  '${DateFormat('d MMM').format(startD)}–${DateFormat('d MMM').format(endD)}',
              start: startD,
              end: DateTime(endD.year, endD.month, endD.day, 23, 59, 59),
            );
          }).reversed.toList();

    String _getGroup(Map<String, dynamic> t) {
      if (_groupBy == 'status') return (t['status'] ?? 'Unknown').toString();
      if (_groupBy == 'priority') {
        return (t['priority'] ?? 'Unknown').toString();
      }
      if (_groupBy == 'consultant') {
        final name =
            (t['consultantName'] ?? t['agentName'] ?? t['assignedToName'] ?? '')
                .toString()
                .trim();
        return name.isEmpty ? 'Unassigned' : name;
      }
      final category =
          (t['category'] ?? t['categoryName'] ?? 'General').toString().trim();
      return category.isEmpty ? 'General' : category;
    }

    final scopedTickets = _rawTickets
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((t) => _isTicketInRange(t, widget.range))
        .toList(growable: false);

    return periods.map((p) {
      final groups = <String, int>{};
      for (final t in scopedTickets) {
        try {
          final created = _parseAnalyticsDate(t['createdAt']);
          if (created != null &&
              !created.isBefore(p.start) &&
              !created.isAfter(p.end)) {
            final g = _getGroup(t);
            groups[g] = (groups[g] ?? 0) + 1;
          }
        } catch (_) {}
      }
      return _SummaryPoint(p.label, groups);
    }).toList();
  }

  static const _palette = [
    Color(0xFF0F766E),
    Color(0xFF7C3AED),
    Color(0xFF059669),
    Color(0xFFD97706),
    Color(0xFFDC2626),
    Color(0xFF0891B2),
    Color(0xFFDB2777),
    Color(0xFF65A30D),
  ];

  @override
  Widget build(BuildContext context) {
    final points = _buildData();
    final allGroups = <String>{};
    for (final p in points) allGroups.addAll(p.groups.keys);
    final groups = allGroups.toList()..sort();
    final maxVal = points.fold<int>(1, (m, p) {
      final sum = p.groups.values.fold<int>(0, (s, v) => s + v);
      return sum > m ? sum : m;
    });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Ticket Summary', style: AppTextStyles.h4),
                Text('Tickets over time by ${_groupBy}',
                    style: AppTextStyles.caption),
              ])),
          const Icon(Icons.bar_chart_rounded,
              color: AppColors.primaryLight, size: 18),
        ]),
        const SizedBox(height: 12),

        // Controls
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _controlChip('Daily', _viewMode == 'daily',
                () => setState(() => _viewMode = 'daily')),
            const SizedBox(width: 6),
            _controlChip('Weekly', _viewMode == 'weekly',
                () => setState(() => _viewMode = 'weekly')),
            const SizedBox(width: 12),
            _controlChip('Status', _groupBy == 'status',
                () => setState(() => _groupBy = 'status')),
            const SizedBox(width: 6),
            _controlChip('Priority', _groupBy == 'priority',
                () => setState(() => _groupBy = 'priority')),
            const SizedBox(width: 6),
            _controlChip('Category', _groupBy == 'category',
                () => setState(() => _groupBy = 'category')),
            const SizedBox(width: 6),
            _controlChip('Consultant', _groupBy == 'consultant',
                () => setState(() => _groupBy = 'consultant')),
          ]),
        ),
        const SizedBox(height: 14),

        if (_loading)
          const SizedBox(
              height: 160, child: Center(child: CircularProgressIndicator()))
        else if (groups.isEmpty)
          const SizedBox(
              height: 120,
              child: Center(
                child: Text('No ticket data yet',
                    style: TextStyle(color: AppColors.textMuted)),
              ))
        else ...[
          // Stacked bar chart
          SizedBox(
            height: 180,
            child: BarChart(BarChartData(
              maxY: maxVal.toDouble() * 1.2,
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) =>
                    const FlLine(color: AppColors.border, strokeWidth: 0.5),
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (v, _) {
                      final idx = v.toInt();
                      if (idx < 0 || idx >= points.length)
                        return const SizedBox.shrink();
                      final lbl = points[idx].label;
                      // For daily show day, for weekly abbreviate
                      final short = lbl.split('–').first.split(' ').first;
                      return Transform.rotate(
                        angle: _viewMode == 'weekly' ? -0.4 : 0,
                        child: Text(short,
                            style: const TextStyle(
                                fontSize: 9, color: AppColors.textMuted)),
                      );
                    },
                  ),
                ),
                leftTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              barGroups: points.asMap().entries.map((entry) {
                final idx = entry.key;
                final point = entry.value;
                final total = point.groups.values.fold<int>(0, (s, v) => s + v);
                if (total == 0) {
                  return BarChartGroupData(
                    x: idx,
                    barRods: [
                      BarChartRodData(
                          toY: 0, color: Colors.transparent, width: 16)
                    ],
                  );
                }
                double fromY = 0;
                final rods = groups
                    .asMap()
                    .entries
                    .map((ge) {
                      final gIdx = ge.key;
                      final g = ge.value;
                      final val = (point.groups[g] ?? 0).toDouble();
                      final color = _groupBy == 'status'
                          ? getStatusColor(g)
                          : _groupBy == 'priority'
                              ? getPriorityColor(g)
                              : _palette[gIdx % _palette.length];
                      final rod = BarChartRodData(
                        fromY: fromY,
                        toY: fromY + val,
                        color: color,
                        width: 16,
                        borderRadius: BorderRadius.vertical(
                          top: gIdx == groups.length - 1 ||
                                  (gIdx ==
                                      groups.indexOf(groups.lastWhere(
                                          (g2) => (point.groups[g2] ?? 0) > 0,
                                          orElse: () => g)))
                              ? const Radius.circular(4)
                              : Radius.zero,
                          bottom: fromY == 0
                              ? const Radius.circular(4)
                              : Radius.zero,
                        ),
                      );
                      fromY += val;
                      return rod;
                    })
                    .where((r) => r.toY > r.fromY)
                    .toList();

                return BarChartGroupData(x: idx, barRods: rods, barsSpace: 0);
              }).toList(),
            )),
          ),
          const SizedBox(height: 10),

          // Legend
          Wrap(
              spacing: 10,
              runSpacing: 6,
              children: groups.asMap().entries.map((e) {
                final color = _groupBy == 'status'
                    ? getStatusColor(e.value)
                    : _groupBy == 'priority'
                        ? getPriorityColor(e.value)
                        : _palette[e.key % _palette.length];
                final total =
                    points.fold<int>(0, (s, p) => s + (p.groups[e.value] ?? 0));
                return Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                      width: 9,
                      height: 9,
                      decoration:
                          BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text('${e.value} ($total)', style: AppTextStyles.caption),
                ]);
              }).toList()),
        ],
      ]),
    );
  }

  Widget _controlChip(String label, bool active, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: active ? AppColors.primaryLight : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: active ? AppColors.primaryLight : AppColors.border),
          ),
          child: Text(label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : AppColors.textSecondary,
              )),
        ),
      );
}

// ════════════════════════════════════════════════════════════════════════════
// CATEGORY BREAKDOWN
// ════════════════════════════════════════════════════════════════════════════

class _CategoryBreakdown extends StatefulWidget {
  final String range;
  const _CategoryBreakdown({required this.range});
  @override
  State<_CategoryBreakdown> createState() => _CategoryBreakdownState();
}

class _CategoryBreakdownState extends State<_CategoryBreakdown> {
  final AnalyticsService _analyticsService = AnalyticsService();
  final Map<String, int> _counts = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_CategoryBreakdown old) {
    super.didUpdateWidget(old);
    if (old.range != widget.range) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _analyticsService.getAnalyticsTicketsAll();
      final counts = <String, int>{};
      for (final t in items) {
        final ticket = Map<String, dynamic>.from(t);
        if (!_isTicketInRange(ticket, widget.range)) continue;
        final rawCategory = ticket['category'] ?? ticket['categoryName'];
        final categoryLabel = rawCategory is Map
            ? (rawCategory['name'] ?? rawCategory['label'])
            : rawCategory;
        final cat = (categoryLabel ?? 'General').toString().trim();
        if (cat.isNotEmpty) counts[cat] = (counts[cat] ?? 0) + 1;
      }
      if (mounted)
        setState(() {
          _counts.clear();
          _counts.addAll(counts);
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    if (_counts.isEmpty) return const SizedBox.shrink();

    final sorted = _counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxVal = sorted.first.value;
    final top = sorted.take(6).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Tickets by Category', style: AppTextStyles.h4),
        Text('Top categories by volume', style: AppTextStyles.caption),
        const SizedBox(height: 14),
        ...top.asMap().entries.map((e) {
          final color = const [
            Color(0xFF0F766E),
            Color(0xFF7C3AED),
            Color(0xFF059669),
            Color(0xFFD97706),
            Color(0xFF0891B2),
            Color(0xFFDB2777),
          ][e.key % 6];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text(e.value.key,
                        style: AppTextStyles.label,
                        overflow: TextOverflow.ellipsis)),
                Text('${e.value.value}',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color)),
              ]),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: e.value.value / maxVal,
                  backgroundColor: color.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation(color),
                  minHeight: 7,
                ),
              ),
            ]),
          );
        }),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// AGENT PERFORMANCE  (mirrors web app's agent table)
// ════════════════════════════════════════════════════════════════════════════

class _AgentPerformanceSection extends StatefulWidget {
  final String range;
  const _AgentPerformanceSection({required this.range});
  @override
  State<_AgentPerformanceSection> createState() =>
      _AgentPerformanceSectionState();
}

class _AgentPerformanceSectionState extends State<_AgentPerformanceSection> {
  final AnalyticsService _analyticsService = AnalyticsService();
  List<_AgentStat> _stats = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_AgentPerformanceSection old) {
    super.didUpdateWidget(old);
    if (old.range != widget.range) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _analyticsService.getAnalyticsTicketsAll();
      final map = <String, _AgentStat>{};
      for (final t in items) {
        final ticket = Map<String, dynamic>.from(t);
        if (!_isTicketInRange(ticket, widget.range)) continue;
        final name = ticket['agentName']?.toString().trim().isNotEmpty == true
            ? ticket['agentName']?.toString().trim()
            : ticket['consultantName']?.toString().trim().isNotEmpty == true
                ? ticket['consultantName']?.toString().trim()
                : ticket['assignedToName']?.toString().trim();
        if (name == null || name.isEmpty) continue;
        final cur = map[name] ??
            _AgentStat(
                name: name,
                assigned: 0,
                resolved: 0,
                totalMins: 0,
                resCount: 0);
        final s = (ticket['status'] ?? '').toString().toUpperCase();
        int newMins = cur.totalMins,
            newRes = cur.resolved,
            newResCount = cur.resCount;
        if (s == 'RESOLVED' || s == 'CLOSED') {
          newRes++;
          try {
            final start = _parseAnalyticsDate(ticket['createdAt']);
            final end = _parseAnalyticsDate(
              ticket['resolvedAt'] ?? ticket['closedAt'] ?? ticket['updatedAt'],
            );
            if (start != null && end != null && !end.isBefore(start)) {
              final dur = end.difference(start).inMinutes;
              newMins += dur;
              newResCount++;
            }
          } catch (_) {}
        }
        map[name] = _AgentStat(
          name: name,
          assigned: cur.assigned + 1,
          resolved: newRes,
          totalMins: newMins,
          resCount: newResCount,
        );
      }
      if (mounted)
        setState(() {
          _stats = map.values.toList()
            ..sort((a, b) => b.assigned.compareTo(a.assigned));
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: _card(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Agent Performance', style: AppTextStyles.h4),
          Text('Response & resolution by consultant',
              style: AppTextStyles.caption),
          const SizedBox(height: 14),
          if (_loading)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator()))
          else if (_stats.isEmpty)
            const Center(
                child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No agent data yet',
                  style: TextStyle(color: AppColors.textMuted)),
            ))
          else ...[
            // Table header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8)),
              child: const Row(children: [
                Expanded(
                    flex: 3,
                    child: Text('AGENT',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5))),
                Expanded(
                    flex: 1,
                    child: Text('TOTAL',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5))),
                Expanded(
                    flex: 1,
                    child: Text('SOLVED',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5))),
                Expanded(
                    flex: 1,
                    child: Text('RATE',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5))),
                Expanded(
                    flex: 2,
                    child: Text('AVG TIME',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5))),
              ]),
            ),
            const SizedBox(height: 8),
            ..._stats.map((s) {
              final rate =
                  s.assigned > 0 ? (s.resolved * 100 / s.assigned).round() : 0;
              final avgMin =
                  s.resCount > 0 ? (s.totalMins / s.resCount).round() : 0;
              final avgStr = avgMin > 0
                  ? (avgMin >= 60
                      ? '${(avgMin / 60).toStringAsFixed(1)}h'
                      : '${avgMin}m')
                  : '—';
              final rateColor = rate >= 80
                  ? const Color(0xFF059669)
                  : rate >= 50
                      ? const Color(0xFFD97706)
                      : const Color(0xFFDC2626);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Expanded(
                      flex: 3,
                      child: Row(children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor:
                              AppColors.primaryLight.withValues(alpha: 0.1),
                          child: Text(s.name[0].toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryLight)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(s.name,
                                style: AppTextStyles.label,
                                overflow: TextOverflow.ellipsis)),
                      ])),
                  Expanded(
                      flex: 1,
                      child: Text('${s.assigned}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13))),
                  Expanded(
                      flex: 1,
                      child: Text('${s.resolved}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: rateColor))),
                  Expanded(
                      flex: 1,
                      child: Text('$rate%',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: rateColor))),
                  Expanded(
                      flex: 2,
                      child: Text(avgStr,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary))),
                ]),
              );
            }),
          ],
        ]),
      );
}

// ════════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS  (used by AdminAnalyticsTab + kept from original)
// ════════════════════════════════════════════════════════════════════════════

class _ConsultantRevenueStat {
  final String name;
  final int total;
  final int pending;
  final int completed;
  final double revenue;

  const _ConsultantRevenueStat({
    required this.name,
    required this.total,
    required this.pending,
    required this.completed,
    required this.revenue,
  });
}

class _BookingsRevenueSection extends StatefulWidget {
  final String range;
  const _BookingsRevenueSection({required this.range});

  @override
  State<_BookingsRevenueSection> createState() =>
      _BookingsRevenueSectionState();
}

class _BookingsRevenueSectionState extends State<_BookingsRevenueSection> {
  final BookingService _bookingService = BookingService();

  bool _loading = true;
  int _totalBookings = 0;
  int _completedBookings = 0;
  int _pendingBookings = 0;
  double _totalRevenue = 0;
  List<_ConsultantRevenueStat> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_BookingsRevenueSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.range != widget.range) _load();
  }

  DateTime? _bookingDate(Booking booking) {
    final created = _parseAnalyticsDate(booking.createdAt);
    if (created != null) return created;
    final slot = booking.slotDate;
    if (slot == null || slot.trim().isEmpty) return null;
    try {
      return DateTime.parse(slot.trim()).toLocal();
    } catch (_) {
      return null;
    }
  }

  bool _inRange(Booking booking) {
    final dt = _bookingDate(booking);
    if (dt == null) return true;
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    var days = 7;
    if (widget.range.toUpperCase() == 'MONTHLY') {
      days = 30;
    } else if (widget.range.toUpperCase() == 'YEARLY') {
      days = 365;
    }
    final cutoff = startOfToday.subtract(Duration(days: days - 1));
    return !dt.isBefore(cutoff);
  }

  Future<List<Booking>> _fetchAllBookings() async {
    final first =
        await _bookingService.getAllBookingsPaginated(page: 0, size: 200);
    final all = <Booking>[
      ...(first['bookings'] as List<Booking>? ?? const <Booking>[]),
    ];
    final totalPages = (first['totalPages'] as int?) ?? 1;

    for (var page = 1; page < totalPages; page++) {
      final next =
          await _bookingService.getAllBookingsPaginated(page: page, size: 200);
      final pageRows = next['bookings'] as List<Booking>? ?? const <Booking>[];
      all.addAll(pageRows);
    }

    if (all.isEmpty) {
      all.addAll(await _bookingService.getAllBookings(page: 0, size: 200));
    }

    final seen = <int>{};
    return all.where((booking) {
      if (seen.contains(booking.id)) return false;
      seen.add(booking.id);
      return true;
    }).toList();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final all = await _fetchAllBookings();
      final scoped = all.where(_inRange).toList();

      final map = <String, _ConsultantRevenueStat>{};
      var completed = 0;
      var pending = 0;
      var revenue = 0.0;

      for (final booking in scoped) {
        final status = booking.status.toUpperCase();
        if (status == 'COMPLETED') {
          completed++;
          revenue += booking.amount ?? 0;
        } else if (status == 'PENDING' || status == 'CONFIRMED') {
          pending++;
        }

        final consultantName = (booking.consultantName ?? '').trim().isNotEmpty
            ? booking.consultantName!.trim()
            : booking.consultantId != null
                ? 'Consultant #${booking.consultantId}'
                : 'Unknown';

        final current = map[consultantName] ??
            const _ConsultantRevenueStat(
              name: '',
              total: 0,
              pending: 0,
              completed: 0,
              revenue: 0,
            );
        map[consultantName] = _ConsultantRevenueStat(
          name: consultantName,
          total: current.total + 1,
          pending: current.pending +
              ((status == 'PENDING' || status == 'CONFIRMED') ? 1 : 0),
          completed: current.completed + (status == 'COMPLETED' ? 1 : 0),
          revenue: current.revenue +
              (status == 'COMPLETED' ? (booking.amount ?? 0) : 0),
        );
      }

      final rows = map.values.toList()
        ..sort((a, b) => b.total.compareTo(a.total));

      if (mounted) {
        setState(() {
          _totalBookings = scoped.length;
          _completedBookings = completed;
          _pendingBookings = pending;
          _totalRevenue = revenue;
          _rows = rows;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _money(double value) =>
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0)
          .format(value);

  Widget _kpi(String title, String value, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(title, style: AppTextStyles.label),
        const SizedBox(height: 2),
        Text(subtitle, style: AppTextStyles.caption),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: _card(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Bookings & Revenue', style: AppTextStyles.h4),
          Text('From completed bookings in selected period',
              style: AppTextStyles.caption),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.0,
              children: [
                _kpi(
                  'Total Bookings',
                  '$_totalBookings',
                  '$_pendingBookings pending / confirmed',
                  const Color(0xFF0F766E),
                ),
                _kpi(
                  'Completed',
                  '$_completedBookings',
                  _totalBookings > 0
                      ? '${((_completedBookings * 100) / _totalBookings).round()}% completion'
                      : '0% completion',
                  const Color(0xFF059669),
                ),
                _kpi(
                  'Total Revenue',
                  _money(_totalRevenue),
                  'from completed bookings',
                  const Color(0xFF0EA5A4),
                ),
                _kpi(
                  'Active Consultants',
                  '${_rows.length}',
                  'with at least one booking',
                  const Color(0xFF7C3AED),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(children: [
                Expanded(
                    flex: 3,
                    child: Text('CONSULTANT',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5))),
                Expanded(
                    child: Text('TOTAL',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5))),
                Expanded(
                    child: Text('PENDING',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5))),
                Expanded(
                    child: Text('DONE',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5))),
                Expanded(
                    flex: 2,
                    child: Text('REVENUE',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5))),
              ]),
            ),
            const SizedBox(height: 8),
            if (_rows.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text('No booking data available',
                      style: TextStyle(color: AppColors.textMuted)),
                ),
              )
            else
              ..._rows.take(10).map((row) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Expanded(
                          flex: 3,
                          child: Text(row.name,
                              style: AppTextStyles.label,
                              overflow: TextOverflow.ellipsis)),
                      Expanded(
                          child: Text('${row.total}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700))),
                      Expanded(
                          child: Text('${row.pending}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFD97706)))),
                      Expanded(
                          child: Text('${row.completed}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF059669)))),
                      Expanded(
                          flex: 2,
                          child: Text(_money(row.revenue),
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0EA5A4)))),
                    ]),
                  )),
          ],
        ]),
      );
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  final List<_LegendEntry>? legend;

  const _ChartCard({required this.title, required this.child, this.legend});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: _card(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: AppTextStyles.h4),
          const SizedBox(height: 16),
          child,
          if (legend != null) ...[
            const SizedBox(height: 12),
            Wrap(
                spacing: 12,
                runSpacing: 6,
                children: legend!
                    .map((l) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                    color: l.color, shape: BoxShape.circle)),
                            const SizedBox(width: 4),
                            Text('${l.label} (${l.value})',
                                style: AppTextStyles.caption),
                          ],
                        ))
                    .toList()),
          ],
        ]),
      );
}

class _LegendEntry {
  final String label;
  final Color color;
  final int value;
  _LegendEntry({required this.label, required this.color, required this.value});
}

class _TimeRow extends StatelessWidget {
  final String label;
  final double hours;
  final Color color;

  const _TimeRow(
      {required this.label, required this.hours, required this.color});

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: AppTextStyles.label),
          Text('${hours.toStringAsFixed(1)}h',
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w700, fontSize: 13)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (hours / 48).clamp(0, 1),
            backgroundColor: color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 8,
          ),
        ),
      ]);
}

// ════════════════════════════════════════════════════════════════════════════
// ADMIN SETTINGS TAB  (kept from original admin_analytics_tab.dart)
// ════════════════════════════════════════════════════════════════════════════

class AdminSettingsTab extends StatelessWidget {
  const AdminSettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SettingsSection(
          title: 'Account',
          items: [
            _SettingsItem(
                icon: Icons.person_outline, label: 'Profile', onTap: () {}),
            _SettingsItem(
                icon: Icons.lock_outline,
                label: 'Change Password',
                onTap: () {}),
            _SettingsItem(
                icon: Icons.notifications_outlined,
                label: 'Notifications',
                onTap: () {}),
          ],
        ),
        const SizedBox(height: 16),
        _SettingsSection(
          title: 'Support Config',
          items: [
            _SettingsItem(
                icon: Icons.chat_bubble_outline,
                label: 'Canned Responses',
                onTap: () {}),
            _SettingsItem(
                icon: Icons.label_outline, label: 'Categories', onTap: () {}),
            _SettingsItem(
                icon: Icons.access_time, label: 'Business Hours', onTap: () {}),
          ],
        ),
        const SizedBox(height: 16),
        _SettingsSection(
          title: 'System',
          items: [
            _SettingsItem(
              icon: Icons.info_outline,
              label: 'App Version',
              trailing: const Text('1.0.0',
                  style: TextStyle(color: AppColors.textMuted)),
              onTap: () {},
            ),
          ],
        ),
      ],
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<_SettingsItem> items;
  const _SettingsSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(title, style: AppTextStyles.label),
          ),
          const Divider(height: 1),
          ...items,
        ]),
      );
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;
  const _SettingsItem(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.trailing});

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: AppColors.textSecondary, size: 20),
        title: Text(label, style: AppTextStyles.body),
        trailing: trailing ??
            const Icon(Icons.chevron_right,
                color: AppColors.textMuted, size: 18),
        onTap: onTap,
      );
}
