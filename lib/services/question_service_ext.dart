// lib/services/question_service_ext.dart
import 'package:dio/dio.dart';
import 'package:finadvise/api_client.dart';
import '../models/all_models.dart';
class QuestionServiceExtended {
  final ApiClient _apiClient = ApiClient();
  Future<List<QuestionModel>> getAllQuestions() async {
    try {
      final response = await _apiClient.dio.get('/api/questions');
      final list = response.data is List ? response.data : response.data['content'] ?? [];
      return (list as List).map((q) => QuestionModel.fromJson(q as Map<String, dynamic>)).toList();
    } catch (e) { return []; }
  }
  Future<QuestionModel?> getQuestionById(int id) async {
    try {
      final response = await _apiClient.dio.get('/api/questions/$id');
      return QuestionModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) { return null; }
  }
  Future<List<AnswerModel>> getAnswers(int questionId) async {
    try {
      final response = await _apiClient.dio.get('/api/questions/$questionId/answers');
      final list = response.data is List ? response.data : [];
      return (list as List).map((a) => AnswerModel.fromJson(a as Map<String, dynamic>)).toList();
    } catch (e) { return []; }
  }
  Future<AnswerModel?> submitAnswer(AnswerModel answer) async {
    try {
      final response = await _apiClient.dio.post('/api/answers', data: answer.toJson());
      return AnswerModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) { return null; }
  }
  Future<bool> deleteAnswer(int answerId) async {
    try {
      await _apiClient.dio.delete('/api/answers/$answerId');
      return true;
    } catch (e) { return false; }
  }
}
