// lib/core/services/consultant_service.dart
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:finadvise/api_client.dart';
import '../models/models.dart';

List<dynamic> _extractArray(dynamic data,
    {List<String> keys = const ['content', 'data', 'items']}) {
  if (data is List) return data;
  if (data is Map) {
    for (final key in keys) {
      final candidate = data[key];
      if (candidate is List) return candidate;
    }
  }
  return const [];
}

class ConsultantService {
  final ApiClient _apiClient = ApiClient();

  // ── CONSULTANTS ────────────────────────────────────────────────────────────

  /// GET /api/consultants — Sabhi consultants ki list
  Future<List<ConsultantModel>> getAllConsultants() async {
    try {
      final response = await _apiClient.dio.get('/api/consultants');
      final list = _extractArray(response.data,
          keys: const ['content', 'data', 'items', 'consultants']);
      return list
          .whereType<Map>()
          .map((e) => ConsultantModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
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
  Future<bool> createConsultant(Map<String, dynamic> data,
      {MultipartFile? profilePhoto}) async {
    try {
      final formData = FormData.fromMap({
        'data': MultipartFile.fromString(
          jsonEncode(data),
          filename: 'data.json',
          contentType: DioMediaType.parse('application/json'),
        ),
        if (profilePhoto != null) 'file': profilePhoto,
      });
      await _apiClient.dio.post(
        '/api/consultants',
        data: formData,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// PUT /api/consultants/{id} — Consultant profile update karein (Multipart)
  Future<bool> updateProfile(int consultantId, Map<String, dynamic> data,
      {MultipartFile? profilePhoto}) async {
    try {
      final formData = FormData.fromMap({
        'data': MultipartFile.fromString(
          jsonEncode(data),
          filename: 'data.json',
          contentType: DioMediaType.parse('application/json'),
        ),
        if (profilePhoto != null) 'file': profilePhoto,
      });
      await _apiClient.dio.put(
        '/api/consultants/$consultantId',
        data: formData,
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
      final list = _extractArray(response.data,
          keys: const ['content', 'data', 'items', 'skills']);
      return list
          .map((e) {
            if (e is String) return e.trim();
            if (e is Map) {
              final value = e['skillName'] ?? e['name'] ?? e['value'] ?? '';
              return value.toString().trim();
            }
            return e.toString().trim();
          })
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();
    } catch (e) {
      return [];
    }
  }

  // ── TIMESLOTS ──────────────────────────────────────────────────────────────

  /// GET /api/timeslots/consultant/{consultantId} — Consultant ke sabhi slots
  Future<List<TimeSlot>> getSlotsByConsultant(int consultantId) async {
    try {
      final response =
          await _apiClient.dio.get('/api/timeslots/consultant/$consultantId');
      final list = _extractArray(response.data,
          keys: const ['content', 'data', 'items', 'timeSlots']);
      return list
          .whereType<Map>()
          .map((e) => TimeSlot.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// GET /api/timeslots/consultant/{consultantId}/available — Sirf available slots
  Future<List<TimeSlot>> getAvailableSlots(int consultantId) async {
    try {
      final response = await _apiClient.dio
          .get('/api/timeslots/consultant/$consultantId/available');
      final list = _extractArray(response.data,
          keys: const ['content', 'data', 'items', 'timeSlots']);
      return list
          .whereType<Map>()
          .map((e) => TimeSlot.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// GET /api/timeslots/consultant/{consultantId}/window — Specific window ke slots
  Future<List<TimeSlot>> getSlotsForWindow(int consultantId) async {
    try {
      final response = await _apiClient.dio
          .get('/api/timeslots/consultant/$consultantId/window');
      final list = _extractArray(response.data,
          keys: const ['content', 'data', 'items', 'timeSlots']);
      return list
          .whereType<Map>()
          .map((e) => TimeSlot.fromJson(Map<String, dynamic>.from(e)))
          .toList();
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
    String? status,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/timeslots',
        data: {
          'consultantId': consultantId,
          'slotDate': slotDate,
          'masterTimeSlotId': masterTimeSlotId,
          'durationMinutes': durationMinutes,
          if (status != null && status.isNotEmpty) 'status': status,
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

  /// GET /api/master-timeslots — Fetch all master timeslots
  Future<List<dynamic>> getAllMasterSlots() async {
    try {
      final response = await _apiClient.dio.get('/api/master-timeslots',
          queryParameters: {'page': 0, 'size': 100});
      final list = _extractArray(response.data,
          keys: const ['content', 'data', 'items', 'masterTimeSlots']);
      return list;
    } catch (e) {
      return [];
    }
  }

  /// GET /api/consultants/{id}/master-timeslots — Consultant ke master slots fetch karein
  Future<List<dynamic>> getMasterSlots(int consultantId) async {
    try {
      final response = await _apiClient.dio
          .get('/api/consultants/$consultantId/master-timeslots');
      return _extractArray(response.data,
          keys: const ['content', 'data', 'items', 'masterTimeSlots']);
    } catch (e) {
      return [];
    }
  }

  /// POST /api/master-timeslots — Naya master slot banayein
  Future<bool> createMasterSlot(String timeRange, {int duration = 60}) async {
    try {
      await _apiClient.dio.post(
        '/api/master-timeslots',
        data: {'timeRange': timeRange, 'duration': duration},
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// PUT /api/master-timeslots/{id} — Master slot update karein
  Future<bool> updateMasterSlot(
    int slotId,
    String timeRange, {
    int duration = 60,
  }) async {
    try {
      await _apiClient.dio.put(
        '/api/master-timeslots/$slotId',
        data: {'timeRange': timeRange, 'duration': duration},
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

  // ── SPECIAL DAYS ───────────────────────────────────────────────────────────

  Future<List<dynamic>> getSpecialDaysByConsultant(int consultantId) async {
    final attempts = <({String path, bool withQuery})>[
      (path: '/api/consultants/$consultantId/special-days', withQuery: false),
      (path: '/api/special-days/consultant/$consultantId', withQuery: false),
      (path: '/api/special-days', withQuery: true),
      (path: '/api/consultant-special-days', withQuery: true),
    ];

    for (final attempt in attempts) {
      try {
        final response = await _apiClient.dio.get(
          attempt.path,
          queryParameters:
              attempt.withQuery ? {'consultantId': consultantId} : null,
        );
        final rows = _extractArray(response.data,
            keys: const ['content', 'data', 'items', 'specialDays']);
        if (rows.isNotEmpty || response.statusCode == 200) return rows;
      } catch (_) {}
    }
    return [];
  }

  Future<bool> publishSpecialDay(int consultantId, String date) async {
    try {
      await _apiClient.dio.post(
        '/api/consultants/$consultantId/special-days',
        data: {
          'dates': [date],
        },
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> unpublishSpecialDay(int consultantId, String date) async {
    try {
      await _apiClient.dio.delete(
        '/api/consultants/$consultantId/special-days/${Uri.encodeComponent(date)}',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── FEEDBACKS ──────────────────────────────────────────────────────────────

  /// GET /api/feedbacks/consultant/{id} — Consultant ke saare feedbacks
  Future<List<Feedback>> getFeedbacksByConsultant(int consultantId) async {
    try {
      final response =
          await _apiClient.dio.get('/api/feedbacks/consultant/$consultantId');
      return (response.data as List).map((e) => Feedback.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }
}
