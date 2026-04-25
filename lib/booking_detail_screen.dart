import 'package:finadvise/app_theme.dart';
import 'package:finadvise/models/models.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BookingDetailScreen extends StatelessWidget {
  final Booking booking;
  final String role;

  const BookingDetailScreen({
    super.key,
    required this.booking,
    required this.role,
  });

  String _fmtDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '—';
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = booking.status.toUpperCase();
    final consultant = booking.consultantName ?? 'Expert';
    final client = booking.clientName ?? 'Client';
    final date = _fmtDate(booking.slotDate);
    final time = booking.timeRange?.isNotEmpty == true ? booking.timeRange! : '—';
    final meetingMode = booking.meetingMode?.isNotEmpty == true ? booking.meetingMode! : '—';
    final meetingLink = booking.meetingLink?.trim() ?? '';
    final notes = booking.userNotes?.trim() ?? '';
    final amount = booking.amount ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 1,
        title: Text('Booking #${booking.id}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3A5F), AppColors.brandBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  role.toUpperCase() == 'ADMIN' ? client : consultant,
                  style: AppTextStyles.h2.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _pill(status, Colors.white.withOpacity(0.16)),
                    _pill(meetingMode, Colors.white.withOpacity(0.16)),
                    _pill('₹${amount.toStringAsFixed(0)}', Colors.white.withOpacity(0.16)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _section(
            'Session Details',
            [
              _row('Consultant', consultant),
              _row('Client', client),
              _row('Date', date),
              _row('Time', time),
              _row('Meeting Mode', meetingMode),
              _row('Payment Status', booking.paymentStatus ?? '—'),
            ],
          ),
          if (meetingLink.isNotEmpty) ...[
            const SizedBox(height: 16),
            _section('Meeting Link', [_row('Join URL', meetingLink)]),
          ],
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 16),
            _section('Notes', [
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  notes,
                  style: AppTextStyles.body.copyWith(height: 1.5),
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
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
          Text(title, style: AppTextStyles.h4),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.body,
            ),
          ),
        ],
      ),
    );
  }
}
