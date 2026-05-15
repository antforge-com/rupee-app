import 'dart:async';

import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'razorpay_models.dart';
export 'razorpay_models.dart';

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
  }) {
    return _openNativeCheckout(
      razorpayOrderId: razorpayOrderId,
      amount: amount,
      description: description,
      prefillName: prefillName,
      prefillEmail: prefillEmail,
      prefillContact: prefillContact,
    );
  }

  Future<RazorpayResult> openDirectCheckout({
    required double amount,
    required String description,
    String? prefillName,
    String? prefillEmail,
    String? prefillContact,
  }) {
    return _openNativeCheckout(
      amount: amount,
      description: description,
      prefillName: prefillName,
      prefillEmail: prefillEmail,
      prefillContact: prefillContact,
    );
  }

  Future<RazorpayResult> _openNativeCheckout({
    String? razorpayOrderId,
    required double amount,
    required String description,
    String? prefillName,
    String? prefillEmail,
    String? prefillContact,
  }) async {
    if (amount <= 0) {
      throw 'Invalid payment amount. Please try again.';
    }

    final normalizedOrderId = razorpayOrderId?.trim() ?? '';
    final completer = Completer<RazorpayResult>();
    final razorpay = Razorpay();

    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
      if (completer.isCompleted) return;
      completer.complete(
        RazorpayResult(
          paymentId: r.paymentId ?? '',
          orderId: (r.orderId ?? normalizedOrderId).trim(),
          signature: r.signature ?? '',
        ),
      );
    });

    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
      if (completer.isCompleted) return;
      final code = r.code != null ? '(${r.code}) ' : '';
      completer.completeError(
        '${code}${r.message ?? 'Payment failed or cancelled.'}',
      );
    });

    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse r) {
      if (completer.isCompleted) return;
      completer.completeError(
        'External wallet selected: ${r.walletName ?? 'Unknown'}',
      );
    });

    final options = <String, dynamic>{
      'key': razorpayKeyId,
      'amount': (amount * 100).round(),
      'currency': 'INR',
      'name': 'Meet The Masters',
      'description': description,
      'theme': {'color': '#2563EB'},
      'prefill': {
        if (prefillName != null && prefillName.trim().isNotEmpty)
          'name': prefillName.trim(),
        if (prefillEmail != null && prefillEmail.trim().isNotEmpty)
          'email': prefillEmail.trim(),
        if (prefillContact != null && prefillContact.trim().isNotEmpty)
          'contact': prefillContact.trim(),
      },
    };

    if (normalizedOrderId.isNotEmpty) {
      options['order_id'] = normalizedOrderId;
    }

    try {
      razorpay.open(options);
    } catch (e) {
      razorpay.clear();
      if (!completer.isCompleted) {
        completer.completeError('Failed to open Razorpay checkout: $e');
      }
    }

    try {
      return await completer.future;
    } finally {
      razorpay.clear();
    }
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
        specialBookingId: specialBookingId,
        result: result,
      );

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
      razorpayOrderId: razorpayOrderId,
      amount: totalAmount,
      description: description,
      prefillName: prefillName,
      prefillEmail: prefillEmail,
      prefillContact: prefillContact,
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
      razorpayOrderId: razorpayOrderId,
      amount: totalAmount,
      description: description,
      prefillName: prefillName,
      prefillEmail: prefillEmail,
      prefillContact: prefillContact,
    );
    final v = await verifySpecialBookingPayment(
      specialBookingId: specialBookingId,
      result: result,
    );
    if (!v.success) throw v.error ?? 'Payment verification failed.';
    return v.bookingData ?? {};
  }

  void dispose() {}

  static bool isAlreadyPaid(Map<String, dynamic> j) =>
      (j['paymentStatus'] ?? '').toString().toUpperCase() == 'SUCCESS';

  static bool needsPayment(Map<String, dynamic> j) {
    if (isAlreadyPaid(j)) return false;
    final orderId = (j['razorpayOrderId'] ?? '').toString().trim();
    final amount =
        double.tryParse('${j['totalAmount'] ?? j['total_amount'] ?? 0}') ?? 0;
    return orderId.isNotEmpty && amount > 0;
  }
}
