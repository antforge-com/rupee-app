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
import 'package:finadvise/services/user_service.dart';
import '../models/models.dart';

class FeedbackService {
  final ApiClient _apiClient = ApiClient();
  final UserService _userService = UserService();

  // ── READ ─────────────────────────────────────────────────────────────────

  /// GET /api/feedbacks — Sab feedbacks (array, paginated nahi)
  Future<List<Feedback>> getAllFeedbacks() async {
    try {
      final response = await _apiClient.dio.get('/api/feedbacks');
      final data = response.data;
      final list = data is Map ? (data['content'] ?? data['data'] ?? []) : data;
      return _enrichFeedbackNames(
        (list as List).map((e) => Feedback.fromJson(e)).toList(),
      );
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
      return _enrichFeedbackNames(
        (list as List).map((e) => Feedback.fromJson(e)).toList(),
      );
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
      return _enrichFeedbackName(
        Feedback.fromJson(response.data as Map<String, dynamic>),
      );
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
      return _enrichFeedbackName(
        Feedback.fromJson(response.data as Map<String, dynamic>),
      );
    } catch (e) {
      return null;
    }
  }

  /// GET /api/feedbacks/{id}
  Future<Feedback?> getFeedbackById(int feedbackId) async {
    try {
      final response = await _apiClient.dio.get('/api/feedbacks/$feedbackId');
      return _enrichFeedbackName(
        Feedback.fromJson(response.data as Map<String, dynamic>),
      );
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

  Future<List<Feedback>> _enrichFeedbackNames(List<Feedback> feedbacks) async {
    if (feedbacks.isEmpty) return feedbacks;
    final resolved = await Future.wait(
      feedbacks.map(_enrichFeedbackName),
    );
    return resolved;
  }

  Future<Feedback> _enrichFeedbackName(Feedback feedback) async {
    final existingName = (feedback.clientName ?? '').trim();
    if (existingName.isNotEmpty || feedback.userId == null) {
      return feedback;
    }

    final userId = feedback.userId!;
    try {
      final profile = await _userService.getOnboardingProfile(userId);
      final profileName = _pickName(profile);
      if (profileName.isNotEmpty) {
        return feedback.copyWith(clientName: profileName);
      }
    } catch (_) {}

    try {
      final user = await _userService.getUserById(userId);
      final fallback = _pickName(user?.toJson());
      if (fallback.isNotEmpty) {
        return feedback.copyWith(clientName: fallback);
      }
    } catch (_) {}

    return feedback;
  }

  String _pickName(Map<String, dynamic>? json) {
    if (json == null) return '';
    final raw = (json['name'] ??
            json['fullName'] ??
            json['displayName'] ??
            json['identifier'] ??
            json['email'] ??
            '')
        .toString()
        .trim();
    return raw;
  }
}
