import 'dart:async';
import 'dart:math';

import 'package:finadvise/app_theme.dart';
import 'package:finadvise/models/models.dart';
import 'package:finadvise/services/ticket_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

DateTime? _ticketDate(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final raw = value.trim();
  final normalized =
      (raw.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(raw))
          ? raw
          : '${raw}Z';
  return DateTime.tryParse(normalized)?.toLocal();
}

String _cleanGroupLabel(String input) {
  if (input.isEmpty) return 'Unknown';
  final key = input.toUpperCase().replaceAll('-', '_');
  switch (key) {
    case 'IN_PROGRESS':
      return 'In Progress';
    case 'NEW':
      return 'New';
    case 'OPEN':
      return 'Open';
    case 'PENDING':
      return 'Pending';
    case 'RESOLVED':
      return 'Resolved';
    case 'CLOSED':
      return 'Closed';
    case 'ESCALATED':
      return 'Escalated';
    case 'LOW':
      return 'Low';
    case 'MEDIUM':
      return 'Medium';
    case 'HIGH':
      return 'High';
    case 'URGENT':
      return 'Urgent';
    case 'CRITICAL':
      return 'Critical';
    case 'UNASSIGNED':
      return 'Unassigned';
    default:
      return input
          .split(RegExp(r'[_\s]+'))
          .map((part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
          .join(' ');
  }
}

class _ReportPeriod {
  final String label;
  final DateTime start;
  final DateTime end;
  const _ReportPeriod({
    required this.label,
    required this.start,
    required this.end,
  });
}

class AdminReportsWebTab extends StatefulWidget {
  const AdminReportsWebTab({super.key});

  @override
  State<AdminReportsWebTab> createState() => _AdminReportsWebTabState();
}

class _AdminReportsWebTabState extends State<AdminReportsWebTab> {
  final TicketService _ticketService = TicketService();

  bool _loading = true;
  List<Ticket> _tickets = const [];
  String _view = 'daily';
  String _groupBy = 'priority';
  Timer? _pollTimer;

  final _palette = const [
    Color(0xFF0F766E),
    Color(0xFF7C3AED),
    Color(0xFF16A34A),
    Color(0xFFD97706),
    Color(0xFFDC2626),
    Color(0xFF0891B2),
    Color(0xFFDB2777),
    Color(0xFF65A30D),
  ];

  @override
  void initState() {
    super.initState();
    _load();
    _pollTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final rows =
          await _ticketService.getAllTickets(size: 500, useAnalytics: true);
      if (!mounted) return;
      setState(() {
        _tickets = rows;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<_ReportPeriod> _periods() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_view == 'daily') {
      return List.generate(7, (index) {
        final day = today.subtract(Duration(days: 6 - index));
        return _ReportPeriod(
          label: DateFormat('d MMM').format(day),
          start: day,
          end: DateTime(day.year, day.month, day.day, 23, 59, 59),
        );
      });
    }

    return List.generate(8, (index) {
      final end = today.subtract(Duration(days: (7 - index) * 7));
      final start = end.subtract(const Duration(days: 6));
      return _ReportPeriod(
        label:
            '${DateFormat('d MMM').format(start)}-${DateFormat('d MMM').format(end)}',
        start: start,
        end: DateTime(end.year, end.month, end.day, 23, 59, 59),
      );
    });
  }

  String _groupKey(Ticket ticket) {
    if (_groupBy == 'status') {
      return ticket.status.toUpperCase();
    }
    if (_groupBy == 'priority') {
      return ticket.priority.toUpperCase();
    }
    if (_groupBy == 'category') {
      final category = ticket.category.trim();
      return category.isEmpty ? 'GENERAL' : category.toUpperCase();
    }
    final name = (ticket.consultantName ?? '').trim();
    return name.isEmpty ? 'UNASSIGNED' : name.toUpperCase();
  }

  Color _groupColor(String group, int index) {
    if (_groupBy == 'status') return getStatusColor(group);
    if (_groupBy == 'priority') return getPriorityColor(group);
    return _palette[index % _palette.length];
  }

  List<Ticket> _rangeTicketsForSummary() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lookbackDays = _view == 'daily' ? 7 : 56;
    final start = today.subtract(Duration(days: lookbackDays - 1));
    return _tickets.where((ticket) {
      final created = _ticketDate(ticket.createdAt);
      if (created == null) return false;
      return !created.isBefore(start);
    }).toList(growable: false);
  }

  Widget _summaryCard({
    required String value,
    required String label,
    required Color color,
    required Color bg,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              letterSpacing: 0.8,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF0F766E)),
      );
    }

    final periods = _periods();
    final groups = <String>{};
    for (final ticket in _tickets) {
      groups.add(_groupKey(ticket));
    }
    final sortedGroups = groups.toList()..sort();

    final matrix = <int, Map<String, int>>{};
    for (var i = 0; i < periods.length; i++) {
      final period = periods[i];
      final counts = <String, int>{};
      for (final ticket in _tickets) {
        final created = _ticketDate(ticket.createdAt);
        if (created == null) continue;
        if (created.isBefore(period.start) || created.isAfter(period.end)) {
          continue;
        }
        final key = _groupKey(ticket);
        counts[key] = (counts[key] ?? 0) + 1;
      }
      matrix[i] = counts;
    }

    final maxY = max<double>(
      1,
      matrix.values.fold<double>(0, (m, counts) {
        final periodMax =
            counts.values.isEmpty ? 0.0 : counts.values.reduce(max).toDouble();
        return max(m, periodMax.toDouble());
      }),
    );

    final rangeTickets = _rangeTicketsForSummary();
    final groupedRange = <String, int>{};
    for (final ticket in rangeTickets) {
      final key = _groupKey(ticket);
      groupedRange[key] = (groupedRange[key] ?? 0) + 1;
    }
    final topEntry = groupedRange.entries.isEmpty
        ? const MapEntry<String, int>('NONE', 0)
        : groupedRange.entries.reduce((a, b) => a.value >= b.value ? a : b);

    final topLabelPrefix = _groupBy == 'priority'
        ? 'Top Priority'
        : _groupBy == 'consultant'
            ? 'Top Consultant'
            : _groupBy == 'status'
                ? 'Top Status'
                : 'Top Category';

    return RefreshIndicator(
      color: const Color(0xFF0F766E),
      onRefresh: () => _load(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Row(
            children: [
              const Icon(
                Icons.insights_rounded,
                color: Color(0xFF0F766E),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ticket Reports & Analytics',
                  style: AppTextStyles.h2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Daily and weekly breakdowns of tickets by category, consultant, status, and priority.',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 900;

                    final controls = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _viewToggle('daily', 'Daily'),
                              _viewToggle('weekly', 'Weekly'),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 170,
                          child: DropdownButtonFormField<String>(
                            value: _groupBy,
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    const BorderSide(color: Color(0xFF0F766E)),
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                  value: 'category',
                                  child: Text('By Category')),
                              DropdownMenuItem(
                                  value: 'consultant',
                                  child: Text('By Consultant')),
                              DropdownMenuItem(
                                  value: 'status', child: Text('By Status')),
                              DropdownMenuItem(
                                  value: 'priority',
                                  child: Text('By Priority')),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _groupBy = value);
                            },
                          ),
                        ),
                      ],
                    );

                    if (compact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Ticket Summary', style: AppTextStyles.h3),
                          const SizedBox(height: 4),
                          Text(
                            _view == 'daily'
                                ? 'Last 7 days - grouped by ${_cleanGroupLabel(_groupBy)}'
                                : 'Last 8 weeks - grouped by ${_cleanGroupLabel(_groupBy)}',
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 10),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: controls,
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Ticket Summary', style: AppTextStyles.h3),
                              const SizedBox(height: 4),
                              Text(
                                _view == 'daily'
                                    ? 'Last 7 days - grouped by ${_cleanGroupLabel(_groupBy)}'
                                    : 'Last 8 weeks - grouped by ${_cleanGroupLabel(_groupBy)}',
                                style: const TextStyle(
                                    fontSize: 13, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        controls,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final twoCol = constraints.maxWidth < 900;
                    return GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: twoCol ? 2 : 4,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: twoCol ? 2.2 : 2.3,
                      children: [
                        _summaryCard(
                          value: '${rangeTickets.length}',
                          label:
                              _view == 'daily' ? 'Last 7 Days' : 'Last 8 Weeks',
                          color: const Color(0xFF0F766E),
                          bg: const Color(0xFFECFEFF),
                        ),
                        _summaryCard(
                          value: _cleanGroupLabel(topEntry.key),
                          label: topLabelPrefix,
                          color: const Color(0xFF7C3AED),
                          bg: const Color(0xFFF5F3FF),
                        ),
                        _summaryCard(
                          value: '${topEntry.value}',
                          label: 'Top Count',
                          color: const Color(0xFF16A34A),
                          bg: const Color(0xFFF0FDF4),
                        ),
                        _summaryCard(
                          value: '${_tickets.length}',
                          label: 'Total Tickets',
                          color: const Color(0xFFD97706),
                          bg: const Color(0xFFFFFBEB),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),
                if (_tickets.isEmpty)
                  const SizedBox(
                    height: 220,
                    child: Center(
                      child: Text(
                        'No ticket data available',
                        style: TextStyle(color: Color(0xFF94A3B8)),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 250,
                    child: BarChart(
                      BarChartData(
                        maxY: maxY * 1.35,
                        borderData: FlBorderData(show: false),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (_) => const FlLine(
                            color: Color(0xFFF1F5F9),
                            strokeWidth: 1,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28,
                              getTitlesWidget: (value, meta) {
                                final idx = value.toInt();
                                if (idx < 0 || idx >= periods.length) {
                                  return const SizedBox.shrink();
                                }
                                final label = periods[idx].label;
                                final shown = _view == 'daily'
                                    ? label
                                    : label.split('-').first;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    shown,
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        barGroups: periods.asMap().entries.map((entry) {
                          final pi = entry.key;
                          final counts = matrix[pi] ?? const <String, int>{};
                          final rods =
                              sortedGroups.asMap().entries.map((groupEntry) {
                            final group = groupEntry.value;
                            final toY = (counts[group] ?? 0).toDouble();
                            return BarChartRodData(
                              toY: toY,
                              width: _view == 'daily' ? 8 : 6,
                              color: _groupColor(group, groupEntry.key),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            );
                          }).toList();
                          return BarChartGroupData(
                              x: pi, barsSpace: 2, barRods: rods);
                        }).toList(),
                      ),
                    ),
                  ),
                if (sortedGroups.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: sortedGroups.asMap().entries.map((entry) {
                      final group = entry.value;
                      final color = _groupColor(group, entry.key);
                      final totalCount = matrix.values.fold<int>(
                        0,
                        (sum, counts) => sum + (counts[group] ?? 0),
                      );
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${_cleanGroupLabel(group)} ($totalCount)',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewToggle(String key, String label) {
    final active = _view == key;
    return GestureDetector(
      onTap: () => setState(() => _view = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF0F766E) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}
