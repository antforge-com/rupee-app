// lib/services/subscription_service_ext.dart
import 'package:dio/dio.dart';
import 'package:finadvise/api_client.dart';
import '../models/all_models.dart';
class SubscriptionServiceExtended {
  final ApiClient _apiClient = ApiClient();
  Future<List<SubscriptionPlanModel>> getAllPlans() async {
    try {
      final response = await _apiClient.dio.get('/api/subscription-plans');
      final list = response.data is List ? response.data : response.data['content'] ?? [];
      return (list as List).map((p) => SubscriptionPlanModel.fromJson(p as Map<String, dynamic>)).toList();
    } catch (e) { return []; }
  }
  Future<SubscriptionPlanModel?> createPlan(SubscriptionPlanModel plan) async {
    try {
      final response = await _apiClient.dio.post('/api/subscription-plans', data: plan.toJson());
      return SubscriptionPlanModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) { return null; }
  }
  Future<SubscriptionPlanModel?> getPlanById(int id) async {
    try {
      final response = await _apiClient.dio.get('/api/subscription-plans/$id');
      return SubscriptionPlanModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) { return null; }
  }
  Future<bool> updatePlan(int id, SubscriptionPlanModel plan) async {
    try {
      await _apiClient.dio.put('/api/subscription-plans/$id', data: plan.toJson());
      return true;
    } catch (e) { return false; }
  }
  Future<bool> deletePlan(int id) async {
    try {
      await _apiClient.dio.delete('/api/subscription-plans/$id');
      return true;
    } catch (e) { return false; }
  }
}
