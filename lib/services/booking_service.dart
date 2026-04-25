// lib/core/services/booking_service.dart
// ════════════════════════════════════════════════════════════════════════════
// Swagger spec ke exact endpoints (web BookingsPage.tsx se matched):
//   GET   /api/bookings                    (paginated) — Admin
//   GET   /api/bookings/me                 (current user)
//   GET   /api/bookings/{id}
//   GET   /api/bookings/status/{status}    ← path param
//   GET   /api/bookings/consultant/{id}
//   POST  /api/bookings                    body: BookingRequest
//   POST  /api/bookings/bulk               body: BulkBookingRequest
//   PUT   /api/bookings/{id}               body: BookingUpdateRequest
//   PATCH /api/bookings/{id}/cancel        ← Web uses this (NOT DELETE)
//   PATCH /api/bookings/bulk/cancel?ids=   ← bulk cancel
//   POST  /api/notifications/booking-confirmation
//
// FIX: DELETE /api/bookings/{id} EXIST NAHI KARTA — PATCH /cancel use karo
// Web BookingsPage.tsx line: fetch(`${API_BASE}/api/bookings/${id}/cancel`, { method: "PATCH" })
// ════════════════════════════════════════════════════════════════════════════

import 'package:dio/dio.dart';
import 'package:finadvise/api_client.dart';
import '../models/models.dart';

class BookingService {
  final ApiClient _apiClient = ApiClient();

  // ── READ ─────────────────────────────────────────────────────────────────

