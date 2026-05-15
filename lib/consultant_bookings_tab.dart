// lib/features/consultant/consultant_bookings_tab.dart
// Paginated bookings (10/page) + paginated tickets (10/page) for consultant.
// Adjacent pages are pre-fetched when you land on any page.
import 'dart:async';
import 'package:finadvise/app_theme.dart';
import 'package:finadvise/models/models.dart';
import 'package:finadvise/services/booking_service.dart';
import 'package:finadvise/services/consultant_service.dart';
import 'package:finadvise/services/ticket_service.dart';
import 'package:finadvise/ticket_detail_screen.dart';
import 'package:flutter/material.dart' hide Feedback;

// ─── Shared pagination widget ─────────────────────────────────────────────────

Widget _buildPaginationBar({
  required int currentPage,
  required int totalPages,
  required bool paging,
  required void Function(int) goToPage,
}) {
  if (totalPages <= 1) return const SizedBox.shrink();

  final pages = <int>{1, totalPages, currentPage};
  for (var p = currentPage - 1; p <= currentPage + 1; p++) {
    if (p >= 1 && p <= totalPages) pages.add(p);
  }
  final pageList = pages.toList()..sort();

  return Container(
    margin: const EdgeInsets.symmetric(vertical: 8),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(children: [
      IconButton(
        onPressed: currentPage > 1 ? () => goToPage(currentPage - 1) : null,
        icon: const Icon(Icons.chevron_left_rounded),
        visualDensity: VisualDensity.compact,
      ),
      Expanded(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (var i = 0; i < pageList.length; i++) ...[
              if (i > 0 && pageList[i] - pageList[i - 1] > 1)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text('...', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: GestureDetector(
                  onTap: () => goToPage(pageList[i]),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: currentPage == pageList[i] ? AppColors.primaryLight : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: currentPage == pageList[i] ? AppColors.primaryLight : AppColors.border,
                      ),
                    ),
                    child: Text(
                      '${pageList[i]}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: currentPage == pageList[i] ? Colors.white : AppColors.textSecondary,
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
        onPressed: currentPage < totalPages ? () => goToPage(currentPage + 1) : null,
        icon: const Icon(Icons.chevron_right_rounded),
        visualDensity: VisualDensity.compact,
      ),
      if (paging)
        const SizedBox(
          width: 14, height: 14,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryLight),
        ),
    ]),
  );
}

// ─── ConsultantBookingsTab ────────────────────────────────────────────────────

class ConsultantBookingsTab extends StatefulWidget {
  final String consultantId;
  const ConsultantBookingsTab({super.key, required this.consultantId});

  @override
  State<ConsultantBookingsTab> createState() => _ConsultantBookingsTabState();
}

class _ConsultantBookingsTabState extends State<ConsultantBookingsTab>
    with SingleTickerProviderStateMixin {
  static const _pageSize = 10;

  final BookingService _bookingService = BookingService();
  late TabController _tabCtrl;

  // All bookings for current page
  List<Booking> _bookings = [];
  bool _loading = true;
  bool _paging = false;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalElements = 0;
  int _requestToken = 0;
  final Map<int, List<Booking>> _pageCache = {};

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _load(page: 1);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  int get _consultantIdInt => int.tryParse(widget.consultantId) ?? 0;

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
        if (mounted) setState(() {
          _bookings = cached;
          _currentPage = targetPage;
          _loading = false;
          _paging = false;
        });
        unawaited(_prefetchAdjacent(targetPage));
        return;
      }
    }

    if (mounted) setState(() {
      if (_bookings.isEmpty || force || clearCache) {
        _loading = true;
      } else {
        _paging = true;
      }
    });

    final token = ++_requestToken;
    try {
      final result = await _bookingService.getBookingsByConsultantPaginated(
        _consultantIdInt,
        page: targetPage - 1, // 0-based
        size: _pageSize,
      );
      if (token != _requestToken) return;

      final items = result.content.whereType<Booking>().toList();
      final total = result.totalElements;
      final pages = total <= 0
          ? (items.length == _pageSize ? targetPage + 1 : targetPage)
          : ((total + _pageSize - 1) ~/ _pageSize);

      _pageCache[targetPage] = items;

      if (!mounted || token != _requestToken) return;
      setState(() {
        _bookings = items;
        _currentPage = targetPage;
        _totalPages = pages < 1 ? 1 : pages;
        _totalElements = total < items.length ? items.length : total;
        _loading = false;
        _paging = false;
      });
      unawaited(_prefetchAdjacent(targetPage));
    } catch (_) {
      if (mounted) setState(() { _loading = false; _paging = false; });
    }
  }

  Future<void> _prefetchAdjacent(int current) async {
    for (final page in [current - 1, current + 1]) {
      if (page < 1 || page > _totalPages) continue;
      if (_pageCache.containsKey(page)) continue;
      unawaited(_prefetchPage(page));
    }
  }

  Future<void> _prefetchPage(int page) async {
    try {
      final result = await _bookingService.getBookingsByConsultantPaginated(
        _consultantIdInt, page: page - 1, size: _pageSize);
      if (!mounted || _pageCache.containsKey(page)) return;
      _pageCache[page] = result.content.whereType<Booking>().toList();
    } catch (_) {}
  }

  void _goToPage(int page) {
    if (page < 1 || page > _totalPages || page == _currentPage) return;
    _load(page: page);
  }

  List<Booking> get _upcoming =>
      _bookings.where((b) => b.status == 'CONFIRMED' && !b.isExpired).toList();
  List<Booking> get _pending =>
      _bookings.where((b) => b.status == 'PENDING').toList();
  List<Booking> get _history => _bookings
      .where((b) => b.isExpired || ['COMPLETED', 'CANCELLED'].contains(b.status))
      .toList();

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        color: AppColors.surface,
        child: TabBar(
          controller: _tabCtrl,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.accent,
          tabs: [
            Tab(text: 'Upcoming (${_upcoming.length})'),
            Tab(text: 'Pending (${_pending.length})'),
            const Tab(text: 'History'),
          ],
        ),
      ),
      const Divider(height: 1),
      Expanded(
        child: _loading
            ? ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: 4,
                itemBuilder: (_, __) => const ShimmerCard())
            : Column(children: [
                Expanded(
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _BookingList(
                        bookings: _upcoming,
                        emptyTitle: 'No upcoming bookings',
                        onRefresh: () => _load(page: _currentPage, force: true, clearCache: true),
                      ),
                      _BookingList(
                        bookings: _pending,
                        emptyTitle: 'No pending bookings',
                        onRefresh: () => _load(page: _currentPage, force: true, clearCache: true),
                      ),
                      _BookingList(
                        bookings: _history,
                        emptyTitle: 'No booking history',
                        onRefresh: () => _load(page: _currentPage, force: true, clearCache: true),
                      ),
                    ],
                  ),
                ),
                // Pagination bar at bottom
                if (_totalPages > 1 || _totalElements > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: Column(children: [
                      _buildPaginationBar(
                        currentPage: _currentPage,
                        totalPages: _totalPages,
                        paging: _paging,
                        goToPage: _goToPage,
                      ),
                      Text(
                        'Page $_currentPage of $_totalPages  •  $_totalElements bookings',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ]),
                  ),
              ]),
      ),
    ]);
  }
}

