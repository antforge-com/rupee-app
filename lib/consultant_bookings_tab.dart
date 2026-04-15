// lib/features/consultant/consultant_bookings_tab.dart
import 'package:finadvise/app_theme.dart';
import 'package:finadvise/models/models.dart';
import 'package:finadvise/services/booking_service.dart';
import 'package:finadvise/services/consultant_service.dart';
import 'package:finadvise/services/ticket_service.dart';
import 'package:finadvise/ticket_detail_screen.dart';
import 'package:flutter/material.dart' hide Feedback;

class ConsultantBookingsTab extends StatefulWidget {
  final String consultantId;
  const ConsultantBookingsTab({super.key, required this.consultantId});

  @override
  State<ConsultantBookingsTab> createState() => _ConsultantBookingsTabState();
}

class _ConsultantBookingsTabState extends State<ConsultantBookingsTab> with SingleTickerProviderStateMixin {
  final BookingService _bookingService = BookingService();
  late TabController _tabCtrl;
  List<Booking> _bookings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    // FIX 1: Convert String to int for the service call
    final idAsInt = int.tryParse(widget.consultantId) ?? 0;
    _bookings = await _bookingService.getBookingsByConsultant(idAsInt);
    if (mounted) setState(() => _loading = false);
  }

  List<Booking> get _upcoming => _bookings.where((b) => b.status == 'CONFIRMED' && !b.isExpired).toList();
  List<Booking> get _pending => _bookings.where((b) => b.status == 'PENDING').toList();
  List<Booking> get _history => _bookings.where((b) => b.isExpired || ['COMPLETED', 'CANCELLED'].contains(b.status)).toList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
              ? ListView.builder(padding: const EdgeInsets.all(16), itemCount: 4, itemBuilder: (_, __) => const ShimmerCard())
              : TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _BookingList(bookings: _upcoming, emptyTitle: 'No upcoming bookings', onRefresh: _load),
                    _BookingList(bookings: _pending, emptyTitle: 'No pending bookings', onRefresh: _load),
                    _BookingList(bookings: _history, emptyTitle: 'No history', onRefresh: _load),
                  ],
                ),
        ),
      ],
    );
  }
}

class _BookingList extends StatelessWidget {
  final List<Booking> bookings;
  final String emptyTitle;
  final VoidCallback onRefresh;

