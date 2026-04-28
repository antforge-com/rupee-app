// lib/services/booking_service_ext.dart
import 'package:dio/dio.dart';
import 'package:finadvise/api_client.dart';
import '../models/all_models.dart';
class BookingServiceExtended {
  final ApiClient _apiClient = ApiClient();
  Future<BookingModel?> createBooking(BookingRequest request) async {
    try {
      final response = await _apiClient.dio.post('/api/bookings', data: request.toJson());
      return BookingModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      print('Error: ');
      return null;
    }
  }
  Future<List<BookingModel>> getAllBookings() async {
    try {
      final response = await _apiClient.dio.get('/api/bookings');
      final list = response.data is List ? response.data : response.data['content'] ?? [];
      return (list as List).map((b) => BookingModel.fromJson(b as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }
  Future<BookingModel?> getBookingById(int id) async {
    try {
      final response = await _apiClient.dio.get('/api/bookings/');
      return BookingModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }
  Future<bool> updateBooking(int id, BookingRequest request) async {
    try {
      await _apiClient.dio.put('/api/bookings/', data: request.toJson());
      return true;
    } catch (e) {
      return false;
    }
  }
  Future<bool> cancelBooking(int id) async {
    try {
      await _apiClient.dio.put('/api/bookings//cancel');
      return true;
    } catch (e) {
      return false;
    }
  }
  Future<List<BookingModel>> getUserBookings(int userId) async {
    try {
      final response = await _apiClient.dio.get('/api/bookings/user/');
      final list = response.data is List ? response.data : [];
      return (list as List).map((b) => BookingModel.fromJson(b as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }
  Future<List<BookingModel>> getConsultantBookings(int consultantId) async {
    try {
      final response = await _apiClient.dio.get('/api/bookings/consultant/');
      final list = response.data is List ? response.data : [];
      return (list as List).map((b) => BookingModel.fromJson(b as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }
}
