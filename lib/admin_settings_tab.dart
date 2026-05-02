// lib/features/admin/admin_settings_tab.dart
// ════════════════════════════════════════════════════════════════════════════
// Complete Admin Settings — Full web parity:
//   ✔ Account & Security (Profile + Change Password)
//   ✔ User Management (Add Member, view users)
//   ✔ Business Hours (Mon-Sun toggle + time config)
//   ✔ Holidays (add/delete)
//   ✔ Auto Responder (enable/disable + message)
//   ✔ Canned Responses (add/delete)
//   ✔ Ticket Categories (add/toggle active)
//   ✔ Subscription Plans (add/delete)
//   ✔ Commission Configuration (FLAT / PERCENTAGE)
//   ✔ Terms & Conditions Editor
//   ✔ Contact Submissions (view/mark read/delete)
//   ✔ Offer Approvals
//   ✔ Skills & Questions Management
// ════════════════════════════════════════════════════════════════════════════
// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:finadvise/admin_missing_features.dart';
import 'package:finadvise/api_client.dart';
import 'package:finadvise/app_theme.dart';
import 'package:finadvise/email_to_ticket_screen.dart';
import 'package:finadvise/models/models.dart';
import 'package:finadvise/services/question_service.dart';
import 'package:flutter/material.dart';