  const _BookingList({required this.bookings, required this.emptyTitle, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) return EmptyState(icon: Icons.calendar_today_outlined, title: emptyTitle);
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

// ─────────────────────────────────────────────────────────────────────────────

// lib/features/consultant/consultant_tickets_tab.dart
class ConsultantTicketsTab extends StatefulWidget {
  final String consultantId;
  const ConsultantTicketsTab({super.key, required this.consultantId});

  @override
  State<ConsultantTicketsTab> createState() => _ConsultantTicketsTabState();
}

class _ConsultantTicketsTabState extends State<ConsultantTicketsTab> {
  final ticketService = TicketService();
  List<Ticket> _tickets = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    _tickets = await ticketService.getTicketsByConsultant(widget.consultantId as int);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return ListView.builder(padding: const EdgeInsets.all(16), itemCount: 4, itemBuilder: (_, __) => const ShimmerCard());
    if (_tickets.isEmpty) return const EmptyState(icon: Icons.inbox_outlined, title: 'No tickets assigned');
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _tickets.length,
        itemBuilder: (_, i) => TicketCard(
          ticket: _tickets[i],
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => TicketDetailScreen(ticket: _tickets[i], consultants: const [], role: 'CONSULTANT')),
            );
            _load();
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

// lib/features/consultant/consultant_schedule_tab.dart
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
  void initState() { super.initState(); _load(); }

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
          crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.2,
        ),
        itemCount: _slots.length,
        itemBuilder: (_, i) {
          final slot = _slots[i];
          Color color;
          switch (slot.status) {
            case 'AVAILABLE': color = AppColors.success; break;
            case 'BOOKED': color = AppColors.primaryLight; break;
            default: color = AppColors.textMuted;
          }
          return GestureDetector(
            onTap: () async {
              if (slot.status == 'AVAILABLE') {
                await _consultantService.updateTimeSlot(slot.id, {'status': 'UNAVAILABLE'});
              } else if (slot.status == 'UNAVAILABLE') {
                await _consultantService.updateTimeSlot(slot.id, {'status': 'AVAILABLE'});
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
                  // FIX 2: startTime -> timeRange
                  Text(slot.timeRange, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                  const SizedBox(height: 3),
                  // FIX 3: date -> slotDate
                  Text(slot.slotDate, style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                    child: Text(slot.status, style: TextStyle(fontSize: 8, color: color, fontWeight: FontWeight.w600)),
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

// ─────────────────────────────────────────────────────────────────────────────

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
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    _feedbacks = await ConsultantService().getFeedbacksByConsultant(widget.consultantId);
    if (mounted) setState(() => _loading = false);
  }

  double get _avgRating {
    if (_feedbacks.isEmpty) return 0;
    return _feedbacks.fold(0.0, (sum, f) => sum + f.rating) / _feedbacks.length;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_feedbacks.isEmpty) return const EmptyState(icon: Icons.star_outline, title: 'No feedback yet');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Avg rating card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Average Rating', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(_avgRating.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800)),
                  Row(children: List.generate(5, (i) => Icon(
                    i < _avgRating.round() ? Icons.star_rounded : Icons.star_border_rounded,
                    color: AppColors.gold, size: 20,
                  ))),
                ],
              ),
              const Spacer(),
              Column(
                children: [
                  const Icon(Icons.reviews_outlined, color: Colors.white30, size: 60),
                  Text('${_feedbacks.length} reviews', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                ],
              ),
            ],
          ),
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
              Row(
                children: [
                  Text(f.clientName ?? 'Client', style: AppTextStyles.h4),
                  const Spacer(),
                  Row(children: List.generate(5, (i) => Icon(
                    i < f.rating ? Icons.star_rounded : Icons.star_border_rounded,
                    color: AppColors.gold, size: 16,
                  ))),
                ],
              ),
              // FIX 4 & 5: f.comment -> f.comments
              if (f.comments != null) ...[
                const SizedBox(height: 8),
                Text(f.comments!, style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
              ],
              if (f.createdAt != null) ...[
                const SizedBox(height: 8),
                Text(f.createdAt!, style: AppTextStyles.caption),
              ],
            ],
          ),
        )),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

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
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    _profile = await ConsultantService().getConsultantById(widget.consultantId);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_profile == null) return const EmptyState(icon: Icons.person_outline, title: 'Profile not found');

    final p = _profile!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Avatar + Name
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.accent, Color(0xFF059669)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white24,
                  backgroundImage: p.photoUrl != null ? NetworkImage(p.photoUrl!) : null,
                  child: p.photoUrl == null ? Text(p.name[0].toUpperCase(), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)) : null,
                ),
                const SizedBox(height: 12),
                Text(p.name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                if (p.designation != null) Text(p.designation!, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star_rounded, color: AppColors.gold, size: 18),
                    const SizedBox(width: 4),
                    Text('${p.rating?.toStringAsFixed(1) ?? "—"} · ${p.reviewCount ?? 0} reviews', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
            child: Column(
              children: [
                _ProfileRow(icon: Icons.email_outlined, label: 'Email', value: p.email),
                // FIX 6: feePerSession -> charges
                if (p.charges != null) 
                  _ProfileRow(icon: Icons.currency_rupee, label: 'Session Fee', value: '₹${p.charges!.toStringAsFixed(0)}'),
                
                // FIX 7: Use the pre-built shiftDisplay property from the model
                if (p.shiftDisplay.isNotEmpty)
                  _ProfileRow(icon: Icons.access_time, label: 'Working Hours', value: p.shiftDisplay),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _ProfileRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.caption),
              Text(value, style: AppTextStyles.h4),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── REUSABLE WIDGETS ────────────────────────────────────────────────────────

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
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.calendar_today, color: AppColors.primaryLight),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Booking #${booking.id}', style: AppTextStyles.h4),
                  const SizedBox(height: 4),
                  Text('Status: ${booking.status}', style: AppTextStyles.caption),
                ],
              ),
            ),
          ],
        ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(ticket.userName ?? "User", style: AppTextStyles.caption),
                  const Spacer(),
                  Icon(Icons.flag_outlined, size: 14, color: getPriorityColor(ticket.priority)),
                  const SizedBox(width: 4),
                  Text(
                    ticket.priority,
                    style: AppTextStyles.caption.copyWith(color: getPriorityColor(ticket.priority)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}