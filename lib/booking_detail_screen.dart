import 'package:flutter/material.dart';
import 'package:finadvise/models/models.dart';
import 'package:finadvise/app_theme.dart';

class BookingDetailScreen extends StatelessWidget {
  final Booking booking;
  final String role;

  const BookingDetailScreen({
    super.key,
    required this.booking,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Booking #${booking.id} Details'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Booking Status: ${booking.status}', style: AppTextStyles.h3),
                  const SizedBox(height: 12),
                  Text('Meeting Mode: ${booking.meetingMode ?? "Not specified"}', style: AppTextStyles.body),
                  const SizedBox(height: 8),
                  Text('Amount: ₹${booking.amount?.toStringAsFixed(0) ?? "0"}', style: AppTextStyles.body),
                  if (booking.meetingLink != null && booking.meetingLink!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Meeting Link:', style: AppTextStyles.caption),
                    Text(
                      booking.meetingLink!,
                      style: const TextStyle(color: AppColors.info, decoration: TextDecoration.underline),
                    ),
                  ]
                ],
              ),
            ),
            const Spacer(),
            Center(
              child: Text(
                'More details UI can be built here.',
                style: AppTextStyles.caption,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}