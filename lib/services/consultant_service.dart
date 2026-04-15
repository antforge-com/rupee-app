// lib/core/services/consultant_service.dart
import 'package:dio/dio.dart';
import 'package:finadvise/api_client.dart';
import '../models/models.dart';

class ConsultantService {
  final ApiClient _apiClient = ApiClient();

  // ── CONSULTANTS ────────────────────────────────────────────────────────────

  /// GET /api/consultants — Sabhi consultants ki list
  Future<List<ConsultantModel>> getAllConsultants() async {
    try {
      final response = await _apiClient.dio.get('/api/consultants');
      return (response.data as List).map((e) => ConsultantModel.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// GET /api/consultants/{id} — Ek specific consultant ki details
  Future<ConsultantModel?> getConsultantById(int id) async {
    try {
      final response = await _apiClient.dio.get('/api/consultants/$id');
      return ConsultantModel.fromJson(response.data);
    } catch (e) {
      return null;
    }
  }

  /// POST /api/consultants — Naya consultant banayein (Multipart)
  Future<bool> createConsultant(Map<String, dynamic> data, {MultipartFile? profilePhoto}) async {
    try {
      final formData = FormData.fromMap({
        'data': data,
        if (profilePhoto != null) 'file': profilePhoto,
      });
      await _apiClient.dio.post(
        '/api/consultants', 
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// PUT /api/consultants/{id} — Consultant profile update karein (Multipart)
  Future<bool> updateProfile(int consultantId, Map<String, dynamic> data, {MultipartFile? profilePhoto}) async {
    try {
      final formData = FormData.fromMap({
        'data': data,
        if (profilePhoto != null) 'file': profilePhoto,
      });
      await _apiClient.dio.put(
        '/api/consultants/$consultantId', 
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// DELETE /api/consultants/{id} — Consultant ko delete karein
  Future<bool> deleteConsultant(int id) async {
    try {
      await _apiClient.dio.delete('/api/consultants/$id');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// GET /api/consultants/skills — Saari available skills fetch karein
  Future<List<String>> getAllMasterSkills() async {
    try {
      final response = await _apiClient.dio.get('/api/consultants/skills');
      return List<String>.from(response.data);
    } catch (e) {
      return [];
    }
  }

  // ── TIMESLOTS ──────────────────────────────────────────────────────────────

  /// GET /api/timeslots/consultant/{consultantId} — Consultant ke sabhi slots
  Future<List<TimeSlot>> getSlotsByConsultant(int consultantId) async {
    try {
      final response = await _apiClient.dio.get('/api/timeslots/consultant/$consultantId');
      return (response.data as List).map((e) => TimeSlot.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// GET /api/timeslots/consultant/{consultantId}/available — Sirf available slots
  Future<List<TimeSlot>> getAvailableSlots(int consultantId) async {
    try {
      final response = await _apiClient.dio.get('/api/timeslots/consultant/$consultantId/available');
      return (response.data as List).map((e) => TimeSlot.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// GET /api/timeslots/consultant/{consultantId}/window — Specific window ke slots
  Future<List<TimeSlot>> getSlotsForWindow(int consultantId) async {
    try {
      final response = await _apiClient.dio.get('/api/timeslots/consultant/$consultantId/window');
      return (response.data as List).map((e) => TimeSlot.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// POST /api/timeslots — Naya specific time slot add karein
  Future<TimeSlot?> addCustomSlot({
    required int consultantId,
    required String slotDate,
    required int masterTimeSlotId,
    required int durationMinutes,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/timeslots',
        data: {
          'consultantId': consultantId,
          'slotDate': slotDate,
          'masterTimeSlotId': masterTimeSlotId,
          'durationMinutes': durationMinutes,
        },
      );
      return TimeSlot.fromJson(response.data);
    } catch (e) {
      return null;
    }
  }

  /// PUT /api/timeslots/{id} — Slot update karein (e.g. block/restore ke liye status change)
  Future<bool> updateTimeSlot(int slotId, Map<String, dynamic> data) async {
    try {
      await _apiClient.dio.put('/api/timeslots/$slotId', data: data);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// DELETE /api/timeslots/{id} — Slot ko delete karein
  Future<bool> deleteTimeSlot(int slotId) async {
    try {
      await _apiClient.dio.delete('/api/timeslots/$slotId');
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── MASTER SLOTS ───────────────────────────────────────────────────────────

  /// GET /api/consultants/{id}/master-timeslots — Consultant ke master slots fetch karein
  Future<List<dynamic>> getMasterSlots(int consultantId) async {
    try {
      final response = await _apiClient.dio.get('/api/consultants/$consultantId/master-timeslots');
      return response.data as List;
    } catch (e) {
      return [];
    }
  }

  /// POST /api/master-timeslots — Naya master slot banayein
  Future<bool> createMasterSlot(String timeRange) async {
    try {
      await _apiClient.dio.post(
        '/api/master-timeslots',
        data: {'timeRange': timeRange},
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// PUT /api/master-timeslots/{id} — Master slot update karein
  Future<bool> updateMasterSlot(int slotId, String timeRange) async {
    try {
      await _apiClient.dio.put(
        '/api/master-timeslots/$slotId',
        data: {'timeRange': timeRange},
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// DELETE /api/master-timeslots/{id} — Master slot delete karein
  Future<bool> deleteMasterSlot(int slotId) async {
    try {
      await _apiClient.dio.delete('/api/master-timeslots/$slotId');
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── FEEDBACKS ──────────────────────────────────────────────────────────────

  /// GET /api/feedbacks/consultant/{id} — Consultant ke saare feedbacks
  Future<List<Feedback>> getFeedbacksByConsultant(int consultantId) async {
    try {
      final response = await _apiClient.dio.get('/api/feedbacks/consultant/$consultantId');
      return (response.data as List).map((e) => Feedback.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }
}