// lib/features/admin/admin_dashboard_complete.dart
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// FINADVISE â€” MNC-LEVEL COMPLETE ADMIN DASHBOARD
// Full Swagger API parity Â· Enterprise design Â· Single-file architecture
// Added Real-time Polling Logic for silent background updates.
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

// ignore_for_file: use_build_context_synchronously, file_names, library_private_types_in_public_api

import 'dart:async'; // Real-time timers ke liye import
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:finadvise/app_theme.dart';
import 'package:finadvise/booking_page.dart';
import 'package:finadvise/admin_analytics_web_tab.dart';
import 'package:finadvise/admin_reports_web_tab.dart';
import 'package:finadvise/admin_settings_tab.dart' as settings_ui;
import 'package:finadvise/admin_tickets_tab.dart';
import 'package:finadvise/email_to_ticket_screen.dart';
import 'package:finadvise/login_screen.dart';
import 'package:finadvise/meet_the_masters_brand.dart';
import 'package:finadvise/models/models.dart';
import 'package:finadvise/notifications_screen.dart';
import 'package:finadvise/services/services.dart';
import 'package:finadvise/shared/ticket_number_formatter.dart';
import 'package:finadvise/shared_widgets.dart';
import 'package:finadvise/admin_missing_features.dart';
import 'package:finadvise/ticket_detail_screen.dart' hide EmptyState;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// â”€â”€ 0. DESIGN SYSTEM + SHARED HELPERS
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

// â”€â”€ Snackbar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

// â”€â”€ Input decoration â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

InputDecoration _inp(String label,
        {IconData? icon, String? hint, Widget? suffix, String? prefix}) =>
    InputDecoration(
      labelText: label,
      hintText: hint,
      prefixText: prefix,
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

final _leadingLetterFormatter = TextInputFormatter.withFunction(
  (oldValue, newValue) {
    final text = newValue.text;
    if (text.trimLeft().isEmpty) return newValue;
    return RegExp(r'[A-Za-z]').hasMatch(text.trimLeft()[0])
        ? newValue
        : oldValue;
  },
);

// â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

String _fmtDate(dynamic d) {
  if (d == null) return '';
  try {
    return DateFormat('d MMM yyyy')
        .format(DateTime.parse(d.toString().substring(0, 10)));
  } catch (_) {
    return d.toString().substring(0, 10);
  }
}

String _apiError(Object error, {String fallback = 'Something went wrong.'}) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      final direct = data['message'] ?? data['error'];
      if (direct != null && '$direct'.trim().isNotEmpty) {
        return '$direct'.trim();
      }

      final errors = data['errors'];
      if (errors is List && errors.isNotEmpty) {
        return errors.first.toString();
      }

      final validationErrors = data['validationErrors'];
      if (validationErrors is List && validationErrors.isNotEmpty) {
        return validationErrors.first.toString();
      }
    } else if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }
  }
  return fallback;
}

String _formatClockValue(String value) {
  try {
    final parsed = DateFormat('HH:mm').parseStrict(value);
    return DateFormat('h:mm a').format(parsed);
  } catch (_) {
    return value;
  }
}

int? _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}');
}

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}') ?? 0;
}

double _normalizeSessionFee(dynamic raw) {
  final value = _toDouble(raw);
  if (value >= 10000 && value < 1000000 && value % 10 == 0) {
    return value / 10;
  }
  return value;
}

String _fmtDateTime(dynamic value) {
  if (value == null) return '';
  final raw = value.toString().trim();
  if (raw.isEmpty) return '';
  try {
    return DateFormat('d MMM yyyy, h:mm a')
        .format(DateTime.parse(raw).toLocal());
  } catch (_) {
    return raw;
  }
}

Widget _sectionLbl(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(t.toUpperCase(),
          style: AppTextStyles.caption.copyWith(
              letterSpacing: 0.9,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary)),
    );

// â”€â”€ SLA calculation â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
    final breached = minsLeft < 0;
    final warning = !breached && minsLeft < 60;
    final label = breached
        ? 'Overdue ${(-minsLeft)}m'
        : minsLeft < 60
            ? '${minsLeft}m left'
            : '${(minsLeft / 60).round()}h left';
    return _SlaInfo(breached: breached, warning: warning, label: label);
  } catch (_) {
    return null;
  }
}

// â”€â”€ Premium card decoration â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

BoxDecoration _cardDeco({Color? border, Color? bg}) => BoxDecoration(
      color: bg ?? AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: border ?? AppColors.border),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2))
      ],
    );

// â”€â”€ Small chip â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

Widget _chip(String label, Color color, {double fontSize = 10}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              fontSize: fontSize,
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2)),
    );

// â”€â”€â”€ Gradient stat card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _StatCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final String? subtitle;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.12),
              color.withValues(alpha: 0.05)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: LayoutBuilder(builder: (context, constraints) {
          final compact = constraints.maxHeight < 120;
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  if (onTap != null) const Spacer(),
                  if (onTap != null)
                    Icon(Icons.arrow_forward_ios_rounded,
                        size: 12, color: color.withValues(alpha: 0.5)),
                ]),
                SizedBox(height: compact ? 8 : 10),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value,
                      style: TextStyle(
                          fontSize: compact ? 20 : 22,
                          fontWeight: FontWeight.w800,
                          color: color,
                          letterSpacing: -0.5)),
                ),
                const SizedBox(height: 2),
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary)),
                if (subtitle != null)
                  Text(subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 10, color: color.withValues(alpha: 0.7))),
              ]);
        }),
      ),
    );
  }
}

// â”€â”€ Helper data classes (replaces Dart 3.0 record types) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _MonthStat {
  final String label;
  final int bookings;
  final double revenue;
  const _MonthStat(
      {required this.label, required this.bookings, required this.revenue});
}

class _LegendItem {
  final String label;
  final Color color;
  final int value;
  const _LegendItem(
      {required this.label, required this.color, required this.value});
}

class _AgentStat {
  final String name;
  final int assigned;
  final int resolved;
  final int totalMins;
  final int resCount;
  const _AgentStat(
      {required this.name,
      required this.assigned,
      required this.resolved,
      required this.totalMins,
      required this.resCount});
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// â”€â”€ 1. ADMIN DASHBOARD SHELL
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

enum AdminSection {
  overview,
  tickets,
  bookings,
  advisors,
  analytics,
  reports,
  offers,
  offerApprovals,
  skillsQuestions,
  termsConditions,
  commission,
  contactMessages,
  addMember,
  settings,
  supportConfig,
  subscriptionPlans,
  masterTimeRanges,
  emailInbox,
  cannedResponses,
  autoResponder,
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _bottomIdx = 0;
  AdminSection _section = AdminSection.overview;

  static const _bottomSections = [
    AdminSection.overview,
    AdminSection.tickets,
    AdminSection.bookings,
    AdminSection.advisors,
    AdminSection.analytics,
  ];

  void _go(AdminSection s) {
    final shouldCloseDrawer = _scaffoldKey.currentState?.isDrawerOpen ?? false;
    setState(() {
      _section = s;
      final bi = _bottomSections.indexOf(s);
      if (bi >= 0) _bottomIdx = bi;
    });
    if (shouldCloseDrawer) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('You will be signed out of the admin panel.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await AuthService().logout();
      if (mounted)
        Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (_) => false);
    }
  }

  void _showNotifications() => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (ctx) => SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.65,
            child: NotificationPanel(onClose: () => Navigator.pop(ctx))),
      );

  Widget _body() {
    switch (_section) {
      case AdminSection.overview:
        return _OverviewTab(onSwitch: (i) {
          setState(() {
            _bottomIdx = i;
            _section = _bottomSections[i];
          });
        });
      case AdminSection.tickets:
        return const AdminTicketsTab();
      case AdminSection.bookings:
        return const BookingsPage(isAdmin: true);
      case AdminSection.advisors:
        return const _AdvisorsTab();
      case AdminSection.analytics:
        return const AdminAnalyticsWebTab();
      case AdminSection.reports:
        return const AdminReportsWebTab();
      case AdminSection.offers:
        return const _OffersTab();
      case AdminSection.offerApprovals:
        return const _OfferApprovalsTab();
      case AdminSection.skillsQuestions:
        return const settings_ui.SkillsQuestionsScreen();
      case AdminSection.termsConditions:
        return const _TermsTab();
      case AdminSection.commission:
        return const _CommissionTab();
      case AdminSection.contactMessages:
        return const _ContactTab();
      case AdminSection.addMember:
        return const AdminAddMemberScreen();
      case AdminSection.settings:
        return const AdminProfileSettingsScreen();
      case AdminSection.supportConfig:
        return const _CategoriesScreen();
      case AdminSection.subscriptionPlans:
        return const _PlansScreen();
      case AdminSection.masterTimeRanges:
        return const _MasterTimeRangesScreen();
      case AdminSection.emailInbox:
        return const EmailToTicketScreen();
      case AdminSection.cannedResponses:
        return const _CannedResponsesScreen();
      case AdminSection.autoResponder:
        return const _AutoResponderScreen();
    }
  }

  String get _title {
    const m = {
      AdminSection.overview: 'Overview',
      AdminSection.tickets: 'Tickets',
      AdminSection.bookings: 'Bookings',
      AdminSection.advisors: 'Consultants',
      AdminSection.analytics: 'Analytics',
      AdminSection.reports: 'Reports',
      AdminSection.offers: 'Offers',
      AdminSection.offerApprovals: 'Offer Approvals',
      AdminSection.skillsQuestions: 'Skills & Questions',
      AdminSection.termsConditions: 'Terms & Conditions',
      AdminSection.commission: 'Commission',
      AdminSection.contactMessages: 'Contact Messages',
      AdminSection.addMember: 'Add Member',
      AdminSection.settings: 'Settings',
      AdminSection.supportConfig: 'Support Config',
      AdminSection.subscriptionPlans: 'Subscription Plans',
      AdminSection.masterTimeRanges: 'Master Time Ranges',
      AdminSection.emailInbox: 'Email Inbox',
      AdminSection.cannedResponses: 'Canned Responses',
      AdminSection.autoResponder: 'Auto Responder',
    };
    return m[_section] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: _AdminDrawer(current: _section, onSelect: _go, onLogout: _logout),
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: AppColors.border,
        leading: Builder(
            builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu_rounded,
                      color: AppColors.textPrimary, size: 22),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                )),
        title: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _go(AdminSection.overview),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const MeetTheMastersLogoBadge(
              size: 40,
              padding: 5,
              showAmbientGlow: false,
            ),
            const SizedBox(width: 10),
            Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('MEET THE MASTERS',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          letterSpacing: 1.2)),
                  Text(_title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                ]),
          ]),
        ),
        actions: [
          Consumer<NotificationService>(
            builder: (_, svc, __) =>
                Stack(alignment: Alignment.center, children: [
              IconButton(
                  icon: const Icon(Icons.notifications_outlined,
                      color: AppColors.textPrimary, size: 22),
                  onPressed: _showNotifications),
              if (svc.unreadCount > 0)
                Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                          color: Color(0xFFDC2626), shape: BoxShape.circle),
                      child: Center(
                          child: Text(
                              svc.unreadCount > 9 ? '9+' : '${svc.unreadCount}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold))),
                    )),
            ]),
          ),
        ],
      ),
      body: _body(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: const Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, -4))
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _bottomIdx,
          onTap: (i) => setState(() {
            _bottomIdx = i;
            _section = _bottomSections[i];
          }),
          backgroundColor: Colors.transparent,
          selectedItemColor: AppColors.primaryLight,
          unselectedItemColor: AppColors.textMuted,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedFontSize: 10,
          unselectedFontSize: 10,
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.dashboard_outlined),
                activeIcon: Icon(Icons.dashboard_rounded),
                label: 'Overview'),
            BottomNavigationBarItem(
                icon: Icon(Icons.confirmation_number_outlined),
                activeIcon: Icon(Icons.confirmation_number_rounded),
                label: 'Tickets'),
            BottomNavigationBarItem(
                icon: Icon(Icons.calendar_month_outlined),
                activeIcon: Icon(Icons.calendar_month_rounded),
                label: 'Bookings'),
            BottomNavigationBarItem(
                icon: Icon(Icons.people_outline_rounded),
                activeIcon: Icon(Icons.people_rounded),
                label: 'Consultants'),
            BottomNavigationBarItem(
                icon: Icon(Icons.analytics_outlined),
                activeIcon: Icon(Icons.analytics_rounded),
                label: 'Analytics'),
          ],
        ),
      ),
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// â”€â”€ ADMIN DRAWER
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class _AdminDrawer extends StatelessWidget {
  final AdminSection current;
  final void Function(AdminSection) onSelect;
  final VoidCallback onLogout;
  const _AdminDrawer(
      {required this.current, required this.onSelect, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.surface,
      width: 280,
      child: Column(children: [
        // Header gradient
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
              20, MediaQuery.of(context).padding.top + 24, 20, 24),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.account_balance_rounded,
                  color: Colors.white, size: 26),
            ),
            const SizedBox(height: 14),
            const Text('MEET THE MASTERS',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5)),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6)),
              child: const Text('Admin Panel',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
        ),

        // Nav items
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _group(context, 'Main', [
                _item(context, Icons.dashboard_rounded, 'Overview',
                    AdminSection.overview),
                _item(context, Icons.confirmation_number_rounded, 'Tickets',
                    AdminSection.tickets),
                _item(context, Icons.calendar_month_rounded, 'Bookings',
                    AdminSection.bookings),
                _item(context, Icons.people_rounded, 'Consultants',
                    AdminSection.advisors),
                _item(context, Icons.analytics_rounded, 'Analytics',
                    AdminSection.analytics),
                _item(context, Icons.bar_chart_rounded, 'Reports',
                    AdminSection.reports),
              ]),
              _group(context, 'Management', [
                _item(context, Icons.local_offer_rounded, 'Offers',
                    AdminSection.offers),
                _item(context, Icons.task_alt_rounded, 'Offer Approvals',
                    AdminSection.offerApprovals),
                _item(context, Icons.quiz_rounded, 'Skills & Questions',
                    AdminSection.skillsQuestions),
                _item(context, Icons.person_add_rounded, 'Add Member',
                    AdminSection.addMember),
                _item(context, Icons.card_membership_rounded,
                    'Subscription Plans', AdminSection.subscriptionPlans),
                _item(context, Icons.mark_email_unread_rounded, 'Email Inbox',
                    AdminSection.emailInbox),
                _item(context, Icons.mail_rounded, 'Contact Messages',
                    AdminSection.contactMessages),
              ]),
              _group(context, 'Configuration', [
                _item(context, Icons.gavel_rounded, 'Terms & Conditions',
                    AdminSection.termsConditions),
                _item(context, Icons.currency_rupee_rounded, 'Commission',
                    AdminSection.commission),
                _item(context, Icons.chat_bubble_outline_rounded,
                    'Canned Responses', AdminSection.cannedResponses),
                _item(context, Icons.auto_mode_rounded, 'Auto Responder',
                    AdminSection.autoResponder),
                _item(context, Icons.support_agent_rounded, 'Support Config',
                    AdminSection.supportConfig),
                _item(context, Icons.schedule_rounded, 'Master Time Ranges',
                    AdminSection.masterTimeRanges),
                _item(context, Icons.settings_rounded, 'Settings',
                    AdminSection.settings),
              ]),
            ]),
          ),
        ),

        // Logout
        const Divider(height: 1, color: AppColors.border),
        ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.logout_rounded,
                color: Color(0xFFDC2626), size: 18),
          ),
          title: const Text('Sign Out',
              style: TextStyle(
                  color: Color(0xFFDC2626),
                  fontWeight: FontWeight.w700,
                  fontSize: 14)),
          onTap: onLogout,
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
      ]),
    );
  }

  Widget _group(BuildContext ctx, String title, List<Widget> items) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(title.toUpperCase(),
                style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMuted,
                    letterSpacing: 1.2)),
          ),
          ...items,
        ],
      );

  Widget _item(
      BuildContext ctx, IconData icon, String label, AdminSection section) {
    final active = current == section;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      decoration: BoxDecoration(
        color: active
            ? AppColors.primaryLight.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        dense: true,
        minLeadingWidth: 18,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        leading: Icon(icon,
            size: 19,
            color: active ? AppColors.primaryLight : AppColors.textSecondary),
        title: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                color:
                    active ? AppColors.primaryLight : AppColors.textPrimary)),
        trailing: active
            ? Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(2)))
            : null,
        onTap: () => onSelect(section),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// â”€â”€ 2. OVERVIEW TAB
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class _OverviewTab extends StatefulWidget {
  final void Function(int) onSwitch;
  const _OverviewTab({required this.onSwitch});
  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  final _ts = TicketService();
  final _bs = BookingService();
  final _cs = ConsultantService();
  final _us = UserService();
  List<Ticket> _tickets = [];
  List<Booking> _bookings = [];
  List<ConsultantModel> _consultants = [];
  Map<int, String> _userNames = {};
  Map<int, String> _consultantNames = {};
  bool _loading = true;
  Timer? _pollTimer;

  int get _slaBreachedCount =>
      _tickets.where((t) => _calcSla(t)?.breached ?? false).length;
  int get _escalatedCount => _tickets
      .where(
          (t) => t.escalated == true || t.status.toUpperCase() == 'ESCALATED')
      .length;

  @override
  void initState() {
    super.initState();
    _load();
    // Har 15 seconds mein silent refresh karega (real-time look)
    _pollTimer =
        Timer.periodic(const Duration(seconds: 15), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<List<Ticket>> _fetchAllTickets() async {
    final analytics = await _ts.getAllTickets(useAnalytics: true, size: 500);
    if (analytics.isNotEmpty) return analytics;
    return _ts.getAllTickets(size: 500);
  }

  Future<List<Booking>> _fetchAllBookings() async {
    final first = await _bs.getAllBookingsPaginated(page: 0, size: 200);
    final all = <Booking>[
      ...(first['bookings'] as List<Booking>? ?? const <Booking>[]),
    ];
    final totalPages = (first['totalPages'] as int?) ?? 1;
    for (var page = 1; page < totalPages; page++) {
      final next = await _bs.getAllBookingsPaginated(page: page, size: 200);
      all.addAll(next['bookings'] as List<Booking>? ?? const <Booking>[]);
    }
    if (all.isEmpty) {
      all.addAll(await _bs.getAllBookings(page: 0, size: 200));
    }
    try {
      final specialRows = await _bs.getAllSpecialBookings();
      all.addAll(specialRows.map(Booking.fromJson));
    } catch (_) {}

    final seen = <String>{};
    return all.where((booking) {
      final key = [
        booking.id,
        booking.status,
        booking.slotDate ?? booking.createdAt ?? '',
        booking.consultantId ?? 0,
        booking.userId ?? 0,
      ].join('|');
      if (!seen.add(key)) return false;
      return true;
    }).toList();
  }

  String _normalizeName(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '';
    final lower = text.toLowerCase();
    if (lower == 'null' || lower == 'undefined') return '';
    if (text.contains('@')) {
      final local = text.split('@').first;
      final cleaned = local
          .replaceAll(RegExp(r'[._\-]+'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (cleaned.isNotEmpty) {
        return cleaned
            .split(' ')
            .where((part) => part.isNotEmpty)
            .map((part) =>
                '${part.substring(0, 1).toUpperCase()}${part.substring(1).toLowerCase()}')
            .join(' ');
      }
    }
    return text;
  }

  bool _isGenericLabel(String raw, String prefix) {
    final text = raw.trim().toLowerCase();
    if (text.isEmpty) return true;
    final p = prefix.toLowerCase();
    return text == p ||
        text == '$p -' ||
        RegExp('^${RegExp.escape(p)}\\s*#\\d+\$').hasMatch(text);
  }

  Future<Map<int, String>> _fetchUserLookup() async {
    final out = <int, String>{};
    try {
      final users = await _us.getAllUsers(size: 500);
      for (final user in users) {
        final raw =
            user.name.isNotEmpty ? user.name : (user.identifier ?? user.email);
        final name = _normalizeName(raw);
        if (name.isNotEmpty) {
          out[user.id] = name;
        }
      }
    } catch (_) {}
    return out;
  }

  Map<int, String> _buildConsultantLookup(List<ConsultantModel> consultants) =>
      {
        for (final consultant in consultants)
          if (_normalizeName(consultant.name).isNotEmpty)
            consultant.id: _normalizeName(consultant.name),
      };

  String _displayClientName(Booking booking) {
    final direct = _normalizeName(booking.clientName ?? '');
    if (direct.isNotEmpty &&
        !_isGenericLabel(direct, 'client') &&
        !_isGenericLabel(direct, 'user')) {
      return direct;
    }
    final id = booking.userId;
    if (id != null && _userNames[id]?.trim().isNotEmpty == true) {
      return _userNames[id]!.trim();
    }
    if (direct.isNotEmpty) return direct;
    return id != null ? 'User #$id' : 'Client';
  }

  String _displayConsultantName(Booking booking) {
    final direct = _normalizeName(booking.consultantName ?? '');
    if (direct.isNotEmpty &&
        !_isGenericLabel(direct, 'consultant') &&
        !_isGenericLabel(direct, 'advisor')) {
      return direct;
    }
    final id = booking.consultantId;
    if (id != null && _consultantNames[id]?.trim().isNotEmpty == true) {
      return _consultantNames[id]!.trim();
    }
    if (direct.isNotEmpty) return direct;
    return id != null ? 'Consultant #$id' : 'Consultant';
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    var tickets = _tickets;
    var bookings = _bookings;
    var consultants = _consultants;
    var userNames = _userNames;
    var consultantNames = _consultantNames;

    try {
      tickets = await _fetchAllTickets();
    } catch (_) {}

    try {
      bookings = await _fetchAllBookings();
    } catch (_) {}

    try {
      consultants = await _cs.getAllConsultants();
    } catch (_) {}

    try {
      userNames = await _fetchUserLookup();
    } catch (_) {}

    consultantNames = _buildConsultantLookup(consultants);

    if (mounted) {
      setState(() {
        _tickets = tickets;
        _bookings = bookings;
        _consultants = consultants;
        _userNames = userNames;
        _consultantNames = consultantNames;
        _loading = false;
      });
    }
  }

  int get _openTickets => _tickets
      .where((t) => ['NEW', 'OPEN', 'IN_PROGRESS', 'PENDING']
          .contains(t.status.toUpperCase()))
      .length;
  bool _isRevenueBooking(Booking booking) {
    final status = booking.status.toUpperCase();
    return status == 'COMPLETED';
  }

  int get _completedBookings => _bookings.where(_isRevenueBooking).length;
  double get _revenue => _bookings
      .where(_isRevenueBooking)
      .fold(0.0, (s, b) => s + (b.amount ?? 0));

  DateTime? _parseBookingDateValue(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return null;

    final isoDateOnly = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (isoDateOnly != null) {
      final y = int.tryParse(isoDateOnly.group(1)!);
      final m = int.tryParse(isoDateOnly.group(2)!);
      final d = int.tryParse(isoDateOnly.group(3)!);
      if (y != null && m != null && d != null) {
        return DateTime(y, m, d);
      }
    }

    final ddMmYyyy =
        RegExp(r'^(\d{1,2})[-/](\d{1,2})[-/](\d{4})$').firstMatch(value);
    if (ddMmYyyy != null) {
      final d = int.tryParse(ddMmYyyy.group(1)!);
      final m = int.tryParse(ddMmYyyy.group(2)!);
      final y = int.tryParse(ddMmYyyy.group(3)!);
      if (y != null && m != null && d != null) {
        return DateTime(y, m, d);
      }
    }

    final hasZone =
        value.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(value);
    if (hasZone) return DateTime.tryParse(value);

    if (value.contains('T')) {
      final utc = DateTime.tryParse('${value}Z');
      if (utc != null) return utc.toLocal();
    }

    final parsed = DateTime.tryParse(value);
    return parsed?.toLocal();
  }

  List<_MonthStat> get _monthly {
    final now = DateTime.now();
    return List.generate(6, (i) {
      final month = DateTime(now.year, now.month - (5 - i));
      final bks = _bookings.where((b) {
        final parsed = _parseBookingDateValue(b.slotDate ?? b.createdAt);
        if (parsed == null) return false;
        final d = DateTime(parsed.year, parsed.month, 1);
        return d.year == month.year && d.month == month.month;
      });
      return _MonthStat(
          label: DateFormat('MMM').format(month),
          bookings: bks.length,
          revenue: bks
              .where(_isRevenueBooking)
              .fold(0.0, (s, b) => s + (b.amount ?? 0)));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final stats = _monthly;
    final maxRev = stats.fold(1.0, (m, s) => s.revenue > m ? s.revenue : m);
    final maxBks =
        stats.fold(1, (m, s) => s.bookings > m ? s.bookings : m).toDouble();
    final kpiAspectRatio =
        MediaQuery.of(context).size.width < 430 ? 1.32 : 1.55;

    return RefreshIndicator(
      onRefresh: () => _load(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // Welcome banner
          Container(
            padding: const EdgeInsets.all(18),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6))
              ],
            ),
            child: Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('Admin Dashboard',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                    Text(DateFormat('EEEE, d MMM').format(DateTime.now()),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                        '${_bookings.length} total bookings - ${_consultants.length} consultants',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ])),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.account_balance_rounded,
                    color: Colors.white, size: 28),
              ),
            ]),
          ),

          // KPI Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: kpiAspectRatio,
            children: [
              _StatCard(
                  title: 'Total Bookings',
                  value: '${_bookings.length}',
                  icon: Icons.calendar_month_rounded,
                  color: AppColors.primaryLight,
                  onTap: () => widget.onSwitch(2)),
              _StatCard(
                  title: 'Consultants',
                  value: '${_consultants.length}',
                  icon: Icons.people_rounded,
                  color: AppColors.primary,
                  onTap: () => widget.onSwitch(3)),
              _StatCard(
                  title: 'Revenue',
                  value: 'Rs ${NumberFormat.compact().format(_revenue)}',
                  icon: Icons.currency_rupee_rounded,
                  color: AppColors.success),
              _StatCard(
                  title: 'Open Tickets',
                  value: '$_openTickets',
                  icon: Icons.confirmation_number_rounded,
                  color: AppColors.danger,
                  onTap: () => widget.onSwitch(1)),
            ],
          ),
          const SizedBox(height: 14),

          // Alert strip
          if (_openTickets > 0)
            GestureDetector(
              onTap: () => widget.onSwitch(1),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFDC2626), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(
                          '$_openTickets open ticket${_openTickets != 1 ? 's' : ''} need attention',
                          style: const TextStyle(
                              color: Color(0xFFB91C1C),
                              fontWeight: FontWeight.w700,
                              fontSize: 13))),
                  const Icon(Icons.chevron_right_rounded,
                      color: Color(0xFFDC2626), size: 18),
                ]),
              ),
            ),

          // SLA + Escalated quick cards
          Row(children: [
            Expanded(
                child: _quickAlertCard(
                    context,
                    Icons.timer_off_rounded,
                    '$_slaBreachedCount SLA Breached',
                    const Color(0xFFC0841A),
                    () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SlaBreachedScreen())))),
            const SizedBox(width: 10),
            Expanded(
                child: _quickAlertCard(
                    context,
                    Icons.escalator_warning_rounded,
                    '$_escalatedCount Escalated',
                    const Color(0xFF7C3AED),
                    () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const EscalatedTicketsScreen())))),
          ]),
          const SizedBox(height: 14),

          // Monthly chart
          Container(
            padding: const EdgeInsets.all(18),
            decoration: _cardDeco(),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Monthly Overview', style: AppTextStyles.h4),
                Text('Last 6 months', style: AppTextStyles.caption),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                _legendDot(AppColors.primaryLight, 'Bookings'),
                const SizedBox(width: 16),
                _legendDot(AppColors.gold, 'Revenue'),
              ]),
              const SizedBox(height: 16),
              SizedBox(
                height: 170,
                child: stats.every((s) => s.bookings == 0 && s.revenue == 0)
                    ? const Center(
                        child: Text('No booking data yet',
                            style: TextStyle(color: AppColors.textMuted)))
                    : BarChart(BarChartData(
                        borderData: FlBorderData(show: false),
                        gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (_) => const FlLine(
                                color: AppColors.border, strokeWidth: 0.5)),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 22,
                                  getTitlesWidget: (v, _) {
                                    final i = v.toInt();
                                    if (i < 0 || i >= stats.length)
                                      return const SizedBox.shrink();
                                    return Text(stats[i].label,
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color: AppColors.textMuted));
                                  })),
                          leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                        ),
                        barGroups: stats
                            .asMap()
                            .entries
                            .map((e) => BarChartGroupData(
                                  x: e.key,
                                  barsSpace: 4,
                                  barRods: [
                                    BarChartRodData(
                                        toY: e.value.bookings.toDouble(),
                                        color: AppColors.primaryLight,
                                        width: 11,
                                        borderRadius:
                                            const BorderRadius.vertical(
                                                top: Radius.circular(5))),
                                    BarChartRodData(
                                        toY: maxRev > 0
                                            ? (e.value.revenue / maxRev) *
                                                maxBks
                                            : 0,
                                        color: AppColors.gold,
                                        width: 11,
                                        borderRadius:
                                            const BorderRadius.vertical(
                                                top: Radius.circular(5))),
                                  ],
                                ))
                            .toList(),
                      )),
              ),
            ]),
          ),
          const SizedBox(height: 14),

          // Quick actions
          Text('Quick Actions', style: AppTextStyles.h4),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.1,
            children: [
              _quickAction(context, Icons.local_offer_rounded, 'Offers',
                  const Color(0xFFDC2626), AdminSection.offers),
              _quickAction(context, Icons.task_alt_rounded, 'Approvals',
                  const Color(0xFFF97316), AdminSection.offerApprovals),
              _quickAction(context, Icons.add_circle_outline_rounded,
                  'New Ticket', const Color(0xFF7C3AED), AdminSection.tickets),
              _quickAction(context, Icons.person_add_rounded, 'Add Member',
                  const Color(0xFF059669), AdminSection.addMember),
              _quickAction(context, Icons.currency_rupee_rounded, 'Commission',
                  AppColors.primaryLight, AdminSection.commission),
              _quickAction(context, Icons.mail_rounded, 'Messages',
                  const Color(0xFF0891B2), AdminSection.contactMessages),
            ],
          ),
          const SizedBox(height: 14),

          // Recent bookings
          Text('Recent Bookings', style: AppTextStyles.h4),
          const SizedBox(height: 10),
          if (_bookings.isEmpty)
            const _EmptyCard(
                icon: Icons.calendar_today_outlined, message: 'No bookings yet')
          else
            ..._bookings.take(5).map((b) => _RecentBookingRow(
                  booking: b,
                  clientName: _displayClientName(b),
                  consultantName: _displayConsultantName(b),
                )),

          const SizedBox(height: 14),

          // Top Consultants
          Text('Consultants', style: AppTextStyles.h4),
          const SizedBox(height: 10),
          if (_consultants.isEmpty)
            const _EmptyCard(
                icon: Icons.people_outline, message: 'No consultants yet')
          else
            ..._consultants.take(4).map((c) => _ConsultantRow(consultant: c)),
        ],
      ),
    );
  }

  Widget _quickAlertCard(BuildContext context, IconData icon, String label,
          Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.3))),
          child: Row(children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: color)),
                  Text('View ->',
                      style: TextStyle(
                          fontSize: 10, color: color.withValues(alpha: 0.7))),
                ])),
          ]),
        ),
      );

  Widget _quickAction(BuildContext ctx, IconData icon, String label,
          Color color, AdminSection section) =>
      GestureDetector(
        onTap: () => Navigator.push(ctx,
            MaterialPageRoute(builder: (_) => _SubScaffold(section: section))),
        child: Container(
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.2))),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 20)),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: color),
                textAlign: TextAlign.center),
          ]),
        ),
      );

  Widget _legendDot(Color color, String label) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 5),
        Text(label, style: AppTextStyles.caption),
      ]);
}

