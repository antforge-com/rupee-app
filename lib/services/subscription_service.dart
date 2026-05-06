// lib/core/services/subscription_service.dart
// ════════════════════════════════════════════════════════════════════════════
// Matches RegisterPage.tsx plan-fetching logic:
//   GET /api/subscription-plans         (public)
//   GET /api/subscription-plans/all     (fallback)
//   GET /api/subscription-plans/{id}
//   POST /api/subscription-plans        (admin)
//   PUT  /api/subscription-plans/{id}   (admin)
//   DELETE /api/subscription-plans/{id} (admin)
// ════════════════════════════════════════════════════════════════════════════

import 'package:finadvise/api_client.dart';

class SubscriptionService {
  final ApiClient _apiClient = ApiClient();

  /// Fetches subscription plans — tries /subscription-plans first,
  /// falls back to /subscription-plans/all (matches RegisterPage.tsx exactly)
  Future<List<Map<String, dynamic>>> getSubscriptionPlans() async {
    const endpoints = ['/api/subscription-plans', '/api/subscription-plans/all'];
    for (final endpoint in endpoints) {
      try {
        final response = await _apiClient.dio.get(endpoint);
        final extracted = _extract(response.data);
        if (extracted.isNotEmpty) return extracted;
      } catch (_) {}
    }
    return [];
  }

  /// GET /api/subscription-plans/all (admin — requires token)
  Future<List<Map<String, dynamic>>> getAllPlansAdmin() async {
    try {
      final response = await _apiClient.dio.get('/api/subscription-plans/all');
      return _extract(response.data);
    } catch (_) {
      return [];
    }
  }

  /// GET /api/subscription-plans/{id}
  Future<Map<String, dynamic>?> getPlanById(int id) async {
    try {
      final response = await _apiClient.dio.get('/api/subscription-plans/$id');
      return response.data as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// POST /api/subscription-plans (admin)
  Future<bool> createPlan({
    required String name,
    required double originalPrice,
    required double discountPrice,
    String features = '',
    String tag = '',
  }) async {
    try {
      await _apiClient.dio.post('/api/subscription-plans', data: {
        'name': name,
        'originalPrice': originalPrice,
        'discountPrice': discountPrice,
        'features': features,
        'tag': tag,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// PUT /api/subscription-plans/{id} (admin)
  Future<bool> updatePlan(int id, Map<String, dynamic> data) async {
    try {
      await _apiClient.dio.put('/api/subscription-plans/$id', data: data);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// DELETE /api/subscription-plans/{id} (admin)
  Future<bool> deletePlan(int id) async {
    try {
      await _apiClient.dio.delete('/api/subscription-plans/$id');
      return true;
    } catch (_) {
      return false;
    }
  }

  List<Map<String, dynamic>> _extract(dynamic data) {
    if (data == null) return [];
    if (data is List) {
      return data.whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (data is Map) {
      for (final key in ['content', 'plans', 'subscriptionPlans', 'data', 'items', 'results', 'list']) {
        if (data[key] is List) {
          return (data[key] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    }
    return [];
  }

  /// Alias — some screens call getPlans() instead of getSubscriptionPlans()
  Future<List<Map<String, dynamic>>> getPlans() => getSubscriptionPlans();
}