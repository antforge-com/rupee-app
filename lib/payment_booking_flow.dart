// lib/features/booking/payment_booking_flow.dart
// ════════════════════════════════════════════════════════════════════════════
// Complete Booking + Payment Flow — Usage Example
//
// This mixin/helper demonstrates the exact sequence to:
//   1. Fetch available offers for a consultant
//   2. Let user pick a promo code
//   3. Create the booking (backend applies discount + creates Razorpay order)
//   4. Check if payment is needed (skipped for MEMBER / 100% promo)
//   5. Open Razorpay checkout
//   6. Verify payment with backend → booking becomes CONFIRMED
//
// Supports: Normal bookings, Bulk bookings, Special bookings
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../services/booking_service.dart';
import '../services/offer_service.dart';
import '../services/razorpay_service.dart';

// ── Offer picker helper ───────────────────────────────────────────────────────

/// Fetches applicable offers for the checkout and returns the selected offerId.
/// Returns null if the user skips.
Future<int?> pickOffer(
  BuildContext context, {
  required OfferService offerService,
  required int consultantId,
}) async {
  final offers = await offerService.getCheckoutOffers(consultantId);
  if (offers.isEmpty) return null;
  if (!context.mounted) return null;

  return showModalBottomSheet<int?>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _OfferPickerSheet(offers: offers),
  );
}