class _SubScaffold extends StatelessWidget {
  final AdminSection section;
  const _SubScaffold({required this.section});

  String get _title =>
      const {
        AdminSection.offers: 'Offers',
        AdminSection.offerApprovals: 'Offer Approvals',
        AdminSection.skillsQuestions: 'Skills & Questions',
        AdminSection.addMember: 'Add Member',
        AdminSection.commission: 'Commission',
        AdminSection.contactMessages: 'Contact Messages',
      }[section] ??
      '';

  Widget get _body {
    if (section == AdminSection.offers) return const _OffersTab();
    if (section == AdminSection.offerApprovals)
      return const _OfferApprovalsTab();
    if (section == AdminSection.skillsQuestions)
      return const settings_ui.SkillsQuestionsScreen();
    if (section == AdminSection.addMember) return const AdminAddMemberScreen();
    if (section == AdminSection.commission) return const _CommissionTab();
    if (section == AdminSection.contactMessages) return const _ContactTab();
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(_title,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
            backgroundColor: AppColors.surface,
            iconTheme: const IconThemeData(color: AppColors.textPrimary),
            elevation: 0),
        backgroundColor: AppColors.background,
        body: _body,
      );
}

// â”€â”€ Recent booking row â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _RecentBookingRow extends StatelessWidget {
  final Booking booking;
  final String clientName;
  final String consultantName;

  const _RecentBookingRow({
    required this.booking,
    required this.clientName,
    required this.consultantName,
  });

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final color = getStatusColor(b.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: _cardDeco(),
      child: Row(children: [
        CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primaryLight.withValues(alpha: 0.1),
            child: Text(
                (clientName.isNotEmpty
                        ? clientName
                        : (consultantName.isNotEmpty ? consultantName : 'B'))[0]
                    .toUpperCase(),
                style: const TextStyle(
                    color: AppColors.primaryLight,
                    fontWeight: FontWeight.w700,
                    fontSize: 13))),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(clientName, style: AppTextStyles.label),
          Text('$consultantName - ${b.slotDate ?? ''}',
              style: AppTextStyles.caption),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          _chip(b.status, color),
          if (b.amount != null) ...[
            const SizedBox(height: 4),
            Text('Rs ${b.amount!.toStringAsFixed(0)}',
                style: TextStyle(
                    fontSize: 11,
                    color: const Color(0xFF059669),
                    fontWeight: FontWeight.w700))
          ],
        ]),
      ]),
    );
  }
}

class _ConsultantRow extends StatelessWidget {
  final ConsultantModel consultant;
  const _ConsultantRow({required this.consultant});

  @override
  Widget build(BuildContext context) {
    final c = consultant;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: _cardDeco(),
      child: Row(children: [
        CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            backgroundImage:
                c.photoUrl != null ? NetworkImage(c.photoUrl!) : null,
            child: c.photoUrl == null
                ? Text(c.name[0].toUpperCase(),
                    style: const TextStyle(
                        color: AppColors.primary, fontWeight: FontWeight.w700))
                : null),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c.name, style: AppTextStyles.label),
          Text(c.designation ?? 'Financial Consultant',
              style: AppTextStyles.caption),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (c.rating != null)
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.star_rounded,
                  size: 12, color: Color(0xFFF59E0B)),
              Text(' ${c.rating!.toStringAsFixed(1)}',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary))
            ]),
          if (c.charges != null)
            Text(
                'Rs ${_normalizeSessionFee(c.charges).toStringAsFixed(0)}/session',
                style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF059669),
                    fontWeight: FontWeight.w600)),
        ]),
      ]),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyCard({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: _cardDeco(),
        child: Column(children: [
          Icon(icon, size: 36, color: AppColors.textMuted),
          const SizedBox(height: 8),
          Text(message, style: AppTextStyles.caption),
        ]),
      );
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// â”€â”€ 3. TICKETS TAB â€” paginated + SLA strips + real CSV export + Polling
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class _TicketsTab extends StatefulWidget {
  const _TicketsTab();
  @override
  State<_TicketsTab> createState() => _TicketsTabState();
}

class _TicketsTabState extends State<_TicketsTab> {
  final _ts = TicketService();
  final _cs = ConsultantService();

  List<Ticket> _all = [], _filtered = [];
  List<ConsultantModel> _consultants = [];
  bool _loading = true, _loadingMore = false;
  int _page = 0;
  bool _hasMore = true;
  static const _pageSize = 20;

  String _search = '', _statusF = 'ALL', _priorityF = 'ALL';
  final _statuses = [
    'ALL',
    'NEW',
    'OPEN',
    'IN_PROGRESS',
    'PENDING',
    'RESOLVED',
    'CLOSED',
    'ESCALATED'
  ];
  final _priorities = ['ALL', 'LOW', 'MEDIUM', 'HIGH', 'URGENT', 'CRITICAL'];
  final _scroll = ScrollController();
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadData(reset: true);
    // Tickets list background real-time sync har 15 seconds me
    _pollTimer = Timer.periodic(const Duration(seconds: 15),
        (_) => _loadData(reset: true, silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200 &&
        _hasMore &&
        !_loadingMore) _loadData();
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
      } // silent mein existing list clear nahi karte taaki UI flicker na kare
    } else {
      if (_loadingMore) return;
      setState(() => _loadingMore = true);
    }

    try {
      final results = await Future.wait([
        TicketService().getAllTickets(
            page: reset ? 0 : _page, size: _pageSize, useAnalytics: true),
        if (reset) _cs.getAllConsultants() else Future.value(_consultants),
      ]);
      final tickets = results[0] as List<Ticket>;
      final hasMore = tickets.length == _pageSize;
      if (!reset)
        _page++;
      else
        _page = 1;

      if (mounted)
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
    } catch (_) {
      if (mounted && !silent)
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
    }
  }

  void _applyFilters() => setState(() {
        _filtered = _all.where((t) {
          final ms = (t.description ?? '')
                  .toLowerCase()
                  .contains(_search.toLowerCase()) ||
              t.category.toLowerCase().contains(_search.toLowerCase()) ||
              t.id.toString().contains(_search);
          final mst = _statusF == 'ALL' || t.status.toUpperCase() == _statusF;
          final mp =
              _priorityF == 'ALL' || t.priority.toUpperCase() == _priorityF;
          return ms && mst && mp;
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
    List<UserModel> users = [];
    final categories = <String>{};
    try {
      users = await UserService().getAllUsers();
    } catch (_) {}
    try {
      final rawCats = await AdminService().getCategories();
      for (final cat in rawCats) {
        final name = (cat['name'] ?? '').toString().trim();
        if (name.isNotEmpty) categories.add(name);
      }
    } catch (_) {}
    categories.addAll(await _ts.getUniqueCategories());
    if (!mounted) return;

    final descCtrl = TextEditingController();
    final customCategoryCtrl = TextEditingController();
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
                  Text('Create Ticket', style: AppTextStyles.h3),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: userId,
                    decoration:
                        _inp('User *', icon: Icons.person_outline_rounded),
                    items: users
                        .map((user) => DropdownMenuItem<int>(
                            value: user.id,
                            child: Text((user.identifier ?? 'User').toString(),
                                overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (value) => ss(() => userId = value),
                  ),
                  const SizedBox(height: 10),
                  if (categories.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration:
                          _inp('Category', icon: Icons.label_outline_rounded),
                      items: categories
                          .map((item) => DropdownMenuItem<String>(
                              value: item, child: Text(item)))
                          .toList(),
                      onChanged: (value) => ss(() => category = value),
                    ),
                  const SizedBox(height: 10),
                  TextField(
                      controller: customCategoryCtrl,
                      decoration: _inp('Custom category (optional)',
                          icon: Icons.edit_outlined)),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: priority,
                    decoration: _inp('Priority', icon: Icons.flag_outlined),
                    items: _priorities
                        .where((item) => item != 'ALL')
                        .map((item) => DropdownMenuItem<String>(
                            value: item, child: Text(item)))
                        .toList(),
                    onChanged: (value) =>
                        ss(() => priority = value ?? 'MEDIUM'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int?>(
                    initialValue: consultantId,
                    decoration: _inp('Assign consultant (optional)',
                        icon: Icons.support_agent_outlined),
                    items: [
                      const DropdownMenuItem<int?>(
                          value: null, child: Text('Unassigned')),
                      ..._consultants.map((consultant) =>
                          DropdownMenuItem<int?>(
                              value: consultant.id,
                              child: Text(consultant.name)))
                    ],
                    onChanged: (value) => ss(() => consultantId = value),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                      controller: descCtrl,
                      maxLines: 4,
                      decoration: _inp('Description *',
                          icon: Icons.description_outlined)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: () async {
                        final resolvedCategory =
                            customCategoryCtrl.text.trim().isNotEmpty
                                ? customCategoryCtrl.text.trim()
                                : (category ?? '').trim();
                        if (userId == null) {
                          _snack(ctx, 'Select a user', error: true);
                          return;
                        }
                        if (resolvedCategory.isEmpty) {
                          _snack(ctx, 'Select or enter a category',
                              error: true);
                          return;
                        }
                        if (descCtrl.text.trim().isEmpty) {
                          _snack(ctx, 'Description is required', error: true);
                          return;
                        }
                        final created = await _ts.createTicket(
                            userId: userId!,
                            category: resolvedCategory,
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
                        _snack(context,
                            'Ticket ${formatTicketNumberFromTicket(created)} created',
                            icon: Icons.confirmation_number_outlined);
                        _loadData(reset: true);
                      },
                      child: const Text('Create Ticket'),
                    ),
                  ),
                ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateTicketSheet,
        backgroundColor: AppColors.primaryLight,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Ticket',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: Column(children: [
        // Search + filter bar
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          color: AppColors.surface,
          child: Column(children: [
            Row(children: [
              Expanded(
                  child: TextField(
                onChanged: (v) {
                  _search = v;
                  _applyFilters();
                },
                decoration:
                    _inp('Search tickets...', icon: Icons.search_rounded),
              )),
              const SizedBox(width: 8),
              _iconBtn(
                  Icons.download_rounded, const Color(0xFF059669), _exportCsv,
                  tooltip: 'Export CSV'),
              const SizedBox(width: 6),
              _iconBtn(Icons.refresh_rounded, AppColors.primaryLight,
                  () => _loadData(reset: true),
                  tooltip: 'Refresh'),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: _dropDown(_statuses, _statusF, (v) {
                setState(() => _statusF = v!);
                _loadData(reset: true);
              })),
              const SizedBox(width: 10),
              Expanded(
                  child: _dropDown(_priorities, _priorityF, (v) {
                setState(() => _priorityF = v!);
                _loadData(reset: true);
              })),
            ]),
          ]),
        ),

        // Count bar
        if (!_loading)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            color: AppColors.surfaceVariant,
            child: Row(children: [
              Text(
                  '${_filtered.length} ticket${_filtered.length != 1 ? 's' : ''}',
                  style: AppTextStyles.caption
                      .copyWith(fontWeight: FontWeight.w700)),
              if (_hasMore)
                const Text(' - scroll for more',
                    style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
            ]),
          ),

        // List
        Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                            const Icon(Icons.inbox_outlined,
                                size: 56, color: AppColors.textMuted),
                            const SizedBox(height: 12),
                            const Text('No tickets found',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary)),
                            const Text('Adjust filters or search terms',
                                style: TextStyle(
                                    color: AppColors.textMuted, fontSize: 12)),
                          ]))
                    : RefreshIndicator(
                        onRefresh: () => _loadData(reset: true),
                        child: ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.all(12),
                          itemCount: _filtered.length + (_loadingMore ? 1 : 0),
                          itemBuilder: (_, i) {
                            if (i == _filtered.length)
                              return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                      child: CircularProgressIndicator()));
                            return _TicketCard(
                                ticket: _filtered[i],
                                consultants: _consultants,
                                onRefresh: () => _loadData(reset: true));
                          },
                        ),
                      )),
      ]),
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
        )),
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
    final t = ticket;
    final sla = _calcSla(t);
    final statusColor = getStatusColor(t.status);
    final priorityColor = getPriorityColor(t.priority);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: sla?.breached == true
                ? const Color(0xFFFECACA)
                : sla?.warning == true
                    ? const Color(0xFFFDE68A)
                    : AppColors.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => TicketDetailScreen(
                    ticket: t,
                    consultants: consultants,
                    role: 'ADMIN'))).then((_) => onRefresh()),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Row(children: [
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: AppColors.primaryLight
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6)),
                            child: Text(
                                'Ticket Number: ${formatTicketNumberFromTicket(t)}',
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryLight))),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text(
                                t.category.isEmpty ? 'General' : t.category,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary),
                                overflow: TextOverflow.ellipsis)),
                      ]),
                      const SizedBox(height: 5),
                      Text(
                          (t.description?.isEmpty ?? true)
                              ? 'No description.'
                              : t.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              height: 1.4)),
                    ])),
                const SizedBox(width: 8),
                _chip(t.status, statusColor),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.person_outline_rounded,
                    size: 13, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                    (t.userName?.isEmpty ?? true)
                        ? 'User Name: User'
                        : 'User Name: ${t.userName!}',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
                const Spacer(),
                Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                        color: priorityColor, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text(t.priority,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: priorityColor)),
                if (t.createdAt != null) ...[
                  const SizedBox(width: 10),
                  Text(_fmtDate(t.createdAt),
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textMuted))
                ],
              ]),
            ]),
          ),
          // SLA strip
          if (sla != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: sla.breached
                    ? const Color(0xFFFEF2F2)
                    : sla.warning
                        ? const Color(0xFFFFFBEB)
                        : const Color(0xFFF0FDF4),
                border: Border(
                    top: BorderSide(
                        color: sla.breached
                            ? const Color(0xFFFECACA)
                            : sla.warning
                                ? const Color(0xFFFDE68A)
                                : const Color(0xFFBBF7D0))),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(14)),
              ),
              child: Row(children: [
                Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                        color: sla.breached
                            ? const Color(0xFFDC2626)
                            : sla.warning
                                ? const Color(0xFFF97316)
                                : const Color(0xFF059669),
                        shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(
                    'SLA ${sla.breached ? 'BREACHED' : sla.warning ? 'WARNING' : 'ON TRACK'} - ${t.priority} - ${sla.label}',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: sla.breached
                            ? const Color(0xFFB91C1C)
                            : sla.warning
                                ? const Color(0xFF92400E)
                                : const Color(0xFF15803D))),
              ]),
            ),
        ]),
      ),
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// â”€â”€ 5. ADVISORS TAB
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class _AdvisorsTab extends StatefulWidget {
  const _AdvisorsTab();
  @override
  State<_AdvisorsTab> createState() => _AdvisorsTabState();
}

class _AdvisorsTabState extends State<_AdvisorsTab> {
  final _svc = ConsultantService();
  List<ConsultantModel> _advisors = [];
  bool _loading = true;
  String _search = '';
  Timer? _pollTimer;

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
    _advisors = await _svc.getAllConsultants();
    if (mounted) setState(() => _loading = false);
  }

  List<ConsultantModel> get _filtered => _search.isEmpty
      ? _advisors
      : _advisors
          .where((a) =>
              a.name.toLowerCase().contains(_search.toLowerCase()) ||
              (a.designation ?? '')
                  .toLowerCase()
                  .contains(_search.toLowerCase()))
          .toList();

  Future<bool> _hasActiveBookings(int id) async {
    try {
      final res =
          await BookingService().getBookingsByConsultantPaginated(id, size: 5);
      if (res.totalElements > 0) {
        return res.content.any(
            (b) => ['CONFIRMED', 'PENDING'].contains(b.status.toUpperCase()));
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _delete(ConsultantModel advisor) async {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
              content: Row(children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Checking bookings...')
              ]),
            ));
    final hasBookings = await _hasActiveBookings(advisor.id);
    if (!mounted) return;
    Navigator.pop(context);

    if (hasBookings) {
      showDialog(
          context: context,
          builder: (_) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                title: const Row(children: [
                  Icon(Icons.block_rounded, color: Color(0xFFDC2626)),
                  SizedBox(width: 8),
                  Text('Cannot Delete')
                ]),
                content: Text(
                    '${advisor.name} has active bookings. Cancel all bookings before deleting.'),
                actions: [
                  FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Understood'))
                ],
              ));
      return;
    }

    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Text('Delete ${advisor.name}?'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: const Color(0xFF059669).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFF059669)
                                .withValues(alpha: 0.3))),
                    child: const Row(children: [
                      Icon(Icons.check_circle_outline,
                          color: Color(0xFF059669), size: 16),
                      SizedBox(width: 8),
                      Expanded(
                          child: Text('No active bookings - safe to delete',
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xFF059669))))
                    ])),
                const SizedBox(height: 12),
                const Text('This cannot be undone.'),
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626)),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Delete'))
              ],
            ));

    if (ok != true || !mounted) return;
    final deleted = await _svc.deleteConsultant(advisor.id);
    if (deleted) {
      setState(() => _advisors.removeWhere((a) => a.id == advisor.id));
      _snack(context, '${advisor.name} deleted');
    } else {
      _snack(context, 'Delete failed', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: AppColors.surface,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            builder: (_) => _AdvisorForm(onSaved: () {
                  Navigator.pop(context);
                  _load();
                })),
        backgroundColor: AppColors.primaryLight,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Consultant',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.all(14),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration:
                  _inp('Search consultants...', icon: Icons.search_rounded),
            )),
        Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? const EmptyState(
                        icon: Icons.people_outline,
                        title: 'No consultants found')
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 100),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) => _AdvisorCard(
                            advisor: filtered[i],
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => _AdvisorDetail(
                                        advisor: filtered[i],
                                        onChanged: _load))),
                            onDelete: () => _delete(filtered[i]),
                          ),
                        ),
                      )),
      ]),
    );
  }
}

class _AdvisorCard extends StatelessWidget {
  final ConsultantModel advisor;
  final VoidCallback onTap, onDelete;
  const _AdvisorCard(
      {required this.advisor, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final a = advisor;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: _cardDeco(),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  backgroundImage:
                      a.photoUrl != null ? NetworkImage(a.photoUrl!) : null,
                  child: a.photoUrl == null
                      ? Text(a.name[0].toUpperCase(),
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary))
                      : null),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      Expanded(child: Text(a.name, style: AppTextStyles.h4)),
                      _chip(
                          a.isActive ? 'ACTIVE' : 'INACTIVE',
                          a.isActive
                              ? const Color(0xFF059669)
                              : AppColors.textMuted),
                    ]),
                    if (a.designation != null)
                      Text(a.designation!, style: AppTextStyles.caption),
                    const SizedBox(height: 4),
                    Row(children: [
                      if (a.rating != null) ...[
                        const Icon(Icons.star_rounded,
                            size: 12, color: Color(0xFFF59E0B)),
                        Text(' ${a.rating!.toStringAsFixed(1)}',
                            style: AppTextStyles.caption
                                .copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(width: 10)
                      ],
                      if (a.charges != null)
                        Text(
                            'Rs ${_normalizeSessionFee(a.charges).toStringAsFixed(0)}/session',
                            style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF059669),
                                fontWeight: FontWeight.w600)),
                    ]),
                  ])),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded,
                    color: AppColors.textMuted),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onSelected: (v) {
                  if (v == 'delete') onDelete();
                  if (v == 'detail') onTap();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                      value: 'detail',
                      child: Row(children: [
                        Icon(Icons.info_outline_rounded, size: 18),
                        SizedBox(width: 10),
                        Text('View Details')
                      ])),
                  PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_outline_rounded,
                            size: 18, color: Color(0xFFDC2626)),
                        SizedBox(width: 10),
                        Text('Delete',
                            style: TextStyle(color: Color(0xFFDC2626)))
                      ])),
                ],
              ),
            ])),
      ),
    );
  }
}

class _AdvisorDetail extends StatefulWidget {
  final ConsultantModel advisor;
  final VoidCallback onChanged;
  const _AdvisorDetail({required this.advisor, required this.onChanged});
  @override
  State<_AdvisorDetail> createState() => _AdvisorDetailState();
}

