// lib/features/admin/admin_advisors_tab.dart
// ════════════════════════════════════════════════════════════════════════════
// Web app mein tha: Add Advisor, Edit, Delete, View Profile
// API: POST/PUT /api/consultants  (multipart/form-data)
//      DELETE /api/consultants/{id}
//      GET /api/consultants/{id}/master-timeslots
// ════════════════════════════════════════════════════════════════════════════

import 'package:finadvise/consultant_bookings_tab.dart';
import 'package:flutter/material.dart';
import 'package:finadvise/app_theme.dart';
import 'package:finadvise/models/models.dart';
import 'package:finadvise/services/consultant_service.dart';
import 'package:finadvise/admin_tickets_tab.dart' hide EmptyState;

class AdminAdvisorsTab extends StatefulWidget {
  const AdminAdvisorsTab({super.key});
  @override
  State<AdminAdvisorsTab> createState() => _AdminAdvisorsTabState();
}

class _AdminAdvisorsTabState extends State<AdminAdvisorsTab> {
  final _service = ConsultantService();
  List<ConsultantModel> _advisors = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    _advisors = await _service.getAllConsultants();
    if (mounted) setState(() => _loading = false);
  }

  List<ConsultantModel> get _filtered => _search.isEmpty
      ? _advisors
      : _advisors.where((a) => a.name.toLowerCase().contains(_search.toLowerCase()) || (a.designation ?? '').toLowerCase().contains(_search.toLowerCase())).toList();

  void _showAddAdvisor() => showModalBottomSheet(
    context: context, isScrollControlled: true, backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _AdvisorFormSheet(onSaved: () { Navigator.pop(context); _load(); }),
  );

  void _showAdvisorDetail(ConsultantModel advisor) => Navigator.push(
    context, MaterialPageRoute(builder: (_) => AdvisorDetailScreen(advisor: advisor, onChanged: _load)),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppSearchBar(hint: 'Search advisors...', onChanged: (v) => setState(() => _search = v)),
        Expanded(
          child: _loading
              ? ListView.builder(padding: const EdgeInsets.all(16), itemCount: 5, itemBuilder: (_, __) => const SizedBox(height: 90, child: ShimmerCard()))
              : _filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.people_outline, size: 64, color: AppColors.textMuted),
                          const SizedBox(height: 16),
                          Text('No advisors found', style: AppTextStyles.h3),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _showAddAdvisor, 
                            icon: const Icon(Icons.add, color: Colors.white), 
                            label: const Text('Add Advisor', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) => _AdvisorCard(advisor: _filtered[i], onTap: () => _showAdvisorDetail(_filtered[i]), onDelete: () async {
                          await _service.deleteConsultant(_filtered[i].id);
                          _load();
                        }),
                      ),
                    ),
        ),
      ],
    );
  }
}

class _AdvisorCard extends StatelessWidget {
  final ConsultantModel advisor;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _AdvisorCard({required this.advisor, required this.onTap, required this.onDelete});

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
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                backgroundImage: advisor.photoUrl != null ? NetworkImage(advisor.photoUrl!) : null,
                child: advisor.photoUrl == null ? Text(advisor.name[0].toUpperCase(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)) : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(advisor.name, style: AppTextStyles.h4)),
                        StatusChip(status: advisor.isActive ? 'ACTIVE' : 'INACTIVE', color: advisor.isActive ? AppColors.success : AppColors.textMuted),
                      ],
                    ),
                    if (advisor.designation != null) Text(advisor.designation!, style: AppTextStyles.caption),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (advisor.rating != null) ...[
                          const Icon(Icons.star_rounded, size: 12, color: AppColors.gold),
                          const SizedBox(width: 2),
                          Text(advisor.rating!.toStringAsFixed(1), style: AppTextStyles.caption),
                          const SizedBox(width: 8),
                        ],
                        if (advisor.charges != null) ...[
                          const Icon(Icons.currency_rupee, size: 12, color: AppColors.accent),
                          Text('${advisor.charges!.toStringAsFixed(0)}/session', style: AppTextStyles.caption.copyWith(color: AppColors.accent)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) { 
                  if (v == 'delete') {
                    onDelete(); 
                  }
                  if (v == 'detail') {
                    onTap(); 
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'detail', child: Row(children: [Icon(Icons.info_outline, size: 18), SizedBox(width: 10), Text('View Details')])),
                  PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: AppColors.danger), SizedBox(width: 10), Text('Delete', style: TextStyle(color: AppColors.danger))])),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── ADVISOR DETAIL SCREEN ────────────────────────────────────────────────────

