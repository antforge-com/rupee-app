// lib/features/consultant/consultant_timeslot_manager.dart
// ════════════════════════════════════════════════════════════════════════════
// Web features:
//   - View all timeslots in grid
//   - Block / unblock individual slots
//   - Bulk create slots for a date range
//   - Add custom slot (specific date + master slot)
//   - View master timeslots
// API: GET /api/timeslots/consultant/{id}
//      GET /api/timeslots/consultant/{id}/available
//      POST /api/timeslots  single slot
//      POST /api/timeslots/bulk
//      PUT /api/timeslots/{id}  status update
//      GET /api/consultants/{id}/master-timeslots
// ════════════════════════════════════════════════════════════════════════════

import 'package:finadvise/admin_advisors_tab.dart';
import 'package:finadvise/admin_analytics_tab.dart';
import 'package:finadvise/api_client.dart' as finadvise_api_client;
import 'package:finadvise/app_theme.dart';
import 'package:finadvise/consultant_bookings_tab.dart';
import 'package:finadvise/models/models.dart';
import 'package:finadvise/services/consultant_service.dart';
import 'package:flutter/material.dart';

class ConsultantTimeslotManager extends StatefulWidget {
  final int consultantId;
  const ConsultantTimeslotManager({super.key, required this.consultantId});

  @override
  State<ConsultantTimeslotManager> createState() => _ConsultantTimeslotManagerState();
}

class _ConsultantTimeslotManagerState extends State<ConsultantTimeslotManager> with SingleTickerProviderStateMixin {
  final _service = ConsultantService();
  late TabController _tabs;
  List<TimeSlot> _slots = [];
  List<dynamic> _masterSlots = [];
  bool _loading = true;
  String _filterStatus = 'ALL';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() { 
    _tabs.dispose(); 
    super.dispose(); 
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
    });
    
    // FIXED: Unnecessary cast warning removed by awaiting separately
    final slots = await _service.getSlotsByConsultant(widget.consultantId);
    final masterSlots = await _service.getMasterSlots(widget.consultantId);
    
    if (mounted) {
      setState(() {
        _slots = slots;
        _masterSlots = masterSlots;
        _loading = false;
      });
    }
  }

  List<TimeSlot> get _filtered => _filterStatus == 'ALL' ? _slots : _slots.where((s) => s.status == _filterStatus).toList();

  Color _slotColor(String status) {
    switch (status) {
      case 'AVAILABLE': return AppColors.success;
      case 'BOOKED': return AppColors.primaryLight;
      case 'UNAVAILABLE': return AppColors.textMuted;
      default: return AppColors.textMuted;
    }
  }

  Future<void> _toggleSlot(TimeSlot slot) async {
    if (slot.status == 'BOOKED') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot modify a booked slot')));
      return;
    }
    
    final isBlock = slot.status == 'AVAILABLE';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isBlock ? 'Block Slot' : 'Unblock Slot'),
        content: Text(isBlock ? 'Block ${slot.timeRange} on ${slot.slotDate}?' : 'Make ${slot.timeRange} available again?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: isBlock ? AppColors.danger : AppColors.success),
            child: Text(isBlock ? 'Block' : 'Unblock', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    
    if (confirm != true) {
      return;
    }
    
    bool ok;
    // FIXED: Used updateTimeSlot instead of undefined blockSlot/restoreSlot
    if (isBlock) {
      ok = await _service.updateTimeSlot(slot.id, {'status': 'UNAVAILABLE'});
    } else {
      ok = await _service.updateTimeSlot(slot.id, {'status': 'AVAILABLE'});
    }
    
    if (ok) {
      _loadAll();
    }
  }

  void _showAddSlotSheet() => showModalBottomSheet(
    context: context, isScrollControlled: true, backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _AddSlotSheet(consultantId: widget.consultantId, masterSlots: _masterSlots, service: _service, onAdded: () { Navigator.pop(context); _loadAll(); }),
  );

  void _showBulkCreateSheet() => showModalBottomSheet(
    context: context, isScrollControlled: true, backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _BulkCreateSheet(consultantId: widget.consultantId, masterSlots: _masterSlots, service: _service, onCreated: () { Navigator.pop(context); _loadAll(); }),
  );

  @override
  Widget build(BuildContext context) {
    final available = _slots.where((s) => s.status == 'AVAILABLE').length;
    final booked = _slots.where((s) => s.status == 'BOOKED').length;
    final unavailable = _slots.where((s) => s.status == 'UNAVAILABLE').length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Schedule Manager'),
        actions: [
          IconButton(icon: const Icon(Icons.playlist_add_rounded), onPressed: _showBulkCreateSheet, tooltip: 'Bulk create'),
          IconButton(icon: const Icon(Icons.add_rounded), onPressed: _showAddSlotSheet, tooltip: 'Add slot'),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primaryLight,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.primaryLight,
          tabs: const [Tab(text: 'Time Slots'), Tab(text: 'Master Slots')],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                // Slots tab
                Column(
                  children: [
                    // Summary row
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      color: AppColors.surface,
                      child: Row(
                        children: [
                          _statPill(available, AppColors.success, 'Available'),
                          const SizedBox(width: 8),
                          _statPill(booked, AppColors.primaryLight, 'Booked'),
                          const SizedBox(width: 8),
                          _statPill(unavailable, AppColors.textMuted, 'Blocked'),
                          const Spacer(),
                          Text('${_slots.length} total', style: AppTextStyles.caption),
                        ],
                      ),
                    ),
                    // Filter chips
                    Container(
                      color: AppColors.surface,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Row(
                          children: ['ALL', 'AVAILABLE', 'BOOKED', 'UNAVAILABLE'].map((s) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(s == 'ALL' ? 'All' : s.substring(0, 1) + s.substring(1).toLowerCase()),
                              selected: _filterStatus == s,
                              selectedColor: _slotColor(s).withValues(alpha: 0.15),
                              onSelected: (_) => setState(() => _filterStatus = s),
                              labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _filterStatus == s ? _slotColor(s) : AppColors.textSecondary),
                            ),
                          )).toList(),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: _filtered.isEmpty
                          ? EmptyState(
                              icon: Icons.schedule_outlined,
                              title: 'No slots',
                              subtitle: 'Tap + to add slots',
                              action: ElevatedButton(onPressed: _showAddSlotSheet, child: const Text('Add Slot', style: TextStyle(color: Colors.white))),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadAll,
                              child: GridView.builder(
                                padding: const EdgeInsets.all(12),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.4),
                                itemCount: _filtered.length,
                                itemBuilder: (_, i) {
                                  final s = _filtered[i];
                                  final color = _slotColor(s.status);
                                  final canTap = s.status != 'BOOKED';
                                  return GestureDetector(
                                    onTap: canTap ? () => _toggleSlot(s) : null,
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 150),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: color.withValues(alpha: 0.35)),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                                          const SizedBox(height: 5),
                                          Text(s.timeRange, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color), textAlign: TextAlign.center),
                                          const SizedBox(height: 2),
                                          Text(s.slotDate, style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.7))),
                                          if (s.status == 'BOOKED') ...[
                                            const SizedBox(height: 2),
                                            Text('booked', style: TextStyle(fontSize: 8, color: color.withValues(alpha: 0.6))),
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

                // Master slots tab
                _masterSlots.isEmpty
                    ? EmptyState(icon: Icons.schedule_outlined, title: 'No master slots', subtitle: 'Contact admin to configure master time slots', action: null,)
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _masterSlots.length,
                        itemBuilder: (_, i) {
                          final m = _masterSlots[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.primaryLight.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.access_time_rounded, color: AppColors.primaryLight, size: 18)),
                              title: Text(m['timeRange']?.toString() ?? '', style: AppTextStyles.h4),
                              subtitle: Text('Master slot #${m['id']}', style: AppTextStyles.caption),
                            ),
                          );
                        },
                      ),
              ],
            ),
    );
  }

  Widget _statPill(int count, Color color, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
    child: Row(children: [
      Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text('$count $label', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    ]),
  );
}

