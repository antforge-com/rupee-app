import 'package:finadvise/app_theme.dart';
import 'package:finadvise/models/models.dart';
import 'package:finadvise/services/booking_service.dart';
import 'package:finadvise/services/feedback_service.dart';
import 'package:finadvise/services/ticket_service.dart';
import 'package:finadvise/services/user_service.dart';
import 'package:finadvise/shared_widgets.dart'
    show StatCard, EmptyState, ShimmerCard, SectionHeader;
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
  final _feedbackService = FeedbackService();
  final _ticketService = TicketService();
  final _userService = UserService();

  List<Booking> _bookings = [];
  List<Feedback> _feedbacks = [];
  List<Ticket> _tickets = [];
  Map<int, String> _userNames = {};
  String _feedbackFilter = 'OVERALL';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final results = await Future.wait([
      _bookingService.getBookingsByConsultant(widget.consultantId, size: 100),
      _feedbackService.getFeedbacksByConsultant(widget.consultantId),
      _ticketService.getTicketsByConsultant(widget.consultantId, size: 100),
    ]);

    final bookings = results[0] as List<Booking>;
    final feedbacks = results[1] as List<Feedback>;
    final tickets = results[2] as List<Ticket>;

    final userIds = <int>{
      ...bookings.map((booking) => booking.userId).whereType<int>(),
      ...feedbacks.map((feedback) => feedback.userId).whereType<int>(),
      ...tickets.map((ticket) => ticket.userId).whereType<int>(),
    };
    final userNames = await _loadUserNames(userIds);

    if (!mounted) return;
    setState(() {
      _bookings = bookings;
      _feedbacks = feedbacks;
      _tickets = tickets;
      _userNames = userNames;
      _loading = false;
    });
  }

  Future<Map<int, String>> _loadUserNames(Set<int> userIds) async {
    if (userIds.isEmpty) return const {};

    final resolved = await Future.wait(
      userIds.map((userId) async {
        try {
          final profile = await _userService.getOnboardingProfile(userId);
          final profileName = _normalizeName(
            (profile?['name'] ??
                    profile?['fullName'] ??
                    profile?['displayName'] ??
                    profile?['email'] ??
                    '')
                .toString(),
          );
          if (profileName.isNotEmpty) return MapEntry(userId, profileName);
        } catch (_) {}

        try {
          final user = await _userService.getUserById(userId);
          final fallback = _normalizeName(
            user?.name.isNotEmpty == true
                ? user!.name
                : (user?.identifier ?? user?.email ?? ''),
          );
          if (fallback.isNotEmpty) return MapEntry(userId, fallback);
        } catch (_) {}

        return null;
      }),
    );

    return {
      for (final entry in resolved.whereType<MapEntry<int, String>>())
        entry.key: entry.value,
    };
  }

  String _normalizeName(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '';
    final cleaned = text
        .replaceAll(RegExp(r'[._\-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return '';
    return cleaned
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map(
          (part) =>
              '${part.substring(0, 1).toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  String _displayUserName(
      {int? userId, String? preferred, String fallback = 'Client'}) {
    final direct = _normalizeName(preferred ?? '');
    if (direct.isNotEmpty &&
        direct.toLowerCase() != 'client' &&
        direct.toLowerCase() != 'user') {
      return direct;
    }

    if (userId != null) {
      final lookedUp = _normalizeName(_userNames[userId] ?? '');
      if (lookedUp.isNotEmpty) return lookedUp;
      return 'User #$userId';
    }

    return fallback;
  }

  DateTime? _parseDate(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }

  List<Booking> get _completed {
    final rows = _bookings.where((booking) => booking.isCompleted).toList();
    rows.sort((a, b) {
      final right =
          _parseDate(b.slotDate) ?? _parseDate(b.createdAt) ?? DateTime(1970);
      final left =
          _parseDate(a.slotDate) ?? _parseDate(a.createdAt) ?? DateTime(1970);
      return right.compareTo(left);
    });
    return rows;
  }

  List<Booking> get _upcoming => _bookings
      .where((booking) => booking.isConfirmed && !booking.isExpired)
      .toList();

  double get _totalEarnings =>
      _completed.fold(0, (sum, booking) => sum + (booking.amount ?? 0));

  double get _thisMonthEarnings {
    final now = DateTime.now();
    return _completed.where((booking) {
      final date = _parseDate(booking.slotDate);
      return date != null && date.month == now.month && date.year == now.year;
    }).fold(0, (sum, booking) => sum + (booking.amount ?? 0));
  }

  Map<String, double> get _monthlyBreakdown {
    final map = <String, double>{};
    for (final booking in _completed) {
      final date = _parseDate(booking.slotDate);
      if (date == null) continue;
      final key = DateFormat('MMM yyyy').format(date);
      map[key] = (map[key] ?? 0) + (booking.amount ?? 0);
    }
    return map;
  }

  List<_ConsultantFeedbackEntry> get _bookingFeedbackEntries {
    final bookingsById = {
      for (final booking in _bookings) booking.id: booking,
    };

    final rows = _feedbacks.map((feedback) {
      final booking =
          feedback.bookingId != null ? bookingsById[feedback.bookingId!] : null;
      return _ConsultantFeedbackEntry(
        source: 'BOOKING',
        sourceLabel: 'Booking Feedback',
        sourceId: feedback.bookingId ?? feedback.id,
        userId: feedback.userId ?? booking?.userId,
        userName: _displayUserName(
          userId: feedback.userId ?? booking?.userId,
          preferred: feedback.clientName ?? booking?.clientName,
        ),
        rating: feedback.rating,
        comments: feedback.comments,
        createdAt:
            feedback.createdAt ?? booking?.createdAt ?? booking?.slotDate,
        detailLabel: booking == null
            ? 'Booking #${feedback.bookingId ?? feedback.id}'
            : '${booking.slotDate ?? 'Date pending'}${booking.timeRange?.isNotEmpty == true ? ' · ${booking.timeRange}' : ''}',
      );
    }).toList();

    rows.sort((a, b) => _compareFeedbackDates(a.createdAt, b.createdAt));
    return rows;
  }

  List<_ConsultantFeedbackEntry> get _ticketFeedbackEntries {
    final rows = _tickets
        .where((ticket) =>
            (ticket.feedbackRating ?? 0) > 0 ||
            (ticket.feedbackText?.trim().isNotEmpty ?? false))
        .map((ticket) => _ConsultantFeedbackEntry(
              source: 'TICKET',
              sourceLabel: 'Ticket Feedback',
              sourceId: ticket.id,
              userId: ticket.userId,
              userName: _displayUserName(
                userId: ticket.userId,
                preferred: ticket.userName,
              ),
              rating: (ticket.feedbackRating ?? 0).clamp(0, 5),
              comments: ticket.feedbackText,
              createdAt: ticket.updatedAt ?? ticket.createdAt,
              detailLabel: 'Ticket #${ticket.id} · ${ticket.category}',
            ))
        .toList();

    rows.sort((a, b) => _compareFeedbackDates(a.createdAt, b.createdAt));
    return rows;
  }

  int _compareFeedbackDates(String? left, String? right) {
    final rightDate = _parseDate(right) ?? DateTime(1970);
    final leftDate = _parseDate(left) ?? DateTime(1970);
    return rightDate.compareTo(leftDate);
  }

  List<_ConsultantFeedbackEntry> get _allFeedbackEntries => [
        ..._bookingFeedbackEntries,
        ..._ticketFeedbackEntries,
      ]..sort((a, b) => _compareFeedbackDates(a.createdAt, b.createdAt));

  List<_ConsultantFeedbackEntry> get _visibleFeedbackEntries {
    if (_feedbackFilter == 'BOOKING') return _bookingFeedbackEntries;
    if (_feedbackFilter == 'TICKET') return _ticketFeedbackEntries;
    return _allFeedbackEntries;
  }

  double _averageRating(List<_ConsultantFeedbackEntry> entries) {
    final rated = entries.where((entry) => entry.rating > 0).toList();
    if (rated.isEmpty) return 0;
    final total = rated.fold<double>(0, (sum, entry) => sum + entry.rating);
    return total / rated.length;
  }

  Map<int, int> _distribution(List<_ConsultantFeedbackEntry> entries) {
    final map = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    for (final entry in entries) {
      if (entry.rating <= 0) continue;
      final rating = entry.rating.clamp(1, 5);
      map[rating] = (map[rating] ?? 0) + 1;
    }
    return map;
  }

  String _feedbackFilterLabel(String value) {
    switch (value) {
      case 'BOOKING':
        return 'Booking Feedback';
      case 'TICKET':
        return 'Ticket Feedback';
      default:
        return 'Overall';
    }
  }

  String _formatEntryDate(String? raw) {
    final date = _parseDate(raw);
    if (date == null) return 'Recently';
    return DateFormat('dd MMM yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          SizedBox(height: 160, child: ShimmerCard()),
          SizedBox(height: 200, child: ShimmerCard()),
          ShimmerCard(),
        ],
      );
    }

    final visibleFeedbacks = _visibleFeedbackEntries;
    final averageRating = _averageRating(visibleFeedbacks);
    final distribution = _distribution(visibleFeedbacks);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.accent, Color(0xFF059669)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.22),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Earnings',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  'Rs ${_totalEarnings.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 10,
                  children: [
                    _statPill(
                      Icons.calendar_today_outlined,
                      'This month',
                      'Rs ${_thisMonthEarnings.toStringAsFixed(0)}',
                    ),
                    _statPill(
                      Icons.task_alt_rounded,
                      'Completed',
                      '${_completed.length} sessions',
                    ),
                    _statPill(
                      Icons.star_rounded,
                      'Rating',
                      averageRating > 0
                          ? averageRating.toStringAsFixed(1)
                          : '-',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SizedBox(
                  height: 112,
                  child: _outlinedStatCard(
                    color: AppColors.primaryLight,
                    child: StatCard(
                      title: 'Upcoming',
                      value: '${_upcoming.length}',
                      icon: Icons.schedule_rounded,
                      color: AppColors.primaryLight,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 112,
                  child: _outlinedStatCard(
                    color: AppColors.warning,
                    child: StatCard(
                      title: 'Pending',
                      value:
                          '${_bookings.where((booking) => booking.isPending).length}',
                      icon: Icons.hourglass_empty_rounded,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SectionHeader(title: 'Feedback'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: _feedbackFilter,
                  decoration: const InputDecoration(
                    labelText: 'Feedback Type',
                    prefixIcon: Icon(Icons.tune_rounded),
                  ),
                  items: const ['OVERALL', 'BOOKING', 'TICKET']
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(_feedbackFilterLabel(value)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _feedbackFilter = value);
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _miniStat(
                        'Visible Reviews',
                        '${visibleFeedbacks.length}',
                        AppColors.primaryLight,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _miniStat(
                        'Average',
                        averageRating > 0
                            ? averageRating.toStringAsFixed(1)
                            : '-',
                        AppColors.gold,
                      ),
                    ),
                  ],
                ),
                if (visibleFeedbacks.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  ...[5, 4, 3, 2, 1].map((star) {
                    final count = distribution[star] ?? 0;
                    final ratio = visibleFeedbacks.isEmpty
                        ? 0.0
                        : count / visibleFeedbacks.length;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 34,
                            child: Text(
                              '$star star',
                              style: AppTextStyles.caption,
                            ),
                          ),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: ratio,
                                minHeight: 8,
                                backgroundColor: AppColors.primaryLight
                                    .withValues(alpha: 0.08),
                                valueColor: const AlwaysStoppedAnimation(
                                  AppColors.primaryLight,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '$count',
                            style: AppTextStyles.label,
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (visibleFeedbacks.isEmpty)
            EmptyState(
              icon: Icons.rate_review_outlined,
              title:
                  'No ${_feedbackFilterLabel(_feedbackFilter).toLowerCase()} yet',
              subtitle:
                  'Reviews will appear here after completed sessions and resolved tickets.',
            )
          else
            ...visibleFeedbacks.map(
              (entry) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor:
                              AppColors.primaryLight.withValues(alpha: 0.12),
                          child: Text(
                            entry.userName.isNotEmpty
                                ? entry.userName[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: AppColors.primaryLight,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(entry.userName, style: AppTextStyles.h4),
                              const SizedBox(height: 2),
                              Text(
                                entry.detailLabel,
                                style: AppTextStyles.caption,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: entry.source == 'TICKET'
                                ? const Color(0xFFF8FAFC)
                                : const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: entry.source == 'TICKET'
                                  ? const Color(0xFFD9E2EC)
                                  : const Color(0xFFBBF7D0),
                            ),
                          ),
                          child: Text(
                            entry.sourceLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: entry.source == 'TICKET'
                                  ? AppColors.textSecondary
                                  : AppColors.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (entry.rating > 0) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: List.generate(
                          5,
                          (index) => Icon(
                            index < entry.rating
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: AppColors.gold,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                    if ((entry.comments ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        entry.comments!.trim(),
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      _formatEntryDate(entry.createdAt),
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 20),
          if (_monthlyBreakdown.isNotEmpty) ...[
            SectionHeader(title: 'Monthly Breakdown'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: _monthlyBreakdown.entries.map((entry) {
                  final maxValue = _monthlyBreakdown.values
                      .reduce((left, right) => left > right ? left : right);
                  final ratio = maxValue > 0 ? entry.value / maxValue : 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(entry.key, style: AppTextStyles.label),
                            Text(
                              'Rs ${entry.value.toStringAsFixed(0)}',
                              style: AppTextStyles.label.copyWith(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: ratio,
                            backgroundColor:
                                AppColors.accent.withValues(alpha: 0.1),
                            valueColor:
                                const AlwaysStoppedAnimation(AppColors.accent),
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
          if (_completed.isNotEmpty) ...[
            SectionHeader(title: 'Completed Sessions'),
            const SizedBox(height: 10),
            ..._completed.take(10).map(
                  (booking) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.task_alt_rounded,
                              color: AppColors.success,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _displayUserName(
                                    userId: booking.userId,
                                    preferred: booking.clientName,
                                  ),
                                  style: AppTextStyles.h4,
                                ),
                                Text(
                                  '${booking.slotDate ?? ''}${booking.timeRange?.isNotEmpty == true ? ' · ${booking.timeRange}' : ''}',
                                  style: AppTextStyles.caption,
                                ),
                              ],
                            ),
                          ),
                          if (booking.amount != null)
                            Text(
                              '+Rs ${booking.amount!.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: AppColors.success,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                              textAlign: TextAlign.right,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
          ] else
            const EmptyState(
              icon: Icons.payments_outlined,
              title: 'No earnings yet',
              subtitle: 'Completed sessions will appear here',
            ),
        ],
      ),
    );
  }

  Widget _outlinedStatCard({required Color color, required Widget child}) =>
      Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.42),
            width: 1.2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      );

  Widget _miniStat(String label, String value, Color color) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );

  Widget _statPill(IconData icon, String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white70, size: 12),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
}

class _ConsultantFeedbackEntry {
  final String source;
  final String sourceLabel;
  final int sourceId;
  final int? userId;
  final String userName;
  final int rating;
  final String? comments;
  final String? createdAt;
  final String detailLabel;

  const _ConsultantFeedbackEntry({
    required this.source,
    required this.sourceLabel,
    required this.sourceId,
    this.userId,
    required this.userName,
    required this.rating,
    this.comments,
    this.createdAt,
    required this.detailLabel,
  });
}
