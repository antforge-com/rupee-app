import 'package:dio/dio.dart';
import 'package:finadvise/api_client.dart';


class ApiService {
  final ApiClient _apiClient = ApiClient();

  // --- TICKETS API ---
  Future<List<dynamic>> getAllTickets() async {
    try {
      final response = await _apiClient.dio.get('/api/tickets');
      return response.data as List<dynamic>;
    } catch (e) {
      print('Error fetching tickets: $e');
      return [];
    }
  }

  Future<List<dynamic>> getTicketsByConsultant(String consultantId) async {
    try {
      final response = await _apiClient.dio.get('/api/tickets/consultant/$consultantId');
      return response.data as List<dynamic>;
    } catch (e) {
      print('Error fetching consultant tickets: $e');
      return [];
    }
  }

  Future<bool> updateTicketStatus(int ticketId, String status) async {
    try {
      await _apiClient.dio.put('/api/tickets/$ticketId/status', data: {'status': status});
      return true;
    } catch (e) {
      print('Error updating ticket status: $e');
      return false;
    }
  }

  // --- ADVISORS API ---
  Future<List<dynamic>> getAllAdvisors() async {
    try {
      final response = await _apiClient.dio.get('/api/advisors');
      return response.data as List<dynamic>;
    } catch (e) {
      print('Error fetching advisors: $e');
      return [];
    }
  }

  // --- BOOKINGS API ---
  Future<List<dynamic>> getAllBookings() async {
    try {
      final response = await _apiClient.dio.get('/api/bookings');
      return response.data as List<dynamic>;
    } catch (e) {
      print('Error fetching bookings: $e');
      return [];
    }
  }
}