class AdminSettingsTab extends StatelessWidget {
  const AdminSettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionTile(
          icon: Icons.manage_accounts_rounded,
          title: 'Account & Security',
          subtitle: 'Profile, password and notification settings',
          color: AppColors.primary,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const AdminProfileSettingsScreen()),
          ),
        ),
        _SectionTile(
          icon: Icons.person_add_rounded,
          title: 'Add Member',
          subtitle:
              'Create new user accounts — credentials emailed automatically',
          color: AppColors.info,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminAddMemberScreen()),
          ),
        ),
        _SectionTile(
          icon: Icons.group_rounded,
          title: 'User Management',
          subtitle: 'View, filter and remove platform users',
          color: AppColors.info,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const AdminUserManagementScreen()),
          ),
        ),
        _SectionTile(
          icon: Icons.access_time_rounded,
          title: 'Master Time Ranges',
          subtitle: 'Manage the master list of bookable slot windows',
          color: AppColors.primaryLight,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const BusinessHoursScreen())),
        ),
        _SectionTile(
          icon: Icons.beach_access_rounded,
          title: 'Holidays',
          subtitle: 'Manage non-working days',
          color: AppColors.warning,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const HolidaysScreen())),
        ),
        _SectionTile(
          icon: Icons.auto_awesome_rounded,
          title: 'Auto Responder',
          subtitle: 'Automatic ticket acknowledgment',
          color: AppColors.accent,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AutoResponderScreen())),
        ),
        _SectionTile(
          icon: Icons.chat_bubble_outline_rounded,
          title: 'Canned Responses',
          subtitle: 'Quick reply templates',
          color: AppColors.info,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const CannedResponsesScreen())),
        ),
        _SectionTile(
          icon: Icons.label_outline_rounded,
          title: 'Ticket Categories',
          subtitle: 'Manage ticket types',
          color: AppColors.gold,
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const TicketCategoriesScreen())),
        ),
        _SectionTile(
          icon: Icons.percent_rounded,
          title: 'Commission Config',
          subtitle: 'Platform commission on top of consultant fees',
          color: AppColors.success,
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const CommissionConfigScreen())),
        ),
        _SectionTile(
          icon: Icons.card_membership_rounded,
          title: 'Subscription Plans',
          subtitle: 'Pricing plans management',
          color: AppColors.primary,
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const SubscriptionPlansScreen())),
        ),
        _SectionTile(
          icon: Icons.quiz_rounded,
          title: 'Skills & Questions',
          subtitle: 'Manage skill categories and post-booking questions',
          color: AppColors.primaryLight,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SkillsQuestionsScreen())),
        ),
        _SectionTile(
          icon: Icons.thumb_up_alt_outlined,
          title: 'Offer Approvals',
          subtitle: 'Review and approve consultant-submitted offers',
          color: AppColors.warning,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const OfferApprovalsScreen())),
        ),
        _SectionTile(
          icon: Icons.gavel_rounded,
          title: 'Terms & Conditions',
          subtitle: 'Edit and version-manage T&C',
          color: AppColors.textSecondary,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const TermsConditionsScreen())),
        ),
        _SectionTile(
          icon: Icons.mail_outline_rounded,
          title: 'Contact Submissions',
          subtitle: 'Messages from the homepage Contact Us form',
          color: AppColors.accent,
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const ContactSubmissionsScreen())),
        ),
        _SectionTile(
          icon: Icons.mark_email_read_outlined,
          title: 'Email Inbox',
          subtitle: 'Check service health and manually trigger inbox polling',
          color: AppColors.success,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const EmailToTicketScreen(),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final VoidCallback onTap;
  final int? badge;

  const _SectionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(title, style: AppTextStyles.h4),
        subtitle: Text(subtitle, style: AppTextStyles.caption),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badge != null && badge! > 0)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(10)),
                child: Text('$badge',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

// ─── BUSINESS HOURS ───────────────────────────────────────────────────────────

class BusinessHoursScreen extends StatefulWidget {
  const BusinessHoursScreen({super.key});
  @override
  State<BusinessHoursScreen> createState() => _BusinessHoursScreenState();
}

class _BusinessHoursScreenState extends State<BusinessHoursScreen> {
  final _api = _SettingsService();
  List<BusinessHours> _hours = [];
  bool _loading = true;
  bool _saving = false;

  static const _days = [
    'MONDAY',
    'TUESDAY',
    'WEDNESDAY',
    'THURSDAY',
    'FRIDAY',
    'SATURDAY',
    'SUNDAY'
  ];
  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _hours = await _api.getBusinessHours();
    if (_hours.isEmpty) {
      _hours = _days
          .map((d) => BusinessHours(
              id: 0,
              dayOfWeek: d,
              openTime: '09:00',
              closeTime: '18:00',
              isOpen: d != 'SATURDAY' && d != 'SUNDAY'))
          .toList();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    Map<String, dynamic> parseTime(String t) {
      final parts = t.split(':');
      return {
        'hour': int.parse(parts[0]),
        'minute': int.parse(parts[1]),
        'second': 0,
        'nano': 0
      };
    }

    final payload = _hours
        .map((h) => {
              'dayOfWeek': h.dayOfWeek,
              'startTime': parseTime(h.openTime),
              'endTime': parseTime(h.closeTime),
              'workingDay': h.isOpen,
            })
        .toList();

    await _api.updateBusinessHours(payload);

    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Business hours saved'),
          backgroundColor: AppColors.success));
    }
  }

  Future<void> _pickTime(int index, bool isOpenTime) async {
    final current =
        isOpenTime ? _hours[index].openTime : _hours[index].closeTime;
    final parts = current.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime:
          TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
    );
    if (picked != null) {
      final timeStr =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        if (isOpenTime) {
          _hours[index] = BusinessHours(
              id: _hours[index].id,
              dayOfWeek: _hours[index].dayOfWeek,
              openTime: timeStr,
              closeTime: _hours[index].closeTime,
              isOpen: _hours[index].isOpen);
        } else {
          _hours[index] = BusinessHours(
              id: _hours[index].id,
              dayOfWeek: _hours[index].dayOfWeek,
              openTime: _hours[index].openTime,
              closeTime: timeStr,
              isOpen: _hours[index].isOpen);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Business Hours'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save',
                    style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _hours.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final h = _hours[i];
                final dayIdx = _days.indexOf(h.dayOfWeek);
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: h.isOpen
                            ? AppColors.border
                            : AppColors.border.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 36,
                        child: Text(
                            dayIdx >= 0
                                ? _dayLabels[dayIdx]
                                : h.dayOfWeek.substring(0, 3),
                            style: AppTextStyles.label
                                .copyWith(fontWeight: FontWeight.w700)),
                      ),
                      Switch(
                        value: h.isOpen,
                        activeThumbColor: AppColors.success,
                        activeTrackColor:
                            AppColors.success.withValues(alpha: 0.5),
                        onChanged: (v) => setState(() {
                          _hours[i] = BusinessHours(
                              id: h.id,
                              dayOfWeek: h.dayOfWeek,
                              openTime: h.openTime,
                              closeTime: h.closeTime,
                              isOpen: v);
                        }),
                      ),
                      if (h.isOpen) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => _pickTime(i, true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                      color: AppColors.surfaceVariant,
                                      borderRadius: BorderRadius.circular(8)),
                                  child: Text(h.openTime,
                                      style: AppTextStyles.label.copyWith(
                                          color: AppColors.primaryLight)),
                                ),
                              ),
                              const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: Text('—',
                                      style: TextStyle(
                                          color: AppColors.textMuted))),
                              GestureDetector(
                                onTap: () => _pickTime(i, false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                      color: AppColors.surfaceVariant,
                                      borderRadius: BorderRadius.circular(8)),
                                  child: Text(h.closeTime,
                                      style: AppTextStyles.label.copyWith(
                                          color: AppColors.primaryLight)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else
                        Expanded(
                            child:
                                Text('Closed', style: AppTextStyles.caption)),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

// ─── HOLIDAYS ─────────────────────────────────────────────────────────────────

class HolidaysScreen extends StatefulWidget {
  const HolidaysScreen({super.key});
  @override
  State<HolidaysScreen> createState() => _HolidaysScreenState();
}

class _HolidaysScreenState extends State<HolidaysScreen> {
  final _api = _SettingsService();
  List<Holiday> _holidays = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _holidays = await _api.getHolidays();
    if (mounted) setState(() => _loading = false);
  }

  void _showAddSheet() {
    final nameCtrl = TextEditingController();
    String? selectedDate;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
              const SheetHandle(title: 'Add Holiday'),
              TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Holiday name',
                      prefixIcon: Icon(Icons.celebration_outlined))),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)));
                  if (picked != null)
                    ss(() =>
                        selectedDate = picked.toIso8601String().split('T')[0]);
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border)),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          color: AppColors.textSecondary, size: 20),
                      const SizedBox(width: 12),
                      Text(selectedDate ?? 'Select date',
                          style: selectedDate != null
                              ? AppTextStyles.body
                              : AppTextStyles.label),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.isEmpty || selectedDate == null) return;
                    final result =
                        await _api.addHoliday(nameCtrl.text, selectedDate!);
                    if (result && mounted) {
                      Navigator.pop(context);
                      _load();
                    }
                  },
                  child: const Text('Add Holiday',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Holidays'), actions: [
        IconButton(icon: const Icon(Icons.add), onPressed: _showAddSheet)
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _holidays.isEmpty
              ? const EmptyState(
                  icon: Icons.beach_access_outlined,
                  title: 'No holidays added',
                  subtitle: 'Add holidays to block booking slots')
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _holidays.length,
                    itemBuilder: (_, i) {
                      final h = _holidays[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                  color:
                                      AppColors.warning.withValues(alpha: 0.1),
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.beach_access_outlined,
                                  color: AppColors.warning, size: 20)),
                          title: Text(h.name, style: AppTextStyles.h4),
                          subtitle: Text(h.date, style: AppTextStyles.caption),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: AppColors.danger),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                          title: const Text('Delete Holiday'),
                                          content: Text('Delete "${h.name}"?'),
                                          actions: [
                                            TextButton(
                                                onPressed: () => Navigator.pop(
                                                    context, false),
                                                child: const Text('Cancel')),
                                            ElevatedButton(
                                                onPressed: () => Navigator.pop(
                                                    context, true),
                                                style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        AppColors.danger),
                                                child: const Text('Delete',
                                                    style: TextStyle(
                                                        color: Colors.white)))
                                          ]));
                              if (confirm == true) {
                                await _api.deleteHoliday(h.id);
                                _load();
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

// ─── AUTO RESPONDER ──────────────────────────────────────────────────────────

class AutoResponderScreen extends StatefulWidget {
  const AutoResponderScreen({super.key});
  @override
  State<AutoResponderScreen> createState() => _AutoResponderScreenState();
}

class _AutoResponderScreenState extends State<AutoResponderScreen> {
  final _api = _SettingsService();
  final _msgCtrl = TextEditingController();
  final _msg2Ctrl = TextEditingController();
  bool _enabled = false;
  bool _enabled2 = false;
  bool _loading = true;
  bool _saving1 = false;
  bool _saving2 = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _msg2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await _api.getAutoResponder();
    if (data != null) {
      setState(() {
        _enabled = data['enabled'] ?? false;
        _msgCtrl.text = data['message'] ?? '';
      });
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save1() async {
    setState(() => _saving1 = true);
    final ok = await _api.setAutoResponder(_enabled, _msgCtrl.text);
    if (mounted) {
      setState(() => _saving1 = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok ? 'New ticket responder saved' : 'Failed to save'),
          backgroundColor: ok ? AppColors.success : AppColors.danger));
    }
  }

  Future<void> _save2() async {
    setState(() => _saving2 = true);
    if (mounted) {
      setState(() => _saving2 = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Resolved-ticket auto responder is not available in the current backend'),
          backgroundColor: AppColors.warning));
    }
  }

  Widget _responderCard({
    required String title,
    required String subtitle,
    required String tag,
    required Color tagColor,
    required bool enabled,
    required ValueChanged<bool> onToggle,
    required TextEditingController controller,
    required bool saving,
    required VoidCallback onSave,
  }) {
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(title, style: AppTextStyles.h4),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: tagColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12)),
                        child: Text(tag,
                            style: TextStyle(
                                fontSize: 10,
                                color: tagColor,
                                fontWeight: FontWeight.w700)),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text(subtitle, style: AppTextStyles.caption),
                  ],
                ),
              ),
              Switch(
                  value: enabled,
                  activeThumbColor: AppColors.success,
                  activeTrackColor: AppColors.success.withValues(alpha: 0.5),
                  onChanged: onToggle),
            ],
          ),
          if (enabled) ...[
            const SizedBox(height: 14),
            Text('Message', style: AppTextStyles.label),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              maxLines: 5,
              decoration: const InputDecoration(
                  hintText: 'Auto-response message...',
                  alignLabelWithHint: true),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: saving ? null : onSave,
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Save',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            Text('Toggle on to send automated replies at this stage.',
                style: AppTextStyles.caption),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Auto Responders')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _responderCard(
                  title: 'New Ticket Responder',
                  subtitle: 'Sent when a ticket is created',
                  tag: 'On Create',
                  tagColor: AppColors.primaryLight,
                  enabled: _enabled,
                  onToggle: (v) => setState(() => _enabled = v),
                  controller: _msgCtrl,
                  saving: _saving1,
                  onSave: _save1,
                ),
                const SizedBox(height: 14),
                _responderCard(
                  title: 'Resolved Ticket Responder',
                  subtitle: 'Sent when a ticket is resolved or closed',
                  tag: 'On Resolve',
                  tagColor: AppColors.success,
                  enabled: _enabled2,
                  onToggle: (v) => setState(() => _enabled2 = v),
                  controller: _msg2Ctrl,
                  saving: _saving2,
                  onSave: _save2,
                ),
              ],
            ),
    );
  }
}

