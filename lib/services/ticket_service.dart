import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:finadvise/api_client.dart';

import '../models/models.dart';

List<dynamic> _extractArray(dynamic data,
    {List<String> keys = const ['content', 'data', 'items']}) {
  if (data is List) return data;
  if (data is Map) {
    for (final key in keys) {
      final candidate = data[key];
      if (candidate is List) return candidate;
    }
  }
  return const [];
}

int? _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}');
}

class TicketService {
  final ApiClient _apiClient = ApiClient();

  Future<int?> _resolveCategoryId(String categoryName) async {
    final normalized = categoryName.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    try {
      final response = await _apiClient.dio.get('/api/admin/config/categories');
      final list = _extractArray(
        response.data,
        keys: const ['content', 'data', 'items', 'categories'],
      );

      int? firstActiveId;
      for (final raw in list.whereType<Map>()) {
        final item = Map<String, dynamic>.from(raw);
        final id =
            _toInt(item['id'] ?? item['categoryId'] ?? item['category_id']);
        final name =
            (item['name'] ?? item['categoryName'] ?? item['category'] ?? '')
                .toString()
                .trim()
                .toLowerCase();
        final isActive = item['isActive'] ?? item['active'] ?? true;
        if (id != null && isActive != false && firstActiveId == null) {
          firstActiveId = id;
        }
        if (id != null && isActive != false && name == normalized) {
          return id;
        }
      }
      return firstActiveId;
    } catch (_) {
      return null;
    }
  }

