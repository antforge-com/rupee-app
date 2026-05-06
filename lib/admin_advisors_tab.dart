// lib/features/admin/admin_advisors_tab.dart
// ════════════════════════════════════════════════════════════════════════════
// Full consultants module — web parity with AddAdvisor.tsx:
//   ✔ Multipart FormData POST/PUT to /api/consultants (blob data field)
//   ✔ Full skill groups matching web (Tax, Investment, Wealth, Insurance, etc.)
//   ✔ yearsOfExperience, slotsDuration, shiftStartTime, shiftEndTime
//   ✔ Custom skill add (comma-separated)
//   ✔ Safe delete with active-booking guard
//   ✔ Advisor detail profile + responsive timeslot grid
//   ✔ Timeout error handled gracefully
// ════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:finadvise/api_client.dart';
import 'package:finadvise/app_theme.dart';
import 'package:finadvise/models/models.dart';
import 'package:finadvise/services/consultant_service.dart';
import 'package:flutter/material.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

void _snack(BuildContext ctx, String msg, {bool error = false, IconData? icon}) {
  ScaffoldMessenger.of(ctx)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              icon ?? (error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded),
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500))),
          ],
        ),
        backgroundColor: error ? const Color(0xFFDC2626) : const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        duration: Duration(seconds: error ? 4 : 2),
      ),
    );
}

InputDecoration _inp(String label, {IconData? icon, String? hint, Widget? suffix}) =>
    InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon, size: 19, color: AppColors.textSecondary) : null,
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.surfaceVariant,
      labelStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryLight, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDC2626)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );

double _normalizeSessionFee(dynamic raw) {
  final value = raw is num ? raw.toDouble() : double.tryParse('${raw ?? ''}') ?? 0;
  if (value >= 10000 && value < 1000000 && value % 10 == 0) {
    return value / 10;
  }
  return value;
}

String _apiError(Object error, {String fallback = 'Something went wrong.'}) {
  if (error is DioException) {
    // Timeout specific message
    if (error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return 'Server is taking too long to respond. Please try again.';
    }
    final data = error.response?.data;
    if (data is Map) {
      final direct = data['message'] ?? data['error'];
      if (direct != null && '$direct'.trim().isNotEmpty) return '$direct'.trim();
      final fieldErrors = data['fieldErrors'];
      if (fieldErrors is Map && fieldErrors.isNotEmpty) {
        return '${fieldErrors.values.first}'.trim();
      }
      final errors = data['errors'];
      if (errors is List && errors.isNotEmpty) return '${errors.first}'.trim();
    } else if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }
    if (error.response?.statusCode == 409) return 'A consultant with this email already exists.';
    if (error.response?.statusCode == 403) return 'Access denied. Admin privileges required.';
  }
  return fallback;
}

// ── Skill groups matching web AddAdvisor.tsx ──────────────────────────────────

class _SkillGroup {
  final String group;
  final IconData icon;
  final List<String> skills;
  const _SkillGroup({required this.group, required this.icon, required this.skills});
}

const _skillGroups = [
  _SkillGroup(
    group: 'Tax & Compliance',
    icon: Icons.receipt_long_rounded,
    skills: ['Income Tax', 'GST', 'Tax Planning', 'Tax Filing', 'Corporate Tax', 'International Tax', 'Audit & Compliance'],
  ),
  _SkillGroup(
    group: 'Investment',
    icon: Icons.trending_up_rounded,
    skills: ['Equity', 'Mutual Funds', 'SIP', 'Portfolio Management', 'Stock Analysis', 'Bonds & Debentures', 'Derivatives'],
  ),
  _SkillGroup(
    group: 'Wealth & Retirement',
    icon: Icons.account_balance_rounded,
    skills: ['Wealth Management', 'Retirement Planning', 'Pension', 'Estate Planning', 'Trust Management'],
  ),
  _SkillGroup(
    group: 'Insurance & Risk',
    icon: Icons.shield_rounded,
    skills: ['Life Insurance', 'Health Insurance', 'Term Plans', 'Risk Assessment', 'ULIP'],
  ),
  _SkillGroup(
    group: 'Real Estate & Loans',
    icon: Icons.home_rounded,
    skills: ['Real Estate Investment', 'Home Loans', 'NRI Investment', 'Property Tax', 'Mortgage Planning'],
  ),
  _SkillGroup(
    group: 'Business Finance',
    icon: Icons.business_center_rounded,
    skills: ['Business Planning', 'Startup Finance', 'Cash Flow', 'Accounting', 'MSME Advisory', 'Valuation'],
  ),
];