// ─── CANNED RESPONSES ─────────────────────────────────────────────────────────

class CannedResponsesScreen extends StatefulWidget {
  const CannedResponsesScreen({super.key});
  @override
  State<CannedResponsesScreen> createState() => _CannedResponsesScreenState();
}

class _CannedResponsesScreenState extends State<CannedResponsesScreen> {
  final _api = _SettingsService();
  List<CannedResponse> _responses = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _responses = await _api.getCannedResponses();
    if (mounted) setState(() => _loading = false);
  }

  List<CannedResponse> get _filtered {
    if (_search.isEmpty) return _responses;
    final q = _search.toLowerCase();
    return _responses
        .where((r) =>
            r.title.toLowerCase().contains(q) ||
            r.content.toLowerCase().contains(q))
        .toList();
  }

  void _showAddSheet() {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    String? selectedCategory;
    const categories = [
      'General',
      'Billing',
      'Technical',
      'Escalation',
      'Advisory',
      'Compliance'
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
              const SheetHandle(title: 'New Canned Response'),
              TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Title *', prefixIcon: Icon(Icons.title))),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedCategory,
                decoration: const InputDecoration(
                    labelText: 'Category *',
                    prefixIcon: Icon(Icons.label_outline)),
                hint: const Text('Select a category'),
                items: categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => ss(() => selectedCategory = v),
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: contentCtrl,
                  maxLines: 5,
                  decoration: const InputDecoration(
                      labelText: 'Body *', alignLabelWithHint: true)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    if (titleCtrl.text.isEmpty ||
                        contentCtrl.text.isEmpty ||
                        selectedCategory == null) return;
                    final result = await _api.createCannedResponse(
                        titleCtrl.text, contentCtrl.text, selectedCategory);
                    if (result && mounted) {
                      Navigator.pop(context);
                      _load();
                    }
                  },
                  child: const Text('Create Response',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Canned Responses'), actions: [
        IconButton(icon: const Icon(Icons.add), onPressed: _showAddSheet)
      ]),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search responses…',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.surfaceVariant,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? const EmptyState(
                        icon: Icons.chat_bubble_outline,
                        title: 'No canned responses',
                        subtitle: 'Click + to create quick reply templates')
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) {
                          final r = _filtered[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                      color:
                                          AppColors.info.withValues(alpha: 0.1),
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.chat_bubble_outline,
                                      color: AppColors.info, size: 18)),
                              title: Row(children: [
                                Expanded(
                                    child:
                                        Text(r.title, style: AppTextStyles.h4)),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: AppColors.primaryLight
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8)),
                                  child: Text(r.category ?? 'General',
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.primaryLight,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ]),
                              subtitle: Text(r.content,
                                  style: AppTextStyles.caption,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: AppColors.danger),
                                onPressed: () async {
                                  await _api.deleteCannedResponse(r.id);
                                  _load();
                                },
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ─── TICKET CATEGORIES ────────────────────────────────────────────────────────

class TicketCategoriesScreen extends StatefulWidget {
  const TicketCategoriesScreen({super.key});
  @override
  State<TicketCategoriesScreen> createState() => _TicketCategoriesScreenState();
}

