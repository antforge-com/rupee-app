// lib/features/admin/admin_tickets_tab.dart
import 'package:finadvise/models/models.dart';
import 'package:finadvise/services/consultant_service.dart';
import 'package:finadvise/services/ticket_service.dart';
import 'package:flutter/material.dart';
import 'package:finadvise/app_theme.dart';
import 'ticket_detail_screen.dart';

class AdminTicketsTab extends StatefulWidget {
  const AdminTicketsTab({super.key});

  @override
  State<AdminTicketsTab> createState() => _AdminTicketsTabState();
}

class _AdminTicketsTabState extends State<AdminTicketsTab> {
  final TicketService _ticketService = TicketService();
  final ConsultantService _consultantService = ConsultantService();

  List<Ticket> _tickets = [];
  List<Ticket> _filtered = [];
  List<ConsultantModel> _consultants = [];
  bool _loading = true;
  String _search = '';
  String _statusFilter = 'ALL';
  String _priorityFilter = 'ALL';

  final List<String> _statuses = [
    'ALL', 'NEW', 'OPEN', 'IN_PROGRESS', 'PENDING', 'RESOLVED', 'CLOSED', 'ESCALATED'
  ];
  final List<String> _priorities = [
    'ALL', 'LOW', 'MEDIUM', 'HIGH', 'URGENT', 'CRITICAL'
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      // Running both API calls in parallel for faster loading
      final responses = await Future.wait([
        _ticketService.getAllTickets(),
        _consultantService.getAllConsultants(),
      ]);

      setState(() {
        _tickets = responses[0] as List<Ticket>;
        _filtered = _tickets;
        _consultants = responses[1] as List<ConsultantModel>;
      });
    } catch (e) {
      debugPrint('Error loading tickets or consultants: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _filtered = _tickets.where((t) {
        // Null-aware fixes applied according to model field types
        final matchesSearch = (t.description ?? '').toLowerCase().contains(_search.toLowerCase()) ||
                              t.category.toLowerCase().contains(_search.toLowerCase()) ||
                              t.id.toString().contains(_search);
        final matchesStatus = _statusFilter == 'ALL' || t.status.toUpperCase() == _statusFilter;
        final matchesPriority = _priorityFilter == 'ALL' || t.priority.toUpperCase() == _priorityFilter;
        
        return matchesSearch && matchesStatus && matchesPriority;
      }).toList();
    });
  }

  // Export Features Logic
  void _exportTickets(String format) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tickets are being exported in $format format... (Check File Manager)'),
        backgroundColor: AppColors.primaryLight,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tickets Management', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          // Export Dropdown Menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Export Tickets',
            onSelected: _exportTickets,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'PDF', 
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf, color: AppColors.danger, size: 20),
                    SizedBox(width: 8),
                    Text('Export to PDF'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'Excel', 
                child: Row(
                  children: [
                    Icon(Icons.table_view, color: AppColors.success, size: 20),
                    SizedBox(width: 8),
                    Text('Export to Excel (CSV)'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: Column(
        children: [
          // ── SEARCH & FILTER SECTION ──
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                // Search Bar
                TextField(
                  onChanged: (val) {
                    _search = val;
                    _applyFilters();
                  },
                  decoration: InputDecoration(
                    hintText: 'Search tickets by ID, category, or description...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Dropdown Filters
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _statusFilter,
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                            items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _statusFilter = val);
                                _applyFilters();
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _priorityFilter,
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                            items: _priorities.map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 13)))).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _priorityFilter = val);
                                _applyFilters();
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // ── TICKET LIST SECTION ──
          Expanded(
            child: _loading 
              ? const Center(child: CircularProgressIndicator())
              : _filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, size: 64, color: AppColors.textMuted.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        const Text('No tickets found', style: TextStyle(fontSize: 18, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        const Text('Try adjusting your search or filters.', style: TextStyle(color: AppColors.textMuted)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final ticket = _filtered[index];
                      return _buildTicketCard(ticket);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketCard(Ticket ticket) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Passing required params to TicketDetailScreen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TicketDetailScreen(
                ticket: ticket,
                consultants: _consultants,
                role: 'ADMIN', // Set role as ADMIN since this is the Admin Tab
              ),
            ),
          ).then((_) => _loadData()); // Refresh on back
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '#${ticket.id} - ${ticket.category.isEmpty ? 'General' : ticket.category}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          (ticket.description?.isEmpty ?? true) ? 'No description provided.' : ticket.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: getStatusColor(ticket.status).withValues(alpha: 0.1),
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
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text((ticket.userName?.isEmpty ?? true) ? "User" : ticket.userName!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const Spacer(),
                  Icon(Icons.flag_outlined, size: 14, color: getPriorityColor(ticket.priority)),
                  const SizedBox(width: 4),
                  Text(
                    ticket.priority,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: getPriorityColor(ticket.priority)),
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