  /// GET /api/bookings — Admin: sab bookings (paginated)
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
      return (list as List).map((e) => Booking.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      // Agar 403/404 aaye to empty list return karo
      if (e.response?.statusCode == 403 || e.response?.statusCode == 404) {
        return [];
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// GET /api/bookings — paginated with totalElements support (Admin dashboard ke liye)
  Future<Map<String, dynamic>> getAllBookingsPaginated({
    int page = 0,
    int size = 10,
    String? status,
  }) async {
    try {
      final normalizedStatus = (status ?? '').trim().toUpperCase();
      final isFiltered = normalizedStatus.isNotEmpty && normalizedStatus != 'ALL';
      final response = await _apiClient.dio.get(
        isFiltered ? '/api/bookings/status/$normalizedStatus' : '/api/bookings',
        queryParameters: {'page': page, 'size': size},
      );
      final data = response.data;

      if (data is Map) {
        final list = (data['content'] ?? []) as List;
        return {
          'bookings': list.map((e) => Booking.fromJson(e as Map<String, dynamic>)).toList(),
          'totalElements': data['totalElements'] ?? list.length,
          'totalPages': data['totalPages'] ?? 1,
          'currentPage': data['number'] ?? page,
        };
      } else if (data is List) {
        final bookings = data.map((e) => Booking.fromJson(e as Map<String, dynamic>)).toList();
        return {
          'bookings': bookings,
          'totalElements': bookings.length,
          'totalPages': 1,
          'currentPage': 0,
        };
      }
      return {'bookings': [], 'totalElements': 0, 'totalPages': 0, 'currentPage': 0};
    } catch (_) {
      return {'bookings': [], 'totalElements': 0, 'totalPages': 0, 'currentPage': 0};
    }
  }

  /// GET /api/bookings/me — Apni bookings (logged-in user)
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
      return (list as List).map((e) => Booking.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Paginated version for dashboard check
  Future<({List<dynamic> content, int totalElements})> getBookingsByConsultantPaginated(
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
        content: list.map((e) => Booking.fromJson(e as Map<String, dynamic>)).toList(),
        totalElements: (data['totalElements'] as num?)?.toInt() ?? list.length,
        );
      }
      final list = data is List ? data : [];
      final content = list.map((e) => Booking.fromJson(e as Map<String, dynamic>)).toList();
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
  /// status: PENDING | CONFIRMED | COMPLETED | CANCELLED
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
      return (list as List).map((e) => Booking.fromJson(e as Map<String, dynamic>)).toList();
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
      return (list as List).map((e) => Booking.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
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
    required double baseAmount, // FIX: 'baseAmount' (nahi 'amount')
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
      return Booking.fromJson(response.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// POST /api/bookings/bulk — Exactly 2 slots ki bulk booking
  Future<Map<String, dynamic>?> createBulkBooking({
    required int consultantId,
    required List<int> timeSlotIds, // exactly 2 items
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
    } catch (_) {
      return null;
    }
  }

  // ── UPDATE ────────────────────────────────────────────────────────────────

  /// PUT /api/bookings/{id} — Booking update karo (Admin use)
  Future<bool> updateBooking(
      int bookingId, {
        String? bookingStatus, // PENDING | CONFIRMED | COMPLETED | CANCELLED
        String? paymentStatus, // PENDING | SUCCESS | FAILED | REFUNDED
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
    } catch (_) {
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

  // ── CANCEL (Web BookingsPage.tsx se matched) ──────────────────────────────

  /// PATCH /api/bookings/{id}/cancel — Single booking cancel
  /// Web code: fetch(`${API_BASE}/api/bookings/${id}/cancel`, { method: "PATCH" })
  /// FIX: DELETE /api/bookings/{id} exist NAHI karta!
  Future<bool> cancelBooking(int bookingId) async {
    try {
      await _apiClient.dio.patch('/api/bookings/$bookingId/cancel');
      return true;
    } catch (e) {
      if (e is DioException) {
        // 404 means already cancelled ya exist nahi karta — treat as success
        if (e.response?.statusCode == 404) return true;
      }
      return false;
    }
  }

  /// PATCH /api/bookings/bulk/cancel?ids=1,2,3 — Multiple bookings cancel
  Future<bool> cancelBulkBookings(List<int> bookingIds) async {
    return false;
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

  /// GET /api/bookings/summary
  Future<Map<String, dynamic>?> getBookingSummary() async {
    try {
      final response = await _apiClient.dio.get('/api/bookings/summary');
      return response.data is Map
          ? Map<String, dynamic>.from(response.data)
          : null;
    } catch (_) {
      return null;
    }
  }

  // ── NOTIFICATION ──────────────────────────────────────────────────────────

  /// POST /api/notifications/booking-confirmation
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

  // ── ACTIVE BOOKING CHECK (admin_dashboard ke liye) ────────────────────────

  /// Check karo ki consultant ke koi active bookings hain
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
        final status = (item['bookingStatus'] ?? item['status'] ?? '')
            .toString()
            .toUpperCase();
        if (status == 'CONFIRMED' || status == 'PENDING' || status == 'RESCHEDULED') {
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ── SPECIAL BOOKINGS ──────────────────────────────────────────────────────

  /// POST /api/special-bookings — Create a special booking request
  Future<Map<String, dynamic>?> createSpecialBooking(Map<String, dynamic> payload) async {
    try {
      final response = await _apiClient.dio.post('/api/special-bookings', data: payload);
      return response.data is Map ? Map<String, dynamic>.from(response.data) : null;
    } catch (_) {
      return null;
    }
  }

  /// GET /api/special-bookings/me — My special bookings (logged-in user)
  Future<List<Map<String, dynamic>>> getMySpecialBookings() async {
    final paths = [
      '/api/special-bookings/me',
      '/api/special-bookings/my',
    ];
    for (final path in paths) {
      try {
        final res = await _apiClient.dio.get(path);
        final list = _extractRows(res.data);
        if (list.isNotEmpty || res.statusCode == 200) {
          return list;
        }
      } catch (_) {}
    }
    return [];
  }

  /// GET /api/special-bookings/consultant/{id} — By consultant
  Future<List<Map<String, dynamic>>> getSpecialBookingsByConsultant(int consultantId) async {
    try {
      final res = await _apiClient.dio.get('/api/special-bookings/consultant/$consultantId');
      return _extractRows(res.data);
    } catch (_) {
      return [];
    }
  }

  /// GET /api/special-bookings — All special bookings (Admin)
  Future<List<Map<String, dynamic>>> getAllSpecialBookings() async {
    final paths = [
      '/api/special-bookings',
      '/api/special-bookings/admin',
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
        if (rows.isNotEmpty || res.statusCode == 200) {
          return rows;
        }
      } catch (_) {}
    }
    return [];
  }

  /// PATCH /api/special-bookings/{id}/give-slot — Assign a slot to special booking
  Future<bool> giveSlotSpecialBooking(int id, Map<String, dynamic> payload) async {
    try {
      await _apiClient.dio.patch('/api/special-bookings/$id/give-slot', data: payload);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// PUT /api/special-bookings/{id} — Generic update special booking
  Future<bool> updateSpecialBooking(int id, Map<String, dynamic> payload) async {
    try {
      await _apiClient.dio.put('/api/special-bookings/$id', data: payload);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// PUT /api/special-bookings/{id}/reschedule — Reschedule confirmed special booking
  /// Body: { newDate: "YYYY-MM-DD", newTime: "HH:MM:SS" }
  Future<bool> rescheduleSpecialBooking(int id, {
    required String newDate,
    required String newTime,
  }) async {
    try {
      await _apiClient.dio.put(
        '/api/special-bookings/$id/reschedule',
        data: {
          'newDate': newDate,
          'newTime': newTime,
        },
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  List<Map<String, dynamic>> _extractRows(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (data is Map) {
      final value = data['content'] ?? data['data'] ?? data['items'] ?? [];
      if (value is List) {
        return value
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    return [];
  }
}
