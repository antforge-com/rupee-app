// lib/services/razorpay_service_web.dart
// ════════════════════════════════════════════════════════════════════════════
// Razorpay Payment Service — WEB implementation (Chrome / Flutter Web).
//
// Uses dart:js + checkout.js loaded in web/index.html.
// razorpay_flutter package is NOT used here — it crashes the web compiler.
//
// DO NOT import this file directly. Import razorpay_service.dart instead —
// it picks this file automatically when building for web.
//
// SETUP (web/index.html — already done if web was working before):
//   Add inside <head>:
//     <script src="https://checkout.razorpay.com/v1/checkout.js"></script>
// ════════════════════════════════════════════════════════════════════════════

import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'package:js/js.dart';

import 'razorpay_models.dart';

export 'razorpay_models.dart';

class RazorpayService {
  // ── Key ───────────────────────────────────────────────────────────────────

  static const String razorpayKeyId = String.fromEnvironment(
    'RAZORPAY_KEY_ID',
    defaultValue: 'rzp_test_Sm3DfpSkruuCKl',
  );

  // ── Shared verify client ──────────────────────────────────────────────────

  final PaymentVerifyClient _verifyClient = PaymentVerifyClient();

  // ── Open Razorpay checkout (web — checkout.js) ────────────────────────────

  /// Opens the Razorpay payment sheet on web.
  /// Returns [RazorpayResult] on success.
  /// Throws a [String] error message on failure or user cancellation.
  Future<RazorpayResult> openCheckout({
    required String razorpayOrderId,
    required double amount,
    required String description,
    String? prefillName,
    String? prefillEmail,
    String? prefillContact,
  }) {
    final completer = Completer<RazorpayResult>();

    final prefillMap = <String, dynamic>{};
    if (prefillName != null && prefillName.isNotEmpty) {
      prefillMap['name'] = prefillName;
    }
    if (prefillEmail != null && prefillEmail.isNotEmpty) {
      prefillMap['email'] = prefillEmail;
    }
    if (prefillContact != null && prefillContact.isNotEmpty) {
      prefillMap['contact'] = prefillContact;
    }

    final options = js.JsObject.jsify({
      'key': razorpayKeyId,
      'amount': (amount * 100).round(),
      'currency': 'INR',
      'name': 'Meet The Masters',
      'description': description,
      'order_id': razorpayOrderId,
      'theme': {'color': '#2563EB'},
      'prefill': prefillMap,
      'handler': js.allowInterop((js.JsObject response) {
        if (!completer.isCompleted) {
          completer.complete(RazorpayResult(
            paymentId: response['razorpay_payment_id']?.toString() ?? '',
            orderId: response['razorpay_order_id']?.toString() ?? '',
            signature: response['razorpay_signature']?.toString() ?? '',
          ));
        }
      }),
      'modal': {
        'ondismiss': js.allowInterop(() {
          if (!completer.isCompleted) {
            completer.completeError('Payment cancelled by user.');
          }
        }),
      },
    });

    try {
      final razorpayConstructor = js.context['Razorpay'] as js.JsFunction;
      final rzp = js.JsObject(razorpayConstructor, [options]);

      rzp.callMethod('on', [
        'payment.failed',
        js.allowInterop((js.JsObject resp) {
          if (!completer.isCompleted) {
            String msg = 'Payment failed. Please try again.';
            try {
              final err = resp['error'];
              if (err != null) {
                msg = err['description']?.toString() ?? msg;
              }
            } catch (_) {}
            completer.completeError(msg);
          }
        }),
      ]);

      rzp.callMethod('open');
    } catch (e) {
      if (!completer.isCompleted) {
        completer.completeError(
          'Razorpay failed to open. '
          'Make sure your web/index.html <head> contains:\n'
          '<script src="https://checkout.razorpay.com/v1/checkout.js"></script>',
        );
      }
    }

    return completer.future;
  }