class _AdvisorDetailState extends State<_AdvisorDetail>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _svc = ConsultantService();
  List<TimeSlot> _slots = [];
  bool _loadingSlots = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadSlots();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadSlots() async {
    _slots = await _svc.getSlotsByConsultant(widget.advisor.id);
    if (mounted) setState(() => _loadingSlots = false);
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.advisor;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title:
            Text(a.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        bottom: TabBar(
            controller: _tabs,
            labelColor: AppColors.primaryLight,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.primaryLight,
            tabs: const [Tab(text: 'Profile'), Tab(text: 'Timeslots')]),
      ),
      body: TabBarView(controller: _tabs, children: [
        // Profile
        SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryLight]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(children: [
                  CircleAvatar(
                      radius: 44,
                      backgroundColor: Colors.white24,
                      backgroundImage:
                          a.photoUrl != null ? NetworkImage(a.photoUrl!) : null,
                      child: a.photoUrl == null
                          ? Text(a.name[0].toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white))
                          : null),
                  const SizedBox(height: 12),
                  Text(a.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800)),
                  if (a.designation != null)
                    Text(a.designation!,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                  if (a.rating != null)
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.star_rounded,
                          color: Color(0xFFF59E0B), size: 16),
                      Text(
                          ' ${a.rating!.toStringAsFixed(1)} - ${a.reviewCount ?? 0} reviews',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12))
                    ]),
                ]),
              ),
              const SizedBox(height: 14),
              Container(
                  padding: const EdgeInsets.all(16),
                  decoration: _cardDeco(),
                  child: Column(children: [
                    _infoRow(Icons.email_outlined, 'Email', a.email),
                    if (a.yearsOfExperience != null)
                      _infoRow(Icons.workspace_premium_outlined, 'Experience',
                          '${a.yearsOfExperience!.toStringAsFixed(1)} years'),
                    if (a.slotsDuration != null)
                      _infoRow(Icons.timer_outlined, 'Slot Duration',
                          '${a.slotsDuration} mins'),
                    if (a.charges != null)
                      _infoRow(Icons.currency_rupee_rounded, 'Session Fee',
                          'Rs ${_normalizeSessionFee(a.charges).toStringAsFixed(0)}'),
                    if (a.shiftDisplay.isNotEmpty)
                      _infoRow(Icons.access_time_rounded, 'Working Hours',
                          a.shiftDisplay),
                    _infoRow(Icons.circle_rounded, 'Status',
                        a.isActive ? 'Active' : 'Inactive',
                        valueColor: a.isActive
                            ? const Color(0xFF059669)
                            : AppColors.textMuted),
                  ])),
              if (a.skills.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: _cardDeco(),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Skills', style: AppTextStyles.label),
                          const SizedBox(height: 10),
                          Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: a.skills
                                  .map((s) => Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                          color: AppColors.primaryLight
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(20)),
                                      child: Text(s,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.primaryLight,
                                              fontWeight: FontWeight.w600))))
                                  .toList()),
                        ])),
              ],
            ])),

        // Slots
        _loadingSlots
            ? const Center(child: CircularProgressIndicator())
            : _slots.isEmpty
                ? const EmptyState(
                    icon: Icons.schedule_outlined,
                    title: 'No timeslots configured')
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 1.6),
                    itemCount: _slots.length,
                    itemBuilder: (_, i) {
                      final s = _slots[i];
                      final color = s.status == 'AVAILABLE'
                          ? const Color(0xFF059669)
                          : s.status == 'BOOKED'
                              ? AppColors.primaryLight
                              : AppColors.textMuted;
                      return Container(
                        decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: color.withValues(alpha: 0.3))),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                      color: color, shape: BoxShape.circle)),
                              const SizedBox(height: 4),
                              Text(s.timeRange,
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: color)),
                              Text(s.slotDate,
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: color.withValues(alpha: 0.7))),
                            ]),
                      );
                    },
                  ),
      ]),
    );
  }

  Widget _infoRow(IconData icon, String label, String value,
          {Color? valueColor}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Icon(icon, size: 17, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: AppTextStyles.caption),
            Text(value,
                style: AppTextStyles.label
                    .copyWith(color: valueColor ?? AppColors.textPrimary)),
          ]),
        ]),
      );
}

class _AdvisorForm extends StatefulWidget {
  final ConsultantModel? advisor;
  final VoidCallback onSaved;
  const _AdvisorForm({required this.onSaved, this.advisor});
  @override
  State<_AdvisorForm> createState() => _AdvisorFormState();
}

class _AdvisorFormState extends State<_AdvisorForm> {
  final _nameC = TextEditingController(),
      _emailC = TextEditingController(),
      _desigC = TextEditingController(),
      _chargesC = TextEditingController(),
      _descC = TextEditingController(),
      _experienceC = TextEditingController(),
      _customSkillC = TextEditingController();
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0),
      _end = const TimeOfDay(hour: 18, minute: 0);
  int _slotDuration = 60;
  final List<String> _selectedSkills = [];
  bool _saving = false;
  String? _errorText;
  final _formKey = GlobalKey<FormState>();
  static const _designationExamples = [
    'Certified Financial Planner',
    'Investment Consultant',
    'Tax Consultant',
    'Insurance Planner',
    'Wealth Advisor'
  ];
  static const _skillSuggestions = [
    'Tax Planning',
    'Retirement Planning',
    'Mutual Funds',
    'Insurance',
    'Wealth Management',
    'Investment Planning',
    'Estate Planning',
    'Financial Goal Planning'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.advisor != null) {
      final a = widget.advisor!;
      _nameC.text = a.name;
      _emailC.text = a.email;
      _desigC.text = a.designation ?? '';
      _chargesC.text = _normalizeSessionFee(a.charges).toStringAsFixed(0);
      _descC.text = a.description ?? '';
      _experienceC.text = a.yearsOfExperience?.toStringAsFixed(1) ?? '';
      _slotDuration = a.slotsDuration ?? 60;
      _selectedSkills.addAll(a.skills);
      if (a.shiftStartTime != null)
        _start = TimeOfDay(
            hour: a.shiftStartTime!['hour'] ?? 9,
            minute: a.shiftStartTime!['minute'] ?? 0);
      if (a.shiftEndTime != null)
        _end = TimeOfDay(
            hour: a.shiftEndTime!['hour'] ?? 18,
            minute: a.shiftEndTime!['minute'] ?? 0);
    }
  }

  @override
  void dispose() {
    _nameC.dispose();
    _emailC.dispose();
    _desigC.dispose();
    _chargesC.dispose();
    _descC.dispose();
    _experienceC.dispose();
    _customSkillC.dispose();
    super.dispose();
  }

  String _fmt(TimeOfDay t) =>
      '${t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod}:${t.minute.toString().padLeft(2, '0')} ${t.period == DayPeriod.am ? 'AM' : 'PM'}';
  String _toApiTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  String _messageFromError(Object error) =>
      _apiError(error, fallback: 'Failed to save consultant details.');

  void _toggleSkill(String skill) {
    setState(() {
      if (_selectedSkills.contains(skill)) {
        _selectedSkills.remove(skill);
      } else {
        _selectedSkills.add(skill);
      }
      _errorText = null;
    });
  }

  void _addCustomSkill() {
    final raw = _customSkillC.text.trim();
    if (raw.isEmpty) return;
    final normalized = raw
        .split(' ')
        .where((word) => word.trim().isNotEmpty)
        .map((word) =>
            '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
        .join(' ');
    if (!_selectedSkills.contains(normalized)) {
      setState(() => _selectedSkills.add(normalized));
    }
    _customSkillC.clear();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSkills.isEmpty) {
      setState(() => _errorText = 'Please add at least one skill set.');
      return;
    }
    final startMinutes = (_start.hour * 60) + _start.minute;
    final endMinutes = (_end.hour * 60) + _end.minute;
    if (endMinutes <= startMinutes) {
      setState(() => _errorText = 'End time must be after the start time.');
      return;
    }

    setState(() {
      _saving = true;
      _errorText = null;
    });

    final data = {
      'name': _nameC.text.trim(),
      'email': _emailC.text.trim().toLowerCase(),
      'designation': _desigC.text.trim(),
      'charges': double.tryParse(_chargesC.text.trim()) ?? 0,
      'description': _descC.text.trim(),
      'shiftStartTime': _toApiTime(_start),
      'shiftEndTime': _toApiTime(_end),
      'skills': _selectedSkills,
      'yearsOfExperience': double.tryParse(_experienceC.text.trim()) ?? 0,
      'slotsDuration': _slotDuration,
    };

    try {
      bool ok;
      if (widget.advisor != null) {
        ok = await ConsultantService().updateProfile(
          widget.advisor!.id,
          data,
        );
      } else {
        ok = await ConsultantService().createConsultant(data);
      }

      if (!mounted) return;
      if (ok) {
        widget.onSaved();
      } else {
        setState(() => _errorText = 'Operation failed. Please try again.');
      }
    } catch (error) {
      if (mounted) setState(() => _errorText = _messageFromError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
          key: _formKey,
          child: SingleChildScrollView(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Expanded(
                      child: Text(
                          widget.advisor != null
                              ? 'Edit Consultant'
                              : 'Add New Consultant',
                          style: AppTextStyles.h3)),
                  IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context)),
                ]),
                const SizedBox(height: 16),
                TextFormField(
                    controller: _nameC,
                    decoration:
                        _inp('Full Name *', icon: Icons.person_outline_rounded),
                    validator: (v) => v?.isEmpty == true ? 'Required' : null),
                const SizedBox(height: 10),
                TextFormField(
                    controller: _emailC,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _inp('Email *', icon: Icons.email_outlined),
                    validator: (v) => v?.contains('@') == false
                        ? 'Valid email required'
                        : null),
                const SizedBox(height: 10),
                TextFormField(
                    controller: _desigC,
                    decoration:
                        _inp('Designation *', icon: Icons.work_outline_rounded),
                    validator: (v) => v?.isEmpty == true ? 'Required' : null),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _designationExamples
                      .map((example) => ActionChip(
                            label: Text(example,
                                style: const TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w600)),
                            backgroundColor: AppColors.surfaceVariant,
                            side: const BorderSide(color: AppColors.border),
                            onPressed: () =>
                                setState(() => _desigC.text = example),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 10),
                TextFormField(
                    controller: _chargesC,
                    keyboardType: TextInputType.number,
                    decoration: _inp('Session Fee (Rs) *',
                        icon: Icons.currency_rupee_rounded),
                    validator: (v) => v?.isEmpty == true ? 'Required' : null),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _experienceC,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: _inp('Experience (years) *',
                          icon: Icons.workspace_premium_outlined),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) return 'Required';
                        return double.tryParse(value!.trim()) == null
                            ? 'Invalid years'
                            : null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _slotDuration,
                      decoration:
                          _inp('Slot Duration *', icon: Icons.timer_outlined),
                      items: const [30, 45, 60, 90]
                          .map((value) => DropdownMenuItem<int>(
                              value: value, child: Text('$value mins')))
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _slotDuration = value ?? 60),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                TextFormField(
                    controller: _descC,
                    maxLines: 2,
                    decoration: _inp('Description (optional)',
                        icon: Icons.description_outlined)),
                const SizedBox(height: 14),
                Text('Working Hours', style: AppTextStyles.label),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                      child: GestureDetector(
                          onTap: () async {
                            final p = await showTimePicker(
                                context: context, initialTime: _start);
                            if (p != null) setState(() => _start = p);
                          },
                          child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                  color: AppColors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.border)),
                              child: Column(children: [
                                Text('Start', style: AppTextStyles.caption),
                                Text(_fmt(_start),
                                    style: AppTextStyles.label.copyWith(
                                        color: AppColors.primaryLight))
                              ])))),
                  const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text('--',
                          style: TextStyle(color: AppColors.textMuted))),
                  Expanded(
                      child: GestureDetector(
                          onTap: () async {
                            final p = await showTimePicker(
                                context: context, initialTime: _end);
                            if (p != null) setState(() => _end = p);
                          },
                          child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                  color: AppColors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.border)),
                              child: Column(children: [
                                Text('End', style: AppTextStyles.caption),
                                Text(_fmt(_end),
                                    style: AppTextStyles.label.copyWith(
                                        color: AppColors.primaryLight))
                              ])))),
                ]),
                const SizedBox(height: 16),
                Text('Skill Set', style: AppTextStyles.label),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _skillSuggestions
                      .map((skill) => FilterChip(
                            label: Text(skill),
                            selected: _selectedSkills.contains(skill),
                            selectedColor:
                                AppColors.primaryLight.withValues(alpha: 0.12),
                            checkmarkColor: AppColors.primaryLight,
                            side: BorderSide(
                                color: _selectedSkills.contains(skill)
                                    ? AppColors.primaryLight
                                        .withValues(alpha: 0.35)
                                    : AppColors.border),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _selectedSkills.contains(skill)
                                  ? AppColors.primaryLight
                                  : AppColors.textSecondary,
                            ),
                            onSelected: (_) => _toggleSkill(skill),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _customSkillC,
                      decoration: _inp('Add custom skill',
                          icon: Icons.add_task_outlined),
                      onSubmitted: (_) => _addCustomSkill(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _addCustomSkill,
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryLight),
                    child: const Text('Add'),
                  ),
                ]),
                if (_selectedSkills.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectedSkills
                        .map((skill) => Chip(
                              label: Text(skill),
                              backgroundColor:
                                  AppColors.primaryLight.withValues(alpha: 0.1),
                              side: BorderSide(
                                  color: AppColors.primaryLight
                                      .withValues(alpha: 0.15)),
                              deleteIcon:
                                  const Icon(Icons.close_rounded, size: 16),
                              onDeleted: () => _toggleSkill(skill),
                            ))
                        .toList(),
                  ),
                ],
                if (_errorText != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.danger.withValues(alpha: 0.2)),
                    ),
                    child: Text(_errorText!,
                        style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                        onPressed: _saving ? null : _submit,
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primaryLight,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14))),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : Text(
                                widget.advisor != null
                                    ? 'Save Changes'
                                    : 'Add Consultant',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15)))),
              ]))),
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// â”€â”€ 6. ANALYTICS TAB
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class _AnalyticsTab extends StatefulWidget {
  const _AnalyticsTab();
  @override
  State<_AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<_AnalyticsTab> {
  final _svc = AnalyticsService();
  DashboardAnalytics? _data;
  bool _loading = true;
  String _range = 'WEEKLY';
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
      _data = await _svc.getAnalyticsLegacy(period: _range);
    } catch (error) {
      debugPrint('Analytics load error: $error');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_data == null)
      return const EmptyState(
          icon: Icons.analytics_outlined, title: 'No analytics data');
    final d = _data!;
    final resRate =
        d.totalTickets > 0 ? (d.resolvedTickets * 100 / d.totalTickets) : 0.0;
    final kpiAspectRatio =
        MediaQuery.of(context).size.width < 430 ? 1.32 : 1.55;

    return RefreshIndicator(
        onRefresh: () => _load(),
        child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              // Period toggle
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                _pill('WEEKLY', '7 days'),
                const SizedBox(width: 8),
                _pill('MONTHLY', '30 days'),
              ]),
              const SizedBox(height: 14),

              // KPI
              GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: kpiAspectRatio,
                  children: [
                    _StatCard(
                        title: 'Total Tickets',
                        value: '${d.totalTickets}',
                        icon: Icons.confirmation_number_rounded,
                        color: AppColors.primaryLight),
                    _StatCard(
                        title: 'Resolved',
                        value: '${d.resolvedTickets}',
                        icon: Icons.check_circle_outline_rounded,
                        color: const Color(0xFF059669)),
                    _StatCard(
                        title: 'SLA Breaches',
                        value: '${d.slaBreaches}',
                        icon: Icons.timer_off_rounded,
                        color: const Color(0xFFDC2626)),
                    _StatCard(
                        title: 'Avg Rating',
                        value: d.avgRating > 0
                            ? d.avgRating.toStringAsFixed(1)
                            : '--',
                        icon: Icons.star_rounded,
                        color: const Color(0xFFF59E0B)),
                  ]),
              const SizedBox(height: 14),

              // Resolution rate
              if (d.totalTickets > 0)
                Container(
                    padding: const EdgeInsets.all(16),
                    decoration: _cardDeco(),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Resolution Rate',
                                    style: AppTextStyles.h4),
                                Text('${resRate.round()}%',
                                    style: const TextStyle(
                                        color: Color(0xFF059669),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 22))
                              ]),
                          const SizedBox(height: 10),
                          ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                  value: (d.resolvedTickets / d.totalTickets)
                                      .clamp(0, 1),
                                  backgroundColor: const Color(0xFF059669)
                                      .withValues(alpha: 0.1),
                                  valueColor: const AlwaysStoppedAnimation(
                                      Color(0xFF059669)),
                                  minHeight: 10)),
                        ])),
              const SizedBox(height: 14),

              // Pie: by status
              if (d.ticketsByStatus.isNotEmpty)
                _chartCard(
                  'Tickets by Status',
                  legend: d.ticketsByStatus.entries
                      .map((e) => _LegendItem(
                          label: e.key,
                          color: getStatusColor(e.key),
                          value: e.value))
                      .toList(),
                  child: SizedBox(
                      height: 190,
                      child: PieChart(PieChartData(
                        sections: d.ticketsByStatus.entries
                            .map((e) => PieChartSectionData(
                                value: e.value.toDouble(),
                                title: '${e.value}',
                                color: getStatusColor(e.key),
                                radius: 60,
                                titleStyle: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)))
                            .toList(),
                        sectionsSpace: 2,
                        centerSpaceRadius: 42,
                      ))),
                ),
              const SizedBox(height: 14),

              // Bar: by priority
              if (d.ticketsByPriority.isNotEmpty)
                _chartCard(
                  'Tickets by Priority',
                  child: SizedBox(
                      height: 190,
                      child: BarChart(BarChartData(
                        borderData: FlBorderData(show: false),
                        gridData: const FlGridData(show: false),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (v, _) {
                                    final p = d.ticketsByPriority.keys.toList();
                                    if (v.toInt() < p.length)
                                      return Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: Text(
                                              p[v.toInt()].substring(0, 1),
                                              style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight:
                                                      FontWeight.bold)));
                                    return const SizedBox.shrink();
                                  })),
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
                            .map((e) => BarChartGroupData(x: e.key, barRods: [
                                  BarChartRodData(
                                      toY: e.value.value.toDouble(),
                                      color: getPriorityColor(e.value.key),
                                      width: 32,
                                      borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(8)))
                                ]))
                            .toList(),
                      ))),
                ),
              const SizedBox(height: 14),

              // Response times
              Container(
                  padding: const EdgeInsets.all(16),
                  decoration: _cardDeco(),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Response Times', style: AppTextStyles.h4),
                        const SizedBox(height: 16),
                        _timeBar('Avg First Response', d.avgResponseTime,
                            AppColors.info),
                        const SizedBox(height: 12),
                        _timeBar('Avg Resolution Time', d.avgResolutionTime,
                            const Color(0xFF059669)),
                      ])),
              const SizedBox(height: 14),

              // Agent performance
              _AgentPerformance(range: _range),
            ]));
  }

  Widget _pill(String v, String label) => GestureDetector(
        onTap: () {
          setState(() => _range = v);
          _load();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
              color: _range == v
                  ? AppColors.primaryLight
                  : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color:
                      _range == v ? AppColors.primaryLight : AppColors.border)),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _range == v ? Colors.white : AppColors.textSecondary)),
        ),
      );

  Widget _chartCard(String title,
          {required Widget child, List<_LegendItem>? legend}) =>
      Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDeco(),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: AppTextStyles.h4),
            const SizedBox(height: 16),
            child,
            if (legend != null) ...[
              const SizedBox(height: 12),
              Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: legend
                      .map(
                          (l) => Row(mainAxisSize: MainAxisSize.min, children: [
                                Container(
                                    width: 9,
                                    height: 9,
                                    decoration: BoxDecoration(
                                        color: l.color,
                                        shape: BoxShape.circle)),
                                const SizedBox(width: 4),
                                Text('${l.label} (${l.value})',
                                    style: AppTextStyles.caption)
                              ]))
                      .toList())
            ],
          ]));

  Widget _timeBar(String label, double hours, Color color) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: AppTextStyles.label),
          Text('${hours.toStringAsFixed(1)}h',
              style: TextStyle(color: color, fontWeight: FontWeight.w700))
        ]),
        const SizedBox(height: 6),
        ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
                value: (hours / 48).clamp(0, 1),
                backgroundColor: color.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 8)),
      ]);
}

class _AgentPerformance extends StatefulWidget {
  final String range;
  const _AgentPerformance({required this.range});
  @override
  State<_AgentPerformance> createState() => _AgentPerformanceState();
}

class _AgentPerformanceState extends State<_AgentPerformance> {
  List<_AgentStat> _stats = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_AgentPerformance old) {
    super.didUpdateWidget(old);
    if (old.range != widget.range) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await TicketService().getAllTickets(size: 200);
      final items = res.map((t) => t.toJson()).toList();
      final map = <String, _AgentStat>{};
      for (final t in items) {
        final name =
            t['agentName']?.toString() ?? t['consultantName']?.toString();
        if (name == null || name.isEmpty) continue;
        final cur = map[name] ??
            _AgentStat(
                name: name,
                assigned: 0,
                resolved: 0,
                totalMins: 0,
                resCount: 0);
        final s = (t['status'] ?? '').toString().toUpperCase();
        int newMins = cur.totalMins,
            newRes = cur.resolved,
            newResCount = cur.resCount;
        if (s == 'RESOLVED' || s == 'CLOSED') {
          newRes++;
          try {
            final dur = DateTime.parse(t['updatedAt'].toString())
                .difference(DateTime.parse(t['createdAt'].toString()))
                .inMinutes;
            newMins += dur;
            newResCount++;
          } catch (_) {}
        }
        map[name] = _AgentStat(
            name: name,
            assigned: cur.assigned + 1,
            resolved: newRes,
            totalMins: newMins,
            resCount: newResCount);
      }
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
        decoration: _cardDeco(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Agent Performance', style: AppTextStyles.h4),
          Text('Response & resolution by consultant',
              style: AppTextStyles.caption),
          const SizedBox(height: 14),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_stats.isEmpty)
            const Center(
                child: Text('No agent data',
                    style: TextStyle(color: AppColors.textMuted)))
          else
            Column(children: [
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
                        flex: 2,
                        child: Text('AVG TIME',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textSecondary,
                                letterSpacing: 0.5))),
                  ])),
              const SizedBox(height: 8),
              ..._stats.map((s) {
                final rate = s.assigned > 0
                    ? (s.resolved * 100 / s.assigned).round()
                    : 0;
                final avgMin =
                    s.resCount > 0 ? (s.totalMins / s.resCount).round() : 0;
                final avgStr = avgMin > 0
                    ? (avgMin >= 60
                        ? '${(avgMin / 60).toStringAsFixed(1)}h'
                        : '${avgMin}m')
                    : '--';
                final rateColor = rate >= 80
                    ? const Color(0xFF059669)
                    : rate >= 50
                        ? const Color(0xFFF97316)
                        : const Color(0xFFDC2626);
                return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(children: [
                      Expanded(
                          flex: 3,
                          child: Row(children: [
                            CircleAvatar(
                                radius: 13,
                                backgroundColor: AppColors.primaryLight
                                    .withValues(alpha: 0.1),
                                child: Text(s.name[0].toUpperCase(),
                                    style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primaryLight))),
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
                                  fontWeight: FontWeight.w700))),
                      Expanded(
                          flex: 1,
                          child: Text('${s.resolved}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: rateColor))),
                      Expanded(
                          flex: 2,
                          child: Text(avgStr,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary))),
                    ]));
              }),
            ]),
        ]),
      );
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// â”€â”€ 7. REPORTS TAB
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class _ReportsTab extends StatefulWidget {
  const _ReportsTab();
  @override
  State<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<_ReportsTab> {
  final _ts = TicketService();
  List<Ticket> _tickets = [];
  bool _loading = true;
  String _view = 'daily', _groupBy = 'status';
  final _palette = const [
    AppColors.primary,
    Color(0xFF7C3AED),
    Color(0xFF059669),
    Color(0xFFF97316),
    Color(0xFFDC2626),
    Color(0xFF0891B2)
  ];
  Timer? _pollTimer;

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
      _tickets = await _ts.getAllTickets(size: 500, useAnalytics: true);
    } catch (_) {
      _tickets = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  String _key(Ticket t) {
    if (_groupBy == 'priority') {
      return t.priority.isEmpty ? 'LOW' : t.priority;
    }
    if (_groupBy == 'category') {
      return t.category.isEmpty ? 'General' : t.category;
    }
    if (_groupBy == 'consultant') {
      final name = (t.consultantName ?? '').trim();
      return name.isEmpty ? 'Unassigned' : name;
    }
    return t.status;
  }

  List<String> get _periods {
    final now = DateTime.now();
    if (_view == 'daily')
      return List.generate(
          7,
          (i) =>
              DateFormat('d MMM').format(now.subtract(Duration(days: 6 - i))));
    return List.generate(8, (i) {
      final end = now.subtract(Duration(days: (7 - i) * 7));
      return DateFormat('d/M').format(end.subtract(const Duration(days: 6))) +
          '-' +
          DateFormat('d/M').format(end);
    });
  }

  bool _inPeriod(Ticket t, int pi) {
    try {
      if (t.createdAt == null) return false;
      final dt = DateTime.parse(t.createdAt!);
      final now = DateTime.now();
      if (_view == 'daily') {
        final target = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: 6 - pi));
        return DateTime(dt.year, dt.month, dt.day) == target;
      }
      final end = now.subtract(Duration(days: (7 - pi) * 7));
      final start = end.subtract(const Duration(days: 6));
      return dt.isAfter(start.subtract(const Duration(days: 1))) &&
          dt.isBefore(end.add(const Duration(days: 1)));
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final periods = _periods;
    final groups = <String>{};
    for (final t in _tickets) groups.add(_key(t));
    final gl = groups.toList()..sort();
    final bars = List.generate(periods.length, (pi) {
      final pt = _tickets.where((t) => _inPeriod(t, pi)).toList();
      return BarChartGroupData(
          x: pi,
          barRods: gl
              .asMap()
              .entries
              .map((e) => BarChartRodData(
                  toY: pt.where((t) => _key(t) == e.value).length.toDouble(),
                  color: _palette[e.key % _palette.length],
                  width: _view == 'daily' ? 9 : 6,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4))))
              .toList(),
          barsSpace: 2);
    });

    final total = _tickets.length,
        resolved = _tickets
            .where((t) => t.status == 'RESOLVED' || t.status == 'CLOSED')
            .length,
        open = _tickets
            .where((t) =>
                ['NEW', 'OPEN', 'IN_PROGRESS', 'PENDING'].contains(t.status))
            .length;

    return RefreshIndicator(
        onRefresh: () => _load(),
        child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.1,
                  children: [
                    _scard('Total', '$total', AppColors.primaryLight),
                    _scard('Open', '$open', const Color(0xFFF97316)),
                    _scard('Resolved', '$resolved', const Color(0xFF059669)),
                    _scard(
                        'Rate',
                        total > 0
                            ? '${(resolved * 100 / total).round()}%'
                            : '--',
                        AppColors.info),
                  ]),
              const SizedBox(height: 16),
              Container(
                  padding: const EdgeInsets.all(16),
                  decoration: _cardDeco(),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                              child: Text('Ticket Volume',
                                  style: AppTextStyles.h4)),
                          Text(
                              _view == 'daily' ? 'Last 7 days' : 'Last 8 weeks',
                              style: AppTextStyles.caption)
                        ]),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                              child: _toggle('Daily', _view == 'daily',
                                  () => setState(() => _view = 'daily'))),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _toggle('Weekly', _view == 'weekly',
                                  () => setState(() => _view = 'weekly'))),
                        ]),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: _groupBy,
                          decoration:
                              _inp('Group By', icon: Icons.tune_rounded),
                          items: const [
                            DropdownMenuItem(
                                value: 'status', child: Text('By Status')),
                            DropdownMenuItem(
                                value: 'priority', child: Text('By Priority')),
                            DropdownMenuItem(
                                value: 'category', child: Text('By Category')),
                            DropdownMenuItem(
                                value: 'consultant',
                                child: Text('By Consultant')),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _groupBy = v);
                          },
                        ),
                        const SizedBox(height: 16),
                        if (_tickets.isEmpty)
                          const EmptyState(
                              icon: Icons.bar_chart_outlined,
                              title: 'No ticket data')
                        else
                          SizedBox(
                              height: 220,
                              child: BarChart(BarChartData(
                                borderData: FlBorderData(show: false),
                                gridData: FlGridData(
                                    show: true,
                                    drawVerticalLine: false,
                                    getDrawingHorizontalLine: (_) =>
                                        const FlLine(
                                            color: AppColors.border,
                                            strokeWidth: 0.5)),
                                titlesData: FlTitlesData(
                                  bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 28,
                                          getTitlesWidget: (v, _) {
                                            final i = v.toInt();
                                            if (i < 0 || i >= periods.length)
                                              return const SizedBox.shrink();
                                            return Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 4),
                                                child: Text(periods[i],
                                                    style: const TextStyle(
                                                        fontSize: 8,
                                                        color: AppColors
                                                            .textMuted)));
                                          })),
                                  leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 22,
                                          getTitlesWidget: (v, _) {
                                            if (v % 1 != 0)
                                              return const SizedBox.shrink();
                                            return Text('${v.toInt()}',
                                                style: const TextStyle(
                                                    fontSize: 9,
                                                    color:
                                                        AppColors.textMuted));
                                          })),
                                  rightTitles: const AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                  topTitles: const AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                ),
                                barGroups: bars,
                              ))),
                        if (gl.isNotEmpty && _tickets.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                              spacing: 12,
                              runSpacing: 6,
                              children: gl
                                  .asMap()
                                  .entries
                                  .map((e) => Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                                width: 9,
                                                height: 9,
                                                decoration: BoxDecoration(
                                                    color: _palette[e.key %
                                                        _palette.length],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            2))),
                                            const SizedBox(width: 5),
                                            Text(e.value,
                                                style: AppTextStyles.caption),
                                            const SizedBox(width: 3),
                                            Text(
                                                '(${_tickets.where((t) => _key(t) == e.value).length})',
                                                style: AppTextStyles.caption
                                                    .copyWith(
                                                        color: AppColors
                                                            .textMuted))
                                          ]))
                                  .toList())
                        ],
                      ])),
            ]));
  }

  Widget _scard(String label, String value, Color color) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800, color: color)),
            Text(label,
                style:
                    const TextStyle(fontSize: 11, color: AppColors.textMuted))
          ]));

  Widget _toggle(String label, bool active, VoidCallback onTap) =>
      GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                  color: active
                      ? AppColors.primaryLight
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10)),
              child: Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color:
                          active ? Colors.white : AppColors.textSecondary))));
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// â”€â”€ 8. OFFERS TAB
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class _OffersTab extends StatefulWidget {
  const _OffersTab();
  @override
  State<_OffersTab> createState() => _OffersTabState();
}

