// lib/services/timeslot_service_ext.dart
import 'package:dio/dio.dart';
import 'package:finadvise/api_client.dart';
import '../models/all_models.dart';
class TimeSlotServiceExtended {
  final ApiClient _apiClient = ApiClient();
  Future<List<TimeSlotModel>> getAvailableSlots(int consultantId, String date) async {
    try {
      final response = await _apiClient.dio.get('/api/time-slots',
        queryParameters: {'consultantId': consultantId, 'date': date});
      final list = response.data is List ? response.data : response.data['content'] ?? [];
      return (list as List).map((s) => TimeSlotModel.fromJson(s as Map<String, dynamic>)).toList();
    } catch (e) { return []; }
  }
  Future<TimeSlotModel?> createTimeSlot(TimeSlotRequest request) async {
    try {
      final response = await _apiClient.dio.post('/api/time-slots', data: request.toJson());
      return TimeSlotModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) { return null; }
  }
  Future<bool> deleteTimeSlot(int slotId) async {
    try {
      await _apiClient.dio.delete('/api/time-slots/$slotId');
      return true;
    } catch (e) { return false; }
  }
  Future<List<TimeSlotModel>> getConsultantSlots(int consultantId) async {
    try {
      final response = await _apiClient.dio.get('/api/time-slots/consultant/$consultantId');
      final list = response.data is List ? response.data : [];
      return (list as List).map((s) => TimeSlotModel.fromJson(s as Map<String, dynamic>)).toList();
    } catch (e) { return []; }
  }
  Future<List<TimeSlotModel>> getSlotsByDate(String date) async {
    try {
      final response = await _apiClient.dio.get('/api/time-slots/date/$date');
      final list = response.data is List ? response.data : [];
      return (list as List).map((s) => TimeSlotModel.fromJson(s as Map<String, dynamic>)).toList();
    } catch (e) { return []; }
  }
}
