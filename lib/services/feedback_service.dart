// lib/core/services/feedback_service.dart
// ════════════════════════════════════════════════════════════════════════════
// Swagger spec ke exact endpoints:
//   GET  /api/feedbacks
//   POST /api/feedbacks       body: FeedbackRequest
//   GET  /api/feedbacks/{id}
//   PUT  /api/feedbacks/{id}  body: FeedbackRequest
//   DELETE /api/feedbacks/{id}
//   GET  /api/feedbacks/consultant/{consultantId}
//   GET  /api/feedbacks/booking/{bookingId}
//   GET  /api/feedbacks/meeting/{meetingId}
//
// FeedbackRequest REQUIRED fields: consultantId, meetingId, bookingId, rating(1-5)
// FIX: meetingId swagger mein REQUIRED hai — optional nahi!
// ════════════════════════════════════════════════════════════════════════════

import 'package:finadvise/api_client.dart';
import '../models/models.dart';

class FeedbackService {
  final ApiClient _apiClient = ApiClient();

  // ── READ ─────────────────────────────────────────────────────────────────

  /// GET /api/feedbacks — Sab feedbacks (array, paginated nahi)
  Future<List<Feedback>> getAllFeedbacks() async {
    try {
      final response = await _apiClient.dio.get('/api/feedbacks');
      final data = response.data;
      final list = data is Map ? (data['content'] ?? data['data'] ?? []) : data;
      return (list as List).map((e) => Feedback.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// GET /api/feedbacks/consultant/{consultantId}
  Future<List<Feedback>> getFeedbacksByConsultant(int consultantId) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/feedbacks/consultant/$consultantId',
      );
      final data = response.data;
      final list = data is Map ? (data['content'] ?? data['data'] ?? []) : data;
      return (list as List).map((e) => Feedback.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// GET /api/feedbacks/booking/{bookingId}
  Future<Feedback?> getFeedbackByBooking(int bookingId) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/feedbacks/booking/$bookingId',
      );
      return Feedback.fromJson(response.data);
    } catch (e) {
      return null;
    }
  }

  /// GET /api/feedbacks/meeting/{meetingId}
  Future<Feedback?> getFeedbackByMeeting(int meetingId) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/feedbacks/meeting/$meetingId',
      );
      return Feedback.fromJson(response.data);
    } catch (e) {
      return null;
    }
  }

  /// GET /api/feedbacks/{id}
  Future<Feedback?> getFeedbackById(int feedbackId) async {
    try {
      final response = await _apiClient.dio.get('/api/feedbacks/$feedbackId');
      return Feedback.fromJson(response.data);
    } catch (e) {
      return null;
    }
  }

  // ── CREATE ────────────────────────────────────────────────────────────────

  /// POST /api/feedbacks — Submit feedback
  /// REQUIRED: consultantId, meetingId, bookingId, rating (1-5)
  /// FIX: meetingId swagger mein required hai (min: 1)
  Future<Feedback?> submitFeedback({
    required int consultantId,
    required int meetingId,    // REQUIRED per swagger
    required int bookingId,
    required int rating,       // 1-5
    String? comments,          // max 1000 chars
  }) async {
    try {
      final response = await _apiClient.dio.post('/api/feedbacks', data: {
        'consultantId': consultantId,
        'meetingId': meetingId,
        'bookingId': bookingId,
        'rating': rating,
        if (comments != null && comments.isNotEmpty) 'comments': comments,
      });
      return Feedback.fromJson(response.data);
    } catch (e) {
      return null;
    }
  }

  // ── UPDATE ────────────────────────────────────────────────────────────────

  /// PUT /api/feedbacks/{id} — Feedback update karo
  /// Can update rating and/or comments
  Future<bool> updateFeedback(
    int feedbackId, {
    int? rating,
    String? comments,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (rating != null) body['rating'] = rating;
      if (comments != null) body['comments'] = comments;
      if (body.isEmpty) return true;
      await _apiClient.dio.put('/api/feedbacks/$feedbackId', data: body);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── DELETE ────────────────────────────────────────────────────────────────

  /// DELETE /api/feedbacks/{id}
  Future<bool> deleteFeedback(int feedbackId) async {
    try {
      await _apiClient.dio.delete('/api/feedbacks/$feedbackId');
      return true;
    } catch (e) {
      return false;
    }
  }
}
