// lib/core/services/ticket_service.dart
// ════════════════════════════════════════════════════════════════════════════
// Swagger spec ke exact endpoints:
//   GET  /api/tickets              (paginated, ?sortBy)
//   GET  /api/tickets/{id}
//   GET  /api/tickets/user/{userId}
//   GET  /api/tickets/consultant/{consultantId}
//   GET  /api/tickets/sla-breached
//   GET  /api/tickets/escalated
//   GET  /api/tickets/unique-categories
//   GET  /api/tickets/{ticketId}/comments
//   POST /api/tickets              (multipart: ticketData + file)
//   POST /api/tickets/{id}/escalate   body: { reason }
//   POST /api/tickets/{id}/notes      body: { authorId, noteText }  ← noteText nahi content
//   POST /api/tickets/comments        body: { ticketId, senderId, message, isConsultantReply }
//   POST /api/tickets/{id}/feedback   body: map
//   PATCH /api/tickets/{id}/status    ?status=  ← query param, body nahi!
//   PATCH /api/tickets/{id}/priority  body: { priority: string }
//   PUT   /api/tickets/{id}/assign    body: map (consultantId)
//   DELETE /api/tickets/{id}
//   GET  /api/admin/config/canned-responses
// ════════════════════════════════════════════════════════════════════════════

import 'package:dio/dio.dart';
import 'package:finadvise/api_client.dart';
import '../models/models.dart';

class TicketService {
  final ApiClient _apiClient = ApiClient();

  // ── READ ─────────────────────────────────────────────────────────────────

