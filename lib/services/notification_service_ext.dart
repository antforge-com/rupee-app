// lib/services/notification_service_ext.dart
import 'package:dio/dio.dart';
import 'package:finadvise/api_client.dart';
import '../models/all_models.dart';
class NotificationServiceExtended {
  final ApiClient _apiClient = ApiClient();
  Future<List<NotificationModel>> getNotifications(int userId) async {
    try {
      final response = await _apiClient.dio.get('/api/notifications/user/$userId');
      final list = response.data is List ? response.data : response.data['content'] ?? [];
      return (list as List).map((n) => NotificationModel.fromJson(n as Map<String, dynamic>)).toList();
    } catch (e) { return []; }
  }
  Future<List<NotificationModel>> getUnreadNotifications(int userId) async {
    try {
      final response = await _apiClient.dio.get('/api/notifications/user/$userId/unread');
      final list = response.data is List ? response.data : [];
      return (list as List).map((n) => NotificationModel.fromJson(n as Map<String, dynamic>)).toList();
    } catch (e) { return []; }
  }
  Future<bool> markAsRead(int notificationId) async {
    try {
      await _apiClient.dio.put('/api/notifications/$notificationId/read');
      return true;
    } catch (e) { return false; }
  }
  Future<bool> markAllAsRead(int userId) async {
    try {
      await _apiClient.dio.put('/api/notifications/user/$userId/read-all');
      return true;
    } catch (e) { return false; }
  }
  Future<bool> deleteNotification(int notificationId) async {
    try {
      await _apiClient.dio.delete('/api/notifications/$notificationId');
      return true;
    } catch (e) { return false; }
  }
  Future<int> getUnreadCount(int userId) async {
    try {
      final response = await _apiClient.dio.get('/api/notifications/user/$userId/unread/count');
      return response.data['count'] ?? 0;
    } catch (e) { return 0; }
  }
}