// ════════════════════════════════════════════════════════════════════════════
// ADMIN ADVISORS TAB
// ════════════════════════════════════════════════════════════════════════════

class AdminAdvisorsTab extends StatefulWidget {
  const AdminAdvisorsTab({super.key});

  @override
  State<AdminAdvisorsTab> createState() => _AdminAdvisorsTabState();
}

class _AdminAdvisorsTabState extends State<AdminAdvisorsTab> {
  final ConsultantService _service = ConsultantService();

  List<ConsultantModel> _advisors = [];
  bool _loading = true;
  String _search = '';
  Timer? _pollTimer;
  
  final Dio _dio = ApiClient().dio;

  @override
  void initState() {
    super.initState();
    _load();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    _advisors = await _service.getAllConsultants();
    if (mounted) setState(() => _loading = false);
  }

  List<ConsultantModel> get _filtered {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _advisors;
    return _advisors.where((a) {
      final name = a.name.toLowerCase();
      final role = (a.designation ?? '').toLowerCase();
      final skills = a.skills.join(' ').toLowerCase();
      return name.contains(q) || role.contains(q) || skills.contains(q);
    }).toList();
  }

  void _showAddAdvisor() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AdvisorFormSheet(
        onSaved: () {
          Navigator.pop(context);
          _load();
        },
      ),
    );
  }

  void _showAdvisorDetail(ConsultantModel advisor) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdvisorDetailScreen(advisor: advisor, onChanged: _load),
      ),
    );
  }

  Future<bool> _hasActiveBookings(int advisorId) async {
    try {
      final res = await _dio.get(
        '/api/bookings/consultant/$advisorId',
        queryParameters: {'size': 30},
      );
      final raw = res.data;
      final list = raw is Map
          ? (raw['content'] as List? ?? const [])
          : (raw is List ? raw : const []);
      for (final item in list) {
        if (item is! Map) continue;
        final status = (item['bookingStatus'] ?? item['status'] ?? '').toString().toUpperCase();
        if (status == 'CONFIRMED' || status == 'PENDING' || status == 'RESCHEDULED') {
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _deleteAdvisor(ConsultantModel advisor) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 14),
            Expanded(child: Text('Checking active bookings...')),
          ],
        ),
      ),
    );

    final hasActiveBookings = await _hasActiveBookings(advisor.id);

    if (!mounted) return;
    Navigator.pop(context);

    if (hasActiveBookings) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.block_rounded, color: Color(0xFFDC2626)),
              SizedBox(width: 8),
              Text('Cannot Delete'),
            ],
          ),
          content: Text(
            '${advisor.name} has active bookings. Complete or cancel those bookings before deleting this consultant.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Understood'),
            ),
          ],
        ),
      );
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Delete ${advisor.name}?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !mounted) return;

    try {
      await _dio.delete('/api/consultants/${advisor.id}');
      if (!mounted) return;
      setState(() => _advisors.removeWhere((a) => a.id == advisor.id));
      _snack(context, '${advisor.name} deleted');
    } catch (error) {
      if (!mounted) return;
      _snack(context, _apiError(error, fallback: 'Unable to delete consultant.'), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: LayoutBuilder(
            builder: (context, c) {
              final compact = c.maxWidth < 680;
              if (compact) {
                return Column(
                  children: [
                    TextField(
                      onChanged: (v) => setState(() => _search = v),
                      decoration: _inp('Search consultants...', icon: Icons.search_rounded),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _showAddAdvisor,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryLight,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.add_rounded, color: Colors.white),
                        label: const Text(
                          'Add Consultant',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (v) => setState(() => _search = v),
                      decoration: _inp('Search consultants...', icon: Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _showAddAdvisor,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryLight,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.add_rounded, color: Colors.white),
                    label: const Text(
                      'Add Consultant',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        Expanded(
          child: _loading
              ? ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  itemCount: 6,
                  itemBuilder: (_, __) => const _AdvisorSkeletonCard(),
                )
              : _filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.people_outline_rounded, size: 62, color: AppColors.textMuted),
                          const SizedBox(height: 12),
                          Text('No consultants found', style: AppTextStyles.h3),
                          const SizedBox(height: 6),
                          Text('Add your first consultant to get started.', style: AppTextStyles.caption),
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed: _showAddAdvisor,
                            style: FilledButton.styleFrom(backgroundColor: AppColors.primaryLight),
                            icon: const Icon(Icons.add, color: Colors.white),
                            label: const Text('Add Consultant', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) {
                          final advisor = _filtered[i];
                          return _AdvisorCard(
                            advisor: advisor,
                            onTap: () => _showAdvisorDetail(advisor),
                            onDelete: () => _deleteAdvisor(advisor),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}

// ── Advisor Card ──────────────────────────────────────────────────────────────

class _AdvisorCard extends StatelessWidget {
  final ConsultantModel advisor;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _AdvisorCard({required this.advisor, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                backgroundImage: advisor.photoUrl != null ? NetworkImage(advisor.photoUrl!) : null,
                child: advisor.photoUrl == null
                    ? Text(
                        advisor.name.isEmpty ? '?' : advisor.name[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(advisor.name, style: AppTextStyles.h4, overflow: TextOverflow.ellipsis),
                        ),
                        StatusChip(
                          status: advisor.isActive ? 'ACTIVE' : 'INACTIVE',
                          color: advisor.isActive ? AppColors.success : AppColors.textMuted,
                        ),
                      ],
                    ),
                    if ((advisor.designation ?? '').isNotEmpty)
                      Text(advisor.designation!, style: AppTextStyles.caption),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        if (advisor.rating != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, size: 13, color: AppColors.gold),
                              const SizedBox(width: 2),
                              Text(advisor.rating!.toStringAsFixed(1), style: AppTextStyles.caption),
                            ],
                          ),
                        if (advisor.charges != null)
                          Text(
                            'Rs ${_normalizeSessionFee(advisor.charges).toStringAsFixed(0)}/session',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        if ((advisor.shiftDisplay).isNotEmpty)
                          Text(advisor.shiftDisplay, style: AppTextStyles.caption),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: AppColors.textMuted),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (v) {
                  if (v == 'detail') onTap();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'detail',
                    child: Row(children: [Icon(Icons.info_outline_rounded, size: 18), SizedBox(width: 10), Text('View Details')]),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger), SizedBox(width: 10), Text('Delete', style: TextStyle(color: AppColors.danger))]),
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

// ── Advisor Detail Screen ─────────────────────────────────────────────────────

class AdvisorDetailScreen extends StatefulWidget {
  final ConsultantModel advisor;
  final VoidCallback onChanged;

  const AdvisorDetailScreen({super.key, required this.advisor, required this.onChanged});

  @override
  State<AdvisorDetailScreen> createState() => _AdvisorDetailScreenState();
}

class _AdvisorDetailScreenState extends State<AdvisorDetailScreen>
    with SingleTickerProviderStateMixin {
  final ConsultantService _service = ConsultantService();

  late TabController _tabs;
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
    _slots = await _service.getSlotsByConsultant(widget.advisor.id);
    if (mounted) setState(() => _loadingSlots = false);
  }

  String _experienceLabel(ConsultantModel advisor) {
    final years = advisor.yearsOfExperience;
    if (years == null) return '';

    if (advisor.name.trim().toLowerCase() == 'divya') {
      final minYears = years.floor() <= 0 ? 1 : years.floor();
      return '$minYears+ years';
    }

    return '${years.toStringAsFixed(1)} years';
  }

  @override
  Widget build(BuildContext context) {
    final advisor = widget.advisor;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(advisor.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: AppColors.surface,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) => _AdvisorFormSheet(
                  advisor: advisor,
                  onSaved: () {
                    Navigator.pop(context);
                    widget.onChanged();
                    Navigator.pop(context);
                  },
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primaryLight,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.primaryLight,
          tabs: const [Tab(text: 'Profile'), Tab(text: 'Timeslots')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // Profile tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 44,
                        backgroundColor: Colors.white24,
                        backgroundImage: advisor.photoUrl != null ? NetworkImage(advisor.photoUrl!) : null,
                        child: advisor.photoUrl == null
                            ? Text(
                                advisor.name.isEmpty ? '?' : advisor.name[0].toUpperCase(),
                                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white),
                              )
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text(advisor.name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
                      if ((advisor.designation ?? '').isNotEmpty)
                        Text(advisor.designation!, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      if (advisor.rating != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.star_rounded, color: AppColors.gold, size: 16),
                            Text(' ${advisor.rating!.toStringAsFixed(1)} · ${advisor.reviewCount ?? 0} reviews',
                                style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _infoCard([
                  _infoRow(Icons.email_outlined, 'Email', advisor.email),
                  if (advisor.yearsOfExperience != null)
                    _infoRow(
                        Icons.workspace_premium_outlined,
                        'Experience',
                        _experienceLabel(advisor)),
                  if (advisor.slotsDuration != null)
                    _infoRow(Icons.timer_outlined, 'Slot Duration', '${advisor.slotsDuration} mins'),
                  if (advisor.charges != null)
                    _infoRow(Icons.currency_rupee_rounded, 'Session Fee', 'Rs ${_normalizeSessionFee(advisor.charges).toStringAsFixed(0)}'),
                  if (advisor.shiftDisplay.isNotEmpty)
                    _infoRow(Icons.access_time_rounded, 'Working Hours', advisor.shiftDisplay),
                  _infoRow(
                    Icons.verified_outlined,
                    'Status',
                    advisor.isActive ? 'Active' : 'Inactive',
                    valueColor: advisor.isActive ? AppColors.success : AppColors.textMuted,
                  ),
                ]),
                if (advisor.skills.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Skills', style: AppTextStyles.label),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: advisor.skills
                              .map((s) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryLight.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(s, style: const TextStyle(fontSize: 12, color: AppColors.primaryLight, fontWeight: FontWeight.w600)),
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Timeslots tab
          _loadingSlots
              ? const Center(child: CircularProgressIndicator())
              : _slots.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.schedule, size: 48, color: AppColors.textMuted),
                          const SizedBox(height: 12),
                          Text('No timeslots', style: AppTextStyles.h3),
                          Text('This consultant has no timeslots configured', style: AppTextStyles.caption),
                        ],
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final columns = width >= 1100 ? 5 : width >= 840 ? 4 : width >= 620 ? 3 : 2;
                        return GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 1.65,
                          ),
                          itemCount: _slots.length,
                          itemBuilder: (_, i) {
                            final slot = _slots[i];
                            final color = slot.status == 'AVAILABLE'
                                ? AppColors.success
                                : slot.status == 'BOOKED'
                                    ? AppColors.primaryLight
                                    : AppColors.textMuted;
                            return Container(
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: color.withValues(alpha: 0.35)),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                                  const SizedBox(height: 4),
                                  Text(slot.timeRange, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color), textAlign: TextAlign.center),
                                  Text(slot.slotDate, style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.75))),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
        ],
      ),
    );
  }

  Widget _infoCard(List<Widget> rows) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(children: rows),
      );

  Widget _infoRow(IconData icon, String label, String value, {Color? valueColor}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.caption),
                  Text(value, style: AppTextStyles.label.copyWith(color: valueColor ?? AppColors.textPrimary)),
                ],
              ),
            ),
          ],
        ),
      );
}

