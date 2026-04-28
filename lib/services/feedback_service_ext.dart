// lib/services/feedback_service_ext.dart
import 'package:dio/dio.dart';
import 'package:finadvise/api_client.dart';
import '../models/all_models.dart';
class FeedbackServiceExtended {
  final ApiClient _apiClient = ApiClient();
  Future<FeedbackModel?> createFeedback(FeedbackModel feedback) async {
    try {
      final response = await _apiClient.dio.post('/api/feedback', data: feedback.toJson());
      return FeedbackModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) { print('Error: '); return null; }
  }
  Future<List<FeedbackModel>> getByBooking(int bookingId) async {
    try {
      final response = await _apiClient.dio.get('/api/feedback/booking/$bookingId');
      final list = response.data is List ? response.data : [];
      return (list as List).map((f) => FeedbackModel.fromJson(f as Map<String, dynamic>)).toList();
    } catch (e) { return []; }
  }
  Future<List<FeedbackModel>> getByConsultant(int consultantId) async {
    try {
      final response = await _apiClient.dio.get('/api/feedback/consultant/$consultantId');
      final list = response.data is List ? response.data : [];
      return (list as List).map((f) => FeedbackModel.fromJson(f as Map<String, dynamic>)).toList();
    } catch (e) { return []; }
  }
  Future<bool> updateFeedback(int id, FeedbackModel feedback) async {
    try {
      await _apiClient.dio.put('/api/feedback/$id', data: feedback.toJson());
      return true;
    } catch (e) { return false; }
  }
  Future<bool> deleteFeedback(int id) async {
    try {
      await _apiClient.dio.delete('/api/feedback/$id');
      return true;
    } catch (e) { return false; }
  }
  Future<double> getAverageRating(int consultantId) async {
    try {
      final response = await _apiClient.dio.get('/api/feedback/consultant/$consultantId/rating');
      return (response.data['averageRating'] as num?)?.toDouble() ?? 0.0;
    } catch (e) { return 0.0; }
  }
}