class _BookingList extends StatelessWidget {
  final List<Booking> bookings;
  final String emptyTitle;
  final VoidCallback onRefresh;

  const _BookingList({
    required this.bookings,
    required this.emptyTitle,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return EmptyState(icon: Icons.calendar_today_outlined, title: emptyTitle);
    }
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: bookings.length,
        itemBuilder: (_, i) => BookingCard(booking: bookings[i]),
      ),
    );
  }
}

// ─── ConsultantTicketsTab ─────────────────────────────────────────────────────

class ConsultantTicketsTab extends StatefulWidget {
  final String consultantId;
  const ConsultantTicketsTab({super.key, required this.consultantId});

  @override
  State<ConsultantTicketsTab> createState() => _ConsultantTicketsTabState();
}

class _ConsultantTicketsTabState extends State<ConsultantTicketsTab> {
  static const _pageSize = 10;

  final TicketService _ticketService = TicketService();
  List<Ticket> _tickets = [];
  bool _loading = true;
  bool _paging = false;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalElements = 0;
  int _requestToken = 0;
  final Map<int, List<Ticket>> _pageCache = {};

  @override
  void initState() {
    super.initState();
    _load(page: 1);
  }

  int get _consultantIdInt => int.tryParse(widget.consultantId) ?? 0;

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
        if (mounted) setState(() {
          _tickets = cached;
          _currentPage = targetPage;
          _loading = false;
          _paging = false;
        });
        unawaited(_prefetchAdjacent(targetPage));
        return;
      }
    }

    if (mounted) setState(() {
      if (_tickets.isEmpty || force || clearCache) {
        _loading = true;
      } else {
        _paging = true;
      }
    });

    final token = ++_requestToken;
    try {
      final result = await _ticketService.getTicketsByConsultantPaginated(
        _consultantIdInt,
        page: targetPage - 1,
        size: _pageSize,
        sortBy: 'createdAt',
      );
      if (token != _requestToken) return;

      final rows = result['tickets'];
      final items = rows is List ? rows.whereType<Ticket>().toList() : <Ticket>[];
      final total = (result['totalElements'] as num?)?.toInt() ?? items.length;
      var pages = (result['totalPages'] as num?)?.toInt() ?? 1;
      if (pages <= 0) pages = 1;

      _pageCache[targetPage] = items;

      if (!mounted || token != _requestToken) return;
      setState(() {
        _tickets = items;
        _currentPage = targetPage;
        _totalPages = pages;
        _totalElements = total < items.length ? items.length : total;
        _loading = false;
        _paging = false;
      });
      unawaited(_prefetchAdjacent(targetPage));
    } catch (_) {
      if (mounted) setState(() { _loading = false; _paging = false; });
    }
  }

  Future<void> _prefetchAdjacent(int current) async {
    for (final page in [current - 1, current + 1]) {
      if (page < 1 || page > _totalPages) continue;
      if (_pageCache.containsKey(page)) continue;
      unawaited(_prefetchTicketPage(page));
    }
  }

  Future<void> _prefetchTicketPage(int page) async {
    try {
      final result = await _ticketService.getTicketsByConsultantPaginated(
          _consultantIdInt, page: page - 1, size: _pageSize);
      if (!mounted || _pageCache.containsKey(page)) return;
      final rows = result['tickets'];
      _pageCache[page] =
          rows is List ? rows.whereType<Ticket>().toList() : <Ticket>[];
    } catch (_) {}
  }

  void _goToPage(int page) {
    if (page < 1 || page > _totalPages || page == _currentPage) return;
    _load(page: page);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 4,
          itemBuilder: (_, __) => const ShimmerCard());
    }

    if (_tickets.isEmpty) {
      return const EmptyState(
          icon: Icons.inbox_outlined, title: 'No tickets assigned');
    }

    return Column(children: [
      Expanded(
        child: RefreshIndicator(
          onRefresh: () => _load(page: _currentPage, force: true, clearCache: true),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _tickets.length,
            itemBuilder: (_, i) => TicketCard(
              ticket: _tickets[i],
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TicketDetailScreen(
                      ticket: _tickets[i],
                      consultants: const [],
                      role: 'CONSULTANT',
                    ),
                  ),
                );
                _load(page: _currentPage, force: true, clearCache: true);
              },
            ),
          ),
        ),
      ),
      if (_totalPages > 1 || _totalElements > 0)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Column(children: [
            _buildPaginationBar(
              currentPage: _currentPage,
              totalPages: _totalPages,
              paging: _paging,
              goToPage: _goToPage,
            ),
            Text(
              'Page $_currentPage of $_totalPages  •  $_totalElements tickets',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ]),
        ),
    ]);
  }
}