  /// Opens Razorpay checkout without a pre-created order ID.
  /// Used for direct subscription payments during registration.
  Future<RazorpayResult> openDirectCheckout({
    required double amount,
    required String description,
    String? prefillName,
    String? prefillEmail,
    String? prefillContact,
  }) {
    final completer = Completer<RazorpayResult>();

    final prefillMap = <String, dynamic>{};
    if (prefillName != null && prefillName.isNotEmpty) {
      prefillMap['name'] = prefillName;
    }
    if (prefillEmail != null && prefillEmail.isNotEmpty) {
      prefillMap['email'] = prefillEmail;
    }
    if (prefillContact != null && prefillContact.isNotEmpty) {
      prefillMap['contact'] = prefillContact;
    }

    final options = js.JsObject.jsify({
      'key': razorpayKeyId,
      'amount': (amount * 100).round(),
      'currency': 'INR',
      'name': 'Meet The Masters',
      'description': description,
      'theme': {'color': '#2563EB'},
      'prefill': prefillMap,
      'handler': js.allowInterop((js.JsObject response) {
        if (!completer.isCompleted) {
          completer.complete(RazorpayResult(
            paymentId: response['razorpay_payment_id']?.toString() ?? '',
            orderId: response['razorpay_order_id']?.toString() ?? '',
            signature: response['razorpay_signature']?.toString() ?? '',
          ));
        }
      }),
      'modal': {
        'ondismiss': js.allowInterop(() {
          if (!completer.isCompleted) {
            completer.completeError('Payment cancelled by user.');
          }
        }),
      },
    });

    try {
      final razorpayConstructor = js.context['Razorpay'] as js.JsFunction;
      final rzp = js.JsObject(razorpayConstructor, [options]);

      rzp.callMethod('on', [
        'payment.failed',
        js.allowInterop((js.JsObject resp) {
          if (!completer.isCompleted) {
            String msg = 'Payment failed. Please try again.';
            try {
              final err = resp['error'];
              if (err != null) {
                msg = err['description']?.toString() ?? msg;
              }
            } catch (_) {}
            completer.completeError(msg);
          }
        }),
      ]);

      rzp.callMethod('open');
    } catch (e) {
      if (!completer.isCompleted) {
        completer.completeError(
          'Razorpay failed to open. '
          'Make sure your web/index.html <head> contains:\n'
          '<script src="https://checkout.razorpay.com/v1/checkout.js"></script>',
        );
      }
    }

    return completer.future;
  }

  // ── Backend verification (delegates to shared client) ─────────────────────

  Future<PaymentVerificationResult> verifyBookingPayment({
    required int bookingId,
    required RazorpayResult result,
  }) =>
      _verifyClient.verifyBookingPayment(
          bookingId: bookingId, result: result);

  Future<PaymentVerificationResult> verifySpecialBookingPayment({
    required int specialBookingId,
    required RazorpayResult result,
  }) =>
      _verifyClient.verifySpecialBookingPayment(
          specialBookingId: specialBookingId, result: result);

  // ── Combined helpers (checkout + verify in one call) ──────────────────────

  /// Full flow — single / bulk booking.
  /// Opens checkout → verifies with backend → returns confirmed booking JSON.
  /// Throws [String] if user cancels or payment / verification fails.
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

    final verification = await verifyBookingPayment(
      bookingId: bookingId,
      result: result,
    );

    if (!verification.success) {
      throw verification.error ?? 'Payment verification failed.';
    }
    return verification.bookingData ?? {};
  }

  /// Full flow — special booking.
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

    final verification = await verifySpecialBookingPayment(
      specialBookingId: specialBookingId,
      result: result,
    );

    if (!verification.success) {
      throw verification.error ?? 'Payment verification failed.';
    }
    return verification.bookingData ?? {};
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// No-op on web. Keep for API symmetry with mobile.
  void dispose() {}

  // ── Static utility helpers ────────────────────────────────────────────────

  /// Returns true when booking is already paid (MEMBER role / 100% promo).
  /// When true — skip the checkout entirely, booking is already CONFIRMED.
  static bool isAlreadyPaid(Map<String, dynamic> bookingJson) {
    return (bookingJson['paymentStatus'] ?? '').toString().toUpperCase() ==
        'SUCCESS';
  }

  /// Returns true when Razorpay checkout needs to be opened.
  static bool needsPayment(Map<String, dynamic> bookingJson) {
    if (isAlreadyPaid(bookingJson)) return false;
    final orderId =
        (bookingJson['razorpayOrderId'] ?? '').toString().trim();
    final amount = double.tryParse(
          '${bookingJson['totalAmount'] ?? bookingJson['total_amount'] ?? 0}',
        ) ??
        0;
    return orderId.isNotEmpty && amount > 0;
  }
}