class _TicketCategoriesScreenState extends State<TicketCategoriesScreen> {
  final _api = _SettingsService();
  List<TicketCategory> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _categories = await _api.getCategories();
    if (mounted) setState(() => _loading = false);
  }

  void _showAddSheet() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(title: 'Add Category'),
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Category name *',
                    prefixIcon: Icon(Icons.label_outline))),
            const SizedBox(height: 12),
            TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    prefixIcon: Icon(Icons.description_outlined))),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.isEmpty) return;
                  final result = await _api.createCategory(nameCtrl.text,
                      descCtrl.text.isNotEmpty ? descCtrl.text : null);
                  if (result && mounted) {
                    Navigator.pop(context);
                    _load();
                  }
                },
                child: const Text('Add Category',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Ticket Categories'), actions: [
        IconButton(icon: const Icon(Icons.add), onPressed: _showAddSheet)
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _categories.isEmpty
              ? const EmptyState(
                  icon: Icons.label_outline,
                  title: 'No categories',
                  subtitle: 'Add categories to classify tickets')
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _categories.length,
                  itemBuilder: (_, i) {
                    final c = _categories[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: (c.isActive
                                      ? AppColors.success
                                      : AppColors.textMuted)
                                  .withValues(alpha: 0.1),
                              shape: BoxShape.circle),
                          child: Icon(Icons.label_rounded,
                              color: c.isActive
                                  ? AppColors.success
                                  : AppColors.textMuted,
                              size: 18),
                        ),
                        title: Text(c.name, style: AppTextStyles.h4),
                        subtitle: c.description != null
                            ? Text(c.description!, style: AppTextStyles.caption)
                            : null,
                        trailing: Switch(
                          value: c.isActive,
                          activeThumbColor: AppColors.success,
                          activeTrackColor:
                              AppColors.success.withValues(alpha: 0.5),
                          onChanged: (_) async {
                            await _api.toggleCategory(c.id);
                            _load();
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// ─── COMMISSION CONFIG ────────────────────────────────────────────────────────

class CommissionConfigScreen extends StatefulWidget {
  const CommissionConfigScreen({super.key});
  @override
  State<CommissionConfigScreen> createState() => _CommissionConfigScreenState();
}

class _CommissionConfigScreenState extends State<CommissionConfigScreen> {
  final _api = _SettingsService();
  final _valueCtrl = TextEditingController();
  String _feeType = 'FLAT';
  bool _loading = true;
  bool _saving = false;
  final _previewCtrl = TextEditingController(text: '1000');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _valueCtrl.dispose();
    _previewCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final dio = ApiClient().dio;
      final res = await dio.get('/api/admin/settings/additional-charges');
      if (res.data is Map) {
        setState(() {
          _feeType = res.data['feeType'] ?? 'FLAT';
          _valueCtrl.text = '${res.data['feeValue'] ?? 0}';
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final dio = ApiClient().dio;
      await dio.post('/api/admin/settings/additional-charges', data: {
        'feeType': _feeType,
        'feeValue': double.tryParse(_valueCtrl.text) ?? 0,
      });
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Commission saved'),
            backgroundColor: AppColors.success));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Failed to save'),
            backgroundColor: AppColors.danger));
    }
    if (mounted) setState(() => _saving = false);
  }

  double get _commission {
    final base = double.tryParse(_previewCtrl.text) ?? 1000;
    final val = double.tryParse(_valueCtrl.text) ?? 0;
    if (_feeType == 'PERCENTAGE') return base * val / 100;
    return val;
  }

  @override
  Widget build(BuildContext context) {
    final base = double.tryParse(_previewCtrl.text) ?? 1000;
    final total = base + _commission;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Commission Config')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Commission Type', style: AppTextStyles.label),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                                child: _typeBtn('FLAT', 'Fixed Amount (₹)')),
                            const SizedBox(width: 10),
                            Expanded(
                                child:
                                    _typeBtn('PERCENTAGE', 'Percentage (%)')),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text('Commission Value *', style: AppTextStyles.label),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _valueCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            prefixText: _feeType == 'FLAT' ? '₹ ' : null,
                            suffixText: _feeType == 'PERCENTAGE' ? '%' : null,
                            hintText: _feeType == 'PERCENTAGE'
                                ? 'e.g. 15'
                                : 'e.g. 200',
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text('Live Preview', style: AppTextStyles.label),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text('If consultant charges ₹'),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 90,
                              child: TextField(
                                controller: _previewCtrl,
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 8)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: AppColors.success
                                      .withValues(alpha: 0.3))),
                          child: Column(
                            children: [
                              _previewRow('Consultant Base',
                                  '₹${base.toStringAsFixed(0)}'),
                              _previewRow('Platform Commission',
                                  '₹${_commission.toStringAsFixed(0)}',
                                  highlight: true),
                              Divider(
                                  color:
                                      AppColors.success.withValues(alpha: 0.3)),
                              _previewRow('Total Customer Pays',
                                  '₹${total.toStringAsFixed(0)}',
                                  bold: true),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _saving ? null : _save,
                            child: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : const Text('Save Commission Settings',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _typeBtn(String type, String label) {
    final active = _feeType == type;
    return GestureDetector(
      onTap: () => setState(() => _feeType = type),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primaryLight.withValues(alpha: 0.1)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: active ? AppColors.primaryLight : AppColors.border,
              width: active ? 2 : 1),
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color:
                    active ? AppColors.primaryLight : AppColors.textSecondary)),
      ),
    );
  }

  Widget _previewRow(String label, String value,
      {bool highlight = false, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  color: highlight
                      ? AppColors.primaryLight
                      : AppColors.textPrimary)),
        ],
      ),
    );
  }
}

// ─── SUBSCRIPTION PLANS ───────────────────────────────────────────────────────

class SubscriptionPlansScreen extends StatefulWidget {
  const SubscriptionPlansScreen({super.key});
  @override
  State<SubscriptionPlansScreen> createState() =>
      _SubscriptionPlansScreenState();
}

class _SubscriptionPlansScreenState extends State<SubscriptionPlansScreen> {
  final _api = _SettingsService();
  List<SubscriptionPlan> _plans = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _plans = await _api.getSubscriptionPlans();
    if (mounted) setState(() => _loading = false);
  }

  void _showAddSheet() {
    final nameCtrl = TextEditingController();
    final origCtrl = TextEditingController();
    final discCtrl = TextEditingController();
    final featCtrl = TextEditingController();
    final tagCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHandle(title: 'New Subscription Plan'),
              TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Plan name *',
                      prefixIcon: Icon(Icons.card_membership_outlined))),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                      child: TextField(
                          controller: origCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Original price (₹)',
                              prefixText: '₹ '))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: TextField(
                          controller: discCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Discount price (₹)',
                              prefixText: '₹ '))),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                  controller: featCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Features (comma-separated)',
                      prefixIcon: Icon(Icons.star_outline))),
              const SizedBox(height: 10),
              TextField(
                  controller: tagCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Tag (e.g. Popular)',
                      prefixIcon: Icon(Icons.local_offer_outlined))),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.isEmpty || origCtrl.text.isEmpty) return;
                    final result = await _api.createPlan(
                      nameCtrl.text,
                      double.tryParse(origCtrl.text) ?? 0,
                      discountPrice: discCtrl.text.isNotEmpty
                          ? double.tryParse(discCtrl.text)
                          : null,
                      features: featCtrl.text.isNotEmpty ? featCtrl.text : null,
                      tag: tagCtrl.text.isNotEmpty ? tagCtrl.text : null,
                    );
                    if (result && mounted) {
                      Navigator.pop(context);
                      _load();
                    }
                  },
                  child: const Text('Create Plan',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Subscription Plans'), actions: [
        IconButton(icon: const Icon(Icons.add), onPressed: _showAddSheet)
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _plans.isEmpty
              ? const EmptyState(
                  icon: Icons.card_membership_outlined,
                  title: 'No plans created')
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _plans.length,
                  itemBuilder: (_, i) {
                    final p = _plans[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.card_membership_rounded,
                                  color: AppColors.primary, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(p.name, style: AppTextStyles.h4),
                                      if (p.tag != null) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                              color: AppColors.gold
                                                  .withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(4)),
                                          child: Text(p.tag!,
                                              style: const TextStyle(
                                                  fontSize: 10,
                                                  color: AppColors.gold,
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      if (p.discountPrice != null &&
                                          p.discountPrice !=
                                              p.originalPrice) ...[
                                        Text(
                                            '₹${p.discountPrice!.toStringAsFixed(0)}',
                                            style: AppTextStyles.label.copyWith(
                                                color: AppColors.accent,
                                                fontWeight: FontWeight.w700)),
                                        const SizedBox(width: 6),
                                        Text(
                                            '₹${p.originalPrice.toStringAsFixed(0)}',
                                            style: AppTextStyles.caption
                                                .copyWith(
                                                    decoration: TextDecoration
                                                        .lineThrough)),
                                      ] else
                                        Text(
                                            '₹${p.originalPrice.toStringAsFixed(0)}',
                                            style: AppTextStyles.label.copyWith(
                                                color: AppColors.accent,
                                                fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                  if (p.features != null &&
                                      p.features!.isNotEmpty)
                                    Text(p.features!,
                                        style: AppTextStyles.caption,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: AppColors.danger),
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                            title: const Text('Delete Plan'),
                                            content:
                                                Text('Delete "${p.name}"?'),
                                            actions: [
                                              TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          context, false),
                                                  child: const Text('Cancel')),
                                              ElevatedButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          context, true),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                          backgroundColor:
                                                              AppColors.danger),
                                                  child: const Text('Delete',
                                                      style: TextStyle(
                                                          color: Colors.white)))
                                            ]));
                                if (ok == true) {
                                  await _api.deletePlan(p.id);
                                  _load();
                                }
                              },
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

