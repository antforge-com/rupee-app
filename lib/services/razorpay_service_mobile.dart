// lib/services/razorpay_service_mobile.dart
// ════════════════════════════════════════════════════════════════════════════
// Android/iOS — uses razorpay_flutter SDK.
// razorpay_flutter import is commented out because the package is removed
// from pubspec.yaml for web builds. Uncomment when building for Android.
// ════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'razorpay_models.dart';
export 'razorpay_models.dart';

// ── Uncomment for Android builds (add razorpay_flutter: ^1.3.6 to pubspec) ──
// import 'package:razorpay_flutter/razorpay_flutter.dart';

class RazorpayService {
  static const String razorpayKeyId = String.fromEnvironment(
    'RAZORPAY_KEY_ID',
    defaultValue: 'rzp_test_Sm3DfpSkruuCKl',
  );

  final PaymentVerifyClient _verifyClient = PaymentVerifyClient();

  Future<RazorpayResult> openCheckout({
    required String razorpayOrderId,
    required double amount,
    required String description,
    String? prefillName,
    String? prefillEmail,
    String? prefillContact,
  }) async {
    throw 'Add razorpay_flutter to pubspec.yaml for Android payment support.';
  }

  Future<PaymentVerificationResult> verifyBookingPayment({
    required int bookingId,
    required RazorpayResult result,
  }) =>
      _verifyClient.verifyBookingPayment(bookingId: bookingId, result: result);

  Future<PaymentVerificationResult> verifySpecialBookingPayment({
    required int specialBookingId,
    required RazorpayResult result,
  }) =>
      _verifyClient.verifySpecialBookingPayment(
          specialBookingId: specialBookingId, result: result);

  Future<Map<String, dynamic>> payAndVerifyBooking({
    required int bookingId,
    required String razorpayOrderId,
    required double totalAmount,
    required String description,
    String? prefillName,
    String? prefillEmail,
    String? prefillContact,
  }) async {
    final result = await openCheckout(
      razorpayOrderId: razorpayOrderId, amount: totalAmount,
      description: description, prefillName: prefillName,
      prefillEmail: prefillEmail, prefillContact: prefillContact,
    );
    final v = await verifyBookingPayment(bookingId: bookingId, result: result);
    if (!v.success) throw v.error ?? 'Payment verification failed.';
    return v.bookingData ?? {};
  }

  Future<Map<String, dynamic>> payAndVerifySpecialBooking({
    required int specialBookingId,
    required String razorpayOrderId,
    required double totalAmount,
    required String description,
    String? prefillName,
    String? prefillEmail,
    String? prefillContact,
  }) async {
    final result = await openCheckout(
      razorpayOrderId: razorpayOrderId, amount: totalAmount,
      description: description, prefillName: prefillName,
      prefillEmail: prefillEmail, prefillContact: prefillContact,
    );
    final v = await verifySpecialBookingPayment(
        specialBookingId: specialBookingId, result: result);
    if (!v.success) throw v.error ?? 'Payment verification failed.';
    return v.bookingData ?? {};
  }

  void dispose() {}

  static bool isAlreadyPaid(Map<String, dynamic> j) =>
      (j['paymentStatus'] ?? '').toString().toUpperCase() == 'SUCCESS';

  static bool needsPayment(Map<String, dynamic> j) {
    if (isAlreadyPaid(j)) return false;
    final orderId = (j['razorpayOrderId'] ?? '').toString().trim();
    final amount = double.tryParse('${j['totalAmount'] ?? j['total_amount'] ?? 0}') ?? 0;
    return orderId.isNotEmpty && amount > 0;
  }
}