  /// GET /api/tickets — Sab tickets (paginated)
  /// Swagger mein status/priority query filter nahi hai — sirf page, size, sortBy
  Future<List<Ticket>> getAllTickets({
    int page = 0,
    int size = 10,
    String sortBy = 'createdAt',
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/tickets',
        queryParameters: {'page': page, 'size': size, 'sortBy': sortBy},
      );
      final data = response.data;
      final list = data is Map ? (data['content'] ?? data['data'] ?? []) : data;
      return (list as List).map((e) => Ticket.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// GET /api/tickets/{id}
  Future<Ticket?> getTicketById(int ticketId) async {
    try {
      final response = await _apiClient.dio.get('/api/tickets/$ticketId');
      return Ticket.fromJson(response.data);
    } catch (e) {
      return null;
    }
  }

  /// GET /api/tickets/user/{userId}
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
      final data = response.data;
      final list = data is Map ? (data['content'] ?? data['data'] ?? []) : data;
      return (list as List).map((e) => Ticket.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// GET /api/tickets/consultant/{consultantId}
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
      final data = response.data;
      final list = data is Map ? (data['content'] ?? data['data'] ?? []) : data;
      return (list as List).map((e) => Ticket.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// GET /api/tickets/sla-breached
  Future<List<Ticket>> getSlaBreachedTickets() async {
    try {
      final response = await _apiClient.dio.get('/api/tickets/sla-breached');
      final data = response.data;
      final list = data is Map ? (data['content'] ?? data['data'] ?? []) : data;
      return (list as List).map((e) => Ticket.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// GET /api/tickets/escalated
  Future<List<Ticket>> getEscalatedTickets() async {
    try {
      final response = await _apiClient.dio.get('/api/tickets/escalated');
      final data = response.data;
      final list = data is Map ? (data['content'] ?? data['data'] ?? []) : data;
      return (list as List).map((e) => Ticket.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// GET /api/tickets/unique-categories — Available categories ki list
  Future<List<String>> getUniqueCategories() async {
    try {
      final response = await _apiClient.dio.get('/api/tickets/unique-categories');
      return List<String>.from(response.data as List);
    } catch (e) {
      return [];
    }
  }

  /// GET /api/tickets/{ticketId}/comments — Ticket ka poora thread
  Future<List<TicketComment>> getTicketComments(int ticketId) async {
    try {
      final response = await _apiClient.dio.get('/api/tickets/$ticketId/comments');
      return (response.data as List).map((e) => TicketComment.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  // ── CREATE ────────────────────────────────────────────────────────────────

  /// POST /api/tickets — Naya ticket (multipart/form-data)
  /// Form field name: 'ticketData' (nahi 'data')
  /// TicketRequest required: userId, category, description
  /// Optional: consultantId, priority (LOW|MEDIUM|HIGH|URGENT|CRITICAL)
  Future<Ticket?> createTicket({
    required int userId,
    required String category,
    required String description,
    String priority = 'MEDIUM',
    int? consultantId,
    MultipartFile? attachment,
  }) async {
    try {
      final ticketData = <String, dynamic>{
        'userId': userId,
        'category': category,
        'description': description,
        'priority': priority,
        if (consultantId != null) 'consultantId': consultantId,
      };
      final formData = FormData.fromMap({
        'ticketData': ticketData,   // ← 'ticketData' field name (swagger spec)
        if (attachment != null) 'file': attachment,
      });
      final response = await _apiClient.dio.post(
        '/api/tickets',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      return Ticket.fromJson(response.data);
    } catch (e) {
      return null;
    }
  }

  // ── UPDATE ────────────────────────────────────────────────────────────────

  /// PATCH /api/tickets/{id}/status?status=NEW
  /// FIX: status query param hai, body mein nahi
  /// status values: NEW | OPEN | IN_PROGRESS | PENDING | RESOLVED | CLOSED
  Future<bool> updateTicketStatus(int ticketId, String status) async {
    try {
      await _apiClient.dio.patch(
        '/api/tickets/$ticketId/status',
        queryParameters: {'status': status},   // ← query param, body nahi
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// PATCH /api/tickets/{id}/priority — Priority update
  /// body: { "priority": "HIGH" }
  Future<bool> updateTicketPriority(int ticketId, String priority) async {
    try {
      await _apiClient.dio.patch(
        '/api/tickets/$ticketId/priority',
        data: {'priority': priority},
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// PUT /api/tickets/{id}/assign — Consultant assign karo
  Future<bool> assignTicket(int ticketId, int consultantId) async {
    try {
      await _apiClient.dio.put(
        '/api/tickets/$ticketId/assign',
        data: {'consultantId': consultantId},
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// POST /api/tickets/{id}/escalate — Escalate karo
  /// body: { reason } (required)
  Future<bool> escalateTicket(int ticketId, String reason) async {
    try {
      await _apiClient.dio.post(
        '/api/tickets/$ticketId/escalate',
        data: {'reason': reason},
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── DELETE ────────────────────────────────────────────────────────────────

  /// DELETE /api/tickets/{id}
  Future<bool> deleteTicket(int ticketId) async {
    try {
      await _apiClient.dio.delete('/api/tickets/$ticketId');
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── COMMENTS ─────────────────────────────────────────────────────────────

  /// POST /api/tickets/comments
  /// body: { ticketId, senderId, message, isConsultantReply } — sab required
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
    } catch (e) {
      return null;
    }
  }

  // ── NOTES (Internal) ─────────────────────────────────────────────────────

  /// GET /api/tickets/{id}/notes
  Future<List<TicketNote>> getNotes(int ticketId) async {
    try {
      final response = await _apiClient.dio.get('/api/tickets/$ticketId/notes');
      return (response.data as List).map((e) => TicketNote.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// POST /api/tickets/{id}/notes
  /// body: { authorId (required), noteText (required) }
  /// FIX: 'noteText' field hai, 'content' nahi
  Future<TicketNote?> addNote(int ticketId, {
    required int authorId,
    required String noteText,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/tickets/$ticketId/notes',
        data: {
          'authorId': authorId,
          'noteText': noteText,   // ← 'noteText' (swagger spec), 'content' nahi
        },
      );
      return TicketNote.fromJson(response.data);
    } catch (e) {
      return null;
    }
  }

  // ── FEEDBACK (ticket ke liye) ─────────────────────────────────────────────

  /// POST /api/tickets/{id}/feedback — Ticket specific feedback
  Future<bool> submitTicketFeedback(int ticketId, Map<String, dynamic> data) async {
    try {
      await _apiClient.dio.post('/api/tickets/$ticketId/feedback', data: data);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── CANNED RESPONSES ─────────────────────────────────────────────────────

  /// GET /api/admin/config/canned-responses?category=optional
  Future<List<CannedResponse>> getCannedResponses({String? category}) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/admin/config/canned-responses',
        queryParameters: {if (category != null) 'category': category},
      );
      return (response.data as List).map((e) => CannedResponse.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }
}