class _OffersTabState extends State<_OffersTab> {
  List<Map<String, dynamic>> _offers = [];
  bool _loading = true;
  Timer? _pollTimer;

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
      _offers = await OfferService().getAllOffersAdmin();
    } catch (_) {
      _offers = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Text('Delete Offer?'),
              content: const Text('This cannot be undone.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626)),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Delete'))
              ],
            ));
    if (ok != true) return;
    try {
      final success = await OfferService().deleteOffer(id);
      if (success) {
        _snack(context, 'Offer deleted');
        _load();
      } else {
        _snack(context, 'Delete failed', error: true);
      }
    } catch (_) {
      _snack(context, 'Delete failed', error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openForm(),
            backgroundColor: AppColors.primaryLight,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('New Offer',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700))),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _offers.isEmpty
                ? const EmptyState(
                    icon: Icons.local_offer_outlined,
                    title: 'No offers yet',
                    subtitle: 'Tap + to create the first offer')
                : RefreshIndicator(
                    onRefresh: () => _load(),
                    child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        itemCount: _offers.length,
                        itemBuilder: (_, i) {
                          final o = _offers[i];
                          final status = (o['status'] ?? 'PENDING')
                              .toString()
                              .toUpperCase();
                          final statusColor = status == 'APPROVED'
                              ? const Color(0xFF059669)
                              : status == 'REJECTED'
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFFF97316);
                          final isActive =
                              o['isActive'] == true || o['active'] == true;
                          return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: _cardDeco(),
                              child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(children: [
                                          Expanded(
                                              child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                Text(o['title'] ?? '',
                                                    style: AppTextStyles.h4),
                                                if (o['description'] != null)
                                                  Text(o['description'],
                                                      style:
                                                          AppTextStyles.caption,
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis)
                                              ])),
                                          if (o['discount'] != null)
                                            Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 4),
                                                decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFFDC2626),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20)),
                                                child: Text(
                                                    o['discount'].toString(),
                                                    style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w800))),
                                        ]),
                                        const SizedBox(height: 10),
                                        Wrap(
                                            spacing: 8,
                                            runSpacing: 6,
                                            children: [
                                              _chip(status, statusColor),
                                              _chip(
                                                  isActive
                                                      ? 'Active'
                                                      : 'Inactive',
                                                  isActive
                                                      ? const Color(0xFF059669)
                                                      : AppColors.textMuted),
                                              if (o['validFrom'] != null)
                                                _chip(
                                                    'From ${_fmtDate(o['validFrom'])}',
                                                    AppColors.info),
                                              if (o['validTo'] != null)
                                                _chip(
                                                    'Until ${_fmtDate(o['validTo'])}',
                                                    const Color(0xFFF97316)),
                                            ]),
                                        const SizedBox(height: 10),
                                        Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              TextButton.icon(
                                                  onPressed: () => _openForm(o),
                                                  icon: const Icon(
                                                      Icons.edit_outlined,
                                                      size: 15),
                                                  label: const Text('Edit'),
                                                  style: TextButton.styleFrom(
                                                      foregroundColor: AppColors
                                                          .primaryLight,
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 10))),
                                              TextButton.icon(
                                                  onPressed: () =>
                                                      _delete(o['id']),
                                                  icon: const Icon(
                                                      Icons
                                                          .delete_outline_rounded,
                                                      size: 15),
                                                  label: const Text('Delete'),
                                                  style: TextButton.styleFrom(
                                                      foregroundColor:
                                                          const Color(
                                                              0xFFDC2626),
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 10))),
                                            ]),
                                      ])));
                        })),
      );

  void _openForm([Map<String, dynamic>? o]) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _OfferForm(
          offer: o,
          onSaved: () {
            Navigator.pop(context);
            _load();
          }));
}

class _OfferForm extends StatefulWidget {
  final Map<String, dynamic>? offer;
  final VoidCallback onSaved;
  const _OfferForm({this.offer, required this.onSaved});
  @override
  State<_OfferForm> createState() => _OfferFormState();
}

class _OfferFormState extends State<_OfferForm> {
  final _titleC = TextEditingController(),
      _descC = TextEditingController(),
      _discC = TextEditingController();
  bool _isActive = true, _saving = false;
  String? _validFrom, _validTo;
  List<ConsultantModel> _consultants = [];
  int? _selectedConsultantId;
  bool _loadingConsultants = true;

  @override
  void initState() {
    super.initState();
    final o = widget.offer;
    if (o != null) {
      _titleC.text = o['title'] ?? '';
      _descC.text = o['description'] ?? '';
      _discC.text = o['discount'] ?? '';
      _isActive = o['isActive'] == true || o['active'] == true;
      _validFrom = o['validFrom']?.toString().substring(0, 10);
      _validTo = o['validTo']?.toString().substring(0, 10);
      _selectedConsultantId = _toInt(o['consultantId']);
    }
    _loadConsultants();
  }

  @override
  void dispose() {
    _titleC.dispose();
    _descC.dispose();
    _discC.dispose();
    super.dispose();
  }

  Future<void> _loadConsultants() async {
    final consultants = await ConsultantService().getAllConsultants();
    consultants
        .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (!mounted) return;
    setState(() {
      _consultants = consultants;
      if (_selectedConsultantId != null &&
          !_consultants
              .any((consultant) => consultant.id == _selectedConsultantId)) {
        _selectedConsultantId = null;
      }
      _loadingConsultants = false;
    });
  }

  Future<void> _pickDate(bool isFrom) async {
    final p = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(
            (isFrom ? _validFrom : _validTo) ?? '',
          ) ??
          DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primaryLight,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: AppColors.textPrimary,
          ),
          datePickerTheme: DatePickerThemeData(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            headerBackgroundColor:
                AppColors.primaryLight.withValues(alpha: 0.08),
            headerForegroundColor: AppColors.textPrimary,
            dayShape: MaterialStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        child: child!,
      ),
    );
    if (p != null)
      setState(() {
        if (isFrom)
          _validFrom = DateFormat('yyyy-MM-dd').format(p);
        else
          _validTo = DateFormat('yyyy-MM-dd').format(p);
      });
  }

  Future<void> _save() async {
    if (_titleC.text.trim().isEmpty) {
      _snack(context, 'Title required', error: true);
      return;
    }
    if (_discC.text.trim().isEmpty) {
      _snack(context, 'Discount is required', error: true);
      return;
    }
    if (_validFrom == null || _validTo == null) {
      _snack(context, 'Both dates required', error: true);
      return;
    }
    setState(() => _saving = true);
    final payload = {
      'title': _titleC.text.trim(),
      'description': _descC.text.trim(),
      'discount': _discC.text.trim(),
      'active': _isActive,
      'validFrom': '${_validFrom}T00:00:00',
      'validTo': '${_validTo}T23:59:59',
      if (_selectedConsultantId != null) 'consultantId': _selectedConsultantId,
    };
    try {
      final id = widget.offer?['id'];
      bool success;
      if (id != null)
        success = await OfferService().updateOffer(id, payload);
      else
        success = await OfferService().createOffer(payload);

      if (success)
        widget.onSaved();
      else
        _snack(context, 'Save failed', error: true);
    } catch (_) {
      if (mounted) _snack(context, 'Save failed', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24),
        child: SingleChildScrollView(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(children: [
                Expanded(
                    child: Text(
                        widget.offer != null ? 'Edit Offer' : 'New Offer',
                        style: AppTextStyles.h3)),
                IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context))
              ]),
              const SizedBox(height: 16),
              TextField(
                  controller: _titleC,
                  decoration:
                      _inp('Offer title *', icon: Icons.local_offer_outlined)),
              const SizedBox(height: 10),
              TextField(
                  controller: _descC,
                  decoration: _inp('Description'),
                  maxLines: 2),
              const SizedBox(height: 10),
              TextField(
                  controller: _discC,
                  decoration: _inp('Discount badge (e.g. 20% OFF)',
                      icon: Icons.percent_rounded)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: _datePick(
                        'Valid From', _validFrom, () => _pickDate(true))),
                const SizedBox(width: 10),
                Expanded(
                    child: _datePick(
                        'Valid Until', _validTo, () => _pickDate(false))),
              ]),
              const SizedBox(height: 10),
              DropdownButtonFormField<int?>(
                value: _consultants.any(
                  (consultant) => consultant.id == _selectedConsultantId,
                )
                    ? _selectedConsultantId
                    : null,
                isExpanded: true,
                decoration: _inp('Consultant (optional)',
                    icon: Icons.person_outline_rounded),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('All Consultants'),
                  ),
                  ..._consultants.map(
                    (consultant) => DropdownMenuItem<int?>(
                      value: consultant.id,
                      child: Text(consultant.name,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: _loadingConsultants
                    ? null
                    : (value) => setState(() => _selectedConsultantId = value),
              ),
              const SizedBox(height: 6),
              Text(
                _loadingConsultants
                    ? 'Loading consultant names...'
                    : 'Choose a consultant to target a specific offer, or keep it global.',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                  title: const Text('Active (visible to customers)'),
                  activeThumbColor: const Color(0xFF059669),
                  contentPadding: EdgeInsets.zero),
              const SizedBox(height: 16),
              SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryLight,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14))),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text(
                              widget.offer != null
                                  ? 'Update Offer'
                                  : 'Create Offer',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15)))),
            ])),
      );

  Widget _datePick(String label, String? date, VoidCallback onTap) =>
      GestureDetector(
          onTap: onTap,
          child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white,
                      AppColors.surfaceVariant,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppTextStyles.caption),
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.calendar_month_outlined,
                          color: AppColors.textSecondary, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(
                              date != null ? _fmtDate(date) : 'Select date',
                              style: date != null
                                  ? AppTextStyles.label
                                      .copyWith(color: AppColors.primaryLight)
                                  : AppTextStyles.caption))
                    ]),
                  ])));
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// â”€â”€ 9. OFFER APPROVALS TAB
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class _OfferApprovalsTab extends StatefulWidget {
  const _OfferApprovalsTab();
  @override
  State<_OfferApprovalsTab> createState() => _OfferApprovalsTabState();
}

class _OfferApprovalsTabState extends State<_OfferApprovalsTab> {
  List<Map<String, dynamic>> _offers = [];
  bool _loading = true;
  int? _processing;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _pollTimer =
        Timer.periodic(const Duration(seconds: 15), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final all = await OfferService().getAllOffersAdmin();
      _offers = all
          .where((o) =>
              (o['status'] ?? 'PENDING').toString().toUpperCase() == 'PENDING')
          .toList();
    } catch (_) {
      _offers = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _action(int id, String action) async {
    setState(() => _processing = id);
    final status = action == 'approve' ? 'APPROVED' : 'REJECTED';
    try {
      await OfferService().updateStatus(id, status);
      _snack(context, 'Offer ${status.toLowerCase()}',
          icon: action == 'approve'
              ? Icons.check_circle_outline_rounded
              : Icons.cancel_outlined);
      _load();
    } catch (_) {
      _snack(context, 'Action failed', error: true);
    } finally {
      if (mounted) setState(() => _processing = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
            title: const Text('Offer Approvals',
                style: TextStyle(
                    color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
            backgroundColor: AppColors.surface,
            iconTheme: const IconThemeData(color: AppColors.textPrimary),
            actions: [
              IconButton(
                  icon: const Icon(Icons.refresh_rounded), onPressed: _load)
            ]),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _offers.isEmpty
                ? const EmptyState(
                    icon: Icons.task_alt_rounded,
                    title: 'No pending approvals',
                    subtitle: 'All offers have been reviewed')
                : RefreshIndicator(
                    onRefresh: () => _load(),
                    child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _offers.length,
                        itemBuilder: (_, i) {
                          final o = _offers[i];
                          final id = o['id'] as int;
                          final busy = _processing == id;
                          return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration:
                                  _cardDeco(border: const Color(0xFFFDE68A)),
                              child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(children: [
                                          Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                  color: const Color(0xFFF97316)
                                                      .withValues(alpha: 0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          10)),
                                              child: const Icon(
                                                  Icons.pending_outlined,
                                                  color: Color(0xFFF97316),
                                                  size: 18)),
                                          const SizedBox(width: 12),
                                          Expanded(
                                              child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                Text(o['title'] ?? '',
                                                    style: AppTextStyles.h4),
                                                if (o['discount'] != null)
                                                  Text(
                                                      'Discount: ${o['discount']}',
                                                      style:
                                                          AppTextStyles.caption)
                                              ])),
                                          _chip('PENDING',
                                              const Color(0xFFF97316)),
                                        ]),
                                        if (o['description'] != null &&
                                            (o['description'] as String)
                                                .isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(o['description'],
                                              style: AppTextStyles.bodySmall)
                                        ],
                                        const SizedBox(height: 14),
                                        Row(children: [
                                          Expanded(
                                              child: OutlinedButton.icon(
                                            onPressed: busy
                                                ? null
                                                : () => _action(id, 'reject'),
                                            icon: const Icon(
                                                Icons.close_rounded,
                                                size: 16),
                                            label: const Text('Reject'),
                                            style: OutlinedButton.styleFrom(
                                                foregroundColor:
                                                    const Color(0xFFDC2626),
                                                side: const BorderSide(
                                                    color: Color(0xFFDC2626)),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10)),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 10)),
                                          )),
                                          const SizedBox(width: 10),
                                          Expanded(
                                              child: FilledButton.icon(
                                            onPressed: busy
                                                ? null
                                                : () => _action(id, 'approve'),
                                            icon: busy
                                                ? const SizedBox(
                                                    width: 14,
                                                    height: 14,
                                                    child:
                                                        CircularProgressIndicator(
                                                            color: Colors.white,
                                                            strokeWidth: 2))
                                                : const Icon(
                                                    Icons.check_rounded,
                                                    size: 16),
                                            label: Text(busy
                                                ? 'Processing...'
                                                : 'Approve'),
                                            style: FilledButton.styleFrom(
                                                backgroundColor:
                                                    const Color(0xFF059669),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10)),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 10)),
                                          )),
                                        ]),
                                      ])));
                        })),
      );
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// â”€â”€ 10. SKILLS & QUESTIONS TAB
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class _SkillsQuestionsTab extends StatefulWidget {
  const _SkillsQuestionsTab();
  @override
  State<_SkillsQuestionsTab> createState() => _SkillsQuestionsTabState();
}

class _SkillsQuestionsTabState extends State<_SkillsQuestionsTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Map<String, dynamic>> _skills = [], _questions = [];
  bool _loadingSkills = true, _loadingQuestions = true;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadSkills();
    _loadQuestions();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadSkills(silent: true);
      _loadQuestions(silent: true);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadSkills({bool silent = false}) async {
    if (!silent) setState(() => _loadingSkills = true);
    try {
      _skills = await QuestionService().getAllSkills();
    } catch (_) {
      _skills = [];
    }
    if (mounted) setState(() => _loadingSkills = false);
  }

  Future<void> _loadQuestions({bool silent = false}) async {
    if (!silent) setState(() => _loadingQuestions = true);
    try {
      _questions = await QuestionService().getAllQuestions();
    } catch (_) {
      _questions = [];
    }
    if (mounted) setState(() => _loadingQuestions = false);
  }

  String _normalizedKey(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  bool _questionExists(String text, String type) {
    final normalizedText = _normalizedKey(text);
    final normalizedType = _normalizedKey(type);
    return _questions.any((item) {
      final existingText = _normalizedKey((item['text'] ?? '').toString());
      final existingType = _normalizedKey((item['type'] ?? 'TEXT').toString());
      return existingText == normalizedText && existingType == normalizedType;
    });
  }

  void _addSkill() {
    final ctrl = TextEditingController();
    var saving = false;
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => StatefulBuilder(
              builder: (ctx, ss) => Padding(
                padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 20,
                    bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Add Skill', style: AppTextStyles.h3),
                      const SizedBox(height: 16),
                      TextField(
                        controller: ctrl,
                        style: const TextStyle(color: AppColors.textPrimary),
                        cursorColor: AppColors.primaryLight,
                        decoration: _inp('Skill name *',
                            icon: Icons.psychology_rounded),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton(
                            onPressed: saving
                                ? null
                                : () async {
                                    final name = ctrl.text.trim();
                                    if (name.isEmpty) return;
                                    final exists = _skills.any((skill) =>
                                        _normalizedKey((skill['skillName'] ??
                                                    skill['name'] ??
                                                    '')
                                                .toString()) ==
                                        _normalizedKey(name));
                                    if (exists) {
                                      _snack(ctx, 'Skill already exists',
                                          error: true);
                                      return;
                                    }
                                    ss(() => saving = true);
                                    try {
                                      final success = await QuestionService()
                                          .createSkill(name);
                                      if (success && mounted) {
                                        Navigator.pop(ctx);
                                        _loadSkills();
                                      } else if (mounted) {
                                        _snack(context, 'Save failed',
                                            error: true);
                                      }
                                    } catch (error) {
                                      if (mounted) {
                                        _snack(
                                          context,
                                          _apiError(error,
                                              fallback: 'Save failed'),
                                          error: true,
                                        );
                                      }
                                    } finally {
                                      if (ctx.mounted) {
                                        ss(() => saving = false);
                                      }
                                    }
                                  },
                            child: saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Add Skill'),
                          )),
                    ]),
              ),
            ));
  }

  void _deleteSkill(int id) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
                title: const Text('Delete Skill?'),
                content: const Text(
                    'Questions are managed separately and will stay available.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626)),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete'))
                ]));
    if (ok == true) {
      try {
        final success = await QuestionService().deleteSkill(id);
        if (success)
          _loadSkills();
        else if (mounted) _snack(context, 'Delete failed', error: true);
      } catch (error) {
        if (mounted)
          _snack(context, _apiError(error, fallback: 'Delete failed'),
              error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
            title: const Text('Skills & Questions',
                style: TextStyle(
                    color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
            backgroundColor: AppColors.surface,
            iconTheme: const IconThemeData(color: AppColors.textPrimary),
            actions: [
              IconButton(
                  icon: const Icon(Icons.add_rounded),
                  onPressed: () {
                    if (_tabs.index == 0)
                      _addSkill();
                    else
                      _addQuestion();
                  }),
              IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () {
                    _loadSkills();
                    _loadQuestions();
                  }),
            ],
            bottom: TabBar(
                controller: _tabs,
                labelColor: AppColors.primaryLight,
                unselectedLabelColor: AppColors.textMuted,
                indicatorColor: AppColors.primaryLight,
                tabs: const [Tab(text: 'Skills'), Tab(text: 'Questions')])),
        body: TabBarView(controller: _tabs, children: [
          // Skills
          _loadingSkills
              ? const Center(child: CircularProgressIndicator())
              : _skills.isEmpty
                  ? const EmptyState(
                      icon: Icons.psychology_outlined, title: 'No skills added')
                  : RefreshIndicator(
                      onRefresh: () => _loadSkills(),
                      child: ListView.builder(
                          padding: const EdgeInsets.all(14),
                          itemCount: _skills.length,
                          itemBuilder: (_, i) {
                            final s = _skills[i];
                            return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: _cardDeco(),
                                child: ListTile(
                                  leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                          color: AppColors.primaryLight
                                              .withValues(alpha: 0.1),
                                          shape: BoxShape.circle),
                                      child: const Icon(
                                          Icons.psychology_rounded,
                                          color: AppColors.primaryLight,
                                          size: 18)),
                                  title: Text(s['skillName'] ?? s['name'] ?? '',
                                      style: AppTextStyles.h4),
                                  trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (s['active'] == true)
                                          Container(
                                              width: 7,
                                              height: 7,
                                              decoration: const BoxDecoration(
                                                  color: Color(0xFF059669),
                                                  shape: BoxShape.circle)),
                                        const SizedBox(width: 8),
                                        IconButton(
                                            icon: const Icon(
                                                Icons.delete_outline_rounded,
                                                color: Color(0xFFDC2626),
                                                size: 18),
                                            onPressed: () =>
                                                _deleteSkill(s['id'])),
                                      ]),
                                ));
                          })),

          // Questions
          _loadingQuestions
              ? const Center(child: CircularProgressIndicator())
              : _questions.isEmpty
                  ? const EmptyState(
                      icon: Icons.quiz_outlined,
                      title: 'No questions',
                      subtitle: 'Add dynamic questions for members')
                  : RefreshIndicator(
                      onRefresh: () => _loadQuestions(),
                      child: ListView.builder(
                          padding: const EdgeInsets.all(14),
                          itemCount: _questions.length,
                          itemBuilder: (_, i) {
                            final q = _questions[i];
                            final rawType = (q['type'] ?? 'TEXT').toString();
                            final prettyType = rawType
                                .replaceAll('_', ' ')
                                .split(' ')
                                .map((part) => part.isEmpty
                                    ? ''
                                    : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
                                .join(' ');
                            final placeholder =
                                (q['placeholder'] ?? '').toString().trim();
                            final options = (q['options'] ?? '')
                                .toString()
                                .split(RegExp(r'[\n,]'))
                                .map((item) => item.trim())
                                .where((item) => item.isNotEmpty)
                                .toList();
                            return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: _cardDeco(),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                                width: 36,
                                                height: 36,
                                                decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFF7C3AED)
                                                            .withValues(
                                                                alpha: 0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12)),
                                                child: Center(
                                                    child: Text('Q${i + 1}',
                                                        style: const TextStyle(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                            color: Color(
                                                                0xFF7C3AED))))),
                                            const SizedBox(width: 12),
                                            Expanded(
                                                child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                  Text(
                                                      (q['text'] ?? '')
                                                          .toString(),
                                                      style: AppTextStyles.h4
                                                          .copyWith(
                                                              height: 1.35)),
                                                  const SizedBox(height: 8),
                                                  Wrap(
                                                      spacing: 8,
                                                      runSpacing: 8,
                                                      children: [
                                                        _chip(
                                                            prettyType.isEmpty
                                                                ? 'Text'
                                                                : prettyType,
                                                            const Color(
                                                                0xFF7C3AED)),
                                                        if (placeholder
                                                            .isNotEmpty)
                                                          _chip(
                                                              'Placeholder: $placeholder',
                                                              AppColors.info),
                                                        if (options.isNotEmpty)
                                                          _chip(
                                                              '${options.length} options',
                                                              const Color(
                                                                  0xFFF59E0B)),
                                                      ]),
                                                ])),
                                            IconButton(
                                                icon: const Icon(
                                                    Icons
                                                        .delete_outline_rounded,
                                                    color: Color(0xFFDC2626),
                                                    size: 18),
                                                onPressed: () async {
                                                  final ok = await showDialog<
                                                          bool>(
                                                      context: context,
                                                      builder: (_) =>
                                                          AlertDialog(
                                                              title: const Text(
                                                                  'Delete Question?'),
                                                              content: Text(
                                                                  '"${q['text'] ?? 'This question'}" will be deleted permanently.'),
                                                              actions: [
                                                                TextButton(
                                                                    onPressed: () =>
                                                                        Navigator.pop(
                                                                            context,
                                                                            false),
                                                                    child: const Text(
                                                                        'Cancel')),
                                                                FilledButton(
                                                                    style: FilledButton.styleFrom(
                                                                        backgroundColor:
                                                                            const Color(
                                                                                0xFFDC2626)),
                                                                    onPressed: () =>
                                                                        Navigator.pop(
                                                                            context,
                                                                            true),
                                                                    child: const Text(
                                                                        'Delete'))
                                                              ]));
                                                  if (ok != true) return;
                                                  try {
                                                    final success =
                                                        await QuestionService()
                                                            .deleteQuestion(
                                                                q['id']);
                                                    if (success)
                                                      _loadQuestions();
                                                    else if (mounted)
                                                      _snack(context,
                                                          'Delete failed',
                                                          error: true);
                                                  } catch (error) {
                                                    if (mounted)
                                                      _snack(
                                                          context,
                                                          _apiError(error,
                                                              fallback:
                                                                  'Delete failed'),
                                                          error: true);
                                                  }
                                                }),
                                          ]),
                                      if (options.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: options
                                                .map((item) => Chip(
                                                    label: Text(item),
                                                    backgroundColor: AppColors
                                                        .surfaceVariant,
                                                    side: const BorderSide(
                                                        color:
                                                            AppColors.border)))
                                                .toList()),
                                      ],
                                    ]));
                          })),
        ]),
      );

  void _addQuestion() {
    final ctrl = TextEditingController();
    final placeholderCtrl = TextEditingController();
    final optionsCtrl = TextEditingController();
    String type = 'TEXT';
    var saving = false;
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
                        Text('Add Question', style: AppTextStyles.h3),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                            initialValue: type,
                            decoration: _inp('Question type *',
                                icon: Icons.tune_rounded),
                            items: const [
                              DropdownMenuItem(
                                  value: 'TEXT', child: Text('Short Text')),
                              DropdownMenuItem(
                                  value: 'TEXTAREA', child: Text('Paragraph')),
                              DropdownMenuItem(
                                  value: 'MULTIPLE_CHOICE',
                                  child: Text('Multiple Choice'))
                            ],
                            onChanged: (v) => ss(() => type = v ?? 'TEXT')),
                        const SizedBox(height: 10),
                        TextField(
                            controller: ctrl,
                            maxLines: 2,
                            decoration: _inp('Question text *',
                                icon: Icons.quiz_outlined)),
                        const SizedBox(height: 10),
                        TextField(
                            controller: placeholderCtrl,
                            decoration: _inp(
                                type == 'MULTIPLE_CHOICE'
                                    ? 'Helper text (optional)'
                                    : 'Placeholder (optional)',
                                icon: Icons.short_text_rounded)),
                        if (type == 'MULTIPLE_CHOICE') ...[
                          const SizedBox(height: 10),
                          TextField(
                              controller: optionsCtrl,
                              maxLines: 4,
                              decoration: _inp('Options *',
                                  icon: Icons.list_alt_rounded,
                                  hint: 'One per line or comma separated')),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton(
                              onPressed: saving
                                  ? null
                                  : () async {
                                      final questionText = ctrl.text.trim();
                                      final options = optionsCtrl.text
                                          .split(RegExp(r'[\n,]'))
                                          .map((item) => item.trim())
                                          .where((item) => item.isNotEmpty)
                                          .toList();
                                      if (questionText.isEmpty) return;
                                      if (_questionExists(questionText, type)) {
                                        _snack(ctx,
                                            'This question already exists',
                                            error: true);
                                        return;
                                      }
                                      if (type == 'MULTIPLE_CHOICE' &&
                                          options.isEmpty) {
                                        _snack(ctx, 'Add at least one option',
                                            error: true);
                                        return;
                                      }
                                      ss(() => saving = true);
                                      try {
                                        final success = await QuestionService()
                                            .createQuestion({
                                          'text': questionText,
                                          'type': type,
                                          if (placeholderCtrl.text
                                              .trim()
                                              .isNotEmpty)
                                            'placeholder':
                                                placeholderCtrl.text.trim(),
                                          if (options.isNotEmpty)
                                            'options': options.join(', ')
                                        });
                                        if (success && mounted) {
                                          Navigator.pop(ctx);
                                          _loadQuestions();
                                        } else if (mounted) {
                                          _snack(ctx, 'Save failed',
                                              error: true);
                                        }
                                      } catch (error) {
                                        if (mounted) {
                                          _snack(
                                              ctx,
                                              _apiError(error,
                                                  fallback: 'Save failed'),
                                              error: true);
                                        }
                                      } finally {
                                        if (ctx.mounted) {
                                          ss(() => saving = false);
                                        }
                                      }
                                    },
                              child: saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('Add Question'),
                            )),
                      ])),
                )));
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// â”€â”€ 11. TERMS & CONDITIONS
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class _TermsTab extends StatefulWidget {
  const _TermsTab();
  @override
  State<_TermsTab> createState() => _TermsTabState();
}

