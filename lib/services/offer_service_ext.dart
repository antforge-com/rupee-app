// lib/services/offer_service_ext.dart
import 'package:dio/dio.dart';
import 'package:finadvise/api_client.dart';
import '../models/all_models.dart';
class OfferServiceExtended {
  final ApiClient _apiClient = ApiClient();
  Future<List<OfferModel>> getAllOffers() async {
    try { 
      final response = await _apiClient.dio.get('/api/offers');
      final list = response.data is List ? response.data : response.data['content'] ?? [];
      return (list as List).map((o) => OfferModel.fromJson(o as Map<String, dynamic>)).toList();
    } catch (e) { return []; }
  }
  Future<OfferModel?> createOffer(OfferModel offer) async {
    try {
      final response = await _apiClient.dio.post('/api/offers', data: offer.toJson());
      return OfferModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) { return null; }
  }
  Future<OfferModel?> getOfferById(int id) async {
    try {
      final response = await _apiClient.dio.get('/api/offers/$id');
      return OfferModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) { return null; }
  }
  Future<bool> updateOffer(int id, OfferModel offer) async {
    try {
      await _apiClient.dio.put('/api/offers/$id', data: offer.toJson());
      return true;
    } catch (e) { return false; }
  }
  Future<bool> deleteOffer(int id) async {
    try {
      await _apiClient.dio.delete('/api/offers/$id');
      return true;
    } catch (e) { return false; }
  }
  Future<List<OfferModel>> getActiveOffers() async {
    try {
      final response = await _apiClient.dio.get('/api/offers/active');
      final list = response.data is List ? response.data : [];
      return (list as List).map((o) => OfferModel.fromJson(o as Map<String, dynamic>)).toList();
    } catch (e) { return []; }
  }
}