  Future<List<Ticket>> getAllTickets({
    int page = 0,
    int size = 10,
    String sortBy = 'createdAt',
    bool useAnalytics = false,
  }) async {
    final requests = [
      if (useAnalytics)
        (
          path: '/api/analytics/tickets/all',
          query: <String, dynamic>{},
        ),
      (
        path: '/api/tickets',
        query: <String, dynamic>{'page': page, 'size': size, 'sortBy': sortBy},
      ),
    ];

    for (final request in requests) {
      try {
        final response = await _apiClient.dio.get(
          request.path,
          queryParameters: request.query,
        );
        final list = _extractArray(response.data,
            keys: const ['content', 'data', 'items', 'tickets']);
        return list
            .whereType<Map>()
            .map((e) => Ticket.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } catch (_) {
        // Try the next compatible endpoint.
      }
    }

    return [];
  }

  Future<Ticket?> getTicketById(int ticketId) async {
    try {
      final response = await _apiClient.dio.get('/api/tickets/$ticketId');
      return Ticket.fromJson(response.data);
    } catch (_) {
      return null;
    }
  }

  Future<List<Ticket>> getTicketsByUser(
    int userId, {
    int page = 0,
    int size = 10,
    String sortBy = 'createdAt',
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/tickets/user/$userId',
        queryParameters: {'page': page, 'size': size, 'sortBy': sortBy},
      );
      final list = _extractArray(response.data,
          keys: const ['content', 'data', 'items', 'tickets']);
      return list
          .whereType<Map>()
          .map((e) => Ticket.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Ticket>> getTicketsByConsultant(
    int consultantId, {
    int page = 0,
    int size = 10,
    String sortBy = 'createdAt',
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/tickets/consultant/$consultantId',
        queryParameters: {'page': page, 'size': size, 'sortBy': sortBy},
      );
      final list = _extractArray(response.data,
          keys: const ['content', 'data', 'items', 'tickets']);
      return list
          .whereType<Map>()
          .map((e) => Ticket.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Ticket>> getSlaBreachedTickets() async {
    try {
      final response = await _apiClient.dio.get('/api/tickets/sla-breached');
      final list = _extractArray(response.data,
          keys: const ['content', 'data', 'items', 'tickets']);
      return list
          .whereType<Map>()
          .map((e) => Ticket.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Ticket>> getEscalatedTickets() async {
    try {
      final response = await _apiClient.dio.get('/api/tickets/escalated');
      final list = _extractArray(response.data,
          keys: const ['content', 'data', 'items', 'tickets']);
      return list
          .whereType<Map>()
          .map((e) => Ticket.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<String>> getUniqueCategories() async {
    try {
      final categoriesResponse =
          await _apiClient.dio.get('/api/admin/config/categories');
      final categories = _extractArray(
        categoriesResponse.data,
        keys: const ['content', 'data', 'items', 'categories'],
      );
      final mapped = categories
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((e) => (e['isActive'] ?? e['active'] ?? true) != false)
          .map((e) => (e['name'] ?? e['category'] ?? '').toString().trim())
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();
      if (mapped.isNotEmpty) return mapped;
    } catch (_) {}

    try {
      final response =
          await _apiClient.dio.get('/api/tickets/unique-categories');
      final list = _extractArray(response.data,
          keys: const ['content', 'data', 'items', 'categories']);
      return list
          .map((e) {
            if (e is String) return e.trim();
            if (e is Map) {
              return (e['name'] ?? e['category'] ?? '').toString().trim();
            }
            return e.toString().trim();
          })
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<TicketComment>> getTicketComments(int ticketId) async {
    try {
      final response =
          await _apiClient.dio.get('/api/tickets/$ticketId/comments');
      final list = _extractArray(response.data,
          keys: const ['content', 'data', 'items', 'comments']);
      return list
          .whereType<Map>()
          .map((e) => TicketComment.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<Ticket?> createTicket({
    required int userId,
    required String category,
    required String description,
    String priority = 'MEDIUM',
    int? consultantId,
    MultipartFile? attachment,
  }) async {
    final resolvedCategory = category.trim();
    String normalizeText(String value) =>
        value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
    final normalizedDescription = normalizeText(description);
    final normalizedPriority = priority.trim().toUpperCase();
    final requestStartedAt = DateTime.now();
    final categoryId = await _resolveCategoryId(resolvedCategory);

    bool isRecoverableCreationError(Object error) {
      if (error is DioException) {
        if (error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.sendTimeout ||
            error.type == DioExceptionType.receiveTimeout) {
          return true;
        }
        final code = error.response?.statusCode;
        if (code == 502 || code == 503 || code == 504) {
          return true;
        }
        final msg = (error.message ?? '').toLowerCase();
        if (msg.contains('timed out') || msg.contains('timeout')) {
          return true;
        }
      }
      return false;
    }

    Ticket? findRecoveredTicket(List<Ticket> tickets) {
      final candidates = tickets.where((ticket) {
        if (ticket.userId != null && ticket.userId != userId) return false;
        if (normalizeText(ticket.description ?? '') != normalizedDescription) {
          return false;
        }

        final ticketCategory = ticket.category.trim().toLowerCase();
        if (resolvedCategory.isNotEmpty &&
            ticketCategory.isNotEmpty &&
            ticketCategory != resolvedCategory.toLowerCase()) {
          return false;
        }

        if (ticket.priority.trim().toUpperCase() != normalizedPriority) {
          return false;
        }

        final createdAt = DateTime.tryParse(ticket.createdAt ?? '');
        if (createdAt == null) return true;
        return createdAt.toLocal().isAfter(
            requestStartedAt.toLocal().subtract(const Duration(minutes: 1)));
      }).toList();

      if (candidates.isEmpty) return null;
      candidates.sort((a, b) {
        final bTime = DateTime.tryParse(b.createdAt ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final aTime = DateTime.tryParse(a.createdAt ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      return candidates.first;
    }

    Future<Ticket?> recoverCreatedTicket() async {
      final deadline = DateTime.now().add(const Duration(seconds: 25));
      while (DateTime.now().isBefore(deadline)) {
        try {
          final latest = await getTicketsByUser(
            userId,
            page: 0,
            size: 100,
            sortBy: 'createdAt',
          );
          final recovered = findRecoveredTicket(latest);
          if (recovered != null) return recovered;
        } catch (_) {
          // Ignore transient read failures while polling recovery.
        }
        await Future<void>.delayed(const Duration(seconds: 3));
      }
      return null;
    }

    try {
      final ticketData = <String, dynamic>{
        'userId': userId,
        'category': resolvedCategory,
        if (categoryId != null) 'categoryId': categoryId,
        'description': description.trim(),
        'priority': normalizedPriority,
        'status': 'NEW',
        if (consultantId != null) 'consultantId': consultantId,
      };
      final formData = FormData.fromMap({
        'ticketData': MultipartFile.fromString(
          jsonEncode(ticketData),
          filename: 'ticket-data.json',
          contentType: DioMediaType.parse('application/json'),
        ),
        if (attachment != null) 'file': attachment,
      });
      final response = await _apiClient.dio.post(
        '/api/tickets',
        data: formData,
        options: Options(
          sendTimeout: const Duration(seconds: 45),
          receiveTimeout: const Duration(seconds: 45),
        ),
      );
      final raw = response.data;
      if (raw is Map) {
        return Ticket.fromJson(Map<String, dynamic>.from(raw));
      }
      return null;
    } catch (error) {
      if (isRecoverableCreationError(error)) {
        final recovered = await recoverCreatedTicket();
        if (recovered != null) return recovered;
      }
      try {
        final fallbackBody = <String, dynamic>{
          'userId': userId,
          'category': resolvedCategory,
          if (categoryId != null) 'categoryId': categoryId,
          'description': description.trim(),
          'priority': normalizedPriority,
          'status': 'NEW',
          if (consultantId != null) 'consultantId': consultantId,
        };
        final response = await _apiClient.dio.post(
          '/api/tickets',
          data: fallbackBody,
          options: Options(
            sendTimeout: const Duration(seconds: 45),
            receiveTimeout: const Duration(seconds: 45),
          ),
        );
        final raw = response.data;
        if (raw is Map) {
          return Ticket.fromJson(Map<String, dynamic>.from(raw));
        }
        return null;
      } catch (fallbackError) {
        if (isRecoverableCreationError(fallbackError)) {
          final recovered = await recoverCreatedTicket();
          if (recovered != null) return recovered;
        }
        return null;
      }
    }
  }

  Future<bool> updateTicketStatus(int ticketId, String status) async {
    try {
      await _apiClient.dio.patch(
        '/api/tickets/$ticketId/status',
        queryParameters: {'status': status},
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateTicketPriority(int ticketId, String priority) async {
    try {
      // Preferred contract in web app: query param based priority patch.
      await _apiClient.dio.patch(
        '/api/tickets/$ticketId/priority',
        queryParameters: {'priority': priority},
      );
      return true;
    } catch (_) {
      try {
        // Fallback for deployments expecting JSON body payload.
        await _apiClient.dio.patch(
          '/api/tickets/$ticketId/priority',
          data: {'priority': priority},
        );
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  Future<bool> assignTicket(int ticketId, int consultantId) async {
    try {
      await _apiClient.dio.put(
        '/api/tickets/$ticketId/assign',
        data: {'consultantId': consultantId},
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> escalateTicket(int ticketId, String reason) async {
    try {
      await _apiClient.dio.post(
        '/api/tickets/$ticketId/escalate',
        data: {'reason': reason},
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteTicket(int ticketId) async {
    try {
      await _apiClient.dio.delete('/api/tickets/$ticketId');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<TicketComment?> addComment(
    int ticketId,
    String message, {
    required int senderId,
    bool isConsultantReply = false,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/tickets/comments',
        data: {
          'ticketId': ticketId,
          'senderId': senderId,
          'message': message,
          'isConsultantReply': isConsultantReply,
        },
      );
      return TicketComment.fromJson(response.data);
    } catch (_) {
      return null;
    }
  }

  Future<List<TicketNote>> getNotes(int ticketId) async {
    try {
      final response = await _apiClient.dio.get('/api/tickets/$ticketId/notes');
      final list = _extractArray(response.data,
          keys: const ['content', 'data', 'items', 'notes']);
      return list
          .whereType<Map>()
          .map((e) => TicketNote.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<TicketNote?> addNote(
    int ticketId, {
    required int authorId,
    required String noteText,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/tickets/$ticketId/notes',
        data: {'authorId': authorId, 'noteText': noteText},
      );
      return TicketNote.fromJson(response.data);
    } catch (_) {
      return null;
    }
  }

  Future<bool> submitTicketFeedback(
      int ticketId, Map<String, dynamic> data) async {
    try {
      await _apiClient.dio.post('/api/tickets/$ticketId/feedback', data: data);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<CannedResponse>> getCannedResponses({String? category}) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/admin/config/canned-responses',
        queryParameters: {if (category != null) 'category': category},
      );
      final list = _extractArray(response.data,
          keys: const ['content', 'data', 'items', 'responses']);
      return list
          .whereType<Map>()
          .map((e) => CannedResponse.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
