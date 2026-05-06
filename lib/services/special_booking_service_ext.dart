// lib/services/special_booking_service_ext.dart
import 'package:dio/dio.dart';
import 'package:finadvise/api_client.dart';
import '../models/all_models.dart';
class SpecialBookingServiceExtended {
  final ApiClient _apiClient = ApiClient();
  Future<SpecialBookingModel?> createSpecialBooking(SpecialBookingModel booking) async {
    try {
      final response = await _apiClient.dio.post('/api/special-bookings', data: booking.toJson());
      return SpecialBookingModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) { return null; }
  }
  Future<List<SpecialBookingModel>> getAllSpecialBookings() async {
    try {
      final response = await _apiClient.dio.get('/api/special-bookings');
      final list = response.data is List ? response.data : response.data['content'] ?? [];
      return (list as List).map((b) => SpecialBookingModel.fromJson(b as Map<String, dynamic>)).toList();
    } catch (e) { return []; }
  }
  Future<SpecialBookingModel?> getSpecialBookingById(int id) async {
    try {
      final response = await _apiClient.dio.get('/api/special-bookings/$id');
      return SpecialBookingModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) { return null; }
  }
  Future<bool> updateSpecialBooking(int id, SpecialBookingModel booking) async {
    try {
      await _apiClient.dio.put('/api/special-bookings/$id', data: booking.toJson());
      return true;
    } catch (e) { return false; }
  }
  Future<bool> cancelSpecialBooking(int id) async {
    try {
      await _apiClient.dio.put('/api/special-bookings/$id/cancel');
      return true;
    } catch (e) { return false; }
  }
  Future<List<SpecialBookingModel>> getUserSpecialBookings(int userId) async {
    try {
      final response = await _apiClient.dio.get('/api/special-bookings/user/$userId');
      final list = response.data is List ? response.data : [];
      return (list as List).map((b) => SpecialBookingModel.fromJson(b as Map<String, dynamic>)).toList();
    } catch (e) { return []; }
  }
}
