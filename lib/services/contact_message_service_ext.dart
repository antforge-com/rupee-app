// lib/services/contact_message_service_ext.dart
import 'package:dio/dio.dart';
import 'package:finadvise/api_client.dart';
import '../models/all_models.dart';
class ContactMessageServiceExtended {
  final ApiClient _apiClient = ApiClient();
  Future<ContactMessageModel?> submitContactMessage(ContactMessageModel msg) async {
    try {
      final response = await _apiClient.dio.post('/api/contact-messages', data: msg.toJson());
      return ContactMessageModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) { return null; }
  }
  Future<List<ContactMessageModel>> getAllMessages() async {
    try {
      final response = await _apiClient.dio.get('/api/contact-messages');
      final list = response.data is List ? response.data : response.data['content'] ?? [];
      return (list as List).map((m) => ContactMessageModel.fromJson(m as Map<String, dynamic>)).toList();
    } catch (e) { return []; }
  }
  Future<ContactMessageModel?> getMessageById(int id) async {
    try {
      final response = await _apiClient.dio.get('/api/contact-messages/$id');
      return ContactMessageModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) { return null; }
  }
  Future<bool> markAsResolved(int id) async {
    try {
      await _apiClient.dio.put('/api/contact-messages/$id/resolve');
      return true;
    } catch (e) { return false; }
  }
  Future<bool> deleteMessage(int id) async {
    try {
      await _apiClient.dio.delete('/api/contact-messages/$id');
      return true;
    } catch (e) { return false; }
  }
}
