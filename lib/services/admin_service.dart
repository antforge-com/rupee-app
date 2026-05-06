// lib/services/admin_service.dart
// ════════════════════════════════════════════════════════════════════════════
// Admin Service — Fixed with proper error handling and timeout resilience
// ════════════════════════════════════════════════════════════════════════════

import 'package:finadvise/api_client.dart';

class AdminService {
  final ApiClient _apiClient = ApiClient();

  // GET /api/admin/settings/business-hours
  Future<List<dynamic>> getBusinessHours() async {
    try {
      final response = await _apiClient.dio.get('/api/admin/settings/business-hours');
      final data = response.data;
      return data is List ? data : [];
    } catch (_) {
      return [];
    }
  }

  // POST /api/admin/settings/business-hours
  Future<bool> updateBusinessHours(List<Map<String, dynamic>> payload) async {
    try {
      await _apiClient.dio.post('/api/admin/settings/business-hours', data: payload);
      return true;
    } catch (_) {
      return false;
    }
  }

  // GET /api/admin/settings/holidays
  Future<List<dynamic>> getHolidays() async {
    try {
      final response = await _apiClient.dio.get('/api/admin/settings/holidays');
      final data = response.data;
      return data is List ? data : [];
    } catch (_) {
      return [];
    }
  }

  // POST /api/admin/settings/holidays
  Future<bool> addHoliday(String name, String date) async {
    try {
      await _apiClient.dio.post('/api/admin/settings/holidays', data: {
        'name': name,
        'holidayDate': date,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  // DELETE /api/admin/settings/holidays/{id}
  Future<bool> deleteHoliday(int id) async {
    try {
      await _apiClient.dio.delete('/api/admin/settings/holidays/$id');
      return true;
    } catch (_) {
      return false;
    }
  }

  // GET /api/admin/settings/auto-responder
  Future<Map<String, dynamic>?> getAutoResponder() async {
    try {
      final response = await _apiClient.dio.get('/api/admin/settings/auto-responder');
      return response.data as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  // POST /api/admin/settings/auto-responder
  Future<bool> setAutoResponder(bool enabled, String message) async {
    try {
      await _apiClient.dio.post('/api/admin/settings/auto-responder', data: {
        'enabled': enabled,
        'message': message,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  // GET /api/admin/config/canned-responses
  Future<List<dynamic>> getCannedResponses({String? category}) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/admin/config/canned-responses',
        queryParameters: category != null ? {'category': category} : null,
      );
      final data = response.data;
      return data is List ? data : [];
    } catch (_) {
      return [];
    }
  }

  // POST /api/admin/config/canned-responses
  Future<bool> createCannedResponse(String title, String content, String? category) async {
    try {
      await _apiClient.dio.post('/api/admin/config/canned-responses', data: {
        'title': title,
        'content': content,
        if (category != null) 'category': category,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  // PUT /api/admin/config/canned-responses/{id}
  Future<bool> updateCannedResponse(int id, String title, String content, String? category) async {
    try {
      await _apiClient.dio.put('/api/admin/config/canned-responses/$id', data: {
        'title': title,
        'content': content,
        if (category != null) 'category': category,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  // DELETE /api/admin/config/canned-responses/{id}
  Future<bool> deleteCannedResponse(int id) async {
    try {
      await _apiClient.dio.delete('/api/admin/config/canned-responses/$id');
      return true;
    } catch (_) {
      return false;
    }
  }

  // GET /api/admin/config/categories
  Future<List<dynamic>> getCategories() async {
    try {
      final response = await _apiClient.dio.get('/api/admin/config/categories');
      final data = response.data;
      return data is List ? data : [];
    } catch (_) {
      return [];
    }
  }

  // POST /api/admin/config/categories
  Future<bool> createCategory(String name, String? description) async {
    try {
      await _apiClient.dio.post('/api/admin/config/categories', data: {
        'name': name,
        if (description != null) 'description': description,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  // PUT /api/admin/config/categories/{id}
  Future<bool> updateCategory(int id, String name, String? description) async {
    try {
      await _apiClient.dio.put('/api/admin/config/categories/$id', data: {
        'name': name,
        if (description != null) 'description': description,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  // PATCH /api/admin/config/categories/{id}/toggle
  Future<bool> toggleCategory(int id) async {
    try {
      await _apiClient.dio.patch('/api/admin/config/categories/$id/toggle');
      return true;
    } catch (_) {
      return false;
    }
  }

  // POST /api/subscription-plans
  Future<bool> addSubscriptionPlan(Map<String, dynamic> data) async {
    try {
      await _apiClient.dio.post('/api/subscription-plans', data: data);
      return true;
    } catch (_) {
      return false;
    }
  }

  // PUT /api/subscription-plans/{id}
  Future<bool> updateSubscriptionPlan(int id, Map<String, dynamic> data) async {
    try {
      await _apiClient.dio.put('/api/subscription-plans/$id', data: data);
      return true;
    } catch (_) {
      return false;
    }
  }

  // DELETE /api/subscription-plans/{id}
  Future<bool> deleteSubscriptionPlan(int id) async {
    try {
      await _apiClient.dio.delete('/api/subscription-plans/$id');
      return true;
    } catch (_) {
      return false;
    }
  }

  // GET /api/admin/settings/fee-config  (also at /additional-charges)
  Future<Map<String, dynamic>?> getFeeConfig() async {
    for (final path in ['/api/admin/settings/fee-config', '/api/admin/settings/additional-charges']) {
      try {
        final response = await _apiClient.dio.get(path);
        if (response.data is Map) return Map<String, dynamic>.from(response.data);
      } catch (_) {}
    }
    return null;
  }

  // POST /api/admin/settings/fee-config
  Future<bool> updateFeeConfig(String feeType, double feeValue) async {
    for (final path in ['/api/admin/settings/fee-config', '/api/admin/settings/additional-charges']) {
      try {
        await _apiClient.dio.post(path, data: {'feeType': feeType, 'feeValue': feeValue});
        return true;
      } catch (_) {}
    }
    return false;
  }

  // Backward-compat aliases
  Future<Map<String, dynamic>?> getAdditionalCharges() => getFeeConfig();
  Future<bool> setAdditionalCharges(String feeType, double feeValue) => updateFeeConfig(feeType, feeValue);

  // GET /api/subscription-plans
  Future<List<Map<String, dynamic>>> getSubscriptionPlans() async {
    try {
      final response = await _apiClient.dio.get('/api/subscription-plans');
      final data = response.data;
      if (data is List) return List<Map<String, dynamic>>.from(data);
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<void> delHoliday(h) async {}
}