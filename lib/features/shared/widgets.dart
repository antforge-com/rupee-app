import 'package:finadvise/app_theme.dart';
import 'package:finadvise/meet_the_masters_brand.dart';
import 'package:finadvise/models/models.dart';
import 'package:flutter/material.dart';

// ─── STATUS BADGE ─────────────────────────────────────────────────────────────

class StatusBadge extends StatelessWidget {
  final String status;
  final double fontSize;
  const StatusBadge({super.key, required this.status, this.fontSize = 11});

  @override
  Widget build(BuildContext context) {
    final color = getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ─── PRIORITY BADGE ───────────────────────────────────────────────────────────

class PriorityBadge extends StatelessWidget {
  final String priority;
  const PriorityBadge({super.key, required this.priority});

  @override
  Widget build(BuildContext context) {
    final color = getPriorityColor(priority);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(priority, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ─── SLA STRIP ────────────────────────────────────────────────────────────────

class SlaStrip extends StatelessWidget {
  final Ticket ticket;
  const SlaStrip({super.key, required this.ticket});

  @override
  Widget build(BuildContext context) {
    final sla = ticket.getSlaInfo();
    Color color;
    String label;
    switch (sla.status) {
      case 'breached':
        color = AppColors.danger;
        label = 'SLA BREACHED';
        break;
      case 'warning':
        color = AppColors.warning;
        label = sla.hoursRemaining != null ? '${sla.hoursRemaining}h remaining' : 'SLA WARNING';
        break;
      case 'ok':
        color = AppColors.success;
        label = sla.hoursRemaining != null ? '${sla.hoursRemaining}h remaining' : 'On track';
        break;
      default:
        return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
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

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: AppTextStyles.h2.copyWith(color: color)),
          const SizedBox(height: 2),
          Text(title, style: AppTextStyles.label),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: AppTextStyles.caption),
          ],
        ],
      ),
    );
  }
}

// ─── TICKET CARD ──────────────────────────────────────────────────────────────

class TicketCard extends StatelessWidget {
  final Ticket ticket;
  final VoidCallback onTap;
  final bool showAssignee;

  const TicketCard({
    super.key,
    required this.ticket,
    required this.onTap,
    this.showAssignee = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
                Expanded(
                  child: Text(
                    '#${ticket.id} · ${ticket.title}',
                    style: AppTextStyles.h4,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                StatusBadge(status: ticket.status),
              ],
            ),
            if (ticket.description != null) ...[
              const SizedBox(height: 6),
              Text(
                ticket.description!,
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                PriorityBadge(priority: ticket.priority),
                const SizedBox(width: 12),
                
                if (ticket.category.isNotEmpty) ...[
                  const Icon(Icons.label_outline, size: 13, color: AppColors.textMuted),
                  const SizedBox(width: 3),
                  Text(ticket.category, style: AppTextStyles.caption),
                  const SizedBox(width: 12),
                ],
                
                const Spacer(),
                SlaStrip(ticket: ticket),
              ],
            ),
            if (showAssignee && ticket.consultantName != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: AppColors.primaryLight.withValues(alpha: 0.15),
                    child: Text(
                      ticket.consultantName![0].toUpperCase(),
                      style: const TextStyle(fontSize: 10, color: AppColors.primaryLight, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('Assigned to ${ticket.consultantName}', style: AppTextStyles.caption),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── BOOKING CARD ─────────────────────────────────────────────────────────────

class BookingCard extends StatelessWidget {
  final Booking booking;
  final VoidCallback? onTap;
  final Widget? trailing;

  const BookingCard({super.key, required this.booking, this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    switch (booking.status.toUpperCase()) {
      case 'CONFIRMED': statusColor = AppColors.success; break;
      case 'PENDING': statusColor = AppColors.warning; break;
      case 'CANCELLED': statusColor = AppColors.danger; break;
      case 'COMPLETED': statusColor = AppColors.textMuted; break;
      default: statusColor = AppColors.info;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.calendar_today_rounded, color: statusColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking.consultantName ?? booking.clientName ?? 'Booking #${booking.id}',
                    style: AppTextStyles.h4,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (booking.slotDate != null) ...[
                        const Icon(Icons.calendar_month, size: 12, color: AppColors.textMuted),
                        const SizedBox(width: 3),
                        Text(booking.slotDate!, style: AppTextStyles.caption),
                        const SizedBox(width: 8),
                      ],
                      if (booking.timeRange != null) ...[
                        const Icon(Icons.access_time, size: 12, color: AppColors.textMuted),
                        const SizedBox(width: 3),
                        Text(booking.timeRange!, style: AppTextStyles.caption),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  StatusBadge(status: booking.status),
                ],
              ),
            ),
            if (trailing != null) trailing!
            else if (booking.meetingLink != null && booking.status == 'CONFIRMED')
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.videocam, size: 14),
                label: const Text('Join', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── LOADING SHIMMER ──────────────────────────────────────────────────────────

class MeetTheMastersLoadingIndicator extends StatefulWidget {
  final String? label;
  final double size;
  final bool compact;

  const MeetTheMastersLoadingIndicator({
    super.key,
    this.label,
    this.size = 56,
    this.compact = false,
  });

  @override
  State<MeetTheMastersLoadingIndicator> createState() =>
      _MeetTheMastersLoadingIndicatorState();
}

class _MeetTheMastersLoadingIndicatorState
    extends State<MeetTheMastersLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final badge = AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Transform.scale(
          scale: 0.96 + (t * 0.06),
          child: Opacity(
            opacity: 0.82 + (t * 0.18),
            child: MeetTheMastersLogoBadge(
              size: widget.size,
              padding: widget.size * 0.13,
              showAmbientGlow: !widget.compact,
            ),
          ),
        );
      },
    );

    if ((widget.label ?? '').trim().isEmpty) return badge;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        badge,
        const SizedBox(height: 10),
        Text(
          widget.label!,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class ShimmerCard extends StatelessWidget {
  const ShimmerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const MeetTheMastersLoadingIndicator(size: 34, compact: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  width: 156,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 10,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 10,
                  width: 120,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── EMPTY STATE ──────────────────────────────────────────────────────────────

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
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: AppColors.textMuted),
            ),
            const SizedBox(height: 20),
            Text(title, style: AppTextStyles.h3.copyWith(color: AppColors.textSecondary), textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!, style: AppTextStyles.body.copyWith(color: AppColors.textMuted), textAlign: TextAlign.center),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

// ─── APP HEADER (Sliver) ──────────────────────────────────────────────────────

class FinAdviseHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? bottom;

  const FinAdviseHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      backgroundColor: AppColors.surface,
      floating: true,
      snap: true,
      elevation: 0,
      scrolledUnderElevation: 1,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.h3),
          if (subtitle != null) Text(subtitle!, style: AppTextStyles.caption),
        ],
      ),
      actions: actions,
      bottom: bottom != null
          ? PreferredSize(preferredSize: const Size.fromHeight(52), child: bottom!)
          : null,
    );
  }
}

// ─── SEARCH BAR ───────────────────────────────────────────────────────────────

class AppSearchBar extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  const AppSearchBar({super.key, required this.hint, required this.onChanged, this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: AppTextStyles.body,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTextStyles.body.copyWith(color: AppColors.textMuted),
          prefixIcon: const Icon(Icons.search, color: AppColors.textMuted, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          filled: false,
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
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: onTap,
        ),
        if (unreadCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                unreadCount > 99 ? '99+' : unreadCount.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: AppTextStyles.h4),
          if (action != null)
            TextButton(
              onPressed: onAction,
              child: Text(action!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryLight)),
            ),
        ],
      ),
    );
  }
}