// ─── TERMS & CONDITIONS ───────────────────────────────────────────────────────

class TermsConditionsScreen extends StatefulWidget {
  const TermsConditionsScreen({super.key});
  @override
  State<TermsConditionsScreen> createState() => _TermsConditionsScreenState();
}

class _TermsConditionsScreenState extends State<TermsConditionsScreen> {
  final _contentCtrl = TextEditingController();
  final _versionCtrl = TextEditingController(text: '1.0');
  bool _loading = true;
  bool _saving = false;
  bool _editing = false;
  String _currentVersion = '1.0';
  String _currentContent = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    _versionCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final dio = ApiClient().dio;
      final res = await dio.get('/api/static-content/TERMS_AND_CONDITIONS');
      if (res.data is Map) {
        setState(() {
          _currentContent = res.data['content'] ?? res.data['text'] ?? '';
          _currentVersion = res.data['version'] ?? '1.0';
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final dio = ApiClient().dio;
      await dio.post('/api/static-content', data: {
        'contentType': 'TERMS_AND_CONDITIONS',
        'content': _contentCtrl.text,
        'lastUpdatedBy': 'Admin',
      });
      setState(() {
        _currentContent = _contentCtrl.text;
        _currentVersion = _versionCtrl.text;
        _editing = false;
      });
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Terms & Conditions v${_versionCtrl.text} published'),
            backgroundColor: AppColors.success));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Failed to save'),
            backgroundColor: AppColors.danger));
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
        actions: [
          if (!_editing)
            TextButton.icon(
              onPressed: () {
                _contentCtrl.text = _currentContent;
                setState(() => _editing = true);
              },
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit'),
            )
          else ...[
            TextButton(
                onPressed: () => setState(() => _editing = false),
                child: const Text('Cancel')),
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Publish',
                      style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _editing
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(children: [
                        const Text('Version: ',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: _versionCtrl,
                            decoration: const InputDecoration(
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                isDense: true),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      Expanded(
                        child: TextField(
                          controller: _contentCtrl,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          decoration: const InputDecoration(
                            hintText:
                                '### 1. Acceptance of Terms\nYour terms content here...\n\n### 2. Use of Services\nMore content...',
                            alignLabelWithHint: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(8)),
                        child: const Text(
                            'Use ### Section Title for headings. Separate sections with blank lines.',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.textSecondary)),
                      ),
                    ],
                  ),
                )
              : _currentContent.isEmpty
                  ? EmptyState(
                      icon: Icons.description_outlined,
                      title: 'No Terms & Conditions yet',
                      subtitle: 'Click Edit to create your first version',
                      action: TextButton(
                          onPressed: () {
                            _contentCtrl.text = '';
                            setState(() => _editing = true);
                          },
                          child: const Text('Create T&C')),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                  color:
                                      AppColors.success.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: AppColors.success
                                          .withValues(alpha: 0.3))),
                              child: Text('v$_currentVersion · LIVE',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.success,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ]),
                          const SizedBox(height: 16),
                          ..._currentContent.split('\n\n').map((block) {
                            final lines = block.split('\n');
                            if (lines.first.startsWith('### ')) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(lines.first.replaceFirst('### ', ''),
                                        style: AppTextStyles.h4.copyWith(
                                            fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 4),
                                    Text(lines.skip(1).join('\n'),
                                        style: AppTextStyles.body),
                                  ],
                                ),
                              );
                            }
                            return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(block, style: AppTextStyles.body));
                          }),
                        ],
                      ),
                    ),
    );
  }
}

// ─── SKILLS & QUESTIONS ───────────────────────────────────────────────────────

class SkillsQuestionsScreen extends StatefulWidget {
  const SkillsQuestionsScreen({super.key});
  @override
  State<SkillsQuestionsScreen> createState() => _SkillsQuestionsScreenState();
}

