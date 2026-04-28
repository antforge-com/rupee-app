// lib/services/master_timeslot_service_ext.dart
import 'package:dio/dio.dart';
import 'package:finadvise/api_client.dart';
import '../models/all_models.dart';
class MasterTimeSlotServiceExtended {
  final ApiClient _apiClient = ApiClient();
  Future<List<MasterTimeSlotModel>> getAllMasterSlots() async {
    try {
      final response = await _apiClient.dio.get('/api/master-time-slots');
      final list = response.data is List ? response.data : response.data['content'] ?? [];
      return (list as List).map((s) => MasterTimeSlotModel.fromJson(s as Map<String, dynamic>)).toList();
    } catch (e) { return []; }
  }
  Future<MasterTimeSlotModel?> createMasterSlot(MasterTimeSlotModel slot) async {
    try {
      final response = await _apiClient.dio.post('/api/master-time-slots', data: slot.toJson());
      return MasterTimeSlotModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) { return null; }
  }
  Future<MasterTimeSlotModel?> getMasterSlotById(int id) async {
    try {
      final response = await _apiClient.dio.get('/api/master-time-slots/$id');
      return MasterTimeSlotModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) { return null; }
  }
  Future<bool> updateMasterSlot(int id, MasterTimeSlotModel slot) async {
    try {
      await _apiClient.dio.put('/api/master-time-slots/$id', data: slot.toJson());
      return true;
    } catch (e) { return false; }
  }
  Future<bool> deleteMasterSlot(int id) async {
    try {
      await _apiClient.dio.delete('/api/master-time-slots/$id');
      return true;
    } catch (e) { return false; }
  }
}
