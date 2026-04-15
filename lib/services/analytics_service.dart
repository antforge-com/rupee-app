// lib/core/services/analytics_service.dart
// ════════════════════════════════════════════════════════════════════════════
// Swagger spec ke ALL dashboard endpoints:
//   GET /api/dashboard/analytics?period=WEEKLY      ← resolution analytics
//   GET /api/dashboard/summaries?period=WEEKLY       ← graph data
//   GET /api/dashboard/ticket-volume?days=14
//   GET /api/dashboard/sla-breach?days=14
//   GET /api/dashboard/revenue?days=14
//   GET /api/dashboard/response-times?days=14
//   GET /api/dashboard/reports?days=14&groupBy=CATEGORY
//   GET /api/dashboard/customer-satisfaction?days=14
//   GET /api/dashboard/agent-performance?days=14
// ════════════════════════════════════════════════════════════════════════════

import 'package:finadvise/api_client.dart';
import '../models/models.dart';

class AnalyticsPeriod {
  static const String weekly = 'WEEKLY';
  static const String monthly = 'MONTHLY';
  static const String yearly = 'YEARLY';
}

class AnalyticsService {
  final ApiClient _apiClient = ApiClient();

  // ── PERIOD-BASED ──────────────────────────────────────────────────────────

  /// GET /api/dashboard/analytics?period=WEEKLY
  Future<Map<String, dynamic>?> getAnalytics({
    String period = AnalyticsPeriod.weekly,
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/dashboard/analytics',
        queryParameters: {'period': period},
      );
      return response.data is Map
          ? Map<String, dynamic>.from(response.data)
          : null;
    } catch (e) {
      return null;
    }
  }

  /// GET /api/dashboard/summaries?period=WEEKLY
  /// Returns: Map<String, List<{count, label}>>
  Future<Map<String, dynamic>?> getSummaries({
    String period = AnalyticsPeriod.weekly,
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/dashboard/summaries',
        queryParameters: {'period': period},
      );
      return response.data is Map
          ? Map<String, dynamic>.from(response.data)
          : null;
    } catch (e) {
      return null;
    }
  }

  // ── DAYS-BASED ────────────────────────────────────────────────────────────

  /// GET /api/dashboard/ticket-volume?days=14
  Future<Map<String, dynamic>?> getTicketVolume({int days = 14}) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/dashboard/ticket-volume',
        queryParameters: {'days': days},
      );
      return response.data is Map
          ? Map<String, dynamic>.from(response.data)
          : null;
    } catch (e) {
      return null;
    }
  }

  /// GET /api/dashboard/sla-breach?days=14
  Future<Map<String, dynamic>?> getSlaBreach({int days = 14}) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/dashboard/sla-breach',
        queryParameters: {'days': days},
      );
      return response.data is Map
          ? Map<String, dynamic>.from(response.data)
          : null;
    } catch (e) {
      return null;
    }
  }

  /// GET /api/dashboard/revenue?days=14
  Future<Map<String, dynamic>?> getRevenue({int days = 14}) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/dashboard/revenue',
        queryParameters: {'days': days},
      );
      return response.data is Map
          ? Map<String, dynamic>.from(response.data)
          : null;
    } catch (e) {
      return null;
    }
  }

  /// GET /api/dashboard/response-times?days=14
  Future<Map<String, dynamic>?> getResponseTimes({int days = 14}) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/dashboard/response-times',
        queryParameters: {'days': days},
      );
      return response.data is Map
          ? Map<String, dynamic>.from(response.data)
          : null;
    } catch (e) {
      return null;
    }
  }

  /// GET /api/dashboard/reports?days=14&groupBy=CATEGORY
  /// groupBy: CATEGORY | PRIORITY | STATUS | CONSULTANT (server-side values)
  Future<Map<String, dynamic>?> getReports({
    int days = 14,
    String groupBy = 'CATEGORY',
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/dashboard/reports',
        queryParameters: {'days': days, 'groupBy': groupBy},
      );
      return response.data is Map
          ? Map<String, dynamic>.from(response.data)
          : null;
    } catch (e) {
      return null;
    }
  }

  /// GET /api/dashboard/customer-satisfaction?days=14
  Future<Map<String, dynamic>?> getCustomerSatisfaction({int days = 14}) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/dashboard/customer-satisfaction',
        queryParameters: {'days': days},
      );
      return response.data is Map
          ? Map<String, dynamic>.from(response.data)
          : null;
    } catch (e) {
      return null;
    }
  }

  /// GET /api/dashboard/agent-performance?days=14
  Future<Map<String, dynamic>?> getAgentPerformance({int days = 14}) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/dashboard/agent-performance',
        queryParameters: {'days': days},
      );
      return response.data is Map
          ? Map<String, dynamic>.from(response.data)
          : null;
    } catch (e) {
      return null;
    }
  }

  // ── FULL DASHBOARD (parallel fetch) ──────────────────────────────────────

  /// Sab period-based data ek saath fetch karo
  Future<({Map<String, dynamic>? analytics, Map<String, dynamic>? summaries})>
      getFullDashboard({String period = AnalyticsPeriod.weekly}) async {
    final results = await Future.wait([
      getAnalytics(period: period),
      getSummaries(period: period),
    ]);
    return (
      analytics: results[0],
      summaries: results[1],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADMIN SERVICE
// ─────────────────────────────────────────────────────────────────────────────

class AdminService {
  final ApiClient _apiClient = ApiClient();

  // ── CATEGORIES ────────────────────────────────────────────────────────────

  Future<List<TicketCategory>> getCategories() async {
    try {
      final response = await _apiClient.dio.get('/api/admin/config/categories');
      return (response.data as List).map((e) => TicketCategory.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<TicketCategory?> createCategory({
    required String name,
    String? description,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/admin/config/categories',
        data: {
          'name': name,
          if (description != null) 'description': description,
        },
      );
      return TicketCategory.fromJson(response.data);
    } catch (e) {
      return null;
    }
  }

  Future<bool> toggleCategory(int categoryId) async {
    try {
      await _apiClient.dio.patch('/api/admin/config/categories/$categoryId/toggle');
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── CANNED RESPONSES ──────────────────────────────────────────────────────

  Future<List<CannedResponse>> getCannedResponses({String? category}) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/admin/config/canned-responses',
        queryParameters: {if (category != null) 'category': category},
      );
      return (response.data as List).map((e) => CannedResponse.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<CannedResponse?> createCannedResponse({
    required String title,
    required String content,
    String? category,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/admin/config/canned-responses',
        data: {
          'title': title,
          'content': content,
          if (category != null) 'category': category,
        },
      );
      return CannedResponse.fromJson(response.data);
    } catch (e) {
      return null;
    }
  }

  Future<bool> deleteCannedResponse(int id) async {
    try {
      await _apiClient.dio.delete('/api/admin/config/canned-responses/$id');
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── HOLIDAYS ──────────────────────────────────────────────────────────────

  Future<List<Holiday>> getHolidays() async {
    try {
      final response = await _apiClient.dio.get('/api/admin/settings/holidays');
      return (response.data as List).map((e) => Holiday.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// body: { holidayDate (date format), name }
  Future<Holiday?> addHoliday({
    required String name,
    required String holidayDate, // "YYYY-MM-DD"
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/admin/settings/holidays',
        data: {'name': name, 'holidayDate': holidayDate},
      );
      return Holiday.fromJson(response.data);
    } catch (e) {
      return null;
    }
  }

  Future<bool> deleteHoliday(int holidayId) async {
    try {
      await _apiClient.dio.delete('/api/admin/settings/holidays/$holidayId');
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── BUSINESS HOURS ────────────────────────────────────────────────────────

  Future<List<BusinessHours>> getBusinessHours() async {
    try {
      final response = await _apiClient.dio.get('/api/admin/settings/business-hours');
      return (response.data as List).map((e) => BusinessHours.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// POST /api/admin/settings/business-hours
  /// FIX: API array expect karta hai single object nahi
  /// BusinessHoursRequest: { dayOfWeek, startTime:{hour,minute,second,nano}, endTime, workingDay }
  Future<List<BusinessHours>> setBusinessHours(
    List<Map<String, dynamic>> hoursArray,
  ) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/admin/settings/business-hours',
        data: hoursArray,   // ← array directly
      );
      return (response.data as List).map((e) => BusinessHours.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  // ── AUTO RESPONDER ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getAutoResponder() async {
    try {
      final response = await _apiClient.dio.get('/api/admin/settings/auto-responder');
      return response.data is Map ? Map<String, dynamic>.from(response.data) : null;
    } catch (e) {
      return null;
    }
  }

  /// body: { enabled, message }
  Future<bool> setAutoResponder({
    required bool enabled,
    required String message,
  }) async {
    try {
      await _apiClient.dio.post(
        '/api/admin/settings/auto-responder',
        data: {'enabled': enabled, 'message': message},
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── ADDITIONAL CHARGES ────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getAdditionalCharges() async {
    try {
      final response = await _apiClient.dio.get(
        '/api/admin/settings/additional-charges',
      );
      return response.data is Map ? Map<String, dynamic>.from(response.data) : null;
    } catch (e) {
      return null;
    }
  }

  /// body: { feeType (required), feeValue (required) }
  Future<bool> setAdditionalCharges({
    required String feeType,
    required String feeValue,
  }) async {
    try {
      await _apiClient.dio.post(
        '/api/admin/settings/additional-charges',
        data: {'feeType': feeType, 'feeValue': feeValue},
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── SUBSCRIPTION PLANS ────────────────────────────────────────────────────

  Future<List<SubscriptionPlan>> getSubscriptionPlans() async {
    try {
      final response = await _apiClient.dio.get('/api/subscription-plans');
      return (response.data as List).map((e) => SubscriptionPlan.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// required: name, originalPrice, discountPrice
  Future<SubscriptionPlan?> createPlan({
    required String name,
    required double originalPrice,
    required double discountPrice,
    String? features,
    String? tag,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/subscription-plans',
        data: {
          'name': name,
          'originalPrice': originalPrice,
          'discountPrice': discountPrice,
          if (features != null) 'features': features,
          if (tag != null) 'tag': tag,
        },
      );
      return SubscriptionPlan.fromJson(response.data);
    } catch (e) {
      return null;
    }
  }

  Future<bool> updatePlan(int planId, Map<String, dynamic> data) async {
    try {
      await _apiClient.dio.put('/api/subscription-plans/$planId', data: data);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deletePlan(int planId) async {
    try {
      await _apiClient.dio.delete('/api/subscription-plans/$planId');
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── USERS (admin) ─────────────────────────────────────────────────────────

  /// GET /api/users — Swagger mein page/size query param nahi, array returns
  Future<List<UserModel>> getAllUsers() async {
    try {
      final response = await _apiClient.dio.get('/api/users');
      final data = response.data;
      final list = data is Map ? (data['content'] ?? data['data'] ?? []) : data;
      return (list as List).map((e) => UserModel.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// GET /api/users/role/{role}
  /// role: GUEST | MEMBER | SUBSCRIBER | CONSULTANT | ADMIN
  Future<List<UserModel>> getUsersByRole(String role) async {
    try {
      final response = await _apiClient.dio.get('/api/users/role/$role');
      final data = response.data;
      final list = data is Map ? (data['content'] ?? data['data'] ?? []) : data;
      return (list as List).map((e) => UserModel.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }
}
