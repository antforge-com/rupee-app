// lib/core/services/booking_service.dart
// ════════════════════════════════════════════════════════════════════════════
// Swagger spec ke exact endpoints:
//   GET   /api/bookings                    (paginated)
//   GET   /api/bookings/me                 (current user)
//   GET   /api/bookings/{id}
//   GET   /api/bookings/status/{status}    ← path param
//   GET   /api/bookings/consultant/{id}
//   POST  /api/bookings                    body: BookingRequest
//   POST  /api/bookings/bulk               body: BulkBookingRequest
//   PUT   /api/bookings/{id}               body: BookingUpdateRequest
//   PATCH /api/bookings/{id}/cancel        ← cancel karne ka sahi tarika
//   PATCH /api/bookings/bulk/cancel?ids=   ← bulk cancel
//   POST  /api/notifications/booking-confirmation
//
// FIX: DELETE /api/bookings/{id} EXIST NAHI KARTA — PATCH /cancel use karo
// ════════════════════════════════════════════════════════════════════════════

import 'package:finadvise/api_client.dart';
import '../models/models.dart';

class BookingService {
  final ApiClient _apiClient = ApiClient();

  // ── READ ─────────────────────────────────────────────────────────────────

  /// GET /api/bookings — Admin: sab bookings (paginated)
  Future<List<Booking>> getAllBookings({int page = 0, int size = 10}) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/bookings',
        queryParameters: {'page': page, 'size': size},
      );
      final data = response.data;
      final list = data is Map ? (data['content'] ?? data['data'] ?? []) : data;
      return (list as List).map((e) => Booking.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// GET /api/bookings/me — Apni bookings
  Future<List<Booking>> getMyBookings({int page = 0, int size = 10}) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/bookings/me',
        queryParameters: {'page': page, 'size': size},
      );
      final data = response.data;
      final list = data is Map ? (data['content'] ?? data['data'] ?? []) : data;
      return (list as List).map((e) => Booking.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// GET /api/bookings/{id}
  Future<Booking?> getBookingById(int bookingId) async {
    try {
      final response = await _apiClient.dio.get('/api/bookings/$bookingId');
      return Booking.fromJson(response.data);
    } catch (e) {
      return null;
    }
  }

  /// GET /api/bookings/status/{status}
  /// status: PENDING | CONFIRMED | COMPLETED | CANCELLED
  Future<List<Booking>> getBookingsByStatus(
    String status, {
    int page = 0,
    int size = 10,
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/bookings/status/$status',
        queryParameters: {'page': page, 'size': size},
      );
      final data = response.data;
      final list = data is Map ? (data['content'] ?? data['data'] ?? []) : data;
      return (list as List).map((e) => Booking.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// GET /api/bookings/consultant/{consultantId}
  Future<List<Booking>> getBookingsByConsultant(
    int consultantId, {
    int page = 0,
    int size = 10,
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/bookings/consultant/$consultantId',
        queryParameters: {'page': page, 'size': size},
      );
      final data = response.data;
      final list = data is Map ? (data['content'] ?? data['data'] ?? []) : data;
      return (list as List).map((e) => Booking.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  // ── CREATE ────────────────────────────────────────────────────────────────

  /// POST /api/bookings — Single booking banao
  /// BookingRequest required: consultantId, timeSlotId, baseAmount, meetingMode
  /// meetingMode: PHYSICAL | ONLINE | PHONE
  Future<Booking?> createBooking({
    required int consultantId,
    required int timeSlotId,
    required double baseAmount,   // FIX: 'baseAmount' (nahi 'amount')
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
      return Booking.fromJson(response.data);
    } catch (e) {
      return null;
    }
  }

  /// POST /api/bookings/bulk — Exactly 2 slots ki bulk booking
  /// BulkBookingRequest required: consultantId, timeSlotIds (exactly 2), baseAmountPerSlot, meetingMode
  Future<Map<String, dynamic>?> createBulkBooking({
    required int consultantId,
    required List<int> timeSlotIds,   // exactly 2 items
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
      return response.data as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  // ── UPDATE ────────────────────────────────────────────────────────────────

  /// PUT /api/bookings/{id} — Booking update karo
  /// BookingUpdateRequest fields:
  ///   bookingStatus?, paymentStatus?, consultantId?, timeSlotId?,
  ///   meetingMode?, meetingLink?, meetingId?, meetingNotes?
  Future<bool> updateBooking(
    int bookingId, {
    String? bookingStatus,   // PENDING | CONFIRMED | COMPLETED | CANCELLED
    String? paymentStatus,   // PENDING | SUCCESS | FAILED | REFUNDED
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

      await _apiClient.dio.put('/api/bookings/$bookingId', data: body);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Shortcut: meeting link add karo
  Future<bool> addMeetingLink(
    int bookingId, {
    required String meetingLink,
    String? meetingId,
  }) =>
      updateBooking(bookingId, meetingLink: meetingLink, meetingId: meetingId);

  // ── CANCEL ────────────────────────────────────────────────────────────────

  /// PATCH /api/bookings/{id}/cancel — Single booking cancel
  /// FIX: DELETE /api/bookings/{id} exist NAHI karta!
  Future<bool> cancelBooking(int bookingId) async {
    try {
      await _apiClient.dio.patch('/api/bookings/$bookingId/cancel');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// PATCH /api/bookings/bulk/cancel?ids=1,2,3 — Multiple bookings cancel
  Future<bool> cancelBulkBookings(List<int> bookingIds) async {
    try {
      await _apiClient.dio.patch(
        '/api/bookings/bulk/cancel',
        queryParameters: {'ids': bookingIds},
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── NOTIFICATION ──────────────────────────────────────────────────────────

  /// POST /api/notifications/booking-confirmation
  /// body: { bookingId, slotDate?, timeRange?, meetingMode?, meetingLink?,
  ///         userName?, userEmail?, consultantName?, consultantEmail?,
  ///         amount?, userNotes? }
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
    } catch (e) {
      return false;
    }
  }
}