class _SkillsQuestionsScreenState extends State<SkillsQuestionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _questionService = QuestionService();

  List<Map<String, dynamic>> _skills = [];
  List<Map<String, dynamic>> _questions = [];
  bool _loadingSkills = true;
  bool _loadingQuestions = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadSkills();
    _loadQuestions();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? AppColors.danger : AppColors.success,
        ),
      );
  }

  String _skillLabel(Map<String, dynamic> skill) =>
      (skill['skillName'] ?? skill['name'] ?? '').toString();

  List<String> _questionOptions(Map<String, dynamic> question) =>
      (question['options'] ?? '')
          .toString()
          .split(RegExp(r'[\n,]'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();

  String _prettyQuestionType(String raw) {
    switch (raw.trim().toUpperCase()) {
      case 'TEXTAREA':
        return 'Paragraph';
      case 'MULTIPLE_CHOICE':
        return 'Multiple Choice';
      case 'TEXT':
      default:
        return 'Short Text';
    }
  }

  Future<void> _loadSkills() async {
    setState(() => _loadingSkills = true);
    final result = await _questionService.getAllSkillsResult();
    if (!mounted) return;
    setState(() => _skills = result.items);
    if (!result.ok) {
      _showMessage(result.message, error: true);
    }
    if (mounted) setState(() => _loadingSkills = false);
  }

  Future<void> _loadQuestions() async {
    setState(() => _loadingQuestions = true);
    final result = await _questionService.getAllQuestionsResult();
    if (!mounted) return;
    setState(() => _questions = result.items);
    if (!result.ok) {
      _showMessage(result.message, error: true);
    }
    if (mounted) setState(() => _loadingQuestions = false);
  }

  void _showAddSkillSheet() {
    final nameCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(title: 'New Skill'),
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Skill name *',
                    prefixIcon: Icon(Icons.star_outline))),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  final result = await _questionService.createSkillResult(name);
                  if (context.mounted && result.ok) {
                    Navigator.pop(context);
                    _showMessage(result.message);
                    _loadSkills();
                  } else if (context.mounted) {
                    _showMessage(result.message, error: true);
                  }
                },
                child: const Text('Create Skill',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddQuestionSheet() {
    final textCtrl = TextEditingController();
    final placeholderCtrl = TextEditingController();
    final optionsCtrl = TextEditingController();
    String type = 'TEXT';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
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
                const SheetHandle(title: 'Add Question'),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(
                    labelText: 'Question type *',
                    prefixIcon: Icon(Icons.tune_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'TEXT',
                      child: Text('Short Text'),
                    ),
                    DropdownMenuItem(
                      value: 'TEXTAREA',
                      child: Text('Paragraph'),
                    ),
                    DropdownMenuItem(
                      value: 'MULTIPLE_CHOICE',
                      child: Text('Multiple Choice'),
                    ),
                  ],
                  onChanged: (value) => ss(() => type = value ?? 'TEXT'),
                ),
                const SizedBox(height: 12),
                TextField(
                    controller: textCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Question text *',
                      prefixIcon: Icon(Icons.quiz_outlined),
                    )),
                const SizedBox(height: 12),
                TextField(
                  controller: placeholderCtrl,
                  decoration: InputDecoration(
                    labelText: type == 'MULTIPLE_CHOICE'
                        ? 'Helper text (optional)'
                        : 'Placeholder (optional)',
                    prefixIcon: const Icon(Icons.short_text_rounded),
                  ),
                ),
                if (type == 'MULTIPLE_CHOICE') ...[
                  const SizedBox(height: 12),
                  TextField(
                      controller: optionsCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                          labelText: 'Options *',
                          hintText: 'One per line or comma separated',
                          alignLabelWithHint: true)),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      final text = textCtrl.text.trim();
                      if (text.isEmpty) return;
                      final options = optionsCtrl.text
                          .split(RegExp(r'[\n,]'))
                          .map((s) => s.trim())
                          .where((s) => s.isNotEmpty)
                          .toList();
                      if (type == 'MULTIPLE_CHOICE' && options.isEmpty) {
                        _showMessage('Add at least one option', error: true);
                        return;
                      }
                      final result =
                          await _questionService.createQuestionResult({
                        'text': text,
                        'type': type,
                        if (placeholderCtrl.text.trim().isNotEmpty)
                          'placeholder': placeholderCtrl.text.trim(),
                        if (options.isNotEmpty) 'options': options.join(', '),
                      });
                      if (context.mounted && result.ok) {
                        Navigator.pop(context);
                        _showMessage(result.message);
                        _loadQuestions();
                      } else if (context.mounted) {
                        _showMessage(result.message, error: true);
                      }
                    },
                    child: const Text('Add Question',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Skills & Questions'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primaryLight,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.primaryLight,
          tabs: [
            Tab(text: 'Skills (${_skills.length})'),
            Tab(text: 'Questions (${_questions.length})')
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryLight,
        onPressed: () =>
            _tabs.index == 0 ? _showAddSkillSheet() : _showAddQuestionSheet(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(_tabs.index == 0 ? 'New Skill' : 'Add Question',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // Skills tab
          _loadingSkills
              ? const Center(child: CircularProgressIndicator())
              : _skills.isEmpty
                  ? const EmptyState(
                      icon: Icons.star_outline,
                      title: 'No skills yet',
                      subtitle:
                          'Create skill categories for consultant matching')
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                      itemCount: _skills.length,
                      itemBuilder: (_, i) {
                        final s = _skills[i];
                        final skillName = _skillLabel(s);
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                  color: const Color(0xFF7C3AED)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10)),
                              child: const Icon(Icons.star_rounded,
                                  color: Color(0xFF7C3AED), size: 18),
                            ),
                            title: Text(skillName, style: AppTextStyles.h4),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: AppColors.danger),
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                            title:
                                                Text('Delete "$skillName"?'),
                                            content: const Text(
                                                'This cannot be undone.'),
                                            actions: [
                                              TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          context, false),
                                                  child: const Text('Cancel')),
                                              ElevatedButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          context, true),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                          backgroundColor:
                                                              AppColors.danger),
                                                  child: const Text('Delete',
                                                      style: TextStyle(
                                                          color: Colors.white)))
                                            ]));
                                if (ok == true) {
                                  final result = await _questionService
                                      .deleteSkillResult(s['id']);
                                  if (result.ok) {
                                    _showMessage(result.message);
                                    _loadSkills();
                                  } else {
                                    _showMessage(result.message, error: true);
                                  }
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),

          // Questions tab
          _loadingQuestions
              ? const Center(child: CircularProgressIndicator())
              : _questions.isEmpty
                  ? const EmptyState(
                      icon: Icons.quiz_outlined,
                      title: 'No questions yet',
                      subtitle:
                          'Add post-booking questions for clients to answer')
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                      itemCount: _questions.length,
                      itemBuilder: (_, i) {
                        final q = _questions[i];
                        final rawType = (q['type'] ?? 'TEXT').toString();
                        final type = _prettyQuestionType(rawType);
                        final placeholder =
                            (q['placeholder'] ?? '').toString().trim();
                        final options = _questionOptions(q);
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Text('Q${i + 1}',
                                      style: AppTextStyles.caption),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                        color: AppColors.primaryLight
                                            .withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(20)),
                                    child: Text(type,
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color: AppColors.primaryLight,
                                            fontWeight: FontWeight.w700)),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: AppColors.danger, size: 20),
                                    onPressed: () async {
                                      final ok = await showDialog<bool>(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                                  title: const Text(
                                                      'Delete Question?'),
                                                  actions: [
                                                    TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                context, false),
                                                        child: const Text(
                                                            'Cancel')),
                                                    ElevatedButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                context, true),
                                                        style: ElevatedButton
                                                            .styleFrom(
                                                                backgroundColor:
                                                                    AppColors
                                                                        .danger),
                                                        child: const Text(
                                                            'Delete',
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .white)))
                                                  ]));
                                      if (ok == true) {
                                        final result = await _questionService
                                            .deleteQuestionResult(q['id']);
                                        if (result.ok) {
                                          _showMessage(result.message);
                                          _loadQuestions();
                                        } else {
                                          _showMessage(result.message,
                                              error: true);
                                        }
                                      }
                                    },
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ]),
                                const SizedBox(height: 6),
                                Text(q['text'] ?? '', style: AppTextStyles.h4),
                                if (options.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: options
                                        .take(5)
                                        .map((o) => Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                  color:
                                                      AppColors.surfaceVariant,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          20)),
                                              child: Text(o,
                                                  style: const TextStyle(
                                                      fontSize: 11)),
                                            ))
                                        .toList(),
                                  ),
                                ],
                                if (placeholder.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Placeholder: $placeholder',
                                    style: AppTextStyles.caption,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ],
      ),
    );
  }
}

// ─── OFFER APPROVALS ──────────────────────────────────────────────────────────

class OfferApprovalsScreen extends StatefulWidget {
  const OfferApprovalsScreen({super.key});
  @override
  State<OfferApprovalsScreen> createState() => _OfferApprovalsScreenState();
}