class AdvisorDetailScreen extends StatefulWidget {
  final ConsultantModel advisor;
  final VoidCallback onChanged;
  const AdvisorDetailScreen({super.key, required this.advisor, required this.onChanged});

  @override
  State<AdvisorDetailScreen> createState() => _AdvisorDetailScreenState();
}

class _AdvisorDetailScreenState extends State<AdvisorDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _service = ConsultantService();
  List<TimeSlot> _slots = [];
  bool _loadingSlots = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadSlots();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _loadSlots() async {
    _slots = await _service.getSlotsByConsultant(widget.advisor.id);
    if (mounted) setState(() => _loadingSlots = false);
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.advisor;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(a.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => showModalBottomSheet(
              context: context, isScrollControlled: true, backgroundColor: AppColors.surface,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              builder: (_) => _AdvisorFormSheet(advisor: a, onSaved: () { Navigator.pop(context); widget.onChanged(); Navigator.pop(context); }),
            ),
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
                  width: double.infinity, padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]), borderRadius: BorderRadius.circular(20)),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 44, backgroundColor: Colors.white24,
                        backgroundImage: a.photoUrl != null ? NetworkImage(a.photoUrl!) : null,
                        child: a.photoUrl == null ? Text(a.name[0].toUpperCase(), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)) : null,
                      ),
                      const SizedBox(height: 12),
                      Text(a.name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                      if (a.designation != null) Text(a.designation!, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 8),
                      if (a.rating != null) Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.star_rounded, color: AppColors.gold, size: 16),
                          Text(' ${a.rating!.toStringAsFixed(1)} · ${a.reviewCount ?? 0} reviews', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _infoCard([
                  _infoRow(Icons.email_outlined, 'Email', a.email),
                  if (a.charges != null) _infoRow(Icons.currency_rupee, 'Session Fee', '₹${a.charges!.toStringAsFixed(0)}'),
                  if (a.shiftDisplay.isNotEmpty) _infoRow(Icons.access_time, 'Working Hours', a.shiftDisplay),
                  _infoRow(Icons.verified_outlined, 'Status', a.isActive ? 'Active' : 'Inactive'),
                ]),
                if (a.skills.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity, padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Skills', style: AppTextStyles.label),
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, runSpacing: 8, children: a.skills.map((s) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: AppColors.primaryLight.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)), child: Text(s, style: const TextStyle(fontSize: 12, color: AppColors.primaryLight, fontWeight: FontWeight.w600)))).toList()),
                    ]),
                  ),
                ],
              ],
            ),
          ),

          // Timeslots tab
          _loadingSlots
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${_slots.length} total slots', style: AppTextStyles.label),
                          Row(children: [
                            _legendDot(AppColors.success, 'Available'),
                            const SizedBox(width: 12),
                            _legendDot(AppColors.primaryLight, 'Booked'),
                            const SizedBox(width: 12),
                            _legendDot(AppColors.textMuted, 'Blocked'),
                          ]),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _slots.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.schedule, size: 48, color: AppColors.textMuted),
                                  const SizedBox(height: 16),
                                  Text('No timeslots', style: AppTextStyles.h3),
                                  Text('This advisor has no timeslots configured', style: AppTextStyles.caption),
                                ],
                              ),
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.all(12),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.5),
                              itemCount: _slots.length,
                              itemBuilder: (_, i) {
                                final s = _slots[i];
                                final color = s.status == 'AVAILABLE' ? AppColors.success : s.status == 'BOOKED' ? AppColors.primaryLight : AppColors.textMuted;
                                return Container(
                                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.4))),
                                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                    Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                                    const SizedBox(height: 4),
                                    Text(s.timeRange, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                                    Text(s.slotDate, style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.7))),
                                  ]),
                                );
                              },
                            ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _infoCard(List<Widget> rows) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
    child: Column(children: rows),
  );

  Widget _infoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Icon(icon, size: 18, color: AppColors.textSecondary),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppTextStyles.caption),
        Text(value, style: AppTextStyles.label.copyWith(color: AppColors.textPrimary)),
      ]),
    ]),
  );

  Widget _legendDot(Color color, String label) => Row(children: [
    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 4),
    Text(label, style: AppTextStyles.caption),
  ]);
}