class _TermsTabState extends State<_TermsTab> {
  static const _kLocalTermsVersions = 'fin_terms_versions';
  final _svc = StaticContentService();

  bool _loading = true;
  bool _editing = false;
  bool _saving = false;
  bool _preview = false;

  List<Map<String, dynamic>> _versions = [];
  int? _selectedVersionId;

  late TextEditingController _contentCtrl;
  late TextEditingController _versionCtrl;

  static const _default = '''### 1. Acceptance of Terms
By accessing and using Meet The Masters, you accept and agree to be bound by these Terms & Conditions.

### 2. Use of Services
Our platform provides access to certified financial consultants for lawful purposes only.

### 3. Confidentiality
All consultation sessions and related information are strictly confidential.

### 4. Booking & Payments
Bookings are confirmed upon successful payment. Cancellations must be made at least 24 hours prior.

### 5. Disclaimer
Financial advice provided is for informational purposes only and does not guarantee specific outcomes.

### 6. Privacy Policy
We collect and store your personal data securely in accordance with applicable data protection laws.

### 7. Governing Law
These Terms are governed by the laws of India, jurisdiction: Hyderabad, Telangana.''';

  @override
  void initState() {
    super.initState();
    _contentCtrl = TextEditingController();
    _versionCtrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    _versionCtrl.dispose();
    super.dispose();
  }

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? fallback;
  }

  String _pickString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  bool _pickBool(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is bool) return value;
      if (value is num) return value != 0;
      final raw = value?.toString().toLowerCase().trim();
      if (raw == 'true') return true;
      if (raw == 'false') return false;
    }
    return false;
  }

  Map<String, dynamic> _normalizeVersion(
    Map<String, dynamic> raw, {
    required int fallbackId,
  }) {
    final version = _pickString(raw, ['version', 'ver', 'revision']);
    final content = _pickString(raw, ['content', 'text', 'body', 'message']);
    return {
      ...raw,
      'id': _toInt(raw['id'] ?? raw['contentId'] ?? raw['termId'],
          fallback: fallbackId),
      'version': version.isNotEmpty ? version : '1.0',
      'content': content,
      'updatedAt': _pickString(raw, [
        'updatedAt',
        'lastUpdatedDate',
        'createdAt',
        'submittedAt',
      ]),
      'updatedBy': _pickString(raw, ['updatedBy', 'lastUpdatedBy', 'author']),
      'isActive': _pickBool(raw, ['isActive', 'active', 'isLive', 'published']),
    };
  }

  String _versionKey(Map<String, dynamic> item) {
    final id = _toInt(item['id']);
    if (id > 0) return 'id:$id';
    final ver = '${item['version'] ?? ''}'.trim();
    if (ver.isNotEmpty) return 'ver:$ver';
    final ts = '${item['updatedAt'] ?? ''}'.trim();
    if (ts.isNotEmpty) return 'ts:$ts';
    return 'random:${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<List<Map<String, dynamic>>> _readLocalVersions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kLocalTermsVersions);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeLocalVersions(List<Map<String, dynamic>> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLocalTermsVersions, jsonEncode(items));
    } catch (_) {
      // Best effort only.
    }
  }

  List<Map<String, dynamic>> _mergeVersions(
    List<Map<String, dynamic>> local,
    List<Map<String, dynamic>> remote,
  ) {
    final merged = <String, Map<String, dynamic>>{};

    void upsert(List<Map<String, dynamic>> source) {
      for (var i = 0; i < source.length; i++) {
        final normalized = _normalizeVersion(source[i], fallbackId: i + 1);
        final text = '${normalized['content'] ?? ''}'.trim();
        if (text.isEmpty) continue;
        merged[_versionKey(normalized)] = normalized;
      }
    }

    upsert(local);
    upsert(remote);

    var list = merged.values.toList();
    if (list.isEmpty) {
      list = [
        {
          'id': 1,
          'version': '1.0',
          'content': _default,
          'updatedAt': DateTime.now().toIso8601String(),
          'updatedBy': 'Admin',
          'isActive': true,
        }
      ];
    }

    list.sort((a, b) => _toInt(a['id']).compareTo(_toInt(b['id'])));
    final activeIndex = list.indexWhere((v) => v['isActive'] == true);
    if (activeIndex < 0) {
      for (var i = 0; i < list.length; i++) {
        list[i]['isActive'] = i == list.length - 1;
      }
    } else {
      for (var i = 0; i < list.length; i++) {
        list[i]['isActive'] = i == activeIndex;
      }
    }

    return list;
  }

  Map<String, dynamic> get _activeVersion => _versions
      .firstWhere((v) => v['isActive'] == true, orElse: () => _versions.last);

  Map<String, dynamic>? get _selectedVersion {
    if (_versions.isEmpty) return null;
    if (_selectedVersionId == null) return _activeVersion;
    for (final v in _versions) {
      if (_toInt(v['id']) == _selectedVersionId) return v;
    }
    return _activeVersion;
  }

  String _nextVersion() {
    final current =
        _selectedVersion ?? (_versions.isNotEmpty ? _versions.last : null);
    final parsed = double.tryParse('${current?['version'] ?? '1.0'}') ?? 1.0;
    final next = ((parsed * 10).round() + 1) / 10;
    return next.toStringAsFixed(1);
  }

  void _startEdit() {
    final base = _selectedVersion ?? _activeVersion;
    _contentCtrl.text = '${base['content'] ?? _default}';
    _versionCtrl.text = _nextVersion();
    setState(() {
      _editing = true;
      _preview = false;
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final local = await _readLocalVersions();
    final remote = await _svc.getTermsVersions();
    final merged = _mergeVersions(local, remote);
    if (mounted) {
      setState(() {
        _versions = merged;
        _selectedVersionId = _toInt(_activeVersion['id']);
        _loading = false;
      });
    }
  }

  Future<void> _setActive(int id) async {
    final target = _versions.firstWhere(
      (v) => _toInt(v['id']) == id,
      orElse: () => _activeVersion,
    );

    final updated = _versions
        .map((v) => {...v, 'isActive': _toInt(v['id']) == _toInt(target['id'])})
        .toList();

    setState(() {
      _versions = updated;
      _selectedVersionId = _toInt(target['id']);
    });
    await _writeLocalVersions(updated);

    final content = '${target['content'] ?? ''}'.trim();
    if (content.isNotEmpty) {
      await _svc.publishTerms(
        content: content,
        version: '${target['version'] ?? ''}'.trim().isNotEmpty
            ? '${target['version']}'
            : null,
      );
    }

    if (mounted) _snack(context, 'Active version updated');
  }

  Future<void> _saveNewVersion() async {
    final content = _contentCtrl.text.trim();
    if (content.isEmpty) {
      _snack(context, 'Content cannot be empty', error: true);
      return;
    }

    setState(() => _saving = true);
    final published = await _svc.publishTerms(
      content: content,
      version: _versionCtrl.text.trim(),
    );

    final newVersion = {
      'id': DateTime.now().millisecondsSinceEpoch,
      'version': _versionCtrl.text.trim().isNotEmpty
          ? _versionCtrl.text.trim()
          : '1.0',
      'content': content,
      'updatedAt': DateTime.now().toIso8601String(),
      'updatedBy': 'Admin',
      'isActive': true,
    };

    final updated = _versions.map((v) => {...v, 'isActive': false}).toList()
      ..add(newVersion);

    if (mounted) {
      setState(() {
        _versions = updated;
        _selectedVersionId = _toInt(newVersion['id']);
        _editing = false;
        _preview = false;
      });

      _snack(
        context,
        published
            ? 'Terms & Conditions v${newVersion['version']} published'
            : 'Saved locally (publish endpoint unavailable)',
        error: !published,
      );
    }

    await _writeLocalVersions(updated);
    if (mounted) setState(() => _saving = false);
  }

  List<Map<String, String>> _parse(String text) {
    final sections = <Map<String, String>>[];
    for (final block in text.split('\n\n')) {
      final lines = block.trim().split('\n');
      if (lines.isEmpty) continue;
      if (lines.first.startsWith('### ')) {
        sections.add({
          'title': lines.first.replaceFirst('### ', ''),
          'body': lines.length > 1 ? lines.sublist(1).join(' ') : '',
        });
      } else {
        sections.add({'title': '', 'body': block.trim()});
      }
    }
    return sections;
  }

  Widget _buildReadBody(String text, {required bool showLiveBanner}) {
    final sections = _parse(text);
    final items = <Widget>[
      if (showLiveBanner)
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF059669).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: const Color(0xFF059669).withValues(alpha: 0.3)),
          ),
          child: const Row(children: [
            Icon(Icons.verified_outlined, color: Color(0xFF059669), size: 16),
            SizedBox(width: 8),
            Text(
              'LIVE - currently published version',
              style: TextStyle(
                color: Color(0xFF059669),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ]),
        ),
    ];

    for (final section in sections) {
      final title = section['title'] ?? '';
      final body = section['body'] ?? '';
      final children = <Widget>[];
      if (title.isNotEmpty) {
        children.add(Text(title,
            style: AppTextStyles.h4.copyWith(color: AppColors.primary)));
        children.add(const SizedBox(height: 6));
      }
      if (body.isNotEmpty) {
        children
            .add(Text(body, style: AppTextStyles.body.copyWith(height: 1.7)));
      }
      items.add(Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children),
      ));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child:
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: items),
    );
  }

  Widget _buildPreviewBody(String text) {
    final sections = _parse(text);
    final items = <Widget>[
      Container(
        padding: const EdgeInsets.all(10),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.info.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
        ),
        child: const Text(
          'Preview mode - not published',
          style: TextStyle(
              color: AppColors.info, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    ];

    for (final section in sections) {
      final title = section['title'] ?? '';
      final body = section['body'] ?? '';
      final children = <Widget>[];
      if (title.isNotEmpty) {
        children.add(Text(title,
            style: AppTextStyles.h4.copyWith(color: AppColors.primary)));
      }
      if (body.isNotEmpty) {
        children.add(const SizedBox(height: 6));
        children
            .add(Text(body, style: AppTextStyles.body.copyWith(height: 1.6)));
      }
      items.add(Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children),
      ));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child:
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: items),
    );
  }

  Widget _pillMode(String label, bool active, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: active ? AppColors.primaryLight : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: active ? AppColors.primaryLight : AppColors.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      );

  Widget _buildVersionHistory() {
    final reversed = _versions.reversed.toList();

    return Container(
      decoration: _cardDeco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Version History',
            style: AppTextStyles.caption
                .copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.6),
          ),
        ),
        ...reversed.map((version) {
          final isSelected = _toInt(version['id']) == _selectedVersionId;
          final isActive = version['isActive'] == true;

          return GestureDetector(
            onTap: () =>
                setState(() => _selectedVersionId = _toInt(version['id'])),
            child: Container(
              margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryLight.withValues(alpha: 0.08)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isActive
                      ? const Color(0xFF86EFAC)
                      : isSelected
                          ? AppColors.primaryLight.withValues(alpha: 0.3)
                          : AppColors.border,
                ),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text('v${version['version']}',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      const Spacer(),
                      if (isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: const Text('LIVE',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF166534),
                                  fontWeight: FontWeight.w700)),
                        ),
                    ]),
                    const SizedBox(height: 4),
                    Text(_fmtDateTime(version['updatedAt']),
                        style: AppTextStyles.caption),
                    const SizedBox(height: 2),
                    Text('by ${version['updatedBy'] ?? 'Admin'}',
                        style: AppTextStyles.caption),
                    if (!isActive) ...[
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () => _setActive(_toInt(version['id'])),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryLight,
                          side: const BorderSide(color: AppColors.primaryLight),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Set as Active'),
                      ),
                    ],
                  ]),
            ),
          );
        }),
        const SizedBox(height: 8),
      ]),
    );
  }

  Widget _buildContentPanel() {
    final selected = _selectedVersion;

    if (_editing) {
      return Container(
        decoration: _cardDeco(),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(children: [
              SizedBox(
                width: 96,
                child: TextField(
                    controller: _versionCtrl, decoration: _inp('Version')),
              ),
              const SizedBox(width: 10),
              _pillMode(
                  'Edit', !_preview, () => setState(() => _preview = false)),
              const SizedBox(width: 8),
              _pillMode(
                  'Preview', _preview, () => setState(() => _preview = true)),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() {
                  _editing = false;
                  _preview = false;
                  _contentCtrl.clear();
                }),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 6),
              FilledButton(
                onPressed: _saving ? null : _saveNewVersion,
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryLight),
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Save & Publish'),
              ),
            ]),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 430,
            child: _preview
                ? _buildPreviewBody(_contentCtrl.text)
                : TextField(
                    controller: _contentCtrl,
                    maxLines: null,
                    expands: true,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      height: 1.7,
                      color: AppColors.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.all(16),
                      border: InputBorder.none,
                      fillColor: AppColors.surface,
                      filled: true,
                    ),
                  ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: const Text(
              'Use ### Section Title for headings. Separate sections with blank lines. Previous versions are preserved.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
        ]),
      );
    }

    if (selected == null) {
      return const EmptyState(
        icon: Icons.description_outlined,
        title: 'No terms available',
        subtitle: 'Click Edit & Publish to create one.',
      );
    }

    return Container(
      decoration: _cardDeco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Version ${selected['version']}',
                        style: AppTextStyles.h4),
                    const SizedBox(height: 2),
                    Text(
                      'Updated ${_fmtDateTime(selected['updatedAt'])} by ${selected['updatedBy'] ?? 'Admin'}',
                      style: AppTextStyles.caption,
                    ),
                  ]),
            ),
            FilledButton.icon(
              onPressed: _startEdit,
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryLight),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Edit'),
            ),
          ]),
        ),
        const Divider(height: 1),
        SizedBox(
          height: 450,
          child: _buildReadBody(
            '${selected['content'] ?? ''}',
            showLiveBanner: selected['isActive'] == true,
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Terms & Conditions',
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.surface,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          if (!_editing)
            FilledButton.icon(
              onPressed: _startEdit,
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Edit & Publish'),
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryLight),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 900;
            if (narrow) {
              return ListView(
                children: [
                  _buildVersionHistory(),
                  const SizedBox(height: 12),
                  _buildContentPanel(),
                ],
              );
            }
            return SingleChildScrollView(
              child: SizedBox(
                width: constraints.maxWidth,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 280, child: _buildVersionHistory()),
                    const SizedBox(width: 16),
                    Expanded(child: _buildContentPanel()),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CommissionTab extends StatefulWidget {
  const _CommissionTab();
  @override
  State<_CommissionTab> createState() => _CommissionTabState();
}

class _CommissionTabState extends State<_CommissionTab> {
  bool _loading = true, _saving = false;
  String _feeType = 'FLAT';
  final _valCtrl = TextEditingController(),
      _previewCtrl = TextEditingController(text: '1000');
  final _api = AdminService();

  @override
  void initState() {
    super.initState();
    _previewCtrl.addListener(() => setState(() {}));
    _valCtrl.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _valCtrl.dispose();
    _previewCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final d = await _api.getAdditionalCharges();
    if (d != null) {
      _feeType = (d['feeType'] ?? 'FLAT').toString();
      _valCtrl.text = (d['feeValue'] ?? '0').toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final val = double.tryParse(_valCtrl.text);
    if (val == null || val < 0) {
      _snack(context, 'Enter a valid commission amount', error: true);
      return;
    }
    if (_feeType == 'FLAT' && val > 100000) {
      _snack(context, 'Commission cannot exceed Rs 1,00,000', error: true);
      return;
    }
    if (_feeType == 'PERCENTAGE' && val > 100) {
      _snack(context, 'Cannot exceed 100%', error: true);
      return;
    }
    setState(() => _saving = true);
    final ok = await _api.setAdditionalCharges(_feeType, val);
    if (mounted) {
      setState(() => _saving = false);
      _snack(context, ok ? 'Commission settings saved' : 'Save failed',
          error: !ok);
    }
  }

  double get _base => double.tryParse(_previewCtrl.text) ?? 1000;
  double get _feeVal => double.tryParse(_valCtrl.text) ?? 0;
  double get _commission =>
      _feeType == 'PERCENTAGE' ? _base * _feeVal / 100 : _feeVal;
  double get _total => _base + _commission;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Commission Configuration', style: AppTextStyles.h2),
                      const SizedBox(height: 4),
                      Text(
                          'Platform fee added on top of consultant\'s base charge.',
                          style: AppTextStyles.bodySmall),
                      const SizedBox(height: 20),
                      _sectionLbl('Commission Type'),
                      Row(children: [
                        Expanded(
                            child: _typeBtn('FLAT',
                                Icons.currency_rupee_rounded, 'Fixed (Rs)')),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _typeBtn('PERCENTAGE', Icons.percent_rounded,
                                'Percentage (%)')),
                      ]),
                      const SizedBox(height: 18),
                      _sectionLbl('Commission Value'),
                      TextField(
                          controller: _valCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              _feeType == 'PERCENTAGE'
                                  ? RegExp(r'[\d.]')
                                  : RegExp(r'\d'),
                            )
                          ],
                          decoration: _inp(
                              _feeType == 'PERCENTAGE'
                                  ? 'Enter % (e.g. 15)'
                                  : 'Enter commission amount (Rs)',
                              icon: _feeType == 'PERCENTAGE'
                                  ? Icons.percent_rounded
                                  : Icons.currency_rupee_rounded)),
                      if (_feeType == 'FLAT') ...[
                        const SizedBox(height: 8),
                        Text('Maximum flat commission: Rs 1,00,000',
                            style: AppTextStyles.caption),
                      ],
                      const SizedBox(height: 20),
                      _sectionLbl('Live Calculator'),
                      Container(
                          padding: const EdgeInsets.all(16),
                          decoration: _cardDeco(),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  const Text('Consultant charges Rs',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSecondary)),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                      width: 80,
                                      child: TextField(
                                          controller: _previewCtrl,
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly
                                          ],
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700),
                                          decoration: const InputDecoration(
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 6),
                                              border: OutlineInputBorder(),
                                              isDense: true))),
                                ]),
                                const SizedBox(height: 16),
                                Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                        color: const Color(0xFF059669)
                                            .withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: const Color(0xFF059669)
                                                .withValues(alpha: 0.2))),
                                    child: Column(children: [
                                      _calcRow(
                                          'Consultant Base',
                                          'Rs ${_base.toStringAsFixed(0)}',
                                          AppColors.textPrimary),
                                      const Divider(
                                          height: 16, color: AppColors.border),
                                      _calcRow(
                                          'Platform Commission',
                                          '+ Rs ${_commission.toStringAsFixed(0)}',
                                          AppColors.primaryLight),
                                      const Divider(
                                          height: 16, color: AppColors.border),
                                      _calcRow(
                                          'Customer Pays',
                                          'Rs ${_total.toStringAsFixed(0)}',
                                          const Color(0xFF059669),
                                          bold: true),
                                    ])),
                              ])),
                      const SizedBox(height: 24),
                      SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton(
                              onPressed: _saving ? null : _save,
                              style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primaryLight,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14))),
                              child: _saving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2))
                                  : const Text('Save Commission Settings',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15)))),
                    ])),
      );

  Widget _typeBtn(String type, IconData icon, String label) => GestureDetector(
        onTap: () => setState(() => _feeType = type),
        child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: _feeType == type
                    ? AppColors.primaryLight.withValues(alpha: 0.08)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _feeType == type
                        ? AppColors.primaryLight
                        : AppColors.border,
                    width: _feeType == type ? 2 : 1)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon,
                  color: _feeType == type
                      ? AppColors.primaryLight
                      : AppColors.textSecondary,
                  size: 18),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _feeType == type
                          ? AppColors.primaryLight
                          : AppColors.textSecondary))
            ])),
      );

  Widget _calcRow(String label, String val, Color c, {bool bold = false}) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style:
                const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        Text(val,
            style: TextStyle(
                fontSize: 14,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
                color: c))
      ]);
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// â”€â”€ 13. CONTACT MESSAGES
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class _ContactTab extends StatefulWidget {
  const _ContactTab();
  @override
  State<_ContactTab> createState() => _ContactTabState();
}