class _OfferPickerSheet extends StatelessWidget {
  final List<Map<String, dynamic>> offers;
  const _OfferPickerSheet({required this.offers});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          Text('Apply Promo Code',
              style: Theme.of(context).textTheme.titleMedium),
          const Divider(),
          ...offers.map((offer) {
            final id = offer['id'] as int?;
            final code = offer['code']?.toString() ?? 'PROMO';
            final discount = offer['discount']?.toString() ?? '';
            final desc = offer['description']?.toString() ?? '';
            return ListTile(
              leading: const Icon(Icons.local_offer, color: Colors.green),
              title: Text(code,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('$discount off${desc.isNotEmpty ? ' · $desc' : ''}'),
              trailing: TextButton(
                onPressed: () => Navigator.pop(context, id),
                child: const Text('Apply'),
              ),
            );
          }),
          ListTile(
            leading: const Icon(Icons.close),
            title: const Text('No promo code'),
            onTap: () => Navigator.pop(context, null),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Core payment flow helper ──────────────────────────────────────────────────

class BookingPaymentFlow {
  final BookingService bookingService;
  final OfferService offerService;
  final RazorpayService razorpayService;

  const BookingPaymentFlow({
    required this.bookingService,
    required this.offerService,
    required this.razorpayService,
  });

  // ── Normal booking ────────────────────────────────────────────────────────

  /// Complete flow: create booking → (optional offer) → payment → confirm.
  ///
  /// Returns:
  ///   - `null`   if booking creation failed
  ///   - booking JSON with `paymentStatus == 'SUCCESS'` on success
  ///
  /// Throws a [String] error if payment fails or user cancels checkout.
  Future<Map<String, dynamic>?> bookAndPay({
    required BuildContext context,
    required int consultantId,
    required int timeSlotId,
    required double baseAmount,
    required String meetingMode,
    String? userNotes,
    // Optional: skip offer picker by passing an offerId directly
    int? preSelectedOfferId,
    // Prefill Razorpay sheet
    String? userEmail,
    String? userName,
    String? userPhone,
  }) async {
    // ── Step 1: Pick offer (if not pre-selected) ──────────────────────────
    int? offerId = preSelectedOfferId;
    if (offerId == null && context.mounted) {
      offerId = await pickOffer(
        context,
        offerService: offerService,
        consultantId: consultantId,
      );
    }

    // ── Step 2: Create booking ────────────────────────────────────────────
    final bookingJson = await bookingService.createBooking(
      consultantId: consultantId,
      timeSlotId: timeSlotId,
      baseAmount: baseAmount,
      meetingMode: meetingMode,
      offerId: offerId,
      userNotes: userNotes,
    );

    if (bookingJson == null) return null;

    // ── Step 3: Skip payment if already free ─────────────────────────────
    if (RazorpayService.isAlreadyPaid(bookingJson)) {
      return bookingJson; // MEMBER / 100% promo — already CONFIRMED
    }

    // ── Step 4: Open checkout + verify ────────────────────────────────────
    if (!RazorpayService.needsPayment(bookingJson)) {
      // No payment needed (zero amount edge case)
      return bookingJson;
    }

    final bookingId = bookingJson['id'] as int? ?? 0;
    final orderId = bookingJson['razorpayOrderId']?.toString() ?? '';
    final totalAmount = double.tryParse(
            '${bookingJson['totalAmount'] ?? bookingJson['total_amount'] ?? 0}') ??
        0;
    final discountAmount = double.tryParse(
            '${bookingJson['discountAmount'] ?? 0}') ??
        0;

    // Show discount applied message if any
    if (discountAmount > 0 && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Promo applied! You save ₹${discountAmount.toStringAsFixed(2)}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    // Opens Razorpay checkout → verifies with backend → returns updated booking
    final updatedBooking = await razorpayService.payAndVerifyBooking(
      bookingId: bookingId,
      razorpayOrderId: orderId,
      totalAmount: totalAmount,
      description: 'Consultation booking #$bookingId',
      prefillEmail: userEmail,
      prefillName: userName,
      prefillContact: userPhone,
    );

    return updatedBooking.isNotEmpty ? updatedBooking : bookingJson;
  }

  // ── Bulk booking ──────────────────────────────────────────────────────────

  /// Complete flow for a bulk booking (2–4 slots).
  Future<Map<String, dynamic>?> bulkBookAndPay({
    required BuildContext context,
    required int consultantId,
    required List<int> timeSlotIds,
    required double baseAmountPerSlot,
    required String meetingMode,
    String? userNotes,
    int? preSelectedOfferId,
    String? userEmail,
    String? userName,
    String? userPhone,
  }) async {
    // ── Step 1: Pick offer ────────────────────────────────────────────────
    int? offerId = preSelectedOfferId;
    if (offerId == null && context.mounted) {
      offerId = await pickOffer(
        context,
        offerService: offerService,
        consultantId: consultantId,
      );
    }

    // ── Step 2: Create bulk booking ───────────────────────────────────────
    final bookingJson = await bookingService.createBulkBooking(
      consultantId: consultantId,
      timeSlotIds: timeSlotIds,
      baseAmountPerSlot: baseAmountPerSlot,
      meetingMode: meetingMode,
      offerId: offerId,
      userNotes: userNotes,
    );

    if (bookingJson == null) return null;

    if (RazorpayService.isAlreadyPaid(bookingJson)) return bookingJson;
    if (!RazorpayService.needsPayment(bookingJson)) return bookingJson;

    // BulkBookingResponse uses bookingId (not id)
    final bookingId = (bookingJson['bookingId'] ?? bookingJson['id']) as int? ?? 0;
    final orderId = bookingJson['razorpayOrderId']?.toString() ?? '';
    final totalAmount = double.tryParse(
            '${bookingJson['totalAmount'] ?? bookingJson['total_amount'] ?? 0}') ??
        0;
    final discountAmount =
        double.tryParse('${bookingJson['discountAmount'] ?? 0}') ?? 0;

    if (discountAmount > 0 && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Promo applied! You save ₹${discountAmount.toStringAsFixed(2)}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    final updatedBooking = await razorpayService.payAndVerifyBooking(
      bookingId: bookingId,
      razorpayOrderId: orderId,
      totalAmount: totalAmount,
      description: 'Bulk booking #$bookingId (${timeSlotIds.length} slots)',
      prefillEmail: userEmail,
      prefillName: userName,
      prefillContact: userPhone,
    );

    return updatedBooking.isNotEmpty ? updatedBooking : bookingJson;
  }

  // ── Special booking ───────────────────────────────────────────────────────

  /// Complete flow for a special booking.
  Future<Map<String, dynamic>?> specialBookAndPay({
    required BuildContext context,
    required int consultantId,
    required int durationInHours,
    required double sessionAmount,
    required String meetingMode,
    required String userNotes,
    int? preSelectedOfferId,
    String? userEmail,
    String? userName,
    String? userPhone,
  }) async {
    // ── Step 1: Pick offer ────────────────────────────────────────────────
    int? offerId = preSelectedOfferId;
    if (offerId == null && context.mounted) {
      offerId = await pickOffer(
        context,
        offerService: offerService,
        consultantId: consultantId,
      );
    }

    // ── Step 2: Create special booking ────────────────────────────────────
    final bookingJson = await bookingService.createSpecialBooking({
      'consultantId': consultantId,
      'durationInHours': durationInHours,
      'sessionAmount': sessionAmount,
      'meetingMode': meetingMode,
      'userNotes': userNotes,
      if (offerId != null) 'offerId': offerId,
    });

    if (bookingJson == null) return null;

    if (RazorpayService.isAlreadyPaid(bookingJson)) return bookingJson;
    if (!RazorpayService.needsPayment(bookingJson)) return bookingJson;

    final specialBookingId = bookingJson['id'] as int? ?? 0;
    final orderId = bookingJson['razorpayOrderId']?.toString() ?? '';
    final totalAmount = double.tryParse(
            '${bookingJson['totalAmount'] ?? bookingJson['total_amount'] ?? 0}') ??
        0;
    final discountAmount =
        double.tryParse('${bookingJson['discountAmount'] ?? 0}') ?? 0;

    if (discountAmount > 0 && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Promo applied! You save ₹${discountAmount.toStringAsFixed(2)}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    final updatedBooking = await razorpayService.payAndVerifySpecialBooking(
      specialBookingId: specialBookingId,
      razorpayOrderId: orderId,
      totalAmount: totalAmount,
      description: 'Special booking #$specialBookingId ($durationInHours hr)',
      prefillEmail: userEmail,
      prefillName: userName,
      prefillContact: userPhone,
    );

    return updatedBooking.isNotEmpty ? updatedBooking : bookingJson;
  }
}

// ════════════════════════════════════════════════════════════════════════════
// EXAMPLE WIDGET — Copy-paste into your booking screen
// ════════════════════════════════════════════════════════════════════════════

class BookNowButton extends StatefulWidget {
  /// Data about the slot/consultant being booked
  final int consultantId;
  final int timeSlotId;
  final double baseAmount;
  final String meetingMode;
  final String? userNotes;

  /// Logged-in user details for prefill
  final String? userEmail;
  final String? userName;
  final String? userPhone;

  /// Called with the confirmed booking JSON after payment
  final void Function(Map<String, dynamic> confirmedBooking)? onSuccess;
  final void Function(String error)? onError;

  const BookNowButton({
    super.key,
    required this.consultantId,
    required this.timeSlotId,
    required this.baseAmount,
    required this.meetingMode,
    this.userNotes,
    this.userEmail,
    this.userName,
    this.userPhone,
    this.onSuccess,
    this.onError,
  });

  @override
  State<BookNowButton> createState() => _BookNowButtonState();
}

class _BookNowButtonState extends State<BookNowButton> {
  // One RazorpayService per widget — disposed in dispose()
  final _razorpayService = RazorpayService();
  final _bookingService = BookingService();
  final _offerService = OfferService();
  bool _loading = false;

  @override
  void dispose() {
    _razorpayService.dispose(); // IMPORTANT: always dispose
    super.dispose();
  }

  Future<void> _handleBookNow() async {
    setState(() => _loading = true);

    try {
      final flow = BookingPaymentFlow(
        bookingService: _bookingService,
        offerService: _offerService,
        razorpayService: _razorpayService,
      );

      final result = await flow.bookAndPay(
        context: context,
        consultantId: widget.consultantId,
        timeSlotId: widget.timeSlotId,
        baseAmount: widget.baseAmount,
        meetingMode: widget.meetingMode,
        userNotes: widget.userNotes,
        userEmail: widget.userEmail,
        userName: widget.userName,
        userPhone: widget.userPhone,
      );

      if (!mounted) return;

      if (result == null) {
        widget.onError?.call('Booking creation failed. Please try again.');
        return;
      }

      // Success: booking is now CONFIRMED
      widget.onSuccess?.call(result);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking confirmed!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      widget.onError?.call(msg);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _loading ? null : _handleBookNow,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2563EB),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: _loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              widget.baseAmount > 0
                  ? 'Book Now — ₹${widget.baseAmount.toStringAsFixed(0)}'
                  : 'Book Now (Free)',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// EXAMPLE: How to use BookNowButton in your screen
// ════════════════════════════════════════════════════════════════════════════
//
// BookNowButton(
//   consultantId: consultant.id,
//   timeSlotId: selectedSlot.id,
//   baseAmount: consultant.hourlyRate,
//   meetingMode: 'ONLINE',
//   userNotes: notesController.text,
//   userEmail: currentUser.identifier,
//   userName: currentUser.displayName,
//   userPhone: currentUser.phone,
//   onSuccess: (booking) {
//     Navigator.pushReplacementNamed(context, '/booking-confirmed',
//       arguments: booking);
//   },
//   onError: (e) => showSnackBar(e),
// )