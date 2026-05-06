import 'package:finadvise/api_client.dart';

class AdminService {
  final ApiClient _apiClient = ApiClient();

  // Swagger API: GET /api/subscription-plans
  Future<List<dynamic>> getSubscriptionPlans() async {
    try {
      final response = await _apiClient.dio.get('/api/subscription-plans');
      // API से List of objects रिटर्न होगा
      return response.data as List<dynamic>;
    } catch (e) {
      print("Error fetching plans: $e");
      return []; // Error आने पर खाली लिस्ट भेजें ताकि UI क्रैश न हो
    }
  }
}