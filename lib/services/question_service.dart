// lib/core/services/question_service.dart
// ════════════════════════════════════════════════════════════════════════════
// Question Service — Manage skills, admin questions and user answers
// ════════════════════════════════════════════════════════════════════════════

import 'package:finadvise/api_client.dart';

class QuestionService {
  final ApiClient _apiClient = ApiClient();

  // ── SKILLS ─────────────────────────────────────────────────────────────────

  /// GET /api/skills — All skills (Admin/User)
  Future<List<Map<String, dynamic>>> getAllSkills() async {
    try {
      final response = await _apiClient.dio.get('/api/skills');
      return _extract(response.data);
    } catch (_) {
      return [];
    }
  }

  /// POST /api/skills — Create new skill (Admin)
  Future<bool> createSkill(String name) async {
    try {
      await _apiClient.dio.post('/api/skills', data: {'skillName': name});
      return true;
    } catch (_) {
      return false;
    }
  }

  /// PUT /api/skills/{id} — Update skill (Admin)
  Future<bool> updateSkill(int id, String name) async {
    try {
      await _apiClient.dio.put('/api/skills/$id', data: {'skillName': name});
      return true;
    } catch (_) {
      return false;
    }
  }

  /// DELETE /api/skills/{id} — Delete skill (Admin)
  Future<bool> deleteSkill(int id) async {
    try {
      await _apiClient.dio.delete('/api/skills/$id');
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── QUESTIONS ──────────────────────────────────────────────────────────────

  /// GET /api/questions — All questions (Admin)
  Future<List<Map<String, dynamic>>> getAllQuestions() async {
    try {
      final response = await _apiClient.dio.get('/api/questions');
      return _extract(response.data);
    } catch (_) {
      return [];
    }
  }

  /// POST /api/questions — Create assessment question (Admin)
  Future<bool> createQuestion(Map<String, dynamic> data) async {
    try {
      await _apiClient.dio.post('/api/questions', data: data);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// PUT /api/questions/{id} — Update assessment question (Admin)
  Future<bool> updateQuestion(int id, Map<String, dynamic> data) async {
    try {
      await _apiClient.dio.put('/api/questions/$id', data: data);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// DELETE /api/questions/{id} — Delete question (Admin)
  Future<bool> deleteQuestion(int id) async {
    try {
      await _apiClient.dio.delete('/api/questions/$id');
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── ANSWERS ────────────────────────────────────────────────────────────────

  /// POST /api/answers — Submit answers for NORMAL or SPECIAL booking
  Future<bool> submitAnswers({
    required int bookingId,
    required String bookingType,
    int? consultantId,
    required List<Map<String, dynamic>> answers,
  }) async {
    try {
      await _apiClient.dio.post('/api/answers', data: {
        'bookingId': bookingId,
        'bookingType': bookingType,
        if (consultantId != null) 'consultantId': consultantId,
        'answers': answers
            .map((item) => {
                  'questionId': item['questionId'] ?? item['id'],
                  'text': (item['text'] ?? item['answer'] ?? '').toString(),
                })
            .toList(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// GET /api/users/{userId}/answers — Fetch user's submitted answers
  Future<List<Map<String, dynamic>>> getUserAnswers(int userId) async {
    final paths = [
      '/api/users/$userId/answers',
      '/api/user-answers/$userId',
    ];
    for (final path in paths) {
      try {
        final response = await _apiClient.dio.get(path);
        final rows = _extract(response.data);
        if (rows.isNotEmpty) return rows;
      } catch (_) {}
    }
    return [];
  }

  /// GET /api/users/{userId}/bookings/{bookingId}/answers?type=NORMAL|SPECIAL
  Future<List<Map<String, dynamic>>> getAnswersForBooking(
    int? userId,
    int bookingId, {
    String type = 'NORMAL',
  }) async {
    final paths = [
      if (userId != null) '/api/users/$userId/bookings/$bookingId/answers',
      '/api/bookings/$bookingId/answers',
      '/api/bookings/$bookingId/question-answers',
      '/api/bookings/$bookingId/user-answers',
      '/api/booking-answers/booking/$bookingId',
    ];
    for (final path in paths) {
      try {
        final response = await _apiClient.dio.get(
          path,
          queryParameters: path.contains('/users/')
              ? {'type': type}
              : null,
        );
        final rows = _extract(response.data);
        if (rows.isNotEmpty) return rows;
      } catch (_) {}
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getAnswersForSpecialBooking(int specialBookingId) async {
    final paths = [
      '/api/special-bookings/$specialBookingId/answers',
      '/api/special-bookings/$specialBookingId/question-answers',
      '/api/booking-answers/special-booking/$specialBookingId',
    ];
    for (final path in paths) {
      try {
        final response = await _apiClient.dio.get(path);
        final rows = _extract(response.data);
        if (rows.isNotEmpty) return rows;
      } catch (_) {}
    }
    return [];
  }

  List<Map<String, dynamic>> _extract(dynamic data) {
    if (data is List) return data.map((e) => Map<String, dynamic>.from(e)).toList();
    if (data is Map) {
      for (final key in const [
        'content',
        'data',
        'items',
        'answers',
        'questionAnswers',
        'userAnswers',
      ]) {
        final value = data[key];
        if (value is List) {
          return value.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
    }
    return [];
  }
}
