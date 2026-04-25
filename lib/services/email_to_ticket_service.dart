import 'package:finadvise/api_client.dart';

class EmailToTicketService {
  final ApiClient _apiClient = ApiClient();

  /// GET /api/email-to-ticket/health
  Future<String?> getHealthStatus() async {
    try {
      final response = await _apiClient.dio.get('/api/email-to-ticket/health');
      return response.data?.toString();
    } catch (_) {
      return null;
    }
  }

  /// POST /api/email-to-ticket/poll
  Future<String?> triggerPolling() async {
    try {
      final response = await _apiClient.dio.post('/api/email-to-ticket/poll');
      return response.data?.toString();
    } catch (_) {
      return null;
    }
  }
}
