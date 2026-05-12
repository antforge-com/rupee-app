// lib/services/razorpay_service.dart
// ════════════════════════════════════════════════════════════════════════════
// Razorpay Service — platform-conditional entry point.
//
// THIS IS THE ONLY FILE YOU IMPORT anywhere in the app:
//   import 'package:finadvise/services/razorpay_service.dart';
//
// Dart automatically picks the right implementation at compile time:
//   • Web (Flutter Web / Chrome) → razorpay_service_web.dart
//     Uses dart:js + checkout.js (already working on web)
//
//   • Android → razorpay_service_mobile.dart
//     Uses razorpay_flutter package (native Razorpay SDK)
//
// dart.library.io   = true  on Android / iOS / desktop (native)
// dart.library.io   = false on Web
//
// Neither file is compiled for the wrong platform, so:
//   • dart:js  is never compiled into the Android APK
//   • razorpay_flutter is never compiled into the web bundle
//
// DO NOT import razorpay_service_web.dart or razorpay_service_mobile.dart
// directly — always import this file.
// ════════════════════════════════════════════════════════════════════════════

export 'razorpay_models.dart';
export 'razorpay_service_web.dart'
    if (dart.library.io) 'razorpay_service_mobile.dart';