class _ContactTabState extends State<_ContactTab> {
  List<Map<String, dynamic>> _msgs = [];
  bool _loading = true, _loadingMore = false;
  Map<String, dynamic>? _selected;
  String _filter = 'all';
  int _page = 0;
  bool _hasMore = true;
  static const _pageSize = 20;
  final _searchCtrl = TextEditingController();
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() {}));
    _load(reset: true);
    _pollTimer = Timer.periodic(
        const Duration(seconds: 15), (_) => _load(reset: true, silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _isRead(Map m) => m['isRead'] == true || m['read'] == true;
  int get _unread => _msgs.where((m) => !_isRead(m)).length;

  String _pickText(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  Map<String, dynamic> _normalizeMsg(
    Map<String, dynamic> raw, {
    required int fallbackId,
  }) {
    final name = _pickText(raw, [
      'name',
      'fullName',
      'userName',
      'senderName',
      'firstName',
      'customerName',
    ]);
    final email = _pickText(raw, [
      'email',
      'emailAddress',
      'userEmail',
      'senderEmail',
      'mail',
    ]);
    final message = _pickText(raw, [
      'message',
      'query',
      'description',
      'text',
      'content',
      'body',
      'comments',
    ]);
    final createdAt = _pickText(raw, [
      'createdAt',
      'submittedAt',
      'createdDate',
      'timestamp',
      'date',
    ]);
    final isRead = raw['isRead'] == true || raw['read'] == true;
    return {
      ...raw,
      'id': raw['id'] ?? raw['messageId'] ?? raw['contactId'] ?? fallbackId,
      'name': name.isNotEmpty ? name : '--',
      'email': email.isNotEmpty ? email : '--',
      'message': message,
      'createdAt': createdAt,
      'submittedAt': createdAt,
      'isRead': isRead,
      'read': isRead,
    };
  }

  String _avatarText(Map<String, dynamic> msg) {
    final name = '${msg['name'] ?? ''}'.trim();
    if (name.isEmpty || name == '--') return '?';
    return name.substring(0, 1).toUpperCase();
  }

  Future<void> _load({bool reset = false, bool silent = false}) async {
    if (reset) {
      if (!silent)
        setState(() {
          _loading = true;
          _page = 0;
          _msgs = [];
          _hasMore = true;
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
      final res = await StaticContentService()
          .getContactMessages(page: reset ? 0 : _page, size: _pageSize);

      final rawItems = List<Map<String, dynamic>>.from(res['content'] ?? []);
      final items = rawItems
          .asMap()
          .entries
          .map((entry) => _normalizeMsg(entry.value, fallbackId: entry.key + 1))
          .toList(growable: false);
      bool hasMore = false;
      if (res.containsKey('totalPages')) {
        final tp = res['totalPages'] ?? 1;
        final cp = res['number'] ?? 0;
        hasMore = cp < tp - 1;
        _page = cp + 1;
      } else {
        hasMore = items.length == _pageSize;
        _page = reset ? 1 : _page + 1;
      }

      if (mounted)
        setState(() {
          if (reset)
            _msgs = items;
          else
            _msgs.addAll(items);
          _hasMore = hasMore;
          _loading = false;
          _loadingMore = false;
        });
    } catch (_) {
      if (mounted && !silent)
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
    }
  }

  Future<void> _markRead(int id) async {
    setState(() => _msgs = _msgs
        .map((m) => m['id'] == id ? {...m, 'isRead': true, 'read': true} : m)
        .toList());
    try {
      await StaticContentService().markAsRead(id);
    } catch (_) {}
  }

  Future<void> _markAllRead() async {
    final unread = _msgs
        .where((m) => !_isRead(m))
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    setState(() => _msgs =
        _msgs.map((m) => {...m, 'isRead': true, 'read': true}).toList());
    for (final m in unread) {
      try {
        await StaticContentService().markAsRead(m['id']);
      } catch (_) {}
    }
    _snack(context, 'All marked as read');
  }

  Future<void> _replyToMessage(Map<String, dynamic> message) async {
    final email = (message['email'] ?? '').toString().trim();
    if (email.isEmpty) {
      _snack(context, 'Email address is missing for this message.',
          error: true);
      return;
    }
    final subject = Uri.encodeComponent('Re: Your Rupee Admin query');
    final body = Uri.encodeComponent(
        'Hi ${(message['name'] ?? 'there').toString().trim().isEmpty ? 'there' : message['name']},\n\n');
    final mailToUri = Uri.parse('mailto:$email?subject=$subject&body=$body');
    final mailToOpened =
        await launchUrl(mailToUri, mode: LaunchMode.externalApplication);
    if (mailToOpened) return;
    final gmailUri = Uri.parse(
        'https://mail.google.com/mail/?view=cm&to=$email&su=$subject&body=$body');
    final gmailOpened =
        await launchUrl(gmailUri, mode: LaunchMode.externalApplication);
    if (gmailOpened) return;
    await Clipboard.setData(ClipboardData(text: email));
    if (!mounted) return;
    _snack(context, 'Could not open email app. Address copied: $email',
        icon: Icons.copy_rounded);
  }

  List<Map<String, dynamic>> get _visible {
    var list = _filter == 'unread'
        ? _msgs.where((m) => !_isRead(m)).toList()
        : _filter == 'read'
            ? _msgs.where((m) => _isRead(m)).toList()
            : _msgs;
    final q = _searchCtrl.text.toLowerCase();
    if (q.isNotEmpty)
      list = list
          .where((m) =>
              '${m['name'] ?? ''}'.toLowerCase().contains(q) ||
              '${m['email'] ?? ''}'.toLowerCase().contains(q) ||
              '${m['message'] ?? ''}'.toLowerCase().contains(q))
          .toList();
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(children: [
          const Text('Contact Messages',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16)),
          if (_unread > 0) ...[
            const SizedBox(width: 8),
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(20)),
                child: Text('$_unread',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)))
          ]
        ]),
        backgroundColor: AppColors.surface,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          if (_unread > 0)
            TextButton(
                onPressed: _markAllRead,
                child: const Text('Mark all read',
                    style: TextStyle(fontSize: 12))),
          IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => _load(reset: true)),
        ],
      ),
      body: Column(children: [
        Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Column(children: [
              TextField(
                  controller: _searchCtrl,
                  decoration:
                      _inp('Search messages...', icon: Icons.search_rounded)),
              const SizedBox(height: 8),
              SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                      children: ['all', 'unread', 'read'].map((f) {
                    final count = f == 'all'
                        ? _msgs.length
                        : f == 'unread'
                            ? _unread
                            : _msgs.length - _unread;
                    return Padding(
                        padding: const EdgeInsets.only(right: 8, bottom: 10),
                        child: FilterChip(
                          label: Text(
                              '${f[0].toUpperCase()}${f.substring(1)} ($count)'),
                          selected: _filter == f,
                          onSelected: (_) => setState(() => _filter = f),
                          selectedColor:
                              AppColors.primaryLight.withValues(alpha: 0.12),
                          checkmarkColor: AppColors.primaryLight,
                          labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _filter == f
                                  ? AppColors.primaryLight
                                  : AppColors.textSecondary),
                        ));
                  }).toList())),
            ])),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _msgs.isEmpty
                  ? const EmptyState(
                      icon: Icons.mail_outline_rounded,
                      title: 'No messages',
                      subtitle: 'Contact form submissions appear here')
                  : RefreshIndicator(
                      onRefresh: () => _load(reset: true),
                      child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          itemCount: visible.length +
                              (_loadingMore ? 1 : 0) +
                              (_hasMore && !_loadingMore ? 1 : 0),
                          itemBuilder: (_, i) {
                            if (i == visible.length && _loadingMore)
                              return const Center(
                                  child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: CircularProgressIndicator()));
                            if (i == visible.length && _hasMore)
                              return TextButton(
                                  onPressed: () => _load(),
                                  child: const Text('Load more'));
                            if (i >= visible.length)
                              return const SizedBox.shrink();
                            final m = visible[i];
                            final read = _isRead(m);
                            final isSel = _selected?['id'] == m['id'];
                            return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      setState(
                                          () => _selected = isSel ? null : m);
                                      if (!read) _markRead(m['id']);
                                    },
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 150),
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                          color: isSel
                                              ? AppColors.primaryLight
                                                  .withValues(alpha: 0.05)
                                              : AppColors.surface,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: Border(
                                              left: BorderSide(
                                                  color: isSel
                                                      ? AppColors.primaryLight
                                                      : !read
                                                          ? AppColors
                                                              .primaryLight
                                                          : Colors.transparent,
                                                  width: 3),
                                              top: const BorderSide(
                                                  color: AppColors.border),
                                              right: const BorderSide(
                                                  color: AppColors.border),
                                              bottom: const BorderSide(
                                                  color: AppColors.border))),
                                      child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            CircleAvatar(
                                                radius: 18,
                                                backgroundColor:
                                                    AppColors.primary,
                                                child: Text(_avatarText(m),
                                                    style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 13))),
                                            const SizedBox(width: 12),
                                            Expanded(
                                                child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                  Row(children: [
                                                    Expanded(
                                                        child: Text(
                                                            '${m['name'] ?? 'Unknown'}',
                                                            style: AppTextStyles
                                                                .label
                                                                .copyWith(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w700))),
                                                    if (!read)
                                                      Container(
                                                          width: 7,
                                                          height: 7,
                                                          decoration:
                                                              const BoxDecoration(
                                                                  color: AppColors
                                                                      .primaryLight,
                                                                  shape: BoxShape
                                                                      .circle))
                                                  ]),
                                                  Text('${m['email'] ?? ''}',
                                                      style: AppTextStyles
                                                          .caption),
                                                  const SizedBox(height: 2),
                                                  if ((m['createdAt'] ?? '')
                                                      .toString()
                                                      .isNotEmpty)
                                                    Text(
                                                        _fmtDateTime(
                                                            m['createdAt']),
                                                        style: AppTextStyles
                                                            .caption
                                                            .copyWith(
                                                                color: AppColors
                                                                    .textMuted)),
                                                  const SizedBox(height: 3),
                                                  Text('${m['message'] ?? ''}',
                                                      style: AppTextStyles
                                                          .bodySmall,
                                                      maxLines: 2,
                                                      overflow: TextOverflow
                                                          .ellipsis),
                                                ])),
                                          ]),
                                    ),
                                  ),
                                  if (isSel)
                                    AnimatedSize(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        child: Container(
                                          margin:
                                              const EdgeInsets.only(bottom: 10),
                                          padding: const EdgeInsets.all(16),
                                          decoration: _cardDeco(),
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(children: [
                                                  Text('Full Message',
                                                      style:
                                                          AppTextStyles.label),
                                                  const Spacer(),
                                                  if ((m['createdAt'] ?? '')
                                                      .toString()
                                                      .isNotEmpty)
                                                    Text(
                                                        _fmtDateTime(
                                                            m['createdAt']),
                                                        style: AppTextStyles
                                                            .caption)
                                                ]),
                                                const SizedBox(height: 8),
                                                Container(
                                                    width: double.infinity,
                                                    padding:
                                                        const EdgeInsets.all(
                                                            12),
                                                    decoration: BoxDecoration(
                                                        color: AppColors
                                                            .surfaceVariant,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                                10),
                                                        border: const Border(
                                                            left: BorderSide(
                                                                color: AppColors
                                                                    .primaryLight,
                                                                width: 3))),
                                                    child: Text(
                                                        '${m['message'] ?? ''}',
                                                        style: AppTextStyles
                                                            .body
                                                            .copyWith(
                                                                height: 1.7))),
                                                const SizedBox(height: 12),
                                                SizedBox(
                                                    width: double.infinity,
                                                    child: OutlinedButton.icon(
                                                        onPressed: () =>
                                                            _replyToMessage(m),
                                                        icon: const Icon(
                                                            Icons.reply_rounded,
                                                            size: 16),
                                                        label: Text(
                                                            'Reply to ${m['email'] ?? ''}'),
                                                        style: OutlinedButton.styleFrom(
                                                            foregroundColor:
                                                                AppColors
                                                                    .primaryLight,
                                                            side: const BorderSide(
                                                                color: AppColors
                                                                    .primaryLight),
                                                            shape: RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                        10))))),
                                              ]),
                                        )),
                                ]);
                          })),
        ),
      ]),
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// â”€â”€ 14. ADD MEMBER â€” POST /api/onboarding/admin/member
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class _AddMemberTab extends StatefulWidget {
  const _AddMemberTab();
  @override
  State<_AddMemberTab> createState() => _AddMemberTabState();
}

class _AddMemberTabState extends State<_AddMemberTab> {
  final _nameC = TextEditingController(),
      _emailC = TextEditingController(),
      _phoneC = TextEditingController(),
      _locC = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  final List<Map<String, String>> _added = [];

  @override
  void dispose() {
    _nameC.dispose();
    _emailC.dispose();
    _phoneC.dispose();
    _locC.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final result = await OnboardingService().createMemberByAdmin(
        name: _nameC.text.trim(),
        email: _emailC.text.trim().toLowerCase(),
        phoneNumber: _phoneC.text.trim(),
        location: _locC.text.trim().isNotEmpty ? _locC.text.trim() : null,
      );

      if (result != null) {
        setState(() {
          _added.insert(0, {
            'name': _nameC.text.trim(),
            'email': _emailC.text.trim().toLowerCase(),
            'at': DateFormat('d MMM yyyy').format(DateTime.now())
          });
        });
        _nameC.clear();
        _emailC.clear();
        _phoneC.clear();
        _locC.clear();
        _snack(context, 'Member added! Credentials sent via email',
            icon: Icons.person_add_rounded);
      } else {
        _snack(context, 'Failed to add member. Please try again.', error: true);
      }
    } catch (error) {
      final msg = _apiError(error, fallback: 'Failed to add member');
      if (msg.toLowerCase().contains('already'))
        _snack(context, 'Email or phone already registered', error: true);
      else if (msg.contains('403'))
        _snack(context, 'Access denied - admin role required', error: true);
      else
        _snack(context, msg, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Add Member', style: AppTextStyles.h2),
              const SizedBox(height: 4),
              Text(
                  'Create user accounts. The system auto-generates and emails credentials.',
                  style: AppTextStyles.bodySmall),
              const SizedBox(height: 16),
              Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: const Color(0xFF059669).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color:
                              const Color(0xFF059669).withValues(alpha: 0.3))),
                  child: const Row(children: [
                    Icon(Icons.lock_rounded,
                        color: Color(0xFF059669), size: 16),
                    SizedBox(width: 8),
                    Expanded(
                        child: Text(
                            'A secure password is auto-generated and emailed to the new member.',
                            style: TextStyle(
                                color: Color(0xFF059669),
                                fontSize: 12,
                                height: 1.4)))
                  ])),
              const SizedBox(height: 18),
              Form(
                  key: _formKey,
                  child: Column(children: [
                    TextFormField(
                        controller: _nameC,
                        decoration: _inp('Full Name *',
                            icon: Icons.person_outline_rounded),
                        validator: (v) => (v ?? '').trim().isEmpty
                            ? 'Full name required'
                            : null),
                    const SizedBox(height: 10),
                    TextFormField(
                        controller: _emailC,
                        keyboardType: TextInputType.emailAddress,
                        decoration:
                            _inp('Email Address *', icon: Icons.email_outlined),
                        validator: (v) {
                          if ((v ?? '').trim().isEmpty) return 'Email required';
                          return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                  .hasMatch(v!.trim())
                              ? null
                              : 'Invalid email';
                        }),
                    const SizedBox(height: 10),
                    TextFormField(
                        controller: _phoneC,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10)
                        ],
                        decoration: _inp('Mobile Number *',
                            icon: Icons.phone_outlined,
                            hint: '10-digit mobile'),
                        validator: (v) {
                          if ((v ?? '').trim().isEmpty)
                            return 'Mobile required';
                          return RegExp(r'^[6-9]\d{9}$').hasMatch(v!.trim())
                              ? null
                              : 'Invalid 10-digit mobile';
                        }),
                    const SizedBox(height: 10),
                    TextFormField(
                        controller: _locC,
                        decoration: _inp('Location (optional)',
                            icon: Icons.location_on_outlined)),
                    const SizedBox(height: 18),
                    SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                            onPressed: _saving ? null : _submit,
                            icon: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.person_add_rounded,
                                    color: Colors.white, size: 18),
                            label: Text(_saving ? 'Adding...' : 'Add Member',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 15)),
                            style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primaryLight,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14))))),
                  ])),
              if (_added.isNotEmpty) ...[
                const SizedBox(height: 24),
                _sectionLbl('Recently Added (${_added.length})'),
                Container(
                    decoration: _cardDeco(),
                    child: Column(
                        children: _added
                            .map((m) => ListTile(
                                  leading: CircleAvatar(
                                      backgroundColor: AppColors.primary,
                                      child: Text(m['name']![0].toUpperCase(),
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700))),
                                  title:
                                      Text(m['name']!, style: AppTextStyles.h4),
                                  subtitle: Text(m['email']!,
                                      style: AppTextStyles.caption),
                                  trailing: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        _chip('MEMBER', AppColors.primaryLight),
                                        const SizedBox(height: 3),
                                        Text(m['at']!,
                                            style: AppTextStyles.caption),
                                      ]),
                                ))
                            .toList())),
              ],
            ])),
      );
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// â”€â”€ 15. SETTINGS TAB
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class _SettingsTab extends StatelessWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      _tile(
          context,
          Icons.account_circle_rounded,
          'Profile & Security',
          'Update photo, profile & password',
          AppColors.primaryLight,
          () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const _ProfileSecurityScreen()))),
      _tile(
          context,
          Icons.access_time_rounded,
          'Business Hours',
          'Working days & time configuration',
          const Color(0xFF0891B2),
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const _BusinessHoursScreen()))),
      _tile(
          context,
          Icons.beach_access_rounded,
          'Holidays',
          'Non-working days management',
          const Color(0xFFF97316),
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const _HolidaysScreen()))),
      _tile(
          context,
          Icons.auto_awesome_rounded,
          'Auto Responder',
          'Automatic ticket acknowledgment',
          AppColors.info,
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const _AutoResponderScreen()))),
      _tile(
          context,
          Icons.chat_bubble_outline_rounded,
          'Canned Responses',
          'Quick-reply templates for support',
          const Color(0xFF7C3AED),
          () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const _CannedResponsesScreen()))),
      _tile(
          context,
          Icons.label_rounded,
          'Ticket Categories',
          'Manage support categories & SLA',
          const Color(0xFFF59E0B),
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const _CategoriesScreen()))),
      _tile(
          context,
          Icons.card_membership_rounded,
          'Subscription Plans',
          'Pricing & membership plans',
          AppColors.primary,
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const _PlansScreen()))),
    ]);
  }

  Widget _tile(BuildContext ctx, IconData icon, String title, String subtitle,
          Color color, VoidCallback onTap) =>
      Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: _cardDeco(),
        child: ListTile(
          onTap: onTap,
          leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 20)),
          title: Text(title, style: AppTextStyles.h4),
          subtitle: Text(subtitle, style: AppTextStyles.caption),
          trailing: const Icon(Icons.chevron_right_rounded,
              color: AppColors.textMuted, size: 20),
        ),
      );
}

// â”€â”€â”€ Settings API helper â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

// â”€â”€â”€ Master Time Ranges â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _MasterTimeRangesScreen extends StatefulWidget {
  const _MasterTimeRangesScreen();
  @override
  State<_MasterTimeRangesScreen> createState() =>
      _MasterTimeRangesScreenState();
}

class _MasterTimeRangesScreenState extends State<_MasterTimeRangesScreen> {
  final _svc = ConsultantService();
  final _slotCtrl = TextEditingController();
  final List<int> _durations = const [60, 120, 180];

  List<Map<String, dynamic>> _slots = [];
  int _duration = 60;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _slotCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final raw = await _svc.getAllMasterSlots();
    final items = raw
        .map<Map<String, dynamic>>((row) => {
              'id': _toInt(row['id']) ?? 0,
              'timeRange': _normalizeTimeRange(
                row['timeRange'] ?? row['slotTime'],
                durationMinutes:
                    _toInt(row['durationMinutes']) ?? _toInt(row['duration']),
              ),
              'durationMinutes':
                  _slotDuration(row, fallback: _toInt(row['duration']) ?? 60),
            })
        .where((row) => (row['timeRange'] as String).trim().isNotEmpty)
        .toList()
      ..sort((a, b) => _startMinutes(a['timeRange'] as String)
          .compareTo(_startMinutes(b['timeRange'] as String)));