// ─── ADVISOR FORM SHEET (Add / Edit) ─────────────────────────────────────────

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
  TimeOfDay _shiftStart = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _shiftEnd = const TimeOfDay(hour: 18, minute: 0);
  bool _saving = false;
  final _formKey = GlobalKey<FormState>();
  final _service = ConsultantService();

  @override
  void initState() {
    super.initState();
    if (widget.advisor != null) {
      final a = widget.advisor!;
      _nameCtrl.text = a.name;
      _emailCtrl.text = a.email;
      _desigCtrl.text = a.designation ?? '';
      _chargesCtrl.text = a.charges?.toStringAsFixed(0) ?? '';
      _descCtrl.text = a.description ?? '';
      if (a.shiftStartTime != null) {
        _shiftStart = TimeOfDay(hour: a.shiftStartTime!['hour'] ?? 9, minute: a.shiftStartTime!['minute'] ?? 0);
      }
      if (a.shiftEndTime != null) {
        _shiftEnd = TimeOfDay(hour: a.shiftEndTime!['hour'] ?? 18, minute: a.shiftEndTime!['minute'] ?? 0);
      }
    }
  }

  @override
  void dispose() { _nameCtrl.dispose(); _emailCtrl.dispose(); _desigCtrl.dispose(); _chargesCtrl.dispose(); _descCtrl.dispose(); super.dispose(); }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(context: context, initialTime: isStart ? _shiftStart : _shiftEnd);
    if (picked != null) {
      setState(() { 
        if (isStart) {
          _shiftStart = picked; 
        } else {
          _shiftEnd = picked; 
        }
      });
    }
  }

  String _fmtTime(TimeOfDay t) => '${t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod}:${t.minute.toString().padLeft(2, '0')} ${t.period == DayPeriod.am ? 'AM' : 'PM'}';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final data = {
      'name': _nameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'designation': _desigCtrl.text.trim(),
      'charges': double.tryParse(_chargesCtrl.text) ?? 0,
      'description': _descCtrl.text.trim(),
      'shiftStartTime': {'hour': _shiftStart.hour, 'minute': _shiftStart.minute, 'second': 0, 'nano': 0},
      'shiftEndTime': {'hour': _shiftEnd.hour, 'minute': _shiftEnd.minute, 'second': 0, 'nano': 0},
      'skills': [],
    };

    bool ok = false;
    if (widget.advisor != null) {
      ok = await _service.updateProfile(widget.advisor!.id, data);
    } else {
      try {
        ok = await _service.createConsultant(data);
      } catch (_) { ok = false; }
    }

    if (mounted) setState(() => _saving = false);
    if (ok) widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SheetHandle(title: widget.advisor != null ? 'Edit Advisor' : 'Add New Advisor'),
              TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Full Name *', prefixIcon: Icon(Icons.person_outline)), validator: (v) => v?.isEmpty == true ? 'Required' : null),
              const SizedBox(height: 10),
              TextFormField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email *', prefixIcon: Icon(Icons.email_outlined)), validator: (v) => v?.contains('@') == false ? 'Valid email required' : null),
              const SizedBox(height: 10),
              TextFormField(controller: _desigCtrl, decoration: const InputDecoration(labelText: 'Designation *', prefixIcon: Icon(Icons.work_outline)), validator: (v) => v?.isEmpty == true ? 'Required' : null),
              const SizedBox(height: 10),
              TextFormField(controller: _chargesCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Session Fee (₹) *', prefixText: '₹ ', prefixIcon: Icon(Icons.currency_rupee)), validator: (v) => v?.isEmpty == true ? 'Required' : null),
              const SizedBox(height: 10),
              TextFormField(controller: _descCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Description', alignLabelWithHint: true)),
              const SizedBox(height: 14),
              Text('Working Hours', style: AppTextStyles.label),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _pickTime(true),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                        child: Column(children: [Text('Start', style: AppTextStyles.caption), Text(_fmtTime(_shiftStart), style: AppTextStyles.label.copyWith(color: AppColors.primaryLight))]),
                      ),
                    ),
                  ),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('to', style: TextStyle(color: AppColors.textMuted))),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _pickTime(false),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                        child: Column(children: [Text('End', style: AppTextStyles.caption), Text(_fmtTime(_shiftEnd), style: AppTextStyles.label.copyWith(color: AppColors.primaryLight))]),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : Text(widget.advisor != null ? 'Save Changes' : 'Add Advisor', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── SHARED WIDGETS MOCKS (Fallback) ───────────────────────────────────────

class AppSearchBar extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;

  const AppSearchBar({super.key, required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.grey.withValues(alpha: 0.1),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    );
  }
}

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
      children: [
        Center(
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
          ),
        ),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
      ],
    );
  }
}