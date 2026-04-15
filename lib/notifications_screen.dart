// lib/features/shared/notifications_screen.dart
// ════════════════════════════════════════════════════════════════════════════
// Web features:
//   - Real-time polling (30s) — GET /api/notifications
//   - Unread count badge on bell
//   - Mark individual as read — PUT /api/notifications/{id}/read
//   - Mark all as read
//   - Ticket type → navigate to ticket detail
//   - Booking type → navigate to booking detail
// ════════════════════════════════════════════════════════════════════════════

import 'package:finadvise/admin_analytics_tab.dart';
import 'package:finadvise/app_theme.dart';
import 'package:finadvise/consultant_bookings_tab.dart';
import 'package:finadvise/models/models.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:finadvise/services/notification_service.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          Consumer<NotificationService>(
            builder: (_, svc, __) => svc.unreadCount > 0
                ? TextButton(
                    onPressed: () => svc.markAllRead(),
                    child: const Text('Mark all read', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
      body: Consumer<NotificationService>(
        builder: (_, svc, __) {
          if (svc.isLoading) return const Center(child: CircularProgressIndicator());
          if (svc.notifications.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'No notifications',
              subtitle: "You're all caught up!",
            );
          }
          return RefreshIndicator(
            onRefresh: () => svc.refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: svc.notifications.length,
              itemBuilder: (_, i) => _NotificationTile(
                notification: svc.notifications[i],
                onTap: () => svc.markAsRead(svc.notifications[i].id as int),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;
    return InkWell(
      onTap: () {
        onTap();
        _navigate(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUnread ? AppColors.primaryLight.withValues(alpha: 0.04) : Colors.transparent,
          border: const Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(color: _typeColor.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(_typeIcon, color: _typeColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(notification.title, style: AppTextStyles.label.copyWith(fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500))),
                      Text(_formatTime(notification.createdAt), style: AppTextStyles.caption),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(notification.body, style: AppTextStyles.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (isUnread) ...[
              const SizedBox(width: 8),
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle)),
            ],
          ],
        ),
      ),
    );
  }

  Color get _typeColor {
    switch (notification.type.toLowerCase()) {
      case 'ticket':
      case 'ticket_updated':
      case 'new_assignment': return AppColors.primaryLight;
      case 'booking': return AppColors.success;
      case 'escalation': return AppColors.danger;
      default: return AppColors.textSecondary;
    }
  }

  IconData get _typeIcon {
    switch (notification.type.toLowerCase()) {
      case 'ticket':
      case 'ticket_updated':
      case 'new_assignment': return Icons.confirmation_number_outlined;
      case 'booking': return Icons.calendar_today_outlined;
      case 'escalation': return Icons.warning_amber_outlined;
      default: return Icons.notifications_outlined;
    }
  }

  void _navigate(BuildContext context) {
    final ticketId = notification.data?['ticketId'];
    if (ticketId != null) {
      // Navigate to ticket — handled by parent via route
      Navigator.pushNamed(context, '/ticket/$ticketId');
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('d MMM').format(dt);
  }
}

// ─── NOTIFICATION PANEL (inline, for dashboard) ───────────────────────────────

class NotificationPanel extends StatelessWidget {
  final VoidCallback onClose;
  const NotificationPanel({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 400),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
            child: Row(
              children: [
                Text('Notifications', style: AppTextStyles.h4),
                const Spacer(),
                Consumer<NotificationService>(
                  builder: (_, svc, __) => svc.unreadCount > 0
                      ? TextButton(onPressed: svc.markAllRead, child: Text('Mark all read', style: AppTextStyles.caption.copyWith(color: AppColors.primaryLight)))
                      : const SizedBox.shrink(),
                ),
                IconButton(icon: const Icon(Icons.close, size: 18), onPressed: onClose),
              ],
            ),
          ),
          const Divider(height: 8),
          // List
          Expanded(
            child: Consumer<NotificationService>(
              builder: (_, svc, __) {
                if (svc.notifications.isEmpty) {
                  return const EmptyState(
                    icon: Icons.notifications_none, 
                    title: 'No notifications',
                  );
                }
                return ListView.builder(
                  itemCount: svc.notifications.take(10).length,
                  itemBuilder: (_, i) {
                    final n = svc.notifications[i];
                    return _NotificationTile(notification: n, onTap: () => svc.markAsRead(n.id as int));
                  },
                );
              },
            ),
          ),
          // Footer
          InkWell(
            onTap: () { onClose(); Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())); },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('View all notifications', style: AppTextStyles.label.copyWith(color: AppColors.primaryLight)),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: AppColors.primaryLight, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}