// ─── ConsultantScheduleTab ────────────────────────────────────────────────────

class ConsultantScheduleTab extends StatefulWidget {
  final int consultantId;
  const ConsultantScheduleTab({super.key, required this.consultantId});

  @override
  State<ConsultantScheduleTab> createState() => _ConsultantScheduleTabState();
}

class _ConsultantScheduleTabState extends State<ConsultantScheduleTab> {
  final _consultantService = ConsultantService();
  List<TimeSlot> _slots = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _slots = await _consultantService.getSlotsByConsultant(widget.consultantId);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.2,
        ),
        itemCount: _slots.length,
        itemBuilder: (_, i) {
          final slot = _slots[i];
          Color color;
          switch (slot.status) {
            case 'AVAILABLE':
              color = AppColors.success;
              break;
            case 'BOOKED':
              color = AppColors.primaryLight;
              break;
            default:
              color = AppColors.textMuted;
          }
          return GestureDetector(
            onTap: () async {
              if (slot.status == 'AVAILABLE') {
                await _consultantService
                    .updateTimeSlot(slot.id, {'status': 'UNAVAILABLE'});
              } else if (slot.status == 'UNAVAILABLE') {
                await _consultantService
                    .updateTimeSlot(slot.id, {'status': 'AVAILABLE'});
              }
              _load();
            },
            child: Container(
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.4)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(slot.timeRange,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color)),
                  const SizedBox(height: 3),
                  Text(slot.slotDate,
                      style: const TextStyle(
                          fontSize: 9, color: AppColors.textMuted)),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(slot.status,
                        style: TextStyle(
                            fontSize: 8,
                            color: color,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── ConsultantFeedbacksTab ───────────────────────────────────────────────────

class ConsultantFeedbacksTab extends StatefulWidget {
  final int consultantId;
  const ConsultantFeedbacksTab({super.key, required this.consultantId});

  @override
  State<ConsultantFeedbacksTab> createState() => _ConsultantFeedbacksTabState();
}

class _ConsultantFeedbacksTabState extends State<ConsultantFeedbacksTab> {
  List<Feedback> _feedbacks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _feedbacks = await ConsultantService()
        .getFeedbacksByConsultant(widget.consultantId);
    if (mounted) setState(() => _loading = false);
  }

  double get _avgRating {
    if (_feedbacks.isEmpty) return 0;
    return _feedbacks.fold(0.0, (sum, f) => sum + f.rating) /
        _feedbacks.length;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_feedbacks.isEmpty) {
      return const EmptyState(
          icon: Icons.star_outline, title: 'No feedback yet');
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Average Rating',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 4),
              Text(_avgRating.toStringAsFixed(1),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.w800)),
              Row(
                  children: List.generate(
                      5,
                      (i) => Icon(
                            i < _avgRating.round()
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: AppColors.gold,
                            size: 20,
                          ))),
            ]),
            const Spacer(),
            Column(children: [
              const Icon(Icons.reviews_outlined,
                  color: Colors.white30, size: 60),
              Text('${_feedbacks.length} reviews',
                  style: const TextStyle(color: Colors.white60, fontSize: 12)),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        ..._feedbacks.map((f) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(f.clientName ?? 'Client', style: AppTextStyles.h4),
                      const Spacer(),
                      Row(
                          children: List.generate(
                              5,
                              (i) => Icon(
                                    i < f.rating
                                        ? Icons.star_rounded
                                        : Icons.star_border_rounded,
                                    color: AppColors.gold,
                                    size: 16,
                                  ))),
                    ]),
                    if (f.comments != null) ...[
                      const SizedBox(height: 8),
                      Text(f.comments!,
                          style: AppTextStyles.body
                              .copyWith(color: AppColors.textSecondary)),
                    ],
                    if (f.createdAt != null) ...[
                      const SizedBox(height: 8),
                      Text(f.createdAt!, style: AppTextStyles.caption),
                    ],
                  ]),
            )),
      ],
    );
  }
}

