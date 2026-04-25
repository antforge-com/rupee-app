// lib/features/consultant/consultant_earnings_tab.dart
// ════════════════════════════════════════════════════════════════════════════
// Web feature: Consultant earnings summary
//   - Total earnings from COMPLETED bookings
//   - Monthly breakdown
//   - Per-booking history
// API: GET /api/bookings/consultant/{id}  filter completed
//      GET /api/feedbacks/consultant/{id}  avg rating
// ════════════════════════════════════════════════════════════════════════════

import 'package:finadvise/app_theme.dart';
import 'package:finadvise/models/models.dart';
import 'package:finadvise/services/booking_service.dart';
import 'package:finadvise/services/consultant_service.dart';
import 'package:finadvise/shared_widgets.dart' show StatCard, EmptyState, ShimmerCard, SectionHeader;
import 'package:flutter/material.dart' hide Feedback;
import 'package:intl/intl.dart';

class ConsultantEarningsTab extends StatefulWidget {
  final int consultantId;
  const ConsultantEarningsTab({super.key, required this.consultantId});

  @override
  State<ConsultantEarningsTab> createState() => _ConsultantEarningsTabState();
}

class _ConsultantEarningsTabState extends State<ConsultantEarningsTab> {
  final _bookingService = BookingService();
  final _consultantService = ConsultantService();
  List<Booking> _bookings = [];
  List<Feedback> _feedbacks = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _bookingService.getBookingsByConsultant(widget.consultantId, size: 100),
      _consultantService.getFeedbacksByConsultant(widget.consultantId),
    ]);
    if (mounted) {
      setState(() {
        _bookings = results[0] as List<Booking>;
        _feedbacks = results[1] as List<Feedback>;
        _loading = false;
      });
    }
  }

  List<Booking> get _completed => _bookings.where((b) => b.isCompleted).toList();
  List<Booking> get _upcoming => _bookings.where((b) => b.isConfirmed && !b.isExpired).toList();

  double get _totalEarnings => _completed.fold(0, (sum, b) => sum + (b.amount ?? 0));
  
  double get _thisMonthEarnings {
    final now = DateTime.now();
    return _completed.where((b) {
      if (b.slotDate == null) {
        return false;
      }
      try {
        final d = DateTime.parse(b.slotDate!);
        return d.month == now.month && d.year == now.year;
      } catch (_) {
        return false;
      }
    }).fold(0, (sum, b) => sum + (b.amount ?? 0));
  }

  double get _avgRating {
    if (_feedbacks.isEmpty) return 0;
    return _feedbacks.fold(0.0, (s, f) => s + f.rating) / _feedbacks.length;
  }

  Map<String, double> get _monthlyBreakdown {
    final map = <String, double>{};
    for (final b in _completed) {
      if (b.slotDate == null) continue;
      try {
        final d = DateTime.parse(b.slotDate!);
        final key = DateFormat('MMM yyyy').format(d);
        map[key] = (map[key] ?? 0) + (b.amount ?? 0);
      } catch (_) {}
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return ListView(
        padding: const EdgeInsets.all(16), 
        children: const [
          SizedBox(height: 160, child: ShimmerCard()), 
          SizedBox(height: 200, child: ShimmerCard()), 
          ShimmerCard()
        ]
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary hero
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.accent, Color(0xFF059669)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total Earnings', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 4),
                Text('₹${_totalEarnings.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _statPill(Icons.calendar_today_outlined, 'This month', '₹${_thisMonthEarnings.toStringAsFixed(0)}'),
                    const SizedBox(width: 16),
                    _statPill(Icons.task_alt_rounded, 'Completed', '${_completed.length} sessions'),
                    const SizedBox(width: 16),
                    _statPill(Icons.star_rounded, 'Rating', _avgRating > 0 ? _avgRating.toStringAsFixed(1) : '—'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Quick stats
          Row(
            children: [
              Expanded(child: StatCard(title: 'Upcoming', value: '${_upcoming.length}', icon: Icons.schedule_rounded, color: AppColors.primaryLight)),
              const SizedBox(width: 12),
              Expanded(child: StatCard(title: 'Pending', value: '${_bookings.where((b) => b.isPending).length}', icon: Icons.hourglass_empty_rounded, color: AppColors.warning)),
            ],
          ),
          const SizedBox(height: 20),

          // Monthly breakdown
          if (_monthlyBreakdown.isNotEmpty) ...[
            SectionHeader(title: 'Monthly Breakdown'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
              child: Column(
                children: _monthlyBreakdown.entries.map((e) {
                  final maxVal = _monthlyBreakdown.values.reduce((a, b) => a > b ? a : b);
                  final ratio = maxVal > 0 ? e.value / maxVal : 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(e.key, style: AppTextStyles.label),
                            Text('₹${e.value.toStringAsFixed(0)}', style: AppTextStyles.label.copyWith(color: AppColors.accent, fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: ratio,
                            backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                            valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Recent completed sessions
          if (_completed.isNotEmpty) ...[
            SectionHeader(title: 'Completed Sessions'),
            const SizedBox(height: 10),
            ..._completed.take(10).map((b) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.task_alt_rounded, color: AppColors.success, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b.clientName ?? 'Client #${b.userId}', style: AppTextStyles.h4),
                          Text('${b.slotDate ?? ''} · ${b.timeRange ?? ''}', style: AppTextStyles.caption),
                        ],
                      ),
                    ),
                    if (b.amount != null)
                      Text('+₹${b.amount!.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 15)),
                  ],
                ),
              ),
            )),
          ] else
            const EmptyState(icon: Icons.payments_outlined, title: 'No earnings yet', subtitle: 'Completed sessions will appear here'),
        ],
      ),
    );
  }

  Widget _statPill(IconData icon, String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [Icon(icon, color: Colors.white70, size: 12), const SizedBox(width: 4), Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10))]),
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
    ],
  );
}

// SectionHeader is provided by shared_widgets.dart