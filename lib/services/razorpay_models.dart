// lib/services/razorpay_models.dart
// ════════════════════════════════════════════════════════════════════════════
// Shared Razorpay models + backend verify client.
//
// NO platform-specific imports here — this file compiles on Web, Android,
// iOS, and desktop without changes.
//
// Imported by:
//   • razorpay_service_web.dart    (web checkout)
//   • razorpay_service_mobile.dart (Android checkout)
//   • razorpay_service.dart        (re-exports everything)
// ════════════════════════════════════════════════════════════════════════════

import 'package:finadvise/api_client.dart';

// ── Result models ─────────────────────────────────────────────────────────────

/// Returned by [RazorpayService.openCheckout] on a successful payment.
/// Pass all three fields to [verifyBookingPayment] / [verifySpecialBookingPayment].
class RazorpayResult {
  final String paymentId;
  final String orderId;
  final String signature;

  const RazorpayResult({
    required this.paymentId,
    required this.orderId,
    required this.signature,
  });
}

/// Returned by backend payment-verification endpoints.
class PaymentVerificationResult {
  final bool success;
  final Map<String, dynamic>? bookingData;
  final String? error;

  const PaymentVerificationResult({
    required this.success,
    this.bookingData,
    this.error,
  });
}

// ── Backend verify client ─────────────────────────────────────────────────────
//
// Pure HTTP calls — no dart:js, no razorpay_flutter, no platform deps.
// Both platform implementations call these helpers so the verification
// logic is never duplicated.

class PaymentVerifyClient {
  final ApiClient _apiClient = ApiClient();

  /// POST /api/bookings/{id}/verify-payment
  Future<PaymentVerificationResult> verifyBookingPayment({
    required int bookingId,
    required RazorpayResult result,
  }) =>
      _post('/api/bookings/$bookingId/verify-payment', result);

  /// POST /api/special-bookings/{id}/verify-payment
  Future<PaymentVerificationResult> verifySpecialBookingPayment({
    required int specialBookingId,
    required RazorpayResult result,
  }) =>
      _post('/api/special-bookings/$specialBookingId/verify-payment', result);

  Future<PaymentVerificationResult> _post(
    String endpoint,
    RazorpayResult result,
  ) async {
    try {
      final response = await _apiClient.dio.post(
        endpoint,
        queryParameters: {
          'razorpayPaymentId': result.paymentId,
          'razorpayOrderId': result.orderId,
          'razorpaySignature': result.signature,
        },
      );
      return PaymentVerificationResult(
        success: true,
        bookingData: response.data is Map
            ? Map<String, dynamic>.from(response.data as Map)
            : null,
      );
    } catch (e) {
      return PaymentVerificationResult(
        success: false,
        error: _extractMsg(e),
      );
    }
  }

  static String _extractMsg(Object e) {
    final raw = e.toString();
    final idx = raw.indexOf(':');
    if (idx > 0 && idx < 50) return raw.substring(idx + 1).trim();
    return raw;
  }
}