// ─── ConsultantProfileTab ─────────────────────────────────────────────────────

class ConsultantProfileTab extends StatefulWidget {
  final int consultantId;
  const ConsultantProfileTab({super.key, required this.consultantId});

  @override
  State<ConsultantProfileTab> createState() => _ConsultantProfileTabState();
}

class _ConsultantProfileTabState extends State<ConsultantProfileTab> {
  ConsultantModel? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _profile =
        await ConsultantService().getConsultantById(widget.consultantId);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_profile == null) {
      return const EmptyState(
          icon: Icons.person_outline, title: 'Profile not found');
    }

    final p = _profile!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [AppColors.accent, Color(0xFF059669)]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.white24,
              backgroundImage:
                  p.photoUrl != null ? NetworkImage(p.photoUrl!) : null,
              child: p.photoUrl == null
                  ? Text(p.name[0].toUpperCase(),
                      style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white))
                  : null,
            ),
            const SizedBox(height: 12),
            Text(p.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700)),
            if (p.designation != null)
              Text(p.designation!,
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.star_rounded, color: AppColors.gold, size: 18),
              const SizedBox(width: 4),
              Text(
                  '${p.rating?.toStringAsFixed(1) ?? "—"} · ${p.reviewCount ?? 0} reviews',
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 13)),
            ]),
          ]),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border)),
          child: Column(children: [
            _ProfileRow(icon: Icons.email_outlined, label: 'Email', value: p.email),
            if (p.charges != null)
              _ProfileRow(
                  icon: Icons.currency_rupee,
                  label: 'Session Fee',
                  value: '₹${p.charges!.toStringAsFixed(0)}'),
            if (p.shiftDisplay.isNotEmpty)
              _ProfileRow(
                  icon: Icons.access_time,
                  label: 'Working Hours',
                  value: p.shiftDisplay),
          ]),
        ),
      ]),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _ProfileRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: AppTextStyles.caption),
          Text(value, style: AppTextStyles.h4),
        ]),
      ]),
    );
  }
}