    if (!mounted) return;
    setState(() {
      _slots = items;
      _loading = false;
    });
  }

  int _slotDuration(Map<String, dynamic> row, {int fallback = 60}) {
    final durationMinutes = _toInt(row['durationMinutes']);
    if (durationMinutes != null && durationMinutes > 0) return durationMinutes;
    final duration = _toInt(row['duration']);
    if (duration != null) {
      if (duration >= 60) return duration;
      if (duration >= 1 && duration <= 3) return duration * 60;
    }
    return fallback;
  }

  String _normalizeTimeRange(dynamic raw, {dynamic durationMinutes}) {
    final value = (raw ?? '').toString().trim();
    if (value.isEmpty) return '';
    final parts = value.split('-').map((e) => e.trim()).toList();
    if (parts.length == 2 && parts.first.isNotEmpty && parts.last.isNotEmpty) {
      return '${_normalizeDisplayTime(parts.first)} - ${_normalizeDisplayTime(parts.last)}';
    }
    final start = _parseClockMinutes(value);
    final duration = _toInt(durationMinutes) ?? 60;
    if (start == null) return value;
    return '${_formatMinutes(start)} - ${_formatMinutes(start + duration)}';
  }

  String _normalizeDisplayTime(String value) {
    final mins = _parseClockMinutes(value);
    return mins == null ? value : _formatMinutes(mins);
  }

  int? _parseClockMinutes(String value) {
    final clean = value.trim().toUpperCase();
    if (clean.isEmpty) return null;
    try {
      return DateFormat('h:mm a').parseStrict(clean).hour * 60 +
          DateFormat('h:mm a').parseStrict(clean).minute;
    } catch (_) {}
    try {
      final parsed = DateFormat('H:mm').parseStrict(clean);
      return parsed.hour * 60 + parsed.minute;
    } catch (_) {}
    return null;
  }

  int _startMinutes(String range) {
    final start = range.split('-').first.trim();
    return _parseClockMinutes(start) ?? 0;
  }

  String _formatMinutes(int minutes) {
    final normalized = ((minutes % (24 * 60)) + (24 * 60)) % (24 * 60);
    final hour = normalized ~/ 60;
    final minute = normalized % 60;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  String _durationLabel(int minutes) {
    final hours = minutes ~/ 60;
    return '$hours hr';
  }

  Future<void> _pickStartSlot() async {
    final picked = await showDialog<Map<String, int>>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _MasterTimeRangePickerDialog(
        initialHour: _parseInitialHour(),
        initialDuration: _duration,
      ),
    );
    if (picked == null) return;
    final start = picked['start'] ?? _parseInitialHour();
    final duration = picked['duration'] ?? _duration;
    final end = start + duration;
    if (end > 24 * 60) {
      _snack(context, 'Selected duration must end on the same day.',
          error: true);
      return;
    }

    setState(() {
      _duration = duration;
      _slotCtrl.text = _formatMinutes(start);
    });
  }

  int _parseInitialHour() {
    final existing = _parseClockMinutes(_slotCtrl.text.trim());
    if (existing != null) return existing;
    return 12 * 60;
  }

  Future<void> _addRange() async {
    final startLabel = _slotCtrl.text.trim();
    final start = _parseClockMinutes(startLabel);
    if (start == null) {
      _snack(context, 'Pick a valid slot start time.', error: true);
      return;
    }

    final end = start + _duration;
    if (end > 24 * 60) {
      _snack(context, 'Selected duration must end on the same day.',
          error: true);
      return;
    }

    final range = '${_formatMinutes(start)} - ${_formatMinutes(end)}';
    final exists = _slots.any((slot) =>
        (slot['timeRange'] as String).toUpperCase() == range.toUpperCase());
    if (exists) {
      _snack(context, 'That master time range already exists.', error: true);
      return;
    }

    setState(() => _saving = true);
    final ok = await _svc.createMasterSlot(range, duration: _duration);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      _snack(context, 'Failed to add time range.', error: true);
      return;
    }
    _slotCtrl.clear();
    _snack(context, 'Master time range added');
    await _load();
  }

  Future<void> _deleteRange(Map<String, dynamic> slot) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete time range?'),
        content: Text('Delete ${slot['timeRange']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final deleted = await _svc.deleteMasterSlot((_toInt(slot['id']) ?? 0));
    if (!mounted) return;
    _snack(
      context,
      deleted ? 'Time range deleted' : 'Delete failed',
      error: !deleted,
    );
    if (deleted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Master Time Slots',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: AppColors.surface,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: _cardDeco(
                      bg: const Color(0xFFF8FCFF),
                      border: const Color(0xFFD8E7F8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Master Time Slots', style: AppTextStyles.h2),
                        const SizedBox(height: 8),
                        Text(
                          'Only admin can create, edit, or delete the master list of bookable time ranges. Duration is stored in system minutes and used to build consultant-specific slot windows.',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.55,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: _durations
                              .map(
                                (minutes) => Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      right: minutes == _durations.last ? 0 : 8,
                                    ),
                                    child: _durationOption(minutes),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 14),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final stacked = constraints.maxWidth < 700;
                            final field = Expanded(
                              child: TextField(
                                controller: _slotCtrl,
                                readOnly: true,
                                onTap: _pickStartSlot,
                                decoration: _inp(
                                  'Start time',
                                  hint:
                                      'Pick a ${_durationLabel(_duration).toLowerCase()} slot',
                                  suffix: IconButton(
                                    icon: const Icon(Icons.schedule_rounded),
                                    onPressed: _pickStartSlot,
                                  ),
                                ),
                              ),
                            );
                            final button = SizedBox(
                              height: 52,
                              child: FilledButton(
                                onPressed: _saving ? null : _addRange,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primaryDark,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _saving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Add Time Range',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            );
                            if (stacked) {
                              return Column(
                                children: [
                                  Row(children: [field]),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                      width: double.infinity, child: button),
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                field,
                                const SizedBox(width: 12),
                                button,
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: _cardDeco(),
                    clipBehavior: Clip.antiAlias,
                    child: _slots.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(28),
                            child: EmptyState(
                              icon: Icons.schedule_outlined,
                              title: 'No master time ranges yet',
                              subtitle:
                                  'Create a slot duration and add the first time range.',
                            ),
                          )
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth:
                                    MediaQuery.of(context).size.width - 32,
                              ),
                              child: DataTable(
                                headingRowColor: MaterialStateProperty.all(
                                  const Color(0xFFF6F8FC),
                                ),
                                columnSpacing: 28,
                                columns: const [
                                  DataColumn(
                                    label: Text(
                                      'ID',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'TIME RANGE',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'DURATION',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'ACTIONS',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                                rows: _slots
                                    .map(
                                      (slot) => DataRow(
                                        cells: [
                                          DataCell(
                                            Text(
                                              '#${slot['id']}',
                                              style: const TextStyle(
                                                color: AppColors.primaryDark,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              slot['timeRange'] as String,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              _durationLabel(
                                                _toInt(
                                                      slot['durationMinutes'],
                                                    ) ??
                                                    60,
                                              ),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            OutlinedButton(
                                              onPressed: () =>
                                                  _deleteRange(slot),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor:
                                                    const Color(0xFFDC2626),
                                                side: const BorderSide(
                                                  color: Color(0xFFF8B4B4),
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                              ),
                                              child: const Text('Delete'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _durationOption(int minutes) {
    final selected = _duration == minutes;
    return InkWell(
      onTap: () => setState(() => _duration = minutes),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEAF8F7) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primaryDark : AppColors.border,
          ),
        ),
        child: Text(
          _durationLabel(minutes),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: selected ? AppColors.primaryDark : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _MasterTimeRangePickerDialog extends StatefulWidget {
  final int initialHour;
  final int initialDuration;

  const _MasterTimeRangePickerDialog({
    required this.initialHour,
    required this.initialDuration,
  });

  @override
  State<_MasterTimeRangePickerDialog> createState() =>
      _MasterTimeRangePickerDialogState();
}

class _MasterTimeRangePickerDialogState
    extends State<_MasterTimeRangePickerDialog> {
  late int _selectedStartMinutes;
  late int _duration;

  final List<int> _durations = const [60, 120, 180];

  @override
  void initState() {
    super.initState();
    _selectedStartMinutes = widget.initialHour;
    _duration = widget.initialDuration;
    if (_selectedStartMinutes + _duration > 24 * 60) {
      _selectedStartMinutes = (24 * 60) - _duration;
    }
    _selectedStartMinutes = _normalizeStartForDuration(_selectedStartMinutes);
  }

  bool get _isAm => _selectedStartMinutes < 12 * 60;

  List<int> get _hoursForPeriod {
    final base = _isAm ? 0 : 12;
    return List<int>.generate(12, (index) => (base + index) * 60)
        .where(_isValidStartForDuration)
        .where((minutes) => minutes + _duration <= 24 * 60)
        .toList();
  }

  bool _isValidStartForDuration(int minutes) {
    final hour = (minutes ~/ 60) % 24;
    if (_duration == 120) return hour.isEven;
    if (_duration == 180) return hour.isOdd;
    return true;
  }

  int _normalizeStartForDuration(int minutes, {bool preferAm = false}) {
    final candidateHours = List<int>.generate(24, (index) => index * 60)
        .where(_isValidStartForDuration)
        .where((value) => value + _duration <= 24 * 60)
        .toList();
    if (candidateHours.isEmpty) return minutes;
    if (candidateHours.contains(minutes)) return minutes;

    final samePeriod = candidateHours
        .where((value) => preferAm ? value < 12 * 60 : value >= 12 * 60)
        .toList();
    final scoped = samePeriod.isNotEmpty ? samePeriod : candidateHours;
    return scoped.reduce((best, next) {
      final bestDiff = (best - minutes).abs();
      final nextDiff = (next - minutes).abs();
      return nextDiff < bestDiff ? next : best;
    });
  }

  String get _durationRuleText {
    if (_duration == 120) {
      return '2 hr slots start on even hours.';
    }
    if (_duration == 180) {
      return '3 hr slots start on odd hours.';
    }
    return '1 hr slots can start on any hour.';
  }

  String _formatMinutes(int minutes) {
    final normalized = ((minutes % (24 * 60)) + (24 * 60)) % (24 * 60);
    final hour = normalized ~/ 60;
    final minute = normalized % 60;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  String get _rangeLabel =>
      '${_formatMinutes(_selectedStartMinutes)} - ${_formatMinutes(_selectedStartMinutes + _duration)}';

  void _changePeriod(bool am) {
    final currentHour = (_selectedStartMinutes ~/ 60) % 12;
    final mappedHour = am ? currentHour : currentHour + 12;
    final next = mappedHour * 60;
    setState(() {
      final target = next + _duration > 24 * 60 ? ((am ? 11 : 8) * 60) : next;
      _selectedStartMinutes = _normalizeStartForDuration(target, preferAm: am);
    });
  }

  @override
  Widget build(BuildContext context) {
    final hours = _hoursForPeriod;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 40,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  gradient: LinearGradient(
                    colors: [Color(0xFF2854C5), Color(0xFF24C2A5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, size: 8, color: Color(0xFFFDE68A)),
                          SizedBox(width: 8),
                          Text(
                            'SELECT START TIME',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _rangeLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Pick the starting hour. End time is added automatically.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 14,
                          color: Color(0xFFFDE68A),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _durationRuleText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        ..._durations.map(
                          (minutes) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _pillOption(
                              label: '${minutes ~/ 60} hr',
                              selected: _duration == minutes,
                              onTap: () {
                                setState(() {
                                  _duration = minutes;
                                  final capped =
                                      _selectedStartMinutes + _duration >
                                              24 * 60
                                          ? (24 * 60) - _duration
                                          : _selectedStartMinutes;
                                  _selectedStartMinutes =
                                      _normalizeStartForDuration(
                                    capped,
                                    preferAm: _isAm,
                                  );
                                });
                              },
                            ),
                          ),
                        ),
                        const Spacer(),
                        Column(
                          children: [
                            _periodChip('AM', _isAm, () => _changePeriod(true)),
                            const SizedBox(height: 8),
                            _periodChip(
                                'PM', !_isAm, () => _changePeriod(false)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Column(
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: hours
                          .map(
                            (minutes) => _hourCell(
                              label:
                                  '${((minutes ~/ 60) % 12 == 0) ? 12 : ((minutes ~/ 60) % 12)}',
                              selected: _selectedStartMinutes == minutes,
                              onTap: () => setState(
                                () => _selectedStartMinutes = minutes,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                              side: const BorderSide(color: AppColors.border),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.pop(context, {
                              'start': _selectedStartMinutes,
                              'duration': _duration,
                            }),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primaryDark,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Use This Slot',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pillOption({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.primaryDark : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _periodChip(
    String label,
    bool selected,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 48,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? AppColors.primaryDark : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _hourCell({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 68,
        height: 56,
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryDark : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.primaryDark : const Color(0xFFD9E2EC),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

// â”€â”€â”€ Business Hours â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _BusinessHoursScreen extends StatefulWidget {
  const _BusinessHoursScreen();
  @override
  State<_BusinessHoursScreen> createState() => _BusinessHoursScreenState();
}

class _BusinessHoursScreenState extends State<_BusinessHoursScreen> {
  final _api = AdminService();
  List<Map<String, dynamic>> _hours = [];
  bool _loading = true, _saving = false;
  static const _days = [
    'MONDAY',
    'TUESDAY',
    'WEDNESDAY',
    'THURSDAY',
    'FRIDAY',
    'SATURDAY',
    'SUNDAY'
  ];
  static const _labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final raw = await _api.getBusinessHours();
    if (raw.isEmpty) {
      _hours = _days
          .map((d) => {
                'dayOfWeek': d,
                'openTime': '09:00',
                'closeTime': '18:00',
                'workingDay': d != 'SATURDAY' && d != 'SUNDAY',
                'id': 0
              })
          .toList();
    } else {
      _hours = raw
          .map((h) => {
                'dayOfWeek': h['dayOfWeek'],
                'openTime': _pt(h['startTime']),
                'closeTime': _pt(h['endTime']),
                'workingDay': h['workingDay'] ?? true,
                'id': h['id'] ?? 0
              })
          .toList();
    }
    if (mounted) setState(() => _loading = false);
  }

  String _pt(dynamic t) {
    if (t is Map)
      return '${(t['hour'] ?? 9).toString().padLeft(2, '0')}:${(t['minute'] ?? 0).toString().padLeft(2, '0')}';
    return '09:00';
  }

  Future<void> _pickTime(int i, bool isOpen) async {
    final cur = isOpen
        ? _hours[i]['openTime'] as String
        : _hours[i]['closeTime'] as String;
    final p = cur.split(':');
    final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1])));
    if (picked != null) {
      final ts =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        if (isOpen)
          _hours[i]['openTime'] = ts;
        else
          _hours[i]['closeTime'] = ts;
      });
    }
  }

  Future<void> _save() async {
    for (final h in _hours.where((item) => item['workingDay'] == true)) {
      final open = (h['openTime'] ?? '').toString();
      final close = (h['closeTime'] ?? '').toString();
      final openParts = open.split(':');
      final closeParts = close.split(':');
      if (openParts.length != 2 || closeParts.length != 2) {
        _snack(
            context, 'Each working day needs a valid opening and closing time.',
            error: true);
        return;
      }
      final openMinutes = (int.tryParse(openParts[0]) ?? 0) * 60 +
          (int.tryParse(openParts[1]) ?? 0);
      final closeMinutes = (int.tryParse(closeParts[0]) ?? 0) * 60 +
          (int.tryParse(closeParts[1]) ?? 0);
      if (closeMinutes <= openMinutes) {
        _snack(context, 'Closing time must be later than opening time.',
            error: true);
        return;
      }
    }
    setState(() => _saving = true);
    Map<String, dynamic> tp(String t) {
      final p = t.split(':');
      return {
        'hour': int.parse(p[0]),
        'minute': int.parse(p[1]),
        'second': 0,
        'nano': 0
      };
    }

    final ok = await _api.updateBusinessHours(_hours
        .map((h) => {
              'dayOfWeek': h['dayOfWeek'],
              'startTime': tp(h['openTime'] as String),
              'endTime': tp(h['closeTime'] as String),
              'workingDay': h['workingDay']
            })
        .toList());
    if (mounted) {
      setState(() => _saving = false);
      _snack(context, ok ? 'Business hours saved' : 'Save failed', error: !ok);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
            title: const Text('Business Hours'),
            backgroundColor: AppColors.surface,
            iconTheme: const IconThemeData(color: AppColors.textPrimary),
            actions: [
              TextButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save',
                          style: TextStyle(fontWeight: FontWeight.w700)))
            ]),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView.separated(
                padding: const EdgeInsets.all(14),
                itemCount: _hours.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final h = _hours[i];
                  final di = _days.indexOf(h['dayOfWeek'] as String);
                  final isOpen = h['workingDay'] as bool;
                  return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: _cardDeco(),
                      child: Row(children: [
                        SizedBox(
                            width: 34,
                            child: Text(
                                di >= 0
                                    ? _labels[di]
                                    : (h['dayOfWeek'] as String)
                                        .substring(0, 3),
                                style: AppTextStyles.label
                                    .copyWith(fontWeight: FontWeight.w700))),
                        Switch(
                            value: isOpen,
                            activeThumbColor: const Color(0xFF059669),
                            activeTrackColor:
                                const Color(0xFF059669).withValues(alpha: 0.4),
                            onChanged: (v) =>
                                setState(() => _hours[i]['workingDay'] = v)),
                        if (isOpen) ...[
                          const SizedBox(width: 8),
                          Expanded(
                              child: Row(children: [
                            _timePick(h['openTime'] as String,
                                () => _pickTime(i, true)),
                            const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text('--',
                                    style:
                                        TextStyle(color: AppColors.textMuted))),
                            _timePick(h['closeTime'] as String,
                                () => _pickTime(i, false)),
                          ]))
                        ] else
                          Expanded(
                              child:
                                  Text('Closed', style: AppTextStyles.caption)),
                      ]));
                },
              ),
      );

  Widget _timePick(String time, VoidCallback onTap) => GestureDetector(
      onTap: onTap,
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(8)),
          child: Text(_formatClockValue(time),
              style: AppTextStyles.label
                  .copyWith(color: AppColors.primaryLight))));
}

// â”€â”€â”€ Holidays â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _HolidaysScreen extends StatefulWidget {
  const _HolidaysScreen();
  @override
  State<_HolidaysScreen> createState() => _HolidaysScreenState();
}

class _HolidaysScreenState extends State<_HolidaysScreen> {
  final _api = AdminService();
  List<Map<String, dynamic>> _holidays = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _holidays = List<Map<String, dynamic>>.from(await _api.getHolidays());
    if (mounted) setState(() => _loading = false);
  }

  void _addSheet() {
    final nc = TextEditingController();
    String? selDate;
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => StatefulBuilder(
            builder: (ctx, ss) => Padding(
                padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 20,
                    bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Add Holiday', style: AppTextStyles.h3),
                      const SizedBox(height: 16),
                      TextField(
                          controller: nc,
                          decoration: _inp('Holiday name *',
                              icon: Icons.celebration_outlined)),
                      const SizedBox(height: 10),
                      GestureDetector(
                          onTap: () async {
                            final p = await showDatePicker(
                                context: ctx,
                                initialDate: DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 365 * 2)));
                            if (p != null)
                              ss(() =>
                                  selDate = p.toIso8601String().split('T')[0]);
                          },
                          child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                  color: AppColors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border)),
                              child: Row(children: [
                                const Icon(Icons.calendar_today_outlined,
                                    color: AppColors.textSecondary, size: 18),
                                const SizedBox(width: 10),
                                Text(selDate ?? 'Select date',
                                    style: selDate != null
                                        ? AppTextStyles.body
                                        : AppTextStyles.caption)
                              ]))),
                      const SizedBox(height: 18),
                      SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton(
                              onPressed: () async {
                                if (nc.text.isEmpty || selDate == null) return;
                                final ok =
                                    await _api.addHoliday(nc.text, selDate!);
                                if (ok && mounted) {
                                  Navigator.pop(context);
                                  _load();
                                }
                              },
                              child: const Text('Add Holiday'))),
                    ]))));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
            title: const Text('Holidays'),
            backgroundColor: AppColors.surface,
            iconTheme: const IconThemeData(color: AppColors.textPrimary),
            actions: [
              IconButton(
                  icon: const Icon(Icons.add_rounded), onPressed: _addSheet)
            ]),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _holidays.isEmpty
                ? const EmptyState(
                    icon: Icons.beach_access_outlined,
                    title: 'No holidays added')
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                        padding: const EdgeInsets.all(14),
                        itemCount: _holidays.length,
                        itemBuilder: (_, i) {
                          final h = _holidays[i];
                          return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: _cardDeco(),
                              child: ListTile(
                                leading: Container(
                                    padding: const EdgeInsets.all(9),
                                    decoration: BoxDecoration(
                                        color: const Color(0xFFF97316)
                                            .withValues(alpha: 0.1),
                                        shape: BoxShape.circle),
                                    child: const Icon(
                                        Icons.beach_access_outlined,
                                        color: Color(0xFFF97316),
                                        size: 18)),
                                title: Text(h['name'] ?? '',
                                    style: AppTextStyles.h4),
                                subtitle: Text(_fmtDate(h['holidayDate']),
                                    style: AppTextStyles.caption),
                                trailing: IconButton(
                                    icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: Color(0xFFDC2626)),
                                    onPressed: () async {
                                      final ok = await showDialog<bool>(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                                  title: const Text(
                                                      'Delete Holiday?'),
                                                  content: Text(
                                                      'Delete "${h['name']}"?'),
                                                  actions: [
                                                    TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                context, false),
                                                        child: const Text(
                                                            'Cancel')),
                                                    FilledButton(
                                                        style: FilledButton
                                                            .styleFrom(
                                                                backgroundColor:
                                                                    const Color(
                                                                        0xFFDC2626)),
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                context, true),
                                                        child: const Text(
                                                            'Delete'))
                                                  ]));
                                      if (ok == true) {
                                        await _api.delHoliday(h['id']);
                                        _load();
                                      }
                                    }),
                              ));
                        })),
      );
}

// â”€â”€â”€ Auto Responder â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _AutoResponderScreen extends StatefulWidget {
  const _AutoResponderScreen();
  @override
  State<_AutoResponderScreen> createState() => _AutoResponderScreenState();
}

class _AutoResponderScreenState extends State<_AutoResponderScreen> {
  final _api = AdminService();
  final _msgCtrl = TextEditingController();
  bool _enabled = false, _loading = true, _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final d = await _api.getAutoResponder();
    if (d != null)
      setState(() {
        _enabled = d['enabled'] ?? false;
        _msgCtrl.text = d['message'] ?? '';
      });
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
            title: const Text('Auto Responder'),
            backgroundColor: AppColors.surface,
            iconTheme: const IconThemeData(color: AppColors.textPrimary)),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          padding: const EdgeInsets.all(16),
                          decoration: _cardDeco(),
                          child: Row(children: [
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text('Auto Responder',
                                      style: AppTextStyles.h4),
                                  const SizedBox(height: 4),
                                  Text('Auto-reply when a ticket is created',
                                      style: AppTextStyles.caption)
                                ])),
                            Switch(
                                value: _enabled,
                                activeThumbColor: AppColors.primary,
                                activeTrackColor:
                                    AppColors.primary.withValues(alpha: 0.4),
                                onChanged: (v) => setState(() => _enabled = v))
                          ])),
                      if (_enabled) ...[
                        const SizedBox(height: 14),
                        Text('Auto-reply message', style: AppTextStyles.label),
                        const SizedBox(height: 8),
                        TextField(
                            controller: _msgCtrl,
                            maxLines: 5,
                            decoration: _inp('Your auto-reply message...',
                                icon: Icons.message_outlined))
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton(
                              onPressed: _saving
                                  ? null
                                  : () async {
                                      setState(() => _saving = true);
                                      final ok = await _api.setAutoResponder(
                                          _enabled, _msgCtrl.text);
                                      setState(() => _saving = false);
                                      _snack(
                                          context, ok ? 'Saved' : 'Save failed',
                                          error: !ok);
                                    },
                              child: _saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2))
                                  : const Text('Save Settings',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700)))),
                    ])),
      );
}

// â”€â”€â”€ Canned Responses â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _CannedResponsesScreen extends StatefulWidget {
  const _CannedResponsesScreen();
  @override
  State<_CannedResponsesScreen> createState() => _CannedResponsesScreenState();
}

class _CannedResponsesScreenState extends State<_CannedResponsesScreen> {
  final _api = AdminService();
  List<Map<String, dynamic>> _responses = [];
  List<Map<String, dynamic>> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait<dynamic>([
      _api.getCannedResponses(),
      _api.getCategories(),
    ]);
    _responses = List<Map<String, dynamic>>.from(results[0] as List);
    _categories = List<Map<String, dynamic>>.from(results[1] as List)
        .where((category) =>
            (category['isActive'] ?? category['active'] ?? true) != false)
        .toList(growable: false);
    if (mounted) setState(() => _loading = false);
  }

  void _addSheet() {
    final tc = TextEditingController(), cc = TextEditingController();
    String? selectedCategory =
        _categories.isNotEmpty ? _categories.first['name']?.toString() : null;
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => StatefulBuilder(
              builder: (context, setSheetState) => Padding(
                  padding: EdgeInsets.only(
                      left: 20,
                      right: 20,
                      top: 20,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 20),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('Add Canned Response', style: AppTextStyles.h3),
                    const SizedBox(height: 16),
                    TextField(
                        controller: tc,
                        textCapitalization: TextCapitalization.sentences,
                        inputFormatters: [_leadingLetterFormatter],
                        decoration: _inp('Title *', icon: Icons.title_rounded)),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      isExpanded: true,
                      decoration:
                          _inp('Category *', icon: Icons.label_outline_rounded),
                      items: _categories
                          .map((category) => DropdownMenuItem<String>(
                                value: category['name']?.toString(),
                                child: Text(category['name']?.toString() ?? ''),
                              ))
                          .toList(growable: false),
                      onChanged: (value) =>
                          setSheetState(() => selectedCategory = value),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                        controller: cc,
                        maxLines: 4,
                        decoration: _inp('Response content *',
                            icon: Icons.message_outlined)),
                    const SizedBox(height: 16),
                    SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                            onPressed: () async {
                              final title = tc.text.trim();
                              final content = cc.text.trim();
                              if (title.isEmpty ||
                                  content.isEmpty ||
                                  selectedCategory == null ||
                                  selectedCategory!.isEmpty) {
                                _snack(context,
                                    'Title, category, and content are required',
                                    error: true);
                                return;
                              }
                              final ok = await _api.createCannedResponse(
                                title,
                                content,
                                selectedCategory,
                              );
                              if (ok && mounted) {
                                Navigator.pop(context);
                                _load();
                              }
                            },
                            child: const Text('Add Response',
                                style:
                                    TextStyle(fontWeight: FontWeight.w700)))),
                  ])),
            ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
            title: const Text('Canned Responses'),
            backgroundColor: AppColors.surface,
            iconTheme: const IconThemeData(color: AppColors.textPrimary),
            actions: [
              IconButton(
                  icon: const Icon(Icons.add_rounded), onPressed: _addSheet)
            ]),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _responses.isEmpty
                ? const EmptyState(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'No canned responses')
                : ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: _responses.length,
                    itemBuilder: (_, i) {
                      final r = _responses[i];
                      return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: _cardDeco(),
                          child: ListTile(
                            leading: Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                    color:
                                        AppColors.info.withValues(alpha: 0.1),
                                    shape: BoxShape.circle),
                                child: const Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    color: AppColors.info,
                                    size: 16)),
                            title:
                                Text(r['title'] ?? '', style: AppTextStyles.h4),
                            subtitle: Text(r['content'] ?? '',
                                style: AppTextStyles.caption,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                            trailing: IconButton(
                                icon: const Icon(Icons.delete_outline_rounded,
                                    color: Color(0xFFDC2626), size: 18),
                                onPressed: () async {
                                  await _api.deleteCannedResponse(r['id']);
                                  _load();
                                }),
                          ));
                    }),
      );
}

// â”€â”€â”€ Categories â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _CategoriesScreen extends StatefulWidget {
  const _CategoriesScreen();
  @override
  State<_CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<_CategoriesScreen> {
  final _api = AdminService();
  List<Map<String, dynamic>> _cats = [];
  final Map<int, Map<String, dynamic>> _inactiveCats = {};
  bool _loading = true;

  bool _isCatActive(Map<String, dynamic> category) =>
      category['active'] == true || category['isActive'] == true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final active = List<Map<String, dynamic>>.from(await _api.getCategories());
    final merged = <Map<String, dynamic>>[
      ...active,
      ..._inactiveCats.values.where((item) => !active
          .any((activeItem) => _toInt(activeItem['id']) == _toInt(item['id']))),
    ];
    merged.sort((a, b) {
      final aActive = _isCatActive(a);
      final bActive = _isCatActive(b);
      if (aActive != bActive) return aActive ? -1 : 1;
      return (a['name'] ?? '')
          .toString()
          .compareTo((b['name'] ?? '').toString());
    });
    _cats = merged;
    if (mounted) setState(() => _loading = false);
  }

  void _addSheet() {
    final nc = TextEditingController(), dc = TextEditingController();
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => Padding(
            padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Add Category', style: AppTextStyles.h3),
              const SizedBox(height: 16),
              TextField(
                  controller: nc,
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: [_leadingLetterFormatter],
                  decoration: _inp('Category name *',
                      icon: Icons.label_outline_rounded)),
              const SizedBox(height: 10),
              TextField(
                  controller: dc,
                  decoration: _inp('Description (optional)',
                      icon: Icons.description_outlined)),
              const SizedBox(height: 16),
              SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                      onPressed: () async {
                        if (nc.text.isEmpty) return;
                        final ok = await _api.createCategory(
                            nc.text, dc.text.isNotEmpty ? dc.text : null);
                        if (ok && mounted) {
                          Navigator.pop(context);
                          _load();
                        }
                      },
                      child: const Text('Add Category'))),
            ])));
  }

  Future<void> _toggleCategory(Map<String, dynamic> category) async {
    final id = _toInt(category['id']);
    if (id == null) return;
    final originalActive = _isCatActive(category);
    final nextActive = !originalActive;
    setState(() {
      _cats = _cats
          .map((item) => _toInt(item['id']) == id
              ? {...item, 'active': nextActive, 'isActive': nextActive}
              : item)
          .toList();
      if (nextActive) {
        _inactiveCats.remove(id);
      } else {
        _inactiveCats[id] = {...category, 'active': false, 'isActive': false};
      }
    });
    final ok = await _api.toggleCategory(id);
    if (!ok) {
      if (!mounted) return;
      setState(() {
        _cats = _cats
            .map((item) => _toInt(item['id']) == id
                ? {
                    ...item,
                    'active': originalActive,
                    'isActive': originalActive
                  }
                : item)
            .toList();
        if (originalActive) {
          _inactiveCats.remove(id);
        } else {
          _inactiveCats[id] = {...category, 'active': false, 'isActive': false};
        }
      });
      _snack(context, 'Category status update failed', error: true);
      return;
    }
    if (!nextActive)
      _inactiveCats[id] = {...category, 'active': false, 'isActive': false};
    if (mounted)
      _snack(context,
          nextActive ? 'Category activated' : 'Category moved to inactive');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
            title: const Text('Ticket Categories'),
            backgroundColor: AppColors.surface,
            iconTheme: const IconThemeData(color: AppColors.textPrimary),
            actions: [
              IconButton(
                  icon: const Icon(Icons.add_rounded), onPressed: _addSheet)
            ]),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _cats.isEmpty
                ? const EmptyState(
                    icon: Icons.label_outline_rounded, title: 'No categories')
                : ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: _cats.length,
                    itemBuilder: (_, i) {
                      final c = _cats[i];
                      final isActive = _isCatActive(c);
                      return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: _cardDeco(),
                          child: ListTile(
                            leading: Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                    color: (isActive
                                            ? const Color(0xFF059669)
                                            : AppColors.textMuted)
                                        .withValues(alpha: 0.1),
                                    shape: BoxShape.circle),
                                child: Icon(Icons.label_rounded,
                                    color: isActive
                                        ? const Color(0xFF059669)
                                        : AppColors.textMuted,
                                    size: 17)),
                            title:
                                Text(c['name'] ?? '', style: AppTextStyles.h4),
                            subtitle: c['description'] != null
                                ? Text(c['description'],
                                    style: AppTextStyles.caption)
                                : null,
                            trailing: Switch(
                                value: isActive,
                                activeThumbColor: const Color(0xFF059669),
                                activeTrackColor: const Color(0xFF059669)
                                    .withValues(alpha: 0.4),
                                onChanged: (_) => _toggleCategory(c)),
                          ));
                    }),
      );
}

