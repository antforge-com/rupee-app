// lib/core/services/booking_service.dart
// ════════════════════════════════════════════════════════════════════════════
// Booking Service — with full Razorpay payment integration
//
// Endpoints:
//   GET   /api/bookings                     (paginated) — Admin
//   GET   /api/bookings/me                  (current user)
//   GET   /api/bookings/{id}
//   GET   /api/bookings/status/{status}     ← path param
//   GET   /api/bookings/consultant/{id}
//   POST  /api/bookings                     body: BookingRequest
//   POST  /api/bookings/bulk                body: BulkBookingRequest
//   POST  /api/bookings/{id}/verify-payment ← Razorpay signature verification
//   PUT   /api/bookings/{id}
//   PUT   /api/bookings/bulk/{id}
//   PUT   /api/bookings/{id}/reschedule
//   PUT   /api/bookings/bulk/{id}/reschedule
//   PATCH /api/bookings/{id}/cancel
//   GET   /api/bookings/summary
//   POST  /api/special-bookings
//   POST  /api/special-bookings/{id}/verify-payment  ← Razorpay
//   GET   /api/special-bookings/me
//   GET   /api/special-bookings/consultant/{id}
//   GET   /api/special-bookings
//   PATCH /api/special-bookings/{id}/give-slot
//   PUT   /api/special-bookings/{id}/reschedule
//   PATCH /api/special-bookings/{id}/cancel
//
// Payment flow:
//   1. createBooking() / createBulkBooking() / createSpecialBooking()
//      → backend returns razorpayOrderId + totalAmount
//   2. If RazorpayService.needsPayment(response) → open Razorpay checkout
//   3. On checkout success → verifyBookingPayment() / verifySpecialBookingPayment()
//   4. Booking moves to CONFIRMED automatically
//   5. If totalAmount == 0 (MEMBER / 100% promo) → already CONFIRMED, skip step 2-3
// ════════════════════════════════════════════════════════════════════════════

import 'package:dio/dio.dart';
import 'package:finadvise/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import 'razorpay_service.dart';

class BookingService {
  final ApiClient _apiClient = ApiClient();

  // ── READ ──────────────────────────────────────────────────────────────────