// ─── REUSABLE WIDGETS ─────────────────────────────────────────────────────────

class ShimmerCard extends StatelessWidget {
  const ShimmerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text(title, style: AppTextStyles.h3),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle!, style: AppTextStyles.bodySmall),
          ],
          if (action != null) ...[
            const SizedBox(height: 24),
            action!,
          ],
        ],
      ),
    );
  }
}

class BookingCard extends StatelessWidget {
  final Booking booking;
  const BookingCard({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.calendar_today, color: AppColors.primaryLight),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Booking #${booking.id}', style: AppTextStyles.h4),
                  const SizedBox(height: 4),
                  Text('Status: ${booking.status}',
                      style: AppTextStyles.caption),
                  if (booking.slotDate != null && booking.slotDate!.isNotEmpty)
                    Text('Date: ${booking.slotDate}',
                        style: AppTextStyles.caption),
                  if (booking.timeRange != null && booking.timeRange!.isNotEmpty)
                    Text('Time: ${booking.timeRange}',
                        style: AppTextStyles.caption),
                  if (booking.consultantName != null &&
                      booking.consultantName!.isNotEmpty)
                    Text('Consultant: ${booking.consultantName}',
                        style: AppTextStyles.caption),
                ]),
          ),
        ]),
      ),
    );
  }
}

class TicketCard extends StatelessWidget {
  final Ticket ticket;
  final VoidCallback onTap;

  const TicketCard({super.key, required this.ticket, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        ticket.title,
                        style: AppTextStyles.h4,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: getStatusColor(ticket.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        ticket.status,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: getStatusColor(ticket.status),
                        ),
                      ),
                    ),
                  ]),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.person_outline,
                    size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(ticket.userName ?? 'User', style: AppTextStyles.caption),
                const Spacer(),
                Icon(Icons.flag_outlined,
                    size: 14, color: getPriorityColor(ticket.priority)),
                const SizedBox(width: 4),
                Text(
                  ticket.priority,
                  style: AppTextStyles.caption
                      .copyWith(color: getPriorityColor(ticket.priority)),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}