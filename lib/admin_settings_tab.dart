// lib/features/admin/admin_settings_tab.dart
// ════════════════════════════════════════════════════════════════════════════
// Complete Admin Settings with ALL web features:
//   - Business Hours (Mon-Sun toggle + time config)
//   - Holidays (add/delete)
//   - Auto-responder (enable/disable + message)
//   - Canned Responses (add/delete)
//   - Ticket Categories (add/toggle active)
//   - Subscription Plans (add/edit/delete)
// ════════════════════════════════════════════════════════════════════════════
import 'package:finadvise/admin_advisors_tab.dart';
import 'package:finadvise/admin_analytics_tab.dart';
import 'package:finadvise/api_client.dart';
import 'package:finadvise/app_theme.dart';
import 'package:finadvise/consultant_bookings_tab.dart';
import 'package:finadvise/models/models.dart';
import 'package:flutter/material.dart';

class AdminSettingsTab extends StatelessWidget {
  const AdminSettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionTile(
          icon: Icons.access_time_rounded,
          title: 'Business Hours',
          subtitle: 'Working days & time configuration',
          color: AppColors.primaryLight,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BusinessHoursScreen())),
        ),
        _SectionTile(
          icon: Icons.beach_access_rounded,
          title: 'Holidays',
          subtitle: 'Manage non-working days',
          color: AppColors.warning,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HolidaysScreen())),
        ),
        _SectionTile(
          icon: Icons.auto_awesome_rounded,
          title: 'Auto Responder',
          subtitle: 'Automatic ticket acknowledgment',
          color: AppColors.accent,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AutoResponderScreen())),
        ),
        _SectionTile(
          icon: Icons.chat_bubble_outline_rounded,
          title: 'Canned Responses',
          subtitle: 'Quick reply templates',
          color: AppColors.info,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CannedResponsesScreen())),
        ),
        _SectionTile(
          icon: Icons.label_outline_rounded,
          title: 'Ticket Categories',
          subtitle: 'Manage ticket types',
          color: AppColors.gold,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TicketCategoriesScreen())),
        ),
        _SectionTile(
          icon: Icons.card_membership_rounded,
          title: 'Subscription Plans',
          subtitle: 'Pricing plans management',
          color: AppColors.primary,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionPlansScreen())),
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

  const _SectionTile({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(title, style: AppTextStyles.h4),
        subtitle: Text(subtitle, style: AppTextStyles.caption),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
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

  static const _days = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];
  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    _hours = await _api.getBusinessHours();
    if (_hours.isEmpty) {
      _hours = _days.map((d) => BusinessHours(id: 0, dayOfWeek: d, openTime: '09:00', closeTime: '18:00', isOpen: d != 'SATURDAY' && d != 'SUNDAY')).toList();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    
    // Parse time strings (e.g., "09:00") into LocalTime objects as per Swagger spec
    Map<String, dynamic> parseTime(String t) {
      final parts = t.split(':');
      return {'hour': int.parse(parts[0]), 'minute': int.parse(parts[1]), 'second': 0, 'nano': 0};
    }

    final payload = _hours.map((h) => {
      'dayOfWeek': h.dayOfWeek,
      'startTime': parseTime(h.openTime),
      'endTime': parseTime(h.closeTime),
      'workingDay': h.isOpen,
    }).toList();

    await _api.updateBusinessHours(payload);
    
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Business hours saved'), backgroundColor: AppColors.success));
    }
  }

  Future<void> _pickTime(int index, bool isOpen) async {
    final current = isOpen ? _hours[index].openTime : _hours[index].closeTime;
    final parts = current.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
    );
    if (picked != null) {
      final timeStr = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        if (isOpen) {
          _hours[index] = BusinessHours(id: _hours[index].id, dayOfWeek: _hours[index].dayOfWeek, openTime: timeStr, closeTime: _hours[index].closeTime, isOpen: _hours[index].isOpen);
        } else {
          _hours[index] = BusinessHours(id: _hours[index].id, dayOfWeek: _hours[index].dayOfWeek, openTime: _hours[index].openTime, closeTime: timeStr, isOpen: _hours[index].isOpen);
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
            child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
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
                    border: Border.all(color: h.isOpen ? AppColors.border : AppColors.border.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 36,
                        child: Text(dayIdx >= 0 ? _dayLabels[dayIdx] : h.dayOfWeek.substring(0, 3), style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
                      ),
                      Switch(
                        value: h.isOpen,
                        activeThumbColor: AppColors.success,
                        activeTrackColor: AppColors.success.withValues(alpha: 0.5),
                        onChanged: (v) => setState(() {
                          _hours[i] = BusinessHours(id: h.id, dayOfWeek: h.dayOfWeek, openTime: h.openTime, closeTime: h.closeTime, isOpen: v);
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
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(8)),
                                  child: Text(h.openTime, style: AppTextStyles.label.copyWith(color: AppColors.primaryLight)),
                                ),
                              ),
                              const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('—', style: TextStyle(color: AppColors.textMuted))),
                              GestureDetector(
                                onTap: () => _pickTime(i, false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(8)),
                                  child: Text(h.closeTime, style: AppTextStyles.label.copyWith(color: AppColors.primaryLight)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else
                        Expanded(child: Text('Closed', style: AppTextStyles.caption)),
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
  void initState() { super.initState(); _load(); }
  
  Future<void> _load() async {
    setState(() => _loading = true);
    _holidays = await _api.getHolidays();
    if (mounted) setState(() => _loading = false);
  }

  void _showAddSheet() {
    final nameCtrl = TextEditingController();
    String? selectedDate;
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, ss) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHandle(title: 'Add Holiday'),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Holiday name', prefixIcon: Icon(Icons.celebration_outlined))),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(context: ctx, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                  if (picked != null) ss(() => selectedDate = picked.toIso8601String().split('T')[0]);
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, color: AppColors.textSecondary, size: 20),
                      const SizedBox(width: 12),
                      Text(selectedDate ?? 'Select date', style: selectedDate != null ? AppTextStyles.body : AppTextStyles.label),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.isEmpty || selectedDate == null) return;
                    final result = await _api.addHoliday(nameCtrl.text, selectedDate!);
                    if (result && mounted) { Navigator.pop(context); _load(); }
                  },
                  child: const Text('Add Holiday', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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
      appBar: AppBar(title: const Text('Holidays'), actions: [IconButton(icon: const Icon(Icons.add), onPressed: _showAddSheet)]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _holidays.isEmpty
              ? const EmptyState(icon: Icons.beach_access_outlined, title: 'No holidays added', subtitle: 'Add holidays to block booking slots')
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
                          leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.beach_access_outlined, color: AppColors.warning, size: 20)),
                          title: Text(h.name, style: AppTextStyles.h4),
                          subtitle: Text(h.date, style: AppTextStyles.caption),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Delete Holiday'), content: Text('Delete "${h.name}"?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger), child: const Text('Delete', style: TextStyle(color: Colors.white)))]));
                              if (confirm == true) { await _api.deleteHoliday(h.id); _load(); }
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
  bool _enabled = false;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _msgCtrl.dispose(); super.dispose(); }

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

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await _api.setAutoResponder(_enabled, _msgCtrl.text);
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Auto-responder updated' : 'Failed to save'), backgroundColor: ok ? AppColors.success : AppColors.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Auto Responder')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Auto Responder', style: AppTextStyles.h4),
                              const SizedBox(height: 4),
                              Text('Send automatic reply when ticket is created', style: AppTextStyles.caption),
                            ],
                          ),
                        ),
                        Switch(
                          value: _enabled, 
                          activeThumbColor: AppColors.success,
                          activeTrackColor: AppColors.success.withValues(alpha: 0.5), 
                          onChanged: (v) => setState(() => _enabled = v)
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_enabled) ...[
                    Text('Auto-reply message', style: AppTextStyles.label),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _msgCtrl,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        hintText: 'Thank you for contacting us. We will respond within 24 hours...',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  SizedBox(
                    width: double.infinity, height: 48,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
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

  @override
  void initState() { super.initState(); _load(); }
  
  Future<void> _load() async {
    setState(() => _loading = true);
    _responses = await _api.getCannedResponses();
    if (mounted) setState(() => _loading = false);
  }

  void _showAddSheet() {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    final catCtrl = TextEditingController();
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(title: 'Add Canned Response'),
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title', prefixIcon: Icon(Icons.title))),
            const SizedBox(height: 12),
            TextField(controller: catCtrl, decoration: const InputDecoration(labelText: 'Category (optional)', prefixIcon: Icon(Icons.label_outline))),
            const SizedBox(height: 12),
            TextField(controller: contentCtrl, maxLines: 4, decoration: const InputDecoration(labelText: 'Response content', alignLabelWithHint: true)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  if (titleCtrl.text.isEmpty || contentCtrl.text.isEmpty) return;
                  final result = await _api.createCannedResponse(titleCtrl.text, contentCtrl.text, catCtrl.text.isNotEmpty ? catCtrl.text : null);
                  if (result && mounted) { Navigator.pop(context); _load(); }
                },
                child: const Text('Add Response', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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
      appBar: AppBar(title: const Text('Canned Responses'), actions: [IconButton(icon: const Icon(Icons.add), onPressed: _showAddSheet)]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _responses.isEmpty
              ? const EmptyState(icon: Icons.chat_bubble_outline, title: 'No canned responses', subtitle: 'Add quick reply templates for common queries')
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _responses.length,
                  itemBuilder: (_, i) {
                    final r = _responses[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.chat_bubble_outline, color: AppColors.info, size: 18)),
                        title: Text(r.title, style: AppTextStyles.h4),
                        subtitle: Text(r.content, style: AppTextStyles.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                          onPressed: () async {
                            await _api.deleteCannedResponse(r.id);
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
  void initState() { super.initState(); _load(); }
  
  Future<void> _load() async {
    setState(() => _loading = true);
    _categories = await _api.getCategories();
    if (mounted) setState(() => _loading = false);
  }

  void _showAddSheet() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(title: 'Add Category'),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Category name', prefixIcon: Icon(Icons.label_outline))),
            const SizedBox(height: 12),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description (optional)', prefixIcon: Icon(Icons.description_outlined))),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.isEmpty) return;
                  final result = await _api.createCategory(nameCtrl.text, descCtrl.text.isNotEmpty ? descCtrl.text : null);
                  if (result && mounted) { Navigator.pop(context); _load(); }
                },
                child: const Text('Add Category', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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
      appBar: AppBar(title: const Text('Ticket Categories'), actions: [IconButton(icon: const Icon(Icons.add), onPressed: _showAddSheet)]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _categories.isEmpty
              ? const EmptyState(icon: Icons.label_outline, title: 'No categories', subtitle: 'Add categories to classify tickets')
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
                          decoration: BoxDecoration(color: (c.isActive ? AppColors.success : AppColors.textMuted).withValues(alpha: 0.1), shape: BoxShape.circle),
                          child: Icon(Icons.label_rounded, color: c.isActive ? AppColors.success : AppColors.textMuted, size: 18),
                        ),
                        title: Text(c.name, style: AppTextStyles.h4),
                        subtitle: c.description != null ? Text(c.description!, style: AppTextStyles.caption) : null,
                        trailing: Switch(
                          value: c.isActive,
                          activeThumbColor: AppColors.success,
                          activeTrackColor: AppColors.success.withValues(alpha: 0.5),
                          onChanged: (_) async { await _api.toggleCategory(c.id); _load(); },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// ─── SUBSCRIPTION PLANS ───────────────────────────────────────────────────────

class SubscriptionPlansScreen extends StatefulWidget {
  const SubscriptionPlansScreen({super.key});
  @override
  State<SubscriptionPlansScreen> createState() => _SubscriptionPlansScreenState();
}

class _SubscriptionPlansScreenState extends State<SubscriptionPlansScreen> {
  final _api = _SettingsService();
  List<SubscriptionPlan> _plans = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }
  
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
      context: context, isScrollControlled: true, backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHandle(title: 'New Subscription Plan'),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Plan name', prefixIcon: Icon(Icons.card_membership_outlined))),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: TextField(controller: origCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Original price (₹)', prefixText: '₹ '))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: discCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Discount price (₹)', prefixText: '₹ '))),
                ],
              ),
              const SizedBox(height: 10),
              TextField(controller: featCtrl, decoration: const InputDecoration(labelText: 'Features (comma-separated)', prefixIcon: Icon(Icons.star_outline))),
              const SizedBox(height: 10),
              TextField(controller: tagCtrl, decoration: const InputDecoration(labelText: 'Tag (e.g. Popular)', prefixIcon: Icon(Icons.local_offer_outlined))),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.isEmpty || origCtrl.text.isEmpty) return;
                    final result = await _api.createPlan(
                      nameCtrl.text,
                      double.tryParse(origCtrl.text) ?? 0,
                      discountPrice: discCtrl.text.isNotEmpty ? double.tryParse(discCtrl.text) : null,
                      features: featCtrl.text.isNotEmpty ? featCtrl.text : null,
                      tag: tagCtrl.text.isNotEmpty ? tagCtrl.text : null,
                    );
                    if (result && mounted) { Navigator.pop(context); _load(); }
                  },
                  child: const Text('Create Plan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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
      appBar: AppBar(title: const Text('Subscription Plans'), actions: [IconButton(icon: const Icon(Icons.add), onPressed: _showAddSheet)]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _plans.isEmpty
              ? const EmptyState(icon: Icons.card_membership_outlined, title: 'No plans created')
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
                              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.card_membership_rounded, color: AppColors.primary, size: 22),
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
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                                          child: Text(p.tag!, style: const TextStyle(fontSize: 10, color: AppColors.gold, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      if (p.discountPrice != null && p.discountPrice != p.originalPrice) ...[
                                        Text('₹${p.discountPrice!.toStringAsFixed(0)}', style: AppTextStyles.label.copyWith(color: AppColors.accent, fontWeight: FontWeight.w700)),
                                        const SizedBox(width: 6),
                                        Text('₹${p.originalPrice.toStringAsFixed(0)}', style: AppTextStyles.caption.copyWith(decoration: TextDecoration.lineThrough)),
                                      ] else
                                        Text('₹${p.originalPrice.toStringAsFixed(0)}', style: AppTextStyles.label.copyWith(color: AppColors.accent, fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                  if (p.features != null && p.features!.isNotEmpty)
                                    Text(p.features!, style: AppTextStyles.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                              onPressed: () async {
                                final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Delete Plan'), content: Text('Delete "${p.name}"?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger), child: const Text('Delete', style: TextStyle(color: Colors.white)))]));
                                if (ok == true) { await _api.deletePlan(p.id); _load(); }
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

// ─── PRIVATE API SERVICE FOR ADMIN SETTINGS ──────────────────────────────────
// This isolated class fixes all undefined method errors by connecting directly 
// to ApiClient without relying on mismatched service imports.

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

  // Business Hours
  Future<List<BusinessHours>> getBusinessHours() async {
    try {
      final res = await _dio.get('/api/admin/settings/business-hours');
      return (res.data as List).map((e) => BusinessHours(
        id: e['id'] ?? 0,
        dayOfWeek: e['dayOfWeek'] ?? 'MONDAY',
        openTime: _parseTime(e['startTime']),
        closeTime: _parseTime(e['endTime']),
        isOpen: e['workingDay'] ?? true,
      )).toList();
    } catch (_) { return []; }
  }

  Future<bool> updateBusinessHours(List<Map<String, dynamic>> payload) async {
    try { await _dio.post('/api/admin/settings/business-hours', data: payload); return true; } catch (_) { return false; }
  }

  // Holidays
  Future<List<Holiday>> getHolidays() async {
    try { final r = await _dio.get('/api/admin/settings/holidays'); return (r.data as List).map((e) => Holiday.fromJson(e)).toList(); } catch (_) { return []; }
  }

  Future<bool> addHoliday(String name, String date) async {
    try { await _dio.post('/api/admin/settings/holidays', data: {'name': name, 'holidayDate': date}); return true; } catch (_) { return false; }
  }

  Future<bool> deleteHoliday(int id) async {
    try { await _dio.delete('/api/admin/settings/holidays/$id'); return true; } catch (_) { return false; }
  }

  // Auto Responder
  Future<Map<String, dynamic>?> getAutoResponder() async {
    try { final r = await _dio.get('/api/admin/settings/auto-responder'); return r.data; } catch (_) { return null; }
  }

  Future<bool> setAutoResponder(bool enabled, String message) async {
    try { await _dio.post('/api/admin/settings/auto-responder', data: {'enabled': enabled, 'message': message}); return true; } catch (_) { return false; }
  }

  // Canned Responses
  Future<List<CannedResponse>> getCannedResponses() async {
    try { final r = await _dio.get('/api/admin/config/canned-responses'); return (r.data as List).map((e) => CannedResponse.fromJson(e)).toList(); } catch (_) { return []; }
  }

  Future<bool> createCannedResponse(String title, String content, String? category) async {
    try { await _dio.post('/api/admin/config/canned-responses', data: {'title': title, 'content': content, if (category != null) 'category': category}); return true; } catch (_) { return false; }
  }

  Future<bool> deleteCannedResponse(int id) async {
    try { await _dio.delete('/api/admin/config/canned-responses/$id'); return true; } catch (_) { return false; }
  }

  // Ticket Categories
  Future<List<TicketCategory>> getCategories() async {
    try { final r = await _dio.get('/api/admin/config/categories'); return (r.data as List).map((e) => TicketCategory.fromJson(e)).toList(); } catch (_) { return []; }
  }

  Future<bool> createCategory(String name, String? desc) async {
    try { await _dio.post('/api/admin/config/categories', data: {'name': name, if (desc != null) 'description': desc}); return true; } catch (_) { return false; }
  }

  Future<bool> toggleCategory(int id) async {
    try { await _dio.patch('/api/admin/config/categories/$id/toggle'); return true; } catch (_) { return false; }
  }

  // Subscription Plans
  Future<List<SubscriptionPlan>> getSubscriptionPlans() async {
    try { final r = await _dio.get('/api/subscription-plans'); return (r.data as List).map((e) => SubscriptionPlan.fromJson(e)).toList(); } catch (_) { return []; }
  }

  Future<bool> createPlan(String name, double originalPrice, {double? discountPrice, String? features, String? tag}) async {
    try {
      await _dio.post('/api/subscription-plans', data: {
        'name': name, 'originalPrice': originalPrice,
        if (discountPrice != null) 'discountPrice': discountPrice,
        if (features != null) 'features': features,
        if (tag != null) 'tag': tag,
      });
      return true;
    } catch (_) { return false; }
  }

  Future<bool> deletePlan(int id) async {
    try { await _dio.delete('/api/subscription-plans/$id'); return true; } catch (_) { return false; }
  }
}