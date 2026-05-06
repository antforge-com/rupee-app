// lib/core/services/offer_service.dart
// ════════════════════════════════════════════════════════════════════════════
// Offer Service — Manage discounts and seasonal offers
// ════════════════════════════════════════════════════════════════════════════

import 'package:finadvise/api_client.dart';

class OfferService {
  final ApiClient _apiClient = ApiClient();

  /// GET /api/offers/public — Active offers for users/homepage
  Future<List<Map<String, dynamic>>> getActiveOffers() async {
    for (final path in const ['/api/offers/public', '/api/offers']) {
      try {
        final response = await _apiClient.dio.get(path);
        final rows = _extract(response.data);
        if (rows.isNotEmpty || response.statusCode == 200) return rows;
      } catch (_) {}
    }
    return [];
  }

  /// GET /api/offers/checkout — Offers applicable for a specific consultant
  Future<List<Map<String, dynamic>>> getCheckoutOffers(int consultantId) async {
    try {
      final response = await _apiClient.dio.get('/api/offers/checkout', queryParameters: {'consultantId': consultantId});
      return _extract(response.data);
    } catch (_) {
      return [];
    }
  }

  /// GET /api/offers/my-offers — Offers created by the logged-in consultant
  Future<List<Map<String, dynamic>>> getMyOffers() async {
    try {
      final response = await _apiClient.dio.get('/api/offers/my-offers');
      return _extract(response.data);
    } catch (_) {
      return [];
    }
  }

  /// GET /api/offers/admin — All offers including pending/inactive (Admin)
  Future<List<Map<String, dynamic>>> getAllOffersAdmin() async {
    try {
      final response = await _apiClient.dio.get('/api/offers/admin');
      return _extract(response.data);
    } catch (_) {
      return [];
    }
  }

  /// POST /api/offers — Create new offer (Admin)
  Future<bool> createOffer(Map<String, dynamic> data) async {
    try {
      await _apiClient.dio.post('/api/offers', data: data);
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('createOffer failed: $e');
      return false;
    }
  }

  /// PUT /api/offers/{id} — Update offer (Admin)
  Future<bool> updateOffer(int id, Map<String, dynamic> data) async {
    try {
      await _apiClient.dio.put('/api/offers/$id', data: data);
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('updateOffer failed: $e');
      return false;
    }
  }

  /// DELETE /api/offers/{id} — Delete offer (Admin)
  Future<bool> deleteOffer(int id) async {
    try {
      await _apiClient.dio.delete('/api/offers/$id');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// PUT /api/offers/{id}/status?status=APPROVED — Update status (Admin)
  Future<bool> updateStatus(int id, String status) async {
    try {
      await _apiClient.dio.put('/api/offers/$id/status', queryParameters: {'status': status});
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Approve offer (Admin) — convenience alias
  Future<bool> approveOffer(int id) => updateStatus(id, 'APPROVED');

  /// Reject offer (Admin) — convenience alias
  Future<bool> rejectOffer(int id) => updateStatus(id, 'REJECTED');

  List<Map<String, dynamic>> _extract(dynamic data) {
    if (data is List) return data.map((e) => Map<String, dynamic>.from(e)).toList();
    if (data is Map && data['content'] is List) {
      return (data['content'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }
}
