// lib/services/contact_message_service_ext.dart
import 'package:dio/dio.dart';
import 'package:finadvise/api_client.dart';
import '../models/all_models.dart';
class ContactMessageServiceExtended {
  final ApiClient _apiClient = ApiClient();
  Future<ContactMessageModel?> submitContactMessage(ContactMessageModel msg) async {
    try {
      await _apiClient.dio.post('/api/contact/public/submit', data: msg.toJson());
      return msg;
    } catch (e) { return null; }
  }
  Future<List<ContactMessageModel>> getAllMessages({int page = 0, int size = 20}) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/contact/admin/messages',
        queryParameters: {'page': page, 'size': size},
      );
      final list = response.data is List ? response.data : response.data['content'] ?? [];
      return (list as List).map((m) => ContactMessageModel.fromJson(m as Map<String, dynamic>)).toList();
    } catch (e) { return []; }
  }
  Future<ContactMessageModel?> getMessageById(int id) async {
    try {
      final messages = await getAllMessages(size: 200);
      for (final message in messages) {
        if (message.id == id) return message;
      }
      return null;
    } catch (e) { return null; }
  }
  Future<bool> markAsResolved(int id) async {
    try {
      await _apiClient.dio.patch('/api/contact/admin/messages/$id/read');
      return true;
    } catch (e) { return false; }
  }
  Future<bool> deleteMessage(int id) async {
    return false;
  }
}
