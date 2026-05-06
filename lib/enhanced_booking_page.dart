import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'app_theme.dart';
import 'services/comprehensive_api_service.dart';
import 'services/user_service.dart';

class EnhancedBookingPage extends StatefulWidget {
  const EnhancedBookingPage({super.key});

  @override
  State<EnhancedBookingPage> createState() => _EnhancedBookingPageState();
}

class _EnhancedBookingPageState extends State<EnhancedBookingPage> {
  final _apiService = ComprehensiveApiService();
  final _userService = UserService();

  List<dynamic> _bookings = [];
  List<dynamic> _consultants = [];
  List<dynamic> _timeSlots = [];
  List<dynamic> _questions = [];

  bool _loading = true;
  String _error = '';
  String _selectedStatus = 'ALL';

  final List<String> _statusFilters = [
    'ALL',
    'PENDING',
    'CONFIRMED',
    'COMPLETED',
    'CANCELLED'
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final me = await _userService.getMe();
      final userId = me?.id ?? 0;

      final consultants = await _apiService.getAllConsultants();
      final bookings =
          userId > 0 ? await _apiService.getUserBookings(userId) : [];
      final timeSlots = await _apiService.getAllTimeSlots();
      final questions = await _apiService.getAllQuestions();

      if (mounted) {
        setState(() {
          _consultants = consultants;
          _bookings = bookings;
          _timeSlots = timeSlots;
          _questions = questions;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load data: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _createBooking() async {
    showDialog(
      context: context,
      builder: (context) => BookingFormDialog(
        consultants: _consultants,
        timeSlots: _timeSlots,
        questions: _questions,
        apiService: _apiService,
      ),
    ).then((_) {
      _loadData();
    });
  }

  Future<void> _viewBookingDetails(dynamic booking) async {
    showDialog(
      context: context,
      builder: (context) => BookingDetailsDialog(bookingData: booking),
    );
  }

  Future<void> _cancelBooking(int bookingId) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cancel Booking'),
            content: const Text('Are you sure? This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Yes, Cancel'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed) {
      final success = await _apiService.cancelBooking(bookingId);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking cancelled successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to cancel booking'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error.isNotEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final filteredBookings = _selectedStatus == 'ALL'
        ? _bookings
        : _bookings
            .where(
                (b) => b['status']?.toString().toUpperCase() == _selectedStatus)
            .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('My Bookings',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: filteredBookings.isEmpty
                ? const Center(child: Text('No bookings found'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredBookings.length,
                    itemBuilder: (context, index) =>
                        _buildBookingCard(filteredBookings[index]),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createBooking,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _statusFilters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final status = _statusFilters[index];
          final isSelected = _selectedStatus == status;
          return GestureDetector(
            onTap: () => setState(() => _selectedStatus = status),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF06B6D4) : Colors.white,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color:
                      isSelected ? const Color(0xFF06B6D4) : AppColors.border,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF06B6D4).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : [],
              ),
              child: Center(
                child: Text(
                  status,
                  style: GoogleFonts.inter(
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBookingCard(dynamic b) {
    final status = b['status']?.toString().toUpperCase() ?? 'PENDING';
    final date = b['bookingDate'] ?? 'N/A';
    final time = b['timeRange'] ?? 'N/A';
    final name = b['consultantName'] ?? 'Expert';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: () => _viewBookingDetails(b),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Session with $name',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: AppColors.textPrimary)),
                  _statusChip(status),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Text(date,
                      style: const TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(width: 16),
                  const Icon(Icons.access_time,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Text(time,
                      style: const TextStyle(color: AppColors.textSecondary)),
                ],
              ),
              if (status == 'CONFIRMED' ||
                  status == 'PENDING' ||
                  status == 'COMPLETED') ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (status == 'CONFIRMED' || status == 'PENDING')
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _cancelBooking(b['id']),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.danger,
                              side: const BorderSide(color: AppColors.danger)),
                          child: const Text('Cancel Booking'),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    Color color = AppColors.warning;
    if (status == 'CONFIRMED') color = AppColors.success;
    if (status == 'COMPLETED') color = const Color(0xFF06B6D4);
    if (status == 'CANCELLED') color = AppColors.danger;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: GoogleFonts.inter(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class BookingFormDialog extends StatefulWidget {
  final List<dynamic> consultants;
  final List<dynamic> timeSlots;
  final List<dynamic> questions;
  final ComprehensiveApiService apiService;

  const BookingFormDialog({
    super.key,
    required this.consultants,
    required this.timeSlots,
    required this.questions,
    required this.apiService,
  });

  @override
  State<BookingFormDialog> createState() => _BookingFormDialogState();
}

class _BookingFormDialogState extends State<BookingFormDialog> {
  final _consultantCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  bool _loading = false;

  Future<void> _submitBooking() async {
    if (_consultantCtrl.text.isEmpty) return;
    setState(() => _loading = true);
    try {
      final result = await widget.apiService.createBooking({
        'consultantId': int.tryParse(_consultantCtrl.text) ?? 0,
        'bookingDate': _dateCtrl.text,
        'timeSlotId': int.tryParse(_timeCtrl.text) ?? 0,
      });

      if (result != null && mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('New Booking', style: AppTextStyles.h3),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Consultant'),
              items: widget.consultants
                  .map((c) => DropdownMenuItem(
                      value: c['id']?.toString() ?? '',
                      child: Text(c['name'] ?? 'N/A')))
                  .toList(),
              onChanged: (v) => _consultantCtrl.text = v ?? '',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _dateCtrl,
              decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD)'),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) {
                  _dateCtrl.text = DateFormat('yyyy-MM-dd').format(date);
                }
              },
              readOnly: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _timeCtrl,
              decoration: const InputDecoration(labelText: 'Time Slot ID'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _loading ? null : _submitBooking,
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white))
              : const Text('Book Now'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _consultantCtrl.dispose();
    _dateCtrl.dispose();
    _timeCtrl.dispose();
    super.dispose();
  }
}

class BookingDetailsDialog extends StatelessWidget {
  final dynamic bookingData;
  const BookingDetailsDialog({super.key, required this.bookingData});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Booking Details', style: AppTextStyles.h3),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detailRow('Consultant', bookingData['consultantName'] ?? 'N/A'),
          _detailRow('Date', bookingData['bookingDate'] ?? 'N/A'),
          _detailRow('Time', bookingData['timeRange'] ?? 'N/A'),
          _detailRow('Status', bookingData['status'] ?? 'N/A'),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Close'))
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