// ─── ADD SLOT SHEET ───────────────────────────────────────────────────────────

class _AddSlotSheet extends StatefulWidget {
  final int consultantId;
  final List<dynamic> masterSlots;
  final ConsultantService service;
  final VoidCallback onAdded;
  const _AddSlotSheet({required this.consultantId, required this.masterSlots, required this.service, required this.onAdded});

  @override
  State<_AddSlotSheet> createState() => _AddSlotSheetState();
}

class _AddSlotSheetState extends State<_AddSlotSheet> {
  String? _selectedDate;
  int? _selectedMasterId;
  int _duration = 60;
  bool _adding = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(title: 'Add Time Slot'),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
              if (picked != null) {
                setState(() => _selectedDate = picked.toIso8601String().split('T')[0]);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
              child: Row(children: [
                const Icon(Icons.calendar_today_outlined, color: AppColors.textSecondary, size: 20),
                const SizedBox(width: 12),
                Text(_selectedDate ?? 'Select date', style: _selectedDate != null ? AppTextStyles.body : AppTextStyles.label),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          if (widget.masterSlots.isNotEmpty) ...[
            Text('Time Range', style: AppTextStyles.label),
            const SizedBox(height: 6),
            DropdownButtonFormField<int>(
              value: _selectedMasterId,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.access_time_outlined)),
              hint: const Text('Select time range'),
              items: widget.masterSlots.map<DropdownMenuItem<int>>((m) => DropdownMenuItem(value: m['id'] as int, child: Text(m['timeRange']?.toString() ?? ''))).toList(),
              onChanged: (v) => setState(() => _selectedMasterId = v),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Text('Duration: ', style: AppTextStyles.label),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _duration,
                items: [30, 45, 60, 90, 120].map((d) => DropdownMenuItem(value: d, child: Text('$d min'))).toList(),
                onChanged: (v) => setState(() => _duration = v!),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, height: 48,
            child: ElevatedButton(
              onPressed: _adding || _selectedDate == null || _selectedMasterId == null ? null : () async {
                setState(() {
                  _adding = true;
                });
                final result = await widget.service.addCustomSlot(
                  consultantId: widget.consultantId,
                  slotDate: _selectedDate!,
                  masterTimeSlotId: _selectedMasterId!,
                  durationMinutes: _duration,
                );
                
                if (mounted) {
                  setState(() {
                    _adding = false;
                  });
                }
                
                if (result != null) {
                  widget.onAdded();
                }
              },
              child: _adding ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Add Slot', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── BULK CREATE SHEET ────────────────────────────────────────────────────────

class _BulkCreateSheet extends StatefulWidget {
  final int consultantId;
  final List<dynamic> masterSlots;
  final ConsultantService service;
  final VoidCallback onCreated;
  const _BulkCreateSheet({required this.consultantId, required this.masterSlots, required this.service, required this.onCreated});

  @override
  State<_BulkCreateSheet> createState() => _BulkCreateSheetState();
}

class _BulkCreateSheetState extends State<_BulkCreateSheet> {
  String? _startDate, _endDate;
  final List<int> _selectedMasterIds = [];
  int _duration = 60;
  bool _creating = false;

  Future<void> _create() async {
    if (_startDate == null || _endDate == null || _selectedMasterIds.isEmpty) {
      return;
    }
    setState(() {
      _creating = true;
    });

    final start = DateTime.parse(_startDate!);
    final end = DateTime.parse(_endDate!);
    final slots = <Map<String, dynamic>>[];

    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      for (final masterId in _selectedMasterIds) {
        slots.add({
          'consultantId': widget.consultantId,
          'slotDate': d.toIso8601String().split('T')[0],
          'masterTimeSlotId': masterId,
          'durationMinutes': _duration,
        });
      }
    }

    // Use bulk endpoint
    try {
      final apiClient = ApiClientBulk();
      await apiClient.bulkCreateSlots(slots);
      
      if (mounted) { 
        setState(() {
          _creating = false;
        }); 
        widget.onCreated(); 
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _creating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(title: 'Bulk Create Slots'),
            Text('Date Range', style: AppTextStyles.label),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final p = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
                      if (p != null) {
                        setState(() => _startDate = p.toIso8601String().split('T')[0]);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                      child: Column(children: [Text('From', style: AppTextStyles.caption), Text(_startDate ?? 'Select', style: AppTextStyles.label.copyWith(color: AppColors.primaryLight))]),
                    ),
                  ),
                ),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('to', style: TextStyle(color: AppColors.textMuted))),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final p = await showDatePicker(context: context, initialDate: _startDate != null ? DateTime.parse(_startDate!) : DateTime.now(), firstDate: _startDate != null ? DateTime.parse(_startDate!) : DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
                      if (p != null) {
                        setState(() => _endDate = p.toIso8601String().split('T')[0]);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                      child: Column(children: [Text('To', style: AppTextStyles.caption), Text(_endDate ?? 'Select', style: AppTextStyles.label.copyWith(color: AppColors.primaryLight))]),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Select Time Slots', style: AppTextStyles.label),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: widget.masterSlots.map((m) {
                final id = m['id'] as int;
                final selected = _selectedMasterIds.contains(id);
                return GestureDetector(
                  onTap: () {
                    setState(() { 
                      if (selected) {
                        _selectedMasterIds.remove(id); 
                      } else {
                        _selectedMasterIds.add(id); 
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primaryLight.withValues(alpha: 0.15) : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: selected ? AppColors.primaryLight : AppColors.border),
                    ),
                    child: Text(m['timeRange']?.toString() ?? '', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? AppColors.primaryLight : AppColors.textSecondary)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Text('Duration: ', style: AppTextStyles.label),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _duration,
                items: [30, 45, 60, 90, 120].map((d) => DropdownMenuItem(value: d, child: Text('$d min'))).toList(),
                onChanged: (v) => setState(() => _duration = v!),
              ),
            ]),
            const SizedBox(height: 16),
            if (_startDate != null && _endDate != null && _selectedMasterIds.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                child: Text(
                  'Will create ${(_selectedMasterIds.length * (_endDate != null ? DateTime.parse(_endDate!).difference(DateTime.parse(_startDate!)).inDays + 1 : 0))} slots',
                  style: AppTextStyles.caption.copyWith(color: AppColors.info),
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity, height: 48,
              child: ElevatedButton(
                onPressed: _creating || _startDate == null || _endDate == null || _selectedMasterIds.isEmpty ? null : _create,
                child: _creating ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Create Slots', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ApiClientBulk {
  Future<void> bulkCreateSlots(List<Map<String, dynamic>> slots) async {
    final apiClient = finadvise_api_client.ApiClient();
    await apiClient.dio.post('/api/timeslots/bulk', data: {'timeSlots': slots});
  }
}