  /// GET /api/bookings — Admin: all bookings (paginated)
  Future<List<Booking>> getAllBookings({int page = 0, int size = 20}) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/bookings',
        queryParameters: {'page': page, 'size': size},
      );
      final data = response.data;
      final list = data is Map
          ? (data['content'] ?? data['data'] ?? [])
          : (data is List ? data : []);
      return (list as List)
          .map((e) => Booking.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 403 || e.response?.statusCode == 404) {
        return [];
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// GET /api/bookings — paginated with totalElements (Admin dashboard)
  Future<Map<String, dynamic>> getAllBookingsPaginated({
    int page = 0,
    int size = 10,
    String? status,
  }) async {
    try {
      final normalizedStatus = (status ?? '').trim().toUpperCase();
      final isFiltered =
          normalizedStatus.isNotEmpty && normalizedStatus != 'ALL';
      final response = await _apiClient.dio.get(
        isFiltered
            ? '/api/bookings/status/$normalizedStatus'
            : '/api/bookings',
        queryParameters: {'page': page, 'size': size},
      );
      final data = response.data;
      if (data is Map) {
        final list = (data['content'] ?? []) as List;
        return {
          'bookings': list
              .map((e) => Booking.fromJson(e as Map<String, dynamic>))
              .toList(),
          'totalElements': data['totalElements'] ?? list.length,
          'totalPages': data['totalPages'] ?? 1,
          'currentPage': data['number'] ?? page,
        };
      } else if (data is List) {
        final bookings = data
            .map((e) => Booking.fromJson(e as Map<String, dynamic>))
            .toList();
        return {
          'bookings': bookings,
          'totalElements': bookings.length,
          'totalPages': 1,
          'currentPage': 0,
        };
      }
      return {
        'bookings': [],
        'totalElements': 0,
        'totalPages': 0,
        'currentPage': 0
      };
    } catch (_) {
      return {
        'bookings': [],
        'totalElements': 0,
        'totalPages': 0,
        'currentPage': 0
      };
    }
  }

  /// GET /api/bookings/me — logged-in user's bookings
  Future<List<Booking>> getMyBookings({int page = 0, int size = 20}) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/bookings/me',
        queryParameters: {'page': page, 'size': size},
      );
      final data = response.data;
      final list = data is Map
          ? (data['content'] ?? data['data'] ?? [])
          : (data is List ? data : []);
      return (list as List)
          .map((e) => Booking.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Paginated version for consultant dashboard
  Future<({List<dynamic> content, int totalElements})>
      getBookingsByConsultantPaginated(
    int consultantId, {
    int page = 0,
    int size = 5,
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/bookings/consultant/$consultantId',
        queryParameters: {'page': page, 'size': size},
      );
      final data = response.data;
      if (data is Map) {
        final list = (data['content'] ?? []) as List;
        return (
          content: list
              .map((e) => Booking.fromJson(e as Map<String, dynamic>))
              .toList(),
          totalElements:
              (data['totalElements'] as num?)?.toInt() ?? list.length,
        );
      }
      final list = data is List ? data : [];
      final content = list
          .map((e) => Booking.fromJson(e as Map<String, dynamic>))
          .toList();
      return (content: content, totalElements: content.length);
    } catch (_) {
      return (content: [], totalElements: 0);
    }
  }

  /// GET /api/bookings/{id}
  Future<Booking?> getBookingById(int bookingId) async {
    try {
      final response = await _apiClient.dio.get('/api/bookings/$bookingId');
      return Booking.fromJson(response.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// GET /api/bookings/status/{status}
  Future<List<Booking>> getBookingsByStatus(
    String status, {
    int page = 0,
    int size = 20,
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/bookings/status/$status',
        queryParameters: {'page': page, 'size': size},
      );
      final data = response.data;
      final list = data is Map
          ? (data['content'] ?? data['data'] ?? [])
          : (data is List ? data : []);
      return (list as List)
          .map((e) => Booking.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// GET /api/bookings/consultant/{consultantId}
  Future<List<Booking>> getBookingsByConsultant(
    int consultantId, {
    int page = 0,
    int size = 30,
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/bookings/consultant/$consultantId',
        queryParameters: {'page': page, 'size': size},
      );
      final data = response.data;
      final list = data is Map
          ? (data['content'] ?? data['data'] ?? [])
          : (data is List ? data : []);
      return (list as List)
          .map((e) => Booking.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── CREATE (returns raw JSON so caller can inspect Razorpay fields) ────────

  /// POST /api/bookings — Create a single booking.
  ///
  /// Returns the raw booking JSON which includes:
  ///   - `razorpayOrderId` — use with RazorpayService.openCheckout()
  ///   - `totalAmount`     — if 0 or paymentStatus==SUCCESS, skip checkout
  ///   - `paymentStatus`   — SUCCESS means it's already paid (MEMBER/promo)
  ///   - `bookingStatus`   — CONFIRMED if free, PENDING if payment required
  ///
  /// Pass [offerId] to apply a discount/promo code. The backend validates it,
  /// calculates the discounted total, and returns the updated amount.
  Future<Map<String, dynamic>?> createBooking({
    required int consultantId,
    required int timeSlotId,
    required double baseAmount,
    required String meetingMode,
    int? offerId,
    String? userNotes,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/bookings',
        data: {
          'consultantId': consultantId,
          'timeSlotId': timeSlotId,
          'baseAmount': baseAmount,
          'meetingMode': meetingMode,
          if (offerId != null) 'offerId': offerId,
          if (userNotes != null && userNotes.isNotEmpty) 'userNotes': userNotes,
        },
      );
      return response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : null;
    } catch (_) {
      return null;
    }
  }

  /// POST /api/bookings/bulk — Create a bulk booking (2–4 slots).
  ///
  /// Returns raw JSON with same Razorpay fields as [createBooking].
  /// Pass [offerId] to apply a promo code to the combined total.
  Future<Map<String, dynamic>?> createBulkBooking({
    required int consultantId,
    required List<int> timeSlotIds,
    required double baseAmountPerSlot,
    required String meetingMode,
    int? offerId,
    String? userNotes,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/bookings/bulk',
        data: {
          'consultantId': consultantId,
          'timeSlotIds': timeSlotIds,
          'baseAmountPerSlot': baseAmountPerSlot,
          'meetingMode': meetingMode,
          if (offerId != null) 'offerId': offerId,
          if (userNotes != null && userNotes.isNotEmpty) 'userNotes': userNotes,
        },
      );
      return response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : null;
    } catch (_) {
      return null;
    }
  }

  // ── PAYMENT VERIFICATION ──────────────────────────────────────────────────

  /// POST /api/bookings/{id}/verify-payment
  ///
  /// Called automatically by [RazorpayService.payAndVerifyBooking].
  /// Exposed here for manual use if you manage checkout yourself.
  Future<Map<String, dynamic>?> verifyBookingPayment({
    required int bookingId,
    required String razorpayPaymentId,
    required String razorpayOrderId,
    required String razorpaySignature,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/bookings/$bookingId/verify-payment',
        queryParameters: {
          'razorpayPaymentId': razorpayPaymentId,
          'razorpayOrderId': razorpayOrderId,
          'razorpaySignature': razorpaySignature,
        },
      );
      return response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : null;
    } catch (_) {
      return null;
    }
  }

  /// POST /api/special-bookings/{id}/verify-payment
  Future<Map<String, dynamic>?> verifySpecialBookingPayment({
    required int specialBookingId,
    required String razorpayPaymentId,
    required String razorpayOrderId,
    required String razorpaySignature,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/special-bookings/$specialBookingId/verify-payment',
        queryParameters: {
          'razorpayPaymentId': razorpayPaymentId,
          'razorpayOrderId': razorpayOrderId,
          'razorpaySignature': razorpaySignature,
        },
      );
      return response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : null;
    } catch (_) {
      return null;
    }
  }

  // ── UPDATE ────────────────────────────────────────────────────────────────

  /// PUT /api/bookings/{id}
  Future<bool> updateBooking(
    int bookingId, {
    String? bookingStatus,
    String? paymentStatus,
    int? consultantId,
    int? timeSlotId,
    String? meetingMode,
    String? meetingLink,
    String? meetingId,
    String? meetingNotes,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (bookingStatus != null) body['bookingStatus'] = bookingStatus;
      if (paymentStatus != null) body['paymentStatus'] = paymentStatus;
      if (consultantId != null) body['consultantId'] = consultantId;
      if (timeSlotId != null) body['timeSlotId'] = timeSlotId;
      if (meetingMode != null) body['meetingMode'] = meetingMode;
      if (meetingLink != null) body['meetingLink'] = meetingLink;
      if (meetingId != null) body['meetingId'] = meetingId;
      if (meetingNotes != null) body['meetingNotes'] = meetingNotes;
      if (body.isEmpty) return true;

      for (final path in [
        '/api/bookings/$bookingId',
        '/api/bookings/bulk/$bookingId',
      ]) {
        try {
          await _apiClient.dio.put(path, data: body);
          return true;
        } catch (_) {}
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// PUT /api/bookings/bulk/{id}
  Future<bool> updateBulkBooking(
    int bookingId, {
    String? bookingStatus,
    String? paymentStatus,
    int? consultantId,
    List<int>? timeSlotIds,
    String? meetingMode,
    String? meetingLink,
    String? meetingId,
    String? meetingNotes,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (bookingStatus != null) body['bookingStatus'] = bookingStatus;
      if (paymentStatus != null) body['paymentStatus'] = paymentStatus;
      if (consultantId != null) body['consultantId'] = consultantId;
      if (timeSlotIds != null && timeSlotIds.isNotEmpty) {
        body['timeSlotIds'] = timeSlotIds;
      }
      if (meetingMode != null) body['meetingMode'] = meetingMode;
      if (meetingLink != null) body['meetingLink'] = meetingLink;
      if (meetingId != null) body['meetingId'] = meetingId;
      if (meetingNotes != null) body['meetingNotes'] = meetingNotes;
      if (body.isEmpty) return true;
      await _apiClient.dio.put('/api/bookings/bulk/$bookingId', data: body);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Shortcut: add meeting link to a booking
  Future<bool> addMeetingLink(
    int bookingId, {
    required String meetingLink,
    String? meetingId,
  }) =>
      updateBooking(bookingId, meetingLink: meetingLink, meetingId: meetingId);

  // ── RESCHEDULE ────────────────────────────────────────────────────────────

  /// PUT /api/bookings/{id}/reschedule
  Future<bool> rescheduleBooking(
    int bookingId, {
    required int newTimeSlotId,
  }) async {
    try {
      await _apiClient.dio.put(
        '/api/bookings/$bookingId/reschedule',
        data: {'newTimeSlotId': newTimeSlotId},
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// PUT /api/bookings/bulk/{id}/reschedule
  Future<bool> rescheduleBulkBooking(
    int bookingId, {
    required int oldTimeSlotId,
    required int newTimeSlotId,
  }) async {
    try {
      await _apiClient.dio.put(
        '/api/bookings/bulk/$bookingId/reschedule',
        data: {
          'oldTimeSlotId': oldTimeSlotId,
          'newTimeSlotId': newTimeSlotId,
        },
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── CANCEL ────────────────────────────────────────────────────────────────

  /// PATCH /api/bookings/{id}/cancel
  /// Backend handles Razorpay refund automatically on cancellation.
  Future<bool> cancelBooking(int bookingId) async {
    try {
      await _apiClient.dio.patch('/api/bookings/$bookingId/cancel');
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return true; // Already cancelled
      return false;
    } catch (_) {
      return false;
    }
  }

  // ── SUMMARY ───────────────────────────────────────────────────────────────

  /// GET /api/bookings/summary (Admin only)
  Future<Map<String, dynamic>?> getBookingSummary() async {
    try {
      final response = await _apiClient.dio.get('/api/bookings/summary');
      return response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : null;
    } catch (_) {
      return null;
    }
  }

  // ── ACTIVE BOOKING CHECK ──────────────────────────────────────────────────

  Future<bool> hasActiveBookings(int consultantId) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/bookings/consultant/$consultantId',
        queryParameters: {'size': 30},
      );
      final raw = response.data;
      final list = raw is Map
          ? (raw['content'] ?? raw['data'] ?? [])
          : (raw is List ? raw : []);
      for (final item in list) {
        if (item is! Map) continue;
        final status =
            (item['bookingStatus'] ?? item['status'] ?? '').toString().toUpperCase();
        if (status == 'CONFIRMED' || status == 'PENDING') return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ── SPECIAL BOOKINGS ──────────────────────────────────────────────────────

  Future<int?> _readCurrentUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final intValue = prefs.getInt('fin_user_id') ??
          prefs.getInt('user_id') ??
          prefs.getInt('userId');
      if (intValue != null && intValue > 0) return intValue;
      final raw = prefs.getString('fin_user_id') ??
          prefs.getString('user_id') ??
          prefs.getString('userId');
      return int.tryParse('${raw ?? ''}');
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _normalizeSpecialPayload(Map<String, dynamic> payload) {
    final hoursRaw = payload['durationInHours'] ??
        payload['duration_hours'] ??
        payload['hours'] ??
        1;
    final amountRaw = payload['sessionAmount'] ??
        payload['amount'] ??
        payload['baseAmount'] ??
        payload['totalAmount'];
    final hours = int.tryParse('$hoursRaw') ?? 1;
    final amount = double.tryParse('$amountRaw') ?? 0;

    return {
      'consultantId': payload['consultantId'],
      'durationInHours': hours.clamp(1, 8),
      'sessionAmount': amount,
      'meetingMode': (payload['meetingMode'] ?? 'ONLINE').toString(),
      'userNotes':
          (payload['userNotes'] ?? 'Special booking request').toString(),
      if (payload['offerId'] != null) 'offerId': payload['offerId'],
    };
  }

  /// POST /api/special-bookings
  ///
  /// Returns the raw special-booking JSON which includes:
  ///   - `razorpayOrderId` — pass to RazorpayService.payAndVerifySpecialBooking
  ///   - `totalAmount`     — 0 means already paid (MEMBER / 100% promo)
  ///   - `paymentStatus`   — SUCCESS = already confirmed, PENDING = needs payment
  ///   - `id`              — special booking ID for verification endpoint
  ///
  /// Pass [offerId] (via the payload map key `offerId`) to apply a promo code.
  Future<Map<String, dynamic>?> createSpecialBooking(
      Map<String, dynamic> payload) async {
    final body = _normalizeSpecialPayload(payload);
    for (final requestBody in [
      body,
      {...body, if (!body.containsKey('status')) 'status': 'REQUESTED'},
    ]) {
      try {
        final response = await _apiClient.dio.post(
          '/api/special-bookings',
          data: requestBody,
        );
        final data = response.data;
        if (data is Map) return Map<String, dynamic>.from(data);
        if (data is List && data.isNotEmpty && data.first is Map) {
          return Map<String, dynamic>.from(data.first as Map);
        }
      } catch (_) {}
    }
    return null;
  }

  /// GET /api/special-bookings/me
  Future<List<Map<String, dynamic>>> getMySpecialBookings() async {
    final userId = await _readCurrentUserId();
    final paths = <String>[
      '/api/special-bookings/me',
      '/api/special-bookings/my',
      if (userId != null) '/api/special-bookings/user/$userId',
      if (userId != null) '/api/special-bookings/users/$userId',
      if (userId != null) '/api/users/$userId/special-bookings',
      '/api/special-bookings',
    ];
    for (final path in paths) {
      try {
        final res = await _apiClient.dio.get(path);
        final list = _extractRows(res.data);
        if (list.isNotEmpty) return list;
      } catch (_) {}
    }
    return [];
  }

  /// GET /api/special-bookings/consultant/{id}
  Future<List<Map<String, dynamic>>> getSpecialBookingsByConsultant(
      int consultantId) async {
    final paths = <String>[
      '/api/special-bookings/consultant/$consultantId',
      '/api/consultants/$consultantId/special-bookings',
      '/api/special-bookings?consultantId=$consultantId',
    ];
    for (final path in paths) {
      try {
        final res = await _apiClient.dio.get(path);
        final rows = _extractRows(res.data);
        if (rows.isNotEmpty) return rows;
      } catch (_) {}
    }
    return [];
  }

  /// GET /api/special-bookings (Admin)
  Future<List<Map<String, dynamic>>> getAllSpecialBookings() async {
    final paths = <String>[
      '/api/special-bookings',
      '/api/special-bookings/admin',
      '/api/special-bookings/all',
    ];
    for (final path in paths) {
      try {
        final res = await _apiClient.dio.get(
          path,
          queryParameters: path == '/api/special-bookings'
              ? {'page': 0, 'size': 200}
              : null,
        );
        final rows = _extractRows(res.data);
        if (rows.isNotEmpty) return rows;
      } catch (_) {}
    }
    return [];
  }

  /// PATCH /api/special-bookings/{id}/give-slot (Consultant only)
  Future<bool> giveSlotSpecialBooking(
      int id, Map<String, dynamic> payload) async {
    final date = (payload['date'] ??
            payload['scheduledDate'] ??
            payload['newDate'] ??
            '')
        .toString()
        .trim();
    final time = (payload['startTime'] ??
            payload['scheduledTime'] ??
            payload['newTime'] ??
            payload['time'] ??
            '')
        .toString()
        .trim();

    final payloadCandidates = <Map<String, dynamic>>[
      payload,
      {
        ...payload,
        if (date.isNotEmpty) 'scheduledDate': date,
        if (time.isNotEmpty) 'scheduledTime': time,
      },
      {
        ...payload,
        if (date.isNotEmpty) 'newDate': date,
        if (time.isNotEmpty) 'newTime': time,
      },
    ];

    final attempts = <Future<Response<dynamic>> Function(Map<String, dynamic>)>[
      (data) =>
          _apiClient.dio.patch('/api/special-bookings/$id/give-slot', data: data),
      (data) =>
          _apiClient.dio.put('/api/special-bookings/$id/give-slot', data: data),
      (data) =>
          _apiClient.dio.post('/api/special-bookings/$id/give-slot', data: data),
      (data) =>
          _apiClient.dio.put('/api/special-bookings/$id/schedule', data: data),
      (data) => _apiClient.dio.patch('/api/special-bookings/$id', data: data),
    ];

    for (final candidate in payloadCandidates) {
      for (final attempt in attempts) {
        try {
          await attempt(candidate);
          return true;
        } catch (_) {}
      }
    }
    return false;
  }

  /// PUT /api/special-bookings/{id}
  Future<bool> updateSpecialBooking(
      int id, Map<String, dynamic> payload) async {
    for (final attempt in <Future<Response<dynamic>> Function()>[
      () => _apiClient.dio.put('/api/special-bookings/$id', data: payload),
      () => _apiClient.dio.patch('/api/special-bookings/$id', data: payload),
      () => _apiClient.dio
          .put('/api/special-bookings/$id/schedule', data: payload),
    ]) {
      try {
        await attempt();
        return true;
      } catch (_) {}
    }
    return false;
  }

  /// PUT /api/special-bookings/{id}/reschedule
  Future<bool> rescheduleSpecialBooking(
    int id, {
    required String newDate,
    required String newTime,
  }) async {
    final payload = {
      'newDate': newDate,
      'newTime': newTime,
      'scheduledDate': newDate,
      'scheduledTime': newTime,
    };
    for (final attempt in <Future<Response<dynamic>> Function()>[
      () => _apiClient.dio
          .put('/api/special-bookings/$id/reschedule', data: payload),
      () => _apiClient.dio
          .put('/api/special-bookings/$id/schedule', data: payload),
      () => _apiClient.dio.patch('/api/special-bookings/$id', data: payload),
    ]) {
      try {
        await attempt();
        return true;
      } catch (_) {}
    }
    return false;
  }

  /// PATCH /api/special-bookings/{id}/cancel
  /// Backend handles Razorpay refund automatically.
  Future<bool> cancelSpecialBooking(int id) async {
    try {
      await _apiClient.dio.patch('/api/special-bookings/$id/cancel');
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return true;
      return false;
    } catch (_) {
      return false;
    }
  }

  // ── NOTIFICATION ──────────────────────────────────────────────────────────

  Future<bool> sendBookingConfirmationNotification(
    int bookingId, {
    String? slotDate,
    String? timeRange,
    String? meetingMode,
    String? meetingLink,
    String? userName,
    String? userEmail,
    String? consultantName,
    String? consultantEmail,
    String? amount,
    String? userNotes,
  }) async {
    try {
      await _apiClient.dio.post(
        '/api/notifications/booking-confirmation',
        data: {
          'bookingId': bookingId,
          if (slotDate != null) 'slotDate': slotDate,
          if (timeRange != null) 'timeRange': timeRange,
          if (meetingMode != null) 'meetingMode': meetingMode,
          if (meetingLink != null) 'meetingLink': meetingLink,
          if (userName != null) 'userName': userName,
          if (userEmail != null) 'userEmail': userEmail,
          if (consultantName != null) 'consultantName': consultantName,
          if (consultantEmail != null) 'consultantEmail': consultantEmail,
          if (amount != null) 'amount': amount,
          if (userNotes != null) 'userNotes': userNotes,
        },
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── INTERNAL HELPERS ──────────────────────────────────────────────────────

  List<Map<String, dynamic>> _extractRows(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (data is Map) {
      const keys = [
        'content',
        'data',
        'items',
        'bookings',
        'results',
        'records'
      ];
      for (final key in keys) {
        final value = data[key];
        if (value is List) {
          return value
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    }
    return [];
  }
}