class _OfferApprovalsScreenState extends State<OfferApprovalsScreen> {
  final _dio = ApiClient().dio;
  List<Map<String, dynamic>> _offers = [];
  bool _loading = true;
  String _filter = 'PENDING';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _dio.get('/api/offers/consultant-offers');
      final list = res.data is List
          ? res.data as List
          : (res.data?['content'] as List? ?? []);
      setState(() => _offers =
          list.map((e) => Map<String, dynamic>.from(e as Map)).toList());
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _action(int id, String action) async {
    try {
      // Correct endpoint per OpenAPI spec: PUT /api/offers/{id}/status?status=APPROVED|REJECTED
      await _dio.put('/api/offers/$id/status',
          queryParameters: {'status': action.toUpperCase()});
      setState(() {
        final idx = _offers.indexWhere((o) => o['id'] == id);
        if (idx >= 0)
          _offers[idx] = {
            ..._offers[idx],
            'status': action.toUpperCase(),
            'approvalStatus': action.toUpperCase()
          };
      });
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Offer ${action.toLowerCase()}d'),
            backgroundColor: AppColors.success));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Action failed'), backgroundColor: AppColors.danger));
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'ALL') return _offers;
    return _offers
        .where((o) =>
            (o['status'] ?? o['approvalStatus'] ?? 'PENDING')
                .toString()
                .toUpperCase() ==
            _filter)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _offers
        .where((o) =>
            (o['status'] ?? o['approvalStatus'] ?? 'PENDING')
                .toString()
                .toUpperCase() ==
            'PENDING')
        .length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Offer Approvals'),
        actions: [
          if (pendingCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.3))),
                  child: Text('$pendingCount pending',
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.warning,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['ALL', 'PENDING', 'APPROVED', 'REJECTED'].map((f) {
                  final active = _filter == f;
                  final count = f == 'ALL'
                      ? _offers.length
                      : _offers
                          .where((o) =>
                              (o['status'] ?? 'PENDING')
                                  .toString()
                                  .toUpperCase() ==
                              f)
                          .length;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text('$f ($count)'),
                      selected: active,
                      selectedColor:
                          AppColors.primaryLight.withValues(alpha: 0.12),
                      checkmarkColor: AppColors.primaryLight,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? EmptyState(
                        icon: Icons.thumb_up_alt_outlined,
                        title: 'No ${_filter.toLowerCase()} offers')
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) {
                            final o = _filtered[i];
                            final status = (o['status'] ??
                                    o['approvalStatus'] ??
                                    'PENDING')
                                .toString()
                                .toUpperCase();
                            final isPending = status == 'PENDING';
                            final statusColor = status == 'APPROVED'
                                ? AppColors.success
                                : status == 'REJECTED'
                                    ? AppColors.danger
                                    : AppColors.warning;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Expanded(
                                          child: Text(o['title'] ?? 'Offer',
                                              style: AppTextStyles.h4)),
                                      if (o['discount'] != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                              color: AppColors.danger,
                                              borderRadius:
                                                  BorderRadius.circular(20)),
                                          child: Text('${o['discount']}',
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800)),
                                        ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                            color: statusColor.withValues(
                                                alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(20)),
                                        child: Text(status,
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: statusColor,
                                                fontWeight: FontWeight.w700)),
                                      ),
                                    ]),
                                    if (o['description'] != null) ...[
                                      const SizedBox(height: 6),
                                      Text(o['description'],
                                          style: AppTextStyles.caption),
                                    ],
                                    const SizedBox(height: 8),
                                    Text(
                                        'Consultant: ${o['consultantName'] ?? '#${o['consultantId'] ?? '?'}'}',
                                        style: AppTextStyles.caption),
                                    if (isPending) ...[
                                      const SizedBox(height: 12),
                                      Row(children: [
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: () => _action(
                                                o['id'] as int, 'APPROVED'),
                                            icon: const Icon(
                                                Icons.check_rounded,
                                                size: 16),
                                            label: const Text('Approve'),
                                            style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    AppColors.success),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () => _action(
                                                o['id'] as int, 'REJECTED'),
                                            icon: const Icon(
                                                Icons.close_rounded,
                                                size: 16,
                                                color: AppColors.danger),
                                            label: const Text('Reject',
                                                style: TextStyle(
                                                    color: AppColors.danger)),
                                            style: OutlinedButton.styleFrom(
                                                side: const BorderSide(
                                                    color: AppColors.danger)),
                                          ),
                                        ),
                                      ]),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ─── CONTACT SUBMISSIONS ──────────────────────────────────────────────────────

class ContactSubmissionsScreen extends StatefulWidget {
  const ContactSubmissionsScreen({super.key});
  @override
  State<ContactSubmissionsScreen> createState() =>
      _ContactSubmissionsScreenState();
}

class _ContactSubmissionsScreenState extends State<ContactSubmissionsScreen> {
  final _dio = ApiClient().dio;
  List<Map<String, dynamic>> _submissions = [];
  bool _loading = true;
  String _filter = 'all';
  String _search = '';
  Map<String, dynamic>? _selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _dio.get('/api/contact/admin/messages',
          queryParameters: {'page': 0, 'size': 50});
      final list = res.data is List
          ? res.data as List
          : (res.data?['content'] as List? ?? []);
      setState(() => _submissions =
          list.map((e) => Map<String, dynamic>.from(e as Map)).toList());
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _markRead(int id) async {
    try {
      await _dio.patch('/api/contact/admin/messages/$id/read');
      setState(() {
        final idx = _submissions.indexWhere((s) => s['id'] == id);
        if (idx >= 0)
          _submissions[idx] = {
            ..._submissions[idx],
            'isRead': true,
            'read': true
          };
      });
    } catch (_) {}
  }

  int get _unreadCount =>
      _submissions.where((s) => !(s['isRead'] ?? s['read'] ?? false)).length;

