// lib/core/services/question_service.dart
// ════════════════════════════════════════════════════════════════════════════
// Question Service — Manage skills, admin questions and user answers
// ════════════════════════════════════════════════════════════════════════════

import 'package:dio/dio.dart';
import 'package:finadvise/api_client.dart';

class QuestionServiceActionResult {
  final bool ok;
  final String message;

  const QuestionServiceActionResult({
    required this.ok,
    required this.message,
  });
}

class QuestionServiceListResult {
  final bool ok;
  final String message;
  final List<Map<String, dynamic>> items;

  const QuestionServiceListResult({
    required this.ok,
    required this.message,
    required this.items,
  });
}

class QuestionService {
  final ApiClient _apiClient = ApiClient();

  // ── SKILLS ─────────────────────────────────────────────────────────────────

  /// GET /api/skills — All skills (Admin/User)
  Future<List<Map<String, dynamic>>> getAllSkills() async {
    final result = await getAllSkillsResult();
    return result.items;
  }

  Future<QuestionServiceListResult> getAllSkillsResult() async {
    try {
      final response = await _apiClient.dio.get('/api/skills');
      return QuestionServiceListResult(
        ok: true,
        message: '',
        items: _extract(response.data),
      );
    } catch (error) {
      return QuestionServiceListResult(
        ok: false,
        message: _messageFromError(error, fallback: 'Failed to load skills'),
        items: const <Map<String, dynamic>>[],
      );
    }
  }

  /// POST /api/skills — Create new skill (Admin)
  Future<bool> createSkill(String name) async {
    final result = await createSkillResult(name);
    return result.ok;
  }

  Future<QuestionServiceActionResult> createSkillResult(String name) async {
    try {
      await _apiClient.dio.post('/api/skills', data: {'skillName': name});
      return const QuestionServiceActionResult(
        ok: true,
        message: 'Skill created',
      );
    } catch (error) {
      return QuestionServiceActionResult(
        ok: false,
        message: _messageFromError(error, fallback: 'Failed to create skill'),
      );
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
    final result = await deleteSkillResult(id);
    return result.ok;
  }

  Future<QuestionServiceActionResult> deleteSkillResult(int id) async {
    try {
      await _apiClient.dio.delete('/api/skills/$id');
      return const QuestionServiceActionResult(
        ok: true,
        message: 'Skill deleted',
      );
    } catch (error) {
      return QuestionServiceActionResult(
        ok: false,
        message: _messageFromError(error, fallback: 'Failed to delete skill'),
      );
    }
  }

  // ── QUESTIONS ──────────────────────────────────────────────────────────────

  /// GET /api/questions — All questions (Admin)
  Future<List<Map<String, dynamic>>> getAllQuestions() async {
    final result = await getAllQuestionsResult();
    return result.items;
  }

  Future<QuestionServiceListResult> getAllQuestionsResult() async {
    try {
      final response = await _apiClient.dio.get('/api/questions');
      return QuestionServiceListResult(
        ok: true,
        message: '',
        items: _extract(response.data),
      );
    } catch (error) {
      return QuestionServiceListResult(
        ok: false,
        message:
            _messageFromError(error, fallback: 'Failed to load questions'),
        items: const <Map<String, dynamic>>[],
      );
    }
  }

  /// POST /api/questions — Create assessment question (Admin)
  Future<bool> createQuestion(Map<String, dynamic> data) async {
    final result = await createQuestionResult(data);
    return result.ok;
  }

  Future<QuestionServiceActionResult> createQuestionResult(
    Map<String, dynamic> data,
  ) async {
    try {
      await _apiClient.dio.post('/api/questions', data: data);
      return const QuestionServiceActionResult(
        ok: true,
        message: 'Question created',
      );
    } catch (error) {
      return QuestionServiceActionResult(
        ok: false,
        message:
            _messageFromError(error, fallback: 'Failed to create question'),
      );
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
    final result = await deleteQuestionResult(id);
    return result.ok;
  }

  Future<QuestionServiceActionResult> deleteQuestionResult(int id) async {
    try {
      await _apiClient.dio.delete('/api/questions/$id');
      return const QuestionServiceActionResult(
        ok: true,
        message: 'Question deleted',
      );
    } catch (error) {
      return QuestionServiceActionResult(
        ok: false,
        message:
            _messageFromError(error, fallback: 'Failed to delete question'),
      );
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

  String _messageFromError(Object error, {required String fallback}) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final msg = data['message'] ?? data['error'] ?? data['detail'];
        if (msg != null && '$msg'.trim().isNotEmpty) {
          return '$msg'.trim();
        }
      } else if (data is String && data.trim().isNotEmpty) {
        return data.trim();
      }
      final message = error.message?.trim() ?? '';
      if (message.isNotEmpty) {
        return message;
      }
    }
    return fallback;
  }
}