// â”€â”€â”€ Subscription Plans â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _PlansScreen extends StatefulWidget {
  const _PlansScreen();
  @override
  State<_PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<_PlansScreen> {
  final _api = AdminService();
  List<Map<String, dynamic>> _plans = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _plans = List<Map<String, dynamic>>.from(await _api.getSubscriptionPlans());
    if (mounted) setState(() => _loading = false);
  }

  void _addSheet() {
    final nc = TextEditingController(),
        oc = TextEditingController(),
        dc = TextEditingController(),
        fc = TextEditingController(),
        tc = TextEditingController();
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => Padding(
            padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20),
            child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('New Plan', style: AppTextStyles.h3),
              const SizedBox(height: 16),
              TextField(
                  controller: nc,
                  decoration:
                      _inp('Plan name *', icon: Icons.card_membership_rounded)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: TextField(
                        controller: oc,
                        keyboardType: TextInputType.number,
                        decoration:
                            _inp('Original price (Rs) *', prefix: 'Rs '))),
                const SizedBox(width: 10),
                Expanded(
                    child: TextField(
                        controller: dc,
                        keyboardType: TextInputType.number,
                        decoration:
                            _inp('Discount amount (Rs)', prefix: 'Rs ')))
              ]),
              const SizedBox(height: 10),
              TextField(
                  controller: fc,
                  decoration: _inp('Features (comma-separated)',
                      icon: Icons.star_outline_rounded)),
              const SizedBox(height: 10),
              TextField(
                  controller: tc,
                  decoration:
                      _inp('Tag (e.g. Popular)', icon: Icons.sell_outlined)),
              const SizedBox(height: 16),
              SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                      onPressed: () async {
                        if (nc.text.isEmpty || oc.text.isEmpty) return;
                        final original = double.tryParse(oc.text) ?? 0;
                        final discountInput = double.tryParse(dc.text) ?? 0;
                        final discount = dc.text.trim().isEmpty
                            ? original
                            : (discountInput <= original
                                ? (original - discountInput)
                                : discountInput);
                        final ok = await _api.addSubscriptionPlan({
                          'name': nc.text.trim(),
                          'originalPrice': original,
                          'discountPrice': discount,
                          if (fc.text.isNotEmpty) 'features': fc.text.trim(),
                          if (tc.text.isNotEmpty) 'tag': tc.text.trim()
                        });
                        if (ok && mounted) {
                          Navigator.pop(context);
                          _load();
                        }
                      },
                      child: const Text('Create Plan'))),
            ]))));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
            title: const Text('Subscription Plans'),
            backgroundColor: AppColors.surface,
            iconTheme: const IconThemeData(color: AppColors.textPrimary),
            actions: [
              IconButton(
                  icon: const Icon(Icons.add_rounded), onPressed: _addSheet)
            ]),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _plans.isEmpty
                ? const EmptyState(
                    icon: Icons.card_membership_outlined,
                    title: 'No plans created')
                : ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: _plans.length,
                    itemBuilder: (_, i) {
                      final p = _plans[i];
                      final originalPrice = _toDouble(p['originalPrice']);
                      final discountPrice =
                          _toDouble(p['discountPrice'] ?? p['originalPrice']);
                      final hasDiscount = discountPrice < originalPrice;
                      return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: _cardDeco(),
                          child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(children: [
                                Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    child: const Icon(
                                        Icons.card_membership_rounded,
                                        color: AppColors.primary,
                                        size: 20)),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Row(children: [
                                        Text(p['name'] ?? '',
                                            style: AppTextStyles.h4),
                                        if (p['tag'] != null) ...[
                                          const SizedBox(width: 6),
                                          _chip(
                                              p['tag'], const Color(0xFFF59E0B))
                                        ]
                                      ]),
                                      const SizedBox(height: 4),
                                      if (p['discountPrice'] != null &&
                                          p['discountPrice'] !=
                                              p['originalPrice'])
                                        Row(children: [
                                          Text(
                                              'Rs ${discountPrice.toStringAsFixed(2)}',
                                              style: AppTextStyles.label
                                                  .copyWith(
                                                      color: const Color(
                                                          0xFF059669),
                                                      fontWeight:
                                                          FontWeight.w700)),
                                          const SizedBox(width: 6),
                                          Text(
                                              'Rs ${originalPrice.toStringAsFixed(2)}',
                                              style: AppTextStyles.caption
                                                  .copyWith(
                                                      decoration: TextDecoration
                                                          .lineThrough))
                                        ])
                                      else
                                        Text(
                                            'Rs ${originalPrice.toStringAsFixed(2)}',
                                            style: AppTextStyles.label.copyWith(
                                                color: const Color(0xFF059669),
                                                fontWeight: FontWeight.w700)),
                                      if (p['features'] != null)
                                        Text(p['features'],
                                            style: AppTextStyles.caption,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                    ])),
                                IconButton(
                                    icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: Color(0xFFDC2626),
                                        size: 18),
                                    onPressed: () async {
                                      final ok = await showDialog<bool>(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                                  title: const Text(
                                                      'Delete Plan?'),
                                                  content: Text(
                                                      'Delete "${p['name']}"?'),
                                                  actions: [
                                                    TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                context, false),
                                                        child: const Text(
                                                            'Cancel')),
                                                    FilledButton(
                                                        style: FilledButton
                                                            .styleFrom(
                                                                backgroundColor:
                                                                    const Color(
                                                                        0xFFDC2626)),
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                context, true),
                                                        child: const Text(
                                                            'Delete'))
                                                  ]));
                                      if (ok == true) {
                                        await _api
                                            .deleteSubscriptionPlan(p['id']);
                                        _load();
                                      }
                                    }),
                              ])));
                    }),
      );
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// â”€â”€ 16. USER MANAGEMENT â€” GET/DELETE /api/users
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class _UserManagementTab extends StatefulWidget {
  const _UserManagementTab();
  @override
  State<_UserManagementTab> createState() => _UserManagementTabState();
}

class _UserManagementTabState extends State<_UserManagementTab> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String _roleFilter = 'ALL', _search = '';
  static const _roles = [
    'ALL',
    'GUEST',
    'MEMBER',
    'SUBSCRIBER',
    'CONSULTANT',
    'ADMIN'
  ];
  Timer? _pollTimer;

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
      if (_roleFilter == 'ALL') {
        final users = await UserService().getAllUsers(size: 200);
        _users = users.map((u) => u.toJson()).toList();
      } else {
        final users = await UserService().getUsersByRole(_roleFilter);
        _users = users.map((u) => u.toJson()).toList();
      }
    } catch (_) {
      _users = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _delete(Map<String, dynamic> user) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Text('Delete User?'),
              content: Text(
                  'This will permanently delete ${user['identifier'] ?? 'this user'}.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626)),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Delete'))
              ],
            ));
    if (ok != true) return;
    try {
      final success = await UserService().deleteUser(user['id']);
      if (success) {
        _snack(context, 'User deleted');
        _load();
      } else {
        _snack(context, 'Delete failed', error: true);
      }
    } catch (_) {
      _snack(context, 'Delete failed', error: true);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return _users;
    return _users
        .where((u) =>
            (u['identifier'] ?? '')
                .toLowerCase()
                .contains(_search.toLowerCase()) ||
            (u['role'] ?? '').toLowerCase().contains(_search.toLowerCase()))
        .toList();
  }

  Color _roleColor(String role) {
    switch (role.toUpperCase()) {
      case 'ADMIN':
        return const Color(0xFFDC2626);
      case 'CONSULTANT':
        return const Color(0xFF7C3AED);
      case 'SUBSCRIBER':
        return const Color(0xFF059669);
      case 'MEMBER':
        return AppColors.primaryLight;
      default:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
            title: Text('User Management (${_users.length})',
                style: const TextStyle(
                    color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
            backgroundColor: AppColors.surface,
            iconTheme: const IconThemeData(color: AppColors.textPrimary),
            actions: [
              IconButton(
                  icon: const Icon(Icons.refresh_rounded), onPressed: _load)
            ]),
        body: Column(children: [
          Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              child: Column(children: [
                TextField(
                    onChanged: (v) => setState(() => _search = v),
                    decoration: _inp('Search by email or role...',
                        icon: Icons.search_rounded)),
                const SizedBox(height: 10),
                SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                        children: _roles
                            .map((r) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: GestureDetector(
                                    onTap: () {
                                      setState(() => _roleFilter = r);
                                      _load();
                                    },
                                    child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 150),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                            color: _roleFilter == r
                                                ? AppColors.primaryLight
                                                : AppColors.surfaceVariant,
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                                color: _roleFilter == r
                                                    ? AppColors.primaryLight
                                                    : AppColors.border)),
                                        child: Text(r,
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: _roleFilter == r
                                                    ? Colors.white
                                                    : AppColors
                                                        .textSecondary))))))
                            .toList())),
              ])),
          Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filtered.isEmpty
                      ? const EmptyState(
                          icon: Icons.people_outline_rounded,
                          title: 'No users found')
                      : RefreshIndicator(
                          onRefresh: () => _load(),
                          child: ListView.builder(
                              padding: const EdgeInsets.all(14),
                              itemCount: _filtered.length,
                              itemBuilder: (_, i) {
                                final u = _filtered[i];
                                final role = (u['role'] ?? 'GUEST').toString();
                                return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: _cardDeco(),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                          radius: 20,
                                          backgroundColor: _roleColor(role)
                                              .withValues(alpha: 0.1),
                                          child: Text(
                                              (u['identifier'] ?? '?')[0]
                                                  .toUpperCase(),
                                              style: TextStyle(
                                                  color: _roleColor(role),
                                                  fontWeight:
                                                      FontWeight.w700))),
                                      title: Text(u['identifier'] ?? 'Unknown',
                                          style: AppTextStyles.label),
                                      subtitle: Row(children: [
                                        _chip(role, _roleColor(role)),
                                        if (u['consultantId'] != null) ...[
                                          const SizedBox(width: 6),
                                          _chip(
                                              'Consultant #${u['consultantId']}',
                                              AppColors.info)
                                        ]
                                      ]),
                                      trailing: IconButton(
                                          icon: const Icon(
                                              Icons.delete_outline_rounded,
                                              color: Color(0xFFDC2626),
                                              size: 18),
                                          onPressed: () => _delete(u)),
                                    ));
                              }))),
        ]),
      );
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// â”€â”€ 17. PROFILE & SECURITY SCREEN
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class _ProfileSecurityScreen extends StatefulWidget {
  const _ProfileSecurityScreen();
  @override
  State<_ProfileSecurityScreen> createState() => _ProfileSecurityScreenState();
}

class _ProfileSecurityScreenState extends State<_ProfileSecurityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Account Settings',
              style: TextStyle(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
          backgroundColor: AppColors.surface,
          iconTheme: const IconThemeData(color: AppColors.textPrimary),
          bottom: TabBar(
              controller: _tabs,
              labelColor: AppColors.primaryLight,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: AppColors.primaryLight,
              tabs: const [
                Tab(
                    icon: Icon(Icons.person_outline_rounded, size: 18),
                    text: 'Profile'),
                Tab(
                    icon: Icon(Icons.notifications_outlined, size: 18),
                    text: 'Notifications'),
                Tab(
                    icon: Icon(Icons.lock_outline_rounded, size: 18),
                    text: 'Security')
              ]),
        ),
        body: TabBarView(controller: _tabs, children: [
          const AdminProfileSettingsScreen(),
          const _NotificationSettingsTab(),
          _PasswordForm(),
        ]),
      );
}

class _ProfileForm extends StatefulWidget {
  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  final _nameC = TextEditingController(),
      _locC = TextEditingController(),
      _emailC = TextEditingController(),
      _phoneC = TextEditingController();
  bool _loading = true, _saving = false;
  int? _userId;
  String? _profileImageUrl;
  String? _memberSince;
  String? _role;
  String? _currentPlanName;
  List<Map<String, dynamic>> _plans = [];
  int? _selectedPlanId;
  XFile? _pickedImage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameC.dispose();
    _locC.dispose();
    _emailC.dispose();
    _phoneC.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final me = await UserService().getMe();
      if (me == null) throw 'User not found';
      _userId = me.id;
      _role = me.role;
      _emailC.text = me.identifier ?? '';

      if (_userId != null) {
        try {
          final data = await OnboardingService().getProfile(_userId!);
          if (data != null) {
            _nameC.text = data.name;
            _locC.text = data.location ?? '';
            if ((data.email ?? '').trim().isNotEmpty)
              _emailC.text = data.email ?? '';
            _phoneC.text = data.phoneNumber ?? '';
            _profileImageUrl =
                data.photoUrl?.trim().isEmpty ?? true ? null : data.photoUrl;
            // createdAt not on OnboardingProfile â€” leave _memberSince as-is
            if (data.subscriptionPlanId != null) {
              _selectedPlanId = data.subscriptionPlanId;
              // subscriptionPlanName not on OnboardingProfile â€” resolve from plans list below
            }
          }
        } catch (_) {}
      }

      try {
        _plans = await AdminService().getSubscriptionPlans();
        // Resolve plan name from id now that plans are loaded
        if (_selectedPlanId != null && _currentPlanName == null) {
          final matched = _plans.firstWhere(
            (p) => (p['id'] as num?)?.toInt() == _selectedPlanId,
            orElse: () => <String, dynamic>{},
          );
          if (matched.isNotEmpty) {
            _currentPlanName = matched['name']?.toString();
          }
        }
      } catch (_) {
        _plans = [];
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image == null || !mounted) return;
    setState(() => _pickedImage = image);
  }

  Future<void> _save() async {
    if ((_nameC.text).trim().isEmpty) {
      _snack(context, 'Full name is required', error: true);
      return;
    }
    if (_emailC.text.trim().isEmpty || !_emailC.text.contains('@')) {
      _snack(context, 'Enter a valid email', error: true);
      return;
    }
    if (_phoneC.text.trim().isEmpty ||
        !RegExp(r'^\d{10}$').hasMatch(_phoneC.text.trim())) {
      _snack(context, 'Phone number must be 10 digits', error: true);
      return;
    }
    if (_userId == null) {
      _snack(context, 'User profile could not be loaded', error: true);
      return;
    }

    setState(() => _saving = true);
    try {
      final data = {
        'name': _nameC.text.trim(),
        'location': _locC.text.trim(),
        'email': _emailC.text.trim().toLowerCase(),
        'phoneNumber': _phoneC.text.trim(),
        if (_selectedPlanId != null)
          'subscriptionPlanId': _selectedPlanId.toString(),
      };

      MultipartFile? file;
      if (_pickedImage != null) {
        file = await MultipartFile.fromFile(_pickedImage!.path,
            filename: _pickedImage!.name);
      }

      final ok = await OnboardingService()
          .updateProfile(_userId!, data, profilePhoto: file);
      if (ok) {
        _profileImageUrl = _pickedImage?.path ?? _profileImageUrl;
        _pickedImage = null;
        if (mounted) {
          _snack(context, 'Profile updated');
          _load();
        }
      } else {
        throw 'Update failed';
      }
    } catch (error) {
      if (mounted)
        _snack(context, _apiError(error, fallback: 'Profile update failed'),
            error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  ImageProvider? _profileImageProvider() {
    if (_pickedImage != null) return FileImage(File(_pickedImage!.path));
    if (_profileImageUrl == null || _profileImageUrl!.isEmpty) return null;
    if (_profileImageUrl!.startsWith('http'))
      return NetworkImage(_profileImageUrl!);
    return FileImage(File(_profileImageUrl!));
  }

  @override
  Widget build(BuildContext context) => _loading
      ? const Center(child: CircularProgressIndicator())
      : SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(
                child: Stack(alignment: Alignment.bottomRight, children: [
              CircleAvatar(
                  radius: 50,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  backgroundImage: _profileImageProvider(),
                  child: _profileImageProvider() == null
                      ? const Icon(Icons.person_rounded,
                          size: 50, color: AppColors.primary)
                      : null),
              GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2)),
                      child: const Icon(Icons.camera_alt_rounded,
                          size: 14, color: Colors.white))),
            ])),
            const SizedBox(height: 24),
            TextField(
                controller: _nameC,
                decoration:
                    _inp('Full Name', icon: Icons.person_outline_rounded)),
            const SizedBox(height: 12),
            TextField(
                controller: _emailC,
                keyboardType: TextInputType.emailAddress,
                decoration: _inp('Email', icon: Icons.email_outlined)),
            const SizedBox(height: 12),
            TextField(
                controller: _phoneC,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10)
                ],
                decoration: _inp('Phone Number', icon: Icons.phone_outlined)),
            const SizedBox(height: 12),
            TextField(
                controller: _locC,
                decoration: _inp('Location', icon: Icons.location_on_outlined)),
            if (_plans.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _selectedPlanId,
                decoration: _inp('Subscription Plan',
                    icon: Icons.card_membership_rounded),
                items: _plans
                    .where((plan) => _toInt(plan['id']) != null)
                    .map((plan) => DropdownMenuItem<int>(
                        value: _toInt(plan['id'])!,
                        child: Text(
                            '${plan['name']} (Rs ${_toDouble(plan['discountPrice'] ?? plan['originalPrice']).toStringAsFixed(0)})')))
                    .toList(),
                onChanged: (value) => setState(() => _selectedPlanId = value),
              ),
            ],
            const SizedBox(height: 18),
            Container(
                padding: const EdgeInsets.all(14),
                decoration: _cardDeco(),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if ((_role ?? '').isNotEmpty) _info('Role', _role!),
                      if ((_currentPlanName ?? '').isNotEmpty)
                        _info('Current Plan', _currentPlanName!),
                      if ((_memberSince ?? '').isNotEmpty)
                        _info('Member Since', _fmtDate(_memberSince)),
                    ])),
            const SizedBox(height: 20),
            SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Save Profile'))),
          ]));

  Widget _info(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          SizedBox(
              width: 110, child: Text(label, style: AppTextStyles.caption)),
          Expanded(child: Text(value, style: AppTextStyles.label)),
        ]),
      );
}

class _NotificationSettingsTab extends StatefulWidget {
  const _NotificationSettingsTab();
  @override
  State<_NotificationSettingsTab> createState() =>
      _NotificationSettingsTabState();
}

class _NotificationSettingsTabState extends State<_NotificationSettingsTab> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final svc = context.read<NotificationService>();
      await svc.refresh();
      _items = svc.notifications.map((n) => n.toJson()).toList();
    } catch (_) {
      _items = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _markRead(int id) async {
    final svc = context.read<NotificationService>();
    await svc.markAsRead(id);
    _items = svc.notifications.map((n) => n.toJson()).toList();
    if (mounted) setState(() {});
  }

  Future<void> _markAllRead() async {
    final svc = context.read<NotificationService>();
    await svc.markAllRead();
    _items = svc.notifications.map((n) => n.toJson()).toList();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final unread = _items
        .where((item) => item['isRead'] != true && item['read'] != true)
        .length;
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(children: [
                  Expanded(
                      child: _StatCard(
                          title: 'Unread',
                          value: '$unread',
                          icon: Icons.mark_email_unread_outlined,
                          color: const Color(0xFF7C3AED))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _StatCard(
                          title: 'Inbox',
                          value: '${_items.length}',
                          icon: Icons.notifications_outlined,
                          color: AppColors.primaryLight)),
                ]),
                const SizedBox(height: 16),
                if (unread > 0)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                        onPressed: _markAllRead,
                        icon: const Icon(Icons.done_all_rounded, size: 16),
                        label: const Text('Mark all read')),
                  ),
                if (_items.isEmpty)
                  const EmptyState(
                      icon: Icons.notifications_none_rounded,
                      title: 'No notifications',
                      subtitle: 'Live notification updates will appear here')
                else
                  ..._items.map((item) {
                    final read = item['isRead'] == true || item['read'] == true;
                    final id = _toInt(item['id']) ?? 0;
                    final title =
                        item['type']?.toString().replaceAll('_', ' ') ??
                            'Notification';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: _cardDeco(
                          border: read
                              ? AppColors.border
                              : AppColors.primaryLight.withValues(alpha: 0.25)),
                      child: ListTile(
                        onTap: read ? null : () => _markRead(id),
                        leading: CircleAvatar(
                          backgroundColor: (read
                                  ? AppColors.textMuted
                                  : AppColors.primaryLight)
                              .withValues(alpha: 0.12),
                          child: Icon(
                              read
                                  ? Icons.notifications_none_rounded
                                  : Icons.notifications_active_outlined,
                              color: read
                                  ? AppColors.textMuted
                                  : AppColors.primaryLight,
                              size: 18),
                        ),
                        title: Text(title,
                            style: AppTextStyles.label.copyWith(
                                fontWeight:
                                    read ? FontWeight.w600 : FontWeight.w700)),
                        subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                  (item['body'] ?? item['message'] ?? '')
                                      .toString(),
                                  style: AppTextStyles.bodySmall),
                              if ((item['createdAt'] ?? '')
                                  .toString()
                                  .isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(_fmtDateTime(item['createdAt']),
                                    style: AppTextStyles.caption),
                              ],
                            ]),
                        trailing: read
                            ? const Icon(Icons.done_rounded,
                                color: Color(0xFF059669), size: 18)
                            : TextButton(
                                onPressed: () => _markRead(id),
                                child: const Text('Read')),
                      ),
                    );
                  }),
              ],
            ),
          );
  }
}

class _PasswordForm extends StatefulWidget {
  @override
  State<_PasswordForm> createState() => _PasswordFormState();
}

class _PasswordFormState extends State<_PasswordForm> {
  final _newC = TextEditingController(), _confC = TextEditingController();
  bool _saving = false, _showNew = false, _showConf = false;

  @override
  void dispose() {
    _newC.dispose();
    _confC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),
        Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.info.withValues(alpha: 0.3))),
            child: const Row(children: [
              Icon(Icons.info_outline_rounded, color: AppColors.info, size: 16),
              SizedBox(width: 8),
              Expanded(
                  child: Text('Password must be at least 8 characters.',
                      style: TextStyle(color: AppColors.info, fontSize: 12)))
            ])),
        const SizedBox(height: 16),
        TextField(
            controller: _newC,
            obscureText: !_showNew,
            decoration: _inp('New Password',
                icon: Icons.lock_outline_rounded,
                suffix: IconButton(
                    icon: Icon(
                        _showNew
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 18,
                        color: AppColors.textSecondary),
                    onPressed: () => setState(() => _showNew = !_showNew)))),
        const SizedBox(height: 12),
        TextField(
            controller: _confC,
            obscureText: !_showConf,
            decoration: _inp('Confirm Password',
                icon: Icons.lock_outline_rounded,
                suffix: IconButton(
                    icon: Icon(
                        _showConf
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 18,
                        color: AppColors.textSecondary),
                    onPressed: () => setState(() => _showConf = !_showConf)))),
        const SizedBox(height: 20),
        SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: _saving
                  ? null
                  : () async {
                      if (_newC.text.length < 8) {
                        _snack(context, 'Min 8 characters required',
                            error: true);
                        return;
                      }
                      if (_newC.text != _confC.text) {
                        _snack(context, 'Passwords do not match', error: true);
                        return;
                      }
                      setState(() => _saving = true);
                      try {
                        final res = await AuthService().changePassword(
                            newPassword: _newC.text,
                            confirmPassword: _confC.text);
                        if (res.success) {
                          _newC.clear();
                          _confC.clear();
                          _snack(context, 'Password changed successfully',
                              icon: Icons.lock_rounded);
                        } else {
                          throw res.error ?? 'Change failed';
                        }
                      } catch (error) {
                        _snack(context, error.toString(), error: true);
                      } finally {
                        if (mounted) setState(() => _saving = false);
                      }
                    },
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Change Password'),
            )),
      ]));
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// â”€â”€ 18. SLA BREACHED SCREEN â€” GET /api/tickets/sla-breached
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class SlaBreachedScreen extends StatefulWidget {
  const SlaBreachedScreen({super.key});
  @override
  State<SlaBreachedScreen> createState() => _SlaBreachedScreenState();
}

class _SlaBreachedScreenState extends State<SlaBreachedScreen> {
  final _ts = TicketService();
  List<Ticket> _tickets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _tickets = await _ts.getSlaBreachedTickets();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Row(children: [
            const Text('SLA Breached',
                style: TextStyle(
                    color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
            if (_tickets.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                      color: const Color(0xFFDC2626),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text('${_tickets.length}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)))
            ]
          ]),
          backgroundColor: AppColors.surface,
          iconTheme: const IconThemeData(color: AppColors.textPrimary),
          actions: [
            IconButton(
                icon: const Icon(Icons.refresh_rounded), onPressed: _load)
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _tickets.isEmpty
                ? const EmptyState(
                    icon: Icons.timer_off_rounded,
                    title: 'No SLA breaches',
                    subtitle: 'All tickets are within SLA')
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                        padding: const EdgeInsets.all(14),
                        itemCount: _tickets.length,
                        itemBuilder: (_, i) {
                          final t = _tickets[i];
                          final sla = _calcSla(t);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(14),
                                border:
                                    Border.all(color: const Color(0xFFFECACA)),
                                boxShadow: [
                                  BoxShadow(
                                      color: const Color(0xFFDC2626)
                                          .withValues(alpha: 0.05),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2))
                                ]),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    const Icon(Icons.timer_off_rounded,
                                        color: Color(0xFFDC2626), size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        child: Text(
                                            '${formatTicketNumberFromTicket(t)} - ${t.category}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13))),
                                    _chip(t.status, getStatusColor(t.status)),
                                  ]),
                                  const SizedBox(height: 6),
                                  Text(t.description ?? '',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary)),
                                  const SizedBox(height: 8),
                                  Row(children: [
                                    Icon(Icons.flag_rounded,
                                        size: 13,
                                        color: getPriorityColor(t.priority)),
                                    const SizedBox(width: 4),
                                    Text(t.priority,
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color:
                                                getPriorityColor(t.priority))),
                                    const Spacer(),
                                    if (sla != null)
                                      Text(sla.label,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFFB91C1C))),
                                  ]),
                                ]),
                          );
                        })),
      );
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// â”€â”€ 19. ESCALATED TICKETS SCREEN â€” GET /api/tickets/escalated
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class EscalatedTicketsScreen extends StatefulWidget {
  const EscalatedTicketsScreen({super.key});
  @override
  State<EscalatedTicketsScreen> createState() => _EscalatedTicketsScreenState();
}

class _EscalatedTicketsScreenState extends State<EscalatedTicketsScreen> {
  final _ts = TicketService();
  List<Ticket> _tickets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _tickets = await _ts.getEscalatedTickets();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Row(children: [
            const Text('Escalated Tickets',
                style: TextStyle(
                    color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
            if (_tickets.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF97316),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text('${_tickets.length}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)))
            ]
          ]),
          backgroundColor: AppColors.surface,
          iconTheme: const IconThemeData(color: AppColors.textPrimary),
          actions: [
            IconButton(
                icon: const Icon(Icons.refresh_rounded), onPressed: _load)
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _tickets.isEmpty
                ? const EmptyState(
                    icon: Icons.escalator_warning_rounded,
                    title: 'No escalated tickets')
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                        padding: const EdgeInsets.all(14),
                        itemCount: _tickets.length,
                        itemBuilder: (_, i) {
                          final t = _tickets[i];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(14),
                                border:
                                    Border.all(color: const Color(0xFFFDE68A))),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    const Icon(Icons.warning_amber_rounded,
                                        color: Color(0xFFF97316), size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        child: Text(
                                            '${formatTicketNumberFromTicket(t)} - ${t.category}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                                color: Color(0xFF92400E)))),
                                    _chip(t.status, getStatusColor(t.status)),
                                  ]),
                                  const SizedBox(height: 6),
                                  Text(t.description ?? '',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary)),
                                  const SizedBox(height: 8),
                                  Row(children: [
                                    Icon(Icons.flag_rounded,
                                        size: 13,
                                        color: getPriorityColor(t.priority)),
                                    const SizedBox(width: 4),
                                    Text(t.priority,
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color:
                                                getPriorityColor(t.priority))),
                                    if (t.createdAt != null) ...[
                                      const Spacer(),
                                      Text(_fmtDate(t.createdAt),
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color: AppColors.textMuted))
                                    ],
                                  ]),
                                ]),
                          );
                        })),
      );
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// â”€â”€ CSV EXPORT SERVICE
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class TicketExportService {
  static Future<void> exportToCsv(
      List<Ticket> tickets, BuildContext context) async {
    try {
      final sb = StringBuffer(
          'ID,Category,Status,Priority,Description,User,Created,Updated\n');
      for (final t in tickets) {
        sb.writeln(
            '${t.id},"${t.category}","${t.status}","${t.priority}","${(t.description ?? '').replaceAll('"', "'")}","${t.userName ?? ''}","${t.createdAt ?? ''}","${t.updatedAt ?? ''}"');
      }
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/tickets_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv');
      await file.writeAsString(sb.toString());
      await Share.shareXFiles([XFile(file.path)],
          subject:
              'Tickets Export - ${DateFormat('d MMM yyyy').format(DateTime.now())}');
    } catch (e) {
      if (context.mounted) _snack(context, 'Export failed: $e', error: true);
    }
  }
}

// â”€â”€ Extension to handle null data responses â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
extension on Object? {
  dynamic get data => null;
}
