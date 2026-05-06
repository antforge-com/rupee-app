// lib/services/email_to_ticket_service_ext.dart
import 'package:dio/dio.dart';
import 'package:finadvise/api_client.dart';
import '../models/all_models.dart';
class EmailToTicketServiceExtended {
  final ApiClient _apiClient = ApiClient();
  Future<List<EmailToTicketMappingModel>> getAllMappings() async {
    try {
      final response = await _apiClient.dio.get('/api/email-to-ticket-mappings');
      final list = response.data is List ? response.data : response.data['content'] ?? [];
      return (list as List).map((m) => EmailToTicketMappingModel.fromJson(m as Map<String, dynamic>)).toList();
    } catch (e) { return []; }
  }
  Future<EmailToTicketMappingModel?> createMapping(EmailToTicketMappingModel mapping) async {
    try {
      final response = await _apiClient.dio.post('/api/email-to-ticket-mappings', data: mapping.toJson());
      return EmailToTicketMappingModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) { return null; }
  }
  Future<EmailToTicketMappingModel?> getMappingById(int id) async {
    try {
      final response = await _apiClient.dio.get('/api/email-to-ticket-mappings/$id');
      return EmailToTicketMappingModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) { return null; }
  }
  Future<bool> updateMapping(int id, EmailToTicketMappingModel mapping) async {
    try {
      await _apiClient.dio.put('/api/email-to-ticket-mappings/$id', data: mapping.toJson());
      return true;
    } catch (e) { return false; }
  }
  Future<bool> deleteMapping(int id) async {
    try {
      await _apiClient.dio.delete('/api/email-to-ticket-mappings/$id');
      return true;
    } catch (e) { return false; }
  }
}
