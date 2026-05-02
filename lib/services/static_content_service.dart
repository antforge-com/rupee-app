// lib/core/services/static_content_service.dart
// ════════════════════════════════════════════════════════════════════════════
// Static Content Service — Manage T\u0026C, Privacy Policy, and Contact messages
// ════════════════════════════════════════════════════════════════════════════

import 'package:finadvise/api_client.dart';

class StaticContentService {
  final ApiClient _apiClient = ApiClient();

  /// GET /api/static-content/{type} — Load T\u0026C or Privacy Policy
  /// type: TERMS_AND_CONDITIONS | PRIVACY_POLICY
  Future<String> getContent(String type) async {
    try {
      final response = await _apiClient.dio.get('/api/static-content/$type');
      if (response.data is Map) {
        return response.data['content'] ?? response.data['text'] ?? '';
      }
      return response.data.toString();
    } catch (_) {
      return '';
    }
  }

  /// POST /api/static-content — Save static content (Admin)
  Future<bool> saveContent(Map<String, dynamic> data) async {
    try {
      await _apiClient.dio.post('/api/static-content', data: data);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// GET /api/static-content — Fetch all static pages
  Future<List<Map<String, dynamic>>> getAllContent() async {
    try {
      final response = await _apiClient.dio.get('/api/static-content');
      final data = response.data;
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }
  /// POST /api/contact/public/submit — Submit contact form (Public)
  Future<bool> submitContactMessage({
    required String name,
    required String email,
    required String message,
    String? phone,
    String? subject,
  }) async {
    try {
      await _apiClient.dio.post('/api/contact/public/submit', data: {
        'name': name,
        'email': email,
        'message': message,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (subject != null && subject.isNotEmpty) 'subject': subject,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// GET /api/contact/admin/messages — Fetch all contact submissions (Admin)
  Future<Map<String, dynamic>> getContactMessages({int page = 0, int size = 20}) async {
    try {
      final response = await _apiClient.dio.get('/api/contact/admin/messages', queryParameters: {'page': page, 'size': size});
      if (response.data is Map) return Map<String, dynamic>.from(response.data);
      if (response.data is List) return {'content': response.data};
      return {'content': []};
    } catch (_) {
      return {'content': []};
    }
  }

  /// PATCH /api/contact/admin/messages/{id}/read — Mark message as read
  Future<bool> markAsRead(int id) async {
    try {
      await _apiClient.dio.patch('/api/contact/admin/messages/$id/read');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Backend currently does not expose a delete-contact-message endpoint.
  Future<bool> deleteMessage(int id) async {
    return false;
  }

  /// Backend currently does not expose a clear-all-contact-messages endpoint.
  Future<bool> clearAllMessages() async {
    return false;
  }

  /// GET /api/terms/versions — Fetch all terms & conditions versions
  Future<List<Map<String, dynamic>>> getTermsVersions() async {
    try {
      final response = await _apiClient.dio.get('/api/static-content');
      final rows = response.data is List ? response.data as List : const [];
      return rows
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((e) =>
              (e['contentType'] ?? '').toString().toUpperCase() ==
              'TERMS_AND_CONDITIONS')
          .map((e) => {
                'id': e['contentId'] ?? e['id'] ?? 0,
                'version': e['version'] ?? '1.0',
                'content': e['content'] ?? '',
                'updatedAt': e['lastUpdatedDate'] ?? e['updatedAt'],
                'updatedBy': e['lastUpdatedBy'] ?? e['updatedBy'] ?? 'Admin',
                'isActive': true,
              })
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// POST /api/terms/publish — Publish a new terms & conditions version
  Future<bool> publishTerms({
    required String content,
    String? version,
  }) async {
    try {
      await _apiClient.dio.post('/api/static-content', data: {
        'contentType': 'TERMS_AND_CONDITIONS',
        'content': content,
        'lastUpdatedBy':
            version != null && version.isNotEmpty ? 'Admin v$version' : 'Admin',
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}