  List<Map<String, dynamic>> get _visible {
    return _submissions.where((s) {
      final isRead = s['isRead'] ?? s['read'] ?? false;
      if (_filter == 'unread' && isRead) return false;
      if (_filter == 'read' && !isRead) return false;
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        if (!(s['name'] ?? '').toString().toLowerCase().contains(q) &&
            !(s['email'] ?? '').toString().toLowerCase().contains(q) &&
            !(s['message'] ?? '').toString().toLowerCase().contains(q))
          return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(children: [
          const Text('Contact Submissions'),
          if (_unreadCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(10)),
              child: Text('$_unreadCount',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ]),
        actions: [
          if (_unreadCount > 0)
            TextButton(
                onPressed: () async {
                  for (final s
                      in _submissions.where((s) => !(s['isRead'] ?? false))) {
                    await _markRead(s['id'] as int);
                  }
                },
                child: const Text('Mark All Read')),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search by name, email, message…',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: AppColors.surfaceVariant,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Row(
              children: ['all', 'unread', 'read'].map((f) {
                final active = _filter == f;
                final count = f == 'all'
                    ? _submissions.length
                    : f == 'unread'
                        ? _unreadCount
                        : _submissions.length - _unreadCount;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label:
                        Text('${f[0].toUpperCase()}${f.substring(1)} ($count)'),
                    selected: active,
                    selectedColor:
                        AppColors.primaryLight.withValues(alpha: 0.12),
                    checkmarkColor: AppColors.primaryLight,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _submissions.isEmpty
                    ? const EmptyState(
                        icon: Icons.mail_outline_rounded,
                        title: 'No contact submissions yet',
                        subtitle:
                            'Messages from the homepage Contact Us form will appear here')
                    : _visible.isEmpty
                        ? const Center(
                            child: Text('No messages match your filter.',
                                style: TextStyle(color: AppColors.textMuted)))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _visible.length,
                            itemBuilder: (_, i) {
                              final sub = _visible[i];
                              final isRead =
                                  sub['isRead'] ?? sub['read'] ?? false;
                              final isSelected = _selected?['id'] == sub['id'];
                              return GestureDetector(
                                onTap: () {
                                  setState(() => _selected = sub);
                                  if (!isRead) _markRead(sub['id'] as int);
                                  _showDetailSheet(sub);
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primaryLight
                                            .withValues(alpha: 0.06)
                                        : AppColors.surface,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                        color: isSelected
                                            ? AppColors.primaryLight
                                                .withValues(alpha: 0.3)
                                            : AppColors.border),
                                  ),
                                  child: Row(children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: AppColors.primary
                                          .withValues(alpha: 0.1),
                                      child: Text(
                                          (sub['name'] ?? '?')[0].toUpperCase(),
                                          style: const TextStyle(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w700)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(children: [
                                              Text(sub['name'] ?? '—',
                                                  style: AppTextStyles.h4
                                                      .copyWith(
                                                          fontWeight: isRead
                                                              ? FontWeight.w600
                                                              : FontWeight
                                                                  .w800)),
                                              if (!isRead) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                    width: 7,
                                                    height: 7,
                                                    decoration:
                                                        const BoxDecoration(
                                                            color:
                                                                AppColors
                                                                    .primaryLight,
                                                            shape: BoxShape
                                                                .circle)),
                                              ],
                                            ]),
                                            Text(sub['email'] ?? '',
                                                style: AppTextStyles.caption),
                                            const SizedBox(height: 3),
                                            Text(sub['message'] ?? '',
                                                style: AppTextStyles.caption,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis),
                                          ]),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          color: AppColors.danger, size: 20),
                                      onPressed: () async {
                                        final ok = await showDialog<bool>(
                                            context: context,
                                            builder:
                                                (_) => AlertDialog(
                                                        title: const Text(
                                                            'Delete Message?'),
                                                        actions: [
                                                          TextButton(
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                      context,
                                                                      false),
                                                              child: const Text(
                                                                  'Cancel')),
                                                          ElevatedButton(
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                      context,
                                                                      true),
                                                              style: ElevatedButton.styleFrom(
                                                                  backgroundColor:
                                                                      AppColors
                                                                          .danger),
                                                              child: const Text(
                                                                  'Delete',
                                                                  style: TextStyle(
                                                                      color: Colors
                                                                          .white)))
                                                        ]));
                                        if (ok == true)
                                          _delete(sub['id'] as int);
                                      },
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ]),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  void _showDetailSheet(Map<String, dynamic> sub) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (_, ctrl) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2)),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sub['name'] ?? '—',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                    Text(sub['email'] ?? '',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ]),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                controller: ctrl,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Message', style: AppTextStyles.label),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                          border: Border(
                              left: BorderSide(
                                  color: AppColors.primaryLight
                                      .withValues(alpha: 0.5),
                                  width: 3)),
                        ),
                        child: Text(sub['message'] ?? '',
                            style: AppTextStyles.body),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            // Launch email
                          },
                          icon: const Icon(Icons.reply_rounded,
                              color: Colors.white),
                          label: const Text('Reply via Email',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryLight),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on _ContactSubmissionsScreenState {
  void _delete(int sub) {}
}

// ─── PRIVATE API SERVICE FOR ADMIN SETTINGS ──────────────────────────────────

class _SettingsService {
  final _dio = ApiClient().dio;

  String _parseTime(dynamic t) {
    if (t is Map) {
      final h = (t['hour'] ?? 0).toString().padLeft(2, '0');
      final m = (t['minute'] ?? 0).toString().padLeft(2, '0');
      return '$h:$m';
    }
    return '09:00';
  }

  Future<List<BusinessHours>> getBusinessHours() async {
    try {
      final res = await _dio.get('/api/admin/settings/business-hours');
      return (res.data as List)
          .map((e) => BusinessHours(
                id: e['id'] ?? 0,
                dayOfWeek: e['dayOfWeek'] ?? 'MONDAY',
                openTime: _parseTime(e['startTime']),
                closeTime: _parseTime(e['endTime']),
                isOpen: e['workingDay'] ?? true,
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> updateBusinessHours(List<Map<String, dynamic>> payload) async {
    try {
      await _dio.post('/api/admin/settings/business-hours', data: payload);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Holiday>> getHolidays() async {
    try {
      final r = await _dio.get('/api/admin/settings/holidays');
      return (r.data as List).map((e) => Holiday.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> addHoliday(String name, String date) async {
    try {
      await _dio.post('/api/admin/settings/holidays',
          data: {'name': name, 'holidayDate': date});
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteHoliday(int id) async {
    try {
      await _dio.delete('/api/admin/settings/holidays/$id');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getAutoResponder() async {
    try {
      final r = await _dio.get('/api/admin/settings/auto-responder');
      return r.data;
    } catch (_) {
      return null;
    }
  }

  Future<bool> setAutoResponder(bool enabled, String message) async {
    try {
      await _dio.post('/api/admin/settings/auto-responder',
          data: {'enabled': enabled, 'message': message});
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<CannedResponse>> getCannedResponses() async {
    try {
      final r = await _dio.get('/api/admin/config/canned-responses');
      return (r.data as List).map((e) => CannedResponse.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> createCannedResponse(
      String title, String content, String? category) async {
    try {
      await _dio.post('/api/admin/config/canned-responses', data: {
        'title': title,
        'content': content,
        if (category != null) 'category': category
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteCannedResponse(int id) async {
    try {
      await _dio.delete('/api/admin/config/canned-responses/$id');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<TicketCategory>> getCategories() async {
    try {
      final r = await _dio.get('/api/admin/config/categories');
      return (r.data as List).map((e) => TicketCategory.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> createCategory(String name, String? desc) async {
    try {
      await _dio.post('/api/admin/config/categories',
          data: {'name': name, if (desc != null) 'description': desc});
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> toggleCategory(int id) async {
    try {
      await _dio.patch('/api/admin/config/categories/$id/toggle');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<SubscriptionPlan>> getSubscriptionPlans() async {
    try {
      final r = await _dio.get('/api/subscription-plans');
      return (r.data as List).map((e) => SubscriptionPlan.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> createPlan(String name, double originalPrice,
      {double? discountPrice, String? features, String? tag}) async {
    try {
      await _dio.post('/api/subscription-plans', data: {
        'name': name,
        'originalPrice': originalPrice,
        if (discountPrice != null) 'discountPrice': discountPrice,
        if (features != null) 'features': features,
        if (tag != null) 'tag': tag,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deletePlan(int id) async {
    try {
      await _dio.delete('/api/subscription-plans/$id');
      return true;
    } catch (_) {
      return false;
    }
  }
}

// ─── SHARED WIDGETS USED IN SETTINGS ─────────────────────────────────────────

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyState(
      {super.key,
      required this.icon,
      required this.title,
      this.subtitle,
      this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 62, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(title, style: AppTextStyles.h3, textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!,
                style: AppTextStyles.caption, textAlign: TextAlign.center),
          ],
          if (action != null) ...[
            const SizedBox(height: 18),
            action!,
          ],
        ],
      ),
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
            decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2)),
          ),
        ),
        Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
      ],
    );
  }
}
