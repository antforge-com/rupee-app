// lib/core/widgets/shared_widgets.dart
// Single source of truth — all reusable widgets
import 'package:finadvise/app_theme.dart';
import 'package:finadvise/models/models.dart';
import 'package:flutter/material.dart';

// ─── EMPTY STATE ──────────────────────────────────────────────────────────────

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyState({super.key, required this.icon, required this.title, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(color: AppColors.surfaceVariant, shape: BoxShape.circle),
              child: Icon(icon, size: 40, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            Text(title, style: AppTextStyles.h3, textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!, style: AppTextStyles.bodySmall, textAlign: TextAlign.center),
            ],
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }
}

// ─── SHIMMER CARD ─────────────────────────────────────────────────────────────

class ShimmerCard extends StatefulWidget {
  final double? height;
  const ShimmerCard({super.key, this.height});

  @override
  State<ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<ShimmerCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.35, end: 0.65).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Container(
      height: widget.height ?? 80,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: _anim.value),
        borderRadius: BorderRadius.circular(16),
      ),
    ),
  );
}

// ─── SEARCH BAR ───────────────────────────────────────────────────────────────

class AppSearchBar extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  const AppSearchBar({super.key, required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTextStyles.label,
          prefixIcon: const Icon(Icons.search, color: AppColors.textMuted, size: 20),
        ),
      ),
    );
  }
}

// ─── STAT CARD ────────────────────────────────────────────────────────────────

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final VoidCallback? onTap;

  const StatCard({super.key, required this.title, required this.value, required this.icon, required this.color, this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: color, size: 20),
                ),
                if (subtitle != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                    child: Text(subtitle!, style: const TextStyle(color: AppColors.danger, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(value, style: AppTextStyles.h2),
            const SizedBox(height: 2),
            Text(title, style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }
}

// ─── STATUS CHIP ─────────────────────────────────────────────────────────────

class StatusChip extends StatelessWidget {
  final String status;
  final Color? color;
  const StatusChip({super.key, required this.status, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Text(status.replaceAll('_', ' '), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c)),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge({super.key, required this.status});
  @override
  Widget build(BuildContext context) => StatusChip(status: status);
}

// ─── TICKET CARD ──────────────────────────────────────────────────────────────

class TicketCard extends StatelessWidget {
  final Ticket ticket;
  final VoidCallback onTap;
  final bool showAssignee;

  const TicketCard({super.key, required this.ticket, required this.onTap, this.showAssignee = true});

  @override
  Widget build(BuildContext context) {
    final isBreached = ticket.getSlaInfo().status == 'breached';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 3, height: 48,
                decoration: BoxDecoration(color: getPriorityColor(ticket.priority), borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(ticket.title, style: AppTextStyles.h4, maxLines: 1, overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 8),
                        StatusChip(status: ticket.status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text('#${ticket.id}', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        if (showAssignee) ...[
                          const Icon(Icons.person_outline, size: 12, color: AppColors.textMuted),
                          const SizedBox(width: 2),
                          Text(ticket.userName ?? 'User', style: AppTextStyles.caption),
                          const SizedBox(width: 8),
                        ],
                        Icon(Icons.flag_rounded, size: 12, color: getPriorityColor(ticket.priority)),
                        const SizedBox(width: 2),
                        Text(ticket.priority, style: AppTextStyles.caption.copyWith(color: getPriorityColor(ticket.priority))),
                      ],
                    ),
                    if (isBreached) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.timer_off, size: 12, color: AppColors.danger),
                          const SizedBox(width: 4),
                          Text('SLA Breached', style: AppTextStyles.caption.copyWith(color: AppColors.danger, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── BOOKING CARD ─────────────────────────────────────────────────────────────

class BookingCard extends StatelessWidget {
  final Booking booking;
  final VoidCallback? onTap;

  const BookingCard({super.key, required this.booking, this.onTap});

  Color get _statusColor {
    switch (booking.status.toUpperCase()) {
      case 'CONFIRMED': return AppColors.success;
      case 'PENDING': return AppColors.warning;
      case 'COMPLETED': return AppColors.textMuted;
      case 'CANCELLED': return AppColors.danger;
      default: return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: _statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                child: Icon(Icons.video_call_rounded, color: _statusColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            booking.consultantName ?? 'Session #${booking.id}',
                            style: AppTextStyles.h4, maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        StatusChip(status: booking.status, color: _statusColor),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        // FIXED: Replaced formattedDate with slotDate
                        Text(booking.slotDate ?? '—', style: AppTextStyles.caption),
                        const SizedBox(width: 8),
                        const Icon(Icons.schedule_outlined, size: 12, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        // FIXED: Replaced formattedTime with timeRange
                        Text(booking.timeRange ?? '—', style: AppTextStyles.caption),
                      ],
                    ),
                    if (booking.meetingLink != null && booking.status == 'CONFIRMED') ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.link, size: 12, color: AppColors.primaryLight),
                          const SizedBox(width: 4),
                          Text('Join link available', style: AppTextStyles.caption.copyWith(color: AppColors.primaryLight, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── NOTIFICATION BELL ────────────────────────────────────────────────────────

class NotificationBell extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onTap;

  const NotificationBell({super.key, required this.unreadCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_outlined),
          if (unreadCount > 0)
            Positioned(
              right: -2, top: -2,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text('$unreadCount',
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      onPressed: onTap,
    );
  }
}

// ─── SHEET HANDLE ─────────────────────────────────────────────────────────────

class SheetHandle extends StatelessWidget {
  final String? title;
  const SheetHandle({super.key, this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
        if (title != null) ...[
          const SizedBox(height: 16),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text(title!, style: AppTextStyles.h3)),
          const Divider(height: 20),
        ] else
          const SizedBox(height: 8),
      ],
    );
  }
}

// ─── GRADIENT HERO CARD ──────────────────────────────────────────────────────

class GradientHeroCard extends StatelessWidget {
  final String greeting;
  final String name;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final Widget? action;

  const GradientHeroCard({
    super.key,
    required this.greeting,
    required this.name,
    required this.subtitle,
    required this.icon,
    this.colors = const [AppColors.primary, AppColors.primaryLight],
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: LinearGradient(colors: colors), borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(greeting, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 4),
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                if (action != null) ...[const SizedBox(height: 12), action!],
              ],
            ),
          ),
          Icon(icon, size: 64, color: Colors.white12),
        ],
      ),
    );
  }
}

// ─── SLA ALERT BANNER ────────────────────────────────────────────────────────

class SlaAlertBanner extends StatelessWidget {
  final int count;
  final VoidCallback? onTap;
  const SlaAlertBanner({super.key, required this.count, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('SLA Breach Alert', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700, fontSize: 14)),
                  Text('$count ticket(s) require immediate attention', style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.danger),
          ],
        ),
      ),
    );
  }
}

// ─── SECTION HEADER ──────────────────────────────────────────────────────────

class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const SectionHeader({super.key, required this.title, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppTextStyles.h4),
        if (action != null)
          TextButton(
            onPressed: onAction,
            child: Text(action!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryLight)),
          ),
      ],
    );
  }
}

// ─── QUICK ACTION CARD ────────────────────────────────────────────────────────

class QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const QuickActionCard({super.key, required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}