// ════════════════════════════════════════════════════════════════════════════
// ADVISOR FORM SHEET — Matches web AddAdvisor.tsx exactly
// Uses multipart/form-data with 'data' field as JSON blob
// ════════════════════════════════════════════════════════════════════════════

class _AdvisorFormSheet extends StatefulWidget {
  final ConsultantModel? advisor;
  final VoidCallback onSaved;

  const _AdvisorFormSheet({this.advisor, required this.onSaved});

  @override
  State<_AdvisorFormSheet> createState() => _AdvisorFormSheetState();
}

class _AdvisorFormSheetState extends State<_AdvisorFormSheet> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _desigCtrl = TextEditingController();
  final _chargesCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController();
  final _customSkillCtrl = TextEditingController();

  final _dio = ApiClient().dio;
  final _formKey = GlobalKey<FormState>();

  TimeOfDay _shiftStart = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _shiftEnd = const TimeOfDay(hour: 18, minute: 0);
  int _slotDuration = 60; // minutes — matches web's slotsDuration

  bool _saving = false;
  String? _errorText;

  // Skills — matching web AddAdvisor.tsx skill groups
  final List<String> _selectedSkills = [];

  static const _designationExamples = [
    'Certified Financial Planner',
    'Investment Consultant',
    'Tax Consultant',
    'Insurance Planner',
    'Wealth Advisor',
    'Senior Tax Consultant',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.advisor != null) {
      final a = widget.advisor!;
      _nameCtrl.text = a.name;
      _emailCtrl.text = a.email;
      _desigCtrl.text = a.designation ?? '';
      _chargesCtrl.text = _normalizeSessionFee(a.charges).toStringAsFixed(0);
      _descCtrl.text = a.description ?? '';
      _experienceCtrl.text = a.yearsOfExperience?.toStringAsFixed(1) ?? '';
      _slotDuration = a.slotsDuration ?? 60;
      _selectedSkills.addAll(a.skills);
      if (a.shiftStartTime != null) {
        _shiftStart = TimeOfDay(
          hour: a.shiftStartTime!['hour'] ?? 9,
          minute: a.shiftStartTime!['minute'] ?? 0,
        );
      }
      if (a.shiftEndTime != null) {
        _shiftEnd = TimeOfDay(
          hour: a.shiftEndTime!['hour'] ?? 18,
          minute: a.shiftEndTime!['minute'] ?? 0,
        );
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _desigCtrl.dispose();
    _chargesCtrl.dispose();
    _descCtrl.dispose();
    _experienceCtrl.dispose();
    _customSkillCtrl.dispose();
    super.dispose();
  }

  String _canonical(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  String _titleCase(String s) {
    final trimmed = s.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).map((p) => '${p[0].toUpperCase()}${p.substring(1)}').join(' ');
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod}:${t.minute.toString().padLeft(2, '0')} ${t.period == DayPeriod.am ? 'AM' : 'PM'}';

  /// Convert TimeOfDay → "HH:MM:00" for API (matching web's toLocalTime)
  String _toApiTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  void _toggleSkill(String skill) {
    final normalized = _titleCase(skill);
    final existingIndex = _selectedSkills.indexWhere((s) => _canonical(s) == _canonical(normalized));
    setState(() {
      if (existingIndex >= 0) {
        _selectedSkills.removeAt(existingIndex);
      } else {
        _selectedSkills.add(normalized);
      }
      _errorText = null;
    });
  }

  void _addCustomSkill() {
    final raw = _customSkillCtrl.text.trim();
    if (raw.isEmpty) return;
    final parts = raw.split(',').map(_titleCase).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return;
    setState(() {
      for (final item in parts) {
        final exists = _selectedSkills.any((s) => _canonical(s) == _canonical(item));
        if (!exists) _selectedSkills.add(item);
      }
      _errorText = null;
    });
    _customSkillCtrl.clear();
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _shiftStart : _shiftEnd,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _shiftStart = picked;
        } else {
          _shiftEnd = picked;
        }
        _errorText = null;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSkills.isEmpty) {
      setState(() => _errorText = 'Please select at least one skill.');
      return;
    }

    final startMinutes = (_shiftStart.hour * 60) + _shiftStart.minute;
    final endMinutes = (_shiftEnd.hour * 60) + _shiftEnd.minute;
    if (endMinutes <= startMinutes) {
      setState(() => _errorText = 'Availability end time must be after the start time.');
      return;
    }

    setState(() {
      _saving = true;
      _errorText = null;
    });

    // Build payload matching web AddAdvisor.tsx consultantPayload exactly:
    // name, email, designation, charges, yearsOfExperience, skills[],
    // shiftStartTime ("HH:MM:SS"), shiftEndTime ("HH:MM:SS"),
    // slotsDuration (minutes as int), description (optional)
    final payload = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'email': _emailCtrl.text.trim().toLowerCase(),
      'designation': _desigCtrl.text.trim(),
      'charges': double.tryParse(_chargesCtrl.text.trim()) ?? 0,
      'yearsOfExperience': double.tryParse(_experienceCtrl.text.trim()) ?? 0,
      'skills': _selectedSkills,
      'shiftStartTime': _toApiTime(_shiftStart),
      'shiftEndTime': _toApiTime(_shiftEnd),
      'slotsDuration': _slotDuration,
    };
    if (_descCtrl.text.trim().isNotEmpty) {
      payload['description'] = _descCtrl.text.trim();
    }

    // IMPORTANT: Web uses multipart/form-data with data as JSON blob
    // AddAdvisor.tsx: fd.append("data", new Blob([JSON.stringify(consultantPayload)], { type: "application/json" }))
    final formData = FormData.fromMap({
      'data': MultipartFile.fromString(
        jsonEncode(payload),
        filename: 'data.json',
        contentType: DioMediaType.parse('application/json'),
      ),
    });

    try {
      if (widget.advisor != null) {
        await _dio.put('/api/consultants/${widget.advisor!.id}', data: formData);
      } else {
        await _dio.post('/api/consultants', data: formData);
      }

      if (!mounted) return;
      _snack(context, widget.advisor != null ? 'Consultant updated' : 'Consultant added successfully');
      widget.onSaved();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = _apiError(
          error,
          fallback: widget.advisor != null
              ? 'Failed to update consultant details.'
              : 'Failed to add consultant.',
        );
      });
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
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: SheetHandle(
                      title: widget.advisor != null ? 'Edit Consultant' : 'Add New Consultant',
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),

              // Full Name
              TextFormField(
                controller: _nameCtrl,
                decoration: _inp('Full Name *', icon: Icons.person_outline_rounded),
                validator: (v) {
                  if ((v ?? '').trim().isEmpty) return 'Full name is required';
                  if ((v ?? '').trim().length < 2) return 'Enter consultant\'s full name';
                  return null;
                },
              ),
              const SizedBox(height: 10),

              // Email
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: _inp('Email (Login ID) *', icon: Icons.email_outlined),
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) return 'Email is required';
                  if (!value.contains('@') || !value.contains('.')) return 'Enter a valid email address';
                  return null;
                },
              ),
              const SizedBox(height: 10),

              // Designation + Experience side-by-side (matching web)
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _desigCtrl,
                      decoration: _inp('Designation *', icon: Icons.work_outline_rounded),
                      validator: (v) {
                        if ((v ?? '').trim().isEmpty) return 'Designation required';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _experienceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: _inp('Exp. (yrs) *', icon: Icons.workspace_premium_outlined),
                      validator: (v) {
                        final value = (v ?? '').trim();
                        if (value.isEmpty) return 'Required';
                        final parsed = double.tryParse(value);
                        if (parsed == null || parsed < 0) return 'Invalid';
                        if (parsed > 60) return 'Too high';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Designation quick-fill chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _designationExamples.map((example) => ActionChip(
                  label: Text(example, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  backgroundColor: AppColors.surfaceVariant,
                  side: const BorderSide(color: AppColors.border),
                  onPressed: () => setState(() => _desigCtrl.text = example),
                )).toList(),
              ),
              const SizedBox(height: 10),

              // Session Fee
              TextFormField(
                controller: _chargesCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _inp('Base Charge per Person (Rs) *', icon: Icons.currency_rupee_rounded),
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) return 'Session fee is required';
                  final parsed = double.tryParse(value);
                  if (parsed == null || parsed <= 0) return 'Enter a valid charge amount';
                  if (parsed > 100000) return 'Cannot exceed ₹1,00,000';
                  return null;
                },
              ),
              const SizedBox(height: 10),

              // Description (optional)
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: _inp(
                  'Profile Description (optional)',
                  icon: Icons.description_outlined,
                  hint: 'Short consultant intro shown on profile & booking screens',
                ),
              ),
              const SizedBox(height: 14),

              // Working Hours
              Text('Availability Hours *', style: AppTextStyles.label),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _pickTime(true),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            Text('Start', style: AppTextStyles.caption),
                            Text(_fmtTime(_shiftStart), style: AppTextStyles.label.copyWith(color: AppColors.primaryLight)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('to', style: TextStyle(color: AppColors.textMuted)),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _pickTime(false),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            Text('End', style: AppTextStyles.caption),
                            Text(_fmtTime(_shiftEnd), style: AppTextStyles.label.copyWith(color: AppColors.primaryLight)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Session Duration (matching web's 1hr / 2hr / 3hr selector)
              Text('Session Duration *', style: AppTextStyles.label),
              const SizedBox(height: 8),
              Row(
                children: [60, 120, 180].map((mins) {
                  final active = _slotDuration == mins;
                  final label = mins == 60 ? '1 hr' : mins == 120 ? '2 hrs' : '3 hrs';
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _slotDuration = mins),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            color: active ? AppColors.primaryLight.withValues(alpha: 0.1) : AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: active ? AppColors.primaryLight : AppColors.border,
                              width: active ? 2 : 1,
                            ),
                          ),
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: active ? AppColors.primaryLight : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              Text(
                'Used to generate bookable slots for this consultant.',
                style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),

              // Skill Set — grouped by category (matching web AddAdvisor.tsx skill groups)
              Text('Skill Set *', style: AppTextStyles.label),
              const SizedBox(height: 4),
              Text(
                '${_selectedSkills.length} selected · Click to select',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 8),

              // Show selected skills as removable chips
              if (_selectedSkills.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _selectedSkills.map((skill) => Chip(
                    label: Text(skill, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                    backgroundColor: const Color(0xFF0F766E),
                    side: BorderSide.none,
                    deleteIcon: const Icon(Icons.close_rounded, size: 16, color: Colors.white70),
                    onDeleted: () => _toggleSkill(skill),
                  )).toList(),
                ),
                const SizedBox(height: 10),
              ],

              // Skill groups (scrollable)
              Container(
                constraints: const BoxConstraints(maxHeight: 280),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: _skillGroups.map((group) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Group header
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.5))),
                            ),
                            child: Row(
                              children: [
                                Icon(group.icon, size: 14, color: AppColors.textSecondary),
                                const SizedBox(width: 6),
                                Text(
                                  group.group.toUpperCase(),
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.5),
                                ),
                              ],
                            ),
                          ),
                          // Skills
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Wrap(
                              spacing: 7,
                              runSpacing: 7,
                              children: group.skills.map((skill) {
                                final isSelected = _selectedSkills.any((s) => _canonical(s) == _canonical(skill));
                                return GestureDetector(
                                  onTap: () => _toggleSkill(skill),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFF0F766E) : Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isSelected ? const Color(0xFF0F766E) : AppColors.border,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isSelected) ...[
                                          const Icon(Icons.check_rounded, size: 12, color: Colors.white),
                                          const SizedBox(width: 4),
                                        ],
                                        Text(
                                          skill,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: isSelected ? Colors.white : AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Custom skill add (matching web's + Add button)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customSkillCtrl,
                      decoration: _inp('Add custom skill (comma-separated)', icon: Icons.add_task_outlined),
                      onSubmitted: (_) => _addCustomSkill(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _addCustomSkill,
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F766E)),
                    child: const Text('+ Add'),
                  ),
                ],
              ),

              // Error message
              if (_errorText != null) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    _errorText!,
                    style: const TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _saving ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryLight,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          widget.advisor != null ? 'Save Changes' : 'Add Consultant',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Skeleton Card ─────────────────────────────────────────────────────────────

class _AdvisorSkeletonCard extends StatelessWidget {
  const _AdvisorSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(width: 52, height: 52, decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(26))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 12, width: 150, decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(6))),
                const SizedBox(height: 8),
                Container(height: 10, width: 110, decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(6))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared Widgets ────────────────────────────────────────────────────────────

class StatusChip extends StatelessWidget {
  final String status;
  final Color color;

  const StatusChip({super.key, required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(status, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

class SheetHandle extends StatelessWidget {
  final String title;

  const SheetHandle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
          ),
        ),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
      ],
    );
  }
}
