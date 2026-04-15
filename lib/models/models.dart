// lib/core/models/models.dart
// ════════════════════════════════════════════════════════════════════════════
// ALL MODELS — Swagger spec ke exact field names ke saath
// Base URL: http://52.55.178.31:8081
// ════════════════════════════════════════════════════════════════════════════

// ─── AUTH ─────────────────────────────────────────────────────────────────────

class AuthResult {
  final bool success;
  final String? role;
  final String? userId;
  final String? consultantId;
  final String? message;

  AuthResult({
    required this.success,
    this.role,
    this.userId,
    this.consultantId,
    this.message,
  });
}

// ─── USER ─────────────────────────────────────────────────────────────────────

class UserModel {
  final int id;
  final String name;
  final String email;
  final String role;
  final String? phone;
  final String? photoUrl;
  final String? identifier;
  final int? consultantId;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.photoUrl,
    this.identifier,
    this.consultantId,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] ?? 0,
        name: json['name'] ?? json['fullName'] ?? '',
        email: json['email'] ?? '',
        role: json['role'] ?? 'USER',
        phone: json['phone']?.toString() ?? json['phoneNumber']?.toString(),
        photoUrl: json['photoUrl'] ?? json['profilePicture'],
        identifier: json['identifier']?.toString(),
        consultantId: json['consultantId'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        if (phone != null) 'phone': phone,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (identifier != null) 'identifier': identifier,
        if (consultantId != null) 'consultantId': consultantId,
      };
}

// ─── CONSULTANT ───────────────────────────────────────────────────────────────
// API: GET/POST/PUT/DELETE /api/consultants

class ConsultantModel {
  final int id;
  final String name;
  final String email;
  final String? designation;     // API field: designation
  final String? description;
  final double? charges;         // API field: charges (not feePerSession)
  final double? rating;
  final int? reviewCount;
  final String? photoUrl;
  final Map<String, dynamic>? shiftStartTime;  // {hour, minute, second, nano}
  final Map<String, dynamic>? shiftEndTime;
  final List<String> skills;
  final bool isActive;

  ConsultantModel({
    required this.id,
    required this.name,
    required this.email,
    this.designation,
    this.description,
    this.charges,
    this.rating,
    this.reviewCount,
    this.photoUrl,
    this.shiftStartTime,
    this.shiftEndTime,
    this.skills = const [],
    this.isActive = true,
  });

  factory ConsultantModel.fromJson(Map<String, dynamic> json) => ConsultantModel(
        id: json['id'] ?? 0,
        name: json['name'] ?? json['fullName'] ?? '',
        email: json['email'] ?? '',
        designation: json['designation'] ?? json['title'],
        description: json['description'],
        charges: (json['charges'] ?? json['feePerSession'] ?? json['fee'] ?? 0).toDouble(),
        rating: (json['rating'] ?? 0).toDouble(),
        reviewCount: json['reviewCount'] ?? json['totalReviews'] ?? 0,
        photoUrl: json['photoUrl'] ?? json['profilePicture'],
        shiftStartTime: json['shiftStartTime'] is Map ? Map<String, dynamic>.from(json['shiftStartTime']) : null,
        shiftEndTime: json['shiftEndTime'] is Map ? Map<String, dynamic>.from(json['shiftEndTime']) : null,
        skills: (json['skills'] as List<dynamic>? ?? []).map((s) => s.toString()).toList(),
        isActive: json['isActive'] ?? json['active'] ?? true,
      );

  // Human readable shift time string: "9:00 AM - 6:00 PM"
  String get shiftDisplay {
    if (shiftStartTime == null || shiftEndTime == null) return '';
    final sh = shiftStartTime!['hour'] ?? 0;
    final sm = shiftStartTime!['minute'] ?? 0;
    final eh = shiftEndTime!['hour'] ?? 0;
    final em = shiftEndTime!['minute'] ?? 0;
    String fmt(int h, int m) {
      final period = h >= 12 ? 'PM' : 'AM';
      final displayH = h > 12 ? h - 12 : (h == 0 ? 12 : h);
      return '$displayH:${m.toString().padLeft(2, '0')} $period';
    }
    return '${fmt(sh, sm)} - ${fmt(eh, em)}';
  }
}

// ─── MASTER TIMESLOT ──────────────────────────────────────────────────────────
// API: GET /api/consultants/{id}/master-timeslots
//      POST /api/master-timeslots  body: { timeRange: "9:00 AM - 10:00 AM" }
//      DELETE /api/master-timeslots/{id}

class MasterTimeSlot {
  final int id;
  final String timeRange;   // e.g. "9:00 AM - 10:00 AM"
  final int? consultantId;

  MasterTimeSlot({
    required this.id,
    required this.timeRange,
    this.consultantId,
  });

  factory MasterTimeSlot.fromJson(Map<String, dynamic> json) => MasterTimeSlot(
        id: json['id'] ?? 0,
        timeRange: json['timeRange'] ?? '',
        consultantId: json['consultantId'],
      );
}

// ─── TIMESLOT ─────────────────────────────────────────────────────────────────
// API: POST /api/timeslots  body: { consultantId, slotDate, masterTimeSlotId, durationMinutes, status? }
//      GET /api/timeslots/consultant/{id}/available
//      PUT /api/timeslots/{id}  body: same as POST

class TimeSlot {
  final int id;
  final int consultantId;
  final String slotDate;          // "2026-03-20"
  final int masterTimeSlotId;
  final String timeRange;         // "9:00 AM - 10:00 AM"
  final int durationMinutes;
  final String status;            // AVAILABLE | BOOKED | UNAVAILABLE

  TimeSlot({
    required this.id,
    required this.consultantId,
    required this.slotDate,
    required this.masterTimeSlotId,
    required this.timeRange,
    required this.durationMinutes,
    required this.status,
  });

  factory TimeSlot.fromJson(Map<String, dynamic> json) => TimeSlot(
        id: json['id'] ?? 0,
        consultantId: json['consultantId'] ?? 0,
        slotDate: json['slotDate']?.toString() ?? json['date']?.toString() ?? '',
        masterTimeSlotId: json['masterTimeSlotId'] ?? 0,
        timeRange: json['timeRange'] ?? json['startTime'] ?? '',
        durationMinutes: json['durationMinutes'] ?? 60,
        status: json['status'] ?? 'AVAILABLE',
      );

  bool get isAvailable => status == 'AVAILABLE';
}

// ─── BOOKING ──────────────────────────────────────────────────────────────────
// API: POST /api/bookings  body: { consultantId, timeSlotId, amount, meetingMode, userNotes? }
//      GET /api/bookings/me
//      GET /api/bookings/consultant/{id}
//      GET /api/bookings/status/{status}
//      PUT /api/bookings/{id}  body: BookingUpdateRequest

class Booking {
  final int id;
  final String bookingStatus;    // PENDING | CONFIRMED | COMPLETED | CANCELLED
  final String? paymentStatus;   // PENDING | SUCCESS | FAILED
  final String? meetingMode;     // PHYSICAL | ONLINE | PHONE
  final String? meetingLink;
  final String? meetingId;
  final String? meetingNotes;
  final String? userNotes;
  final double? amount;
  final int? timeSlotId;
  final int? consultantId;
  final String? consultantName;
  final int? userId;
  final String? clientName;
  final String? slotDate;
  final String? timeRange;
  final String? createdAt;

  Booking({
    required this.id,
    required this.bookingStatus,
    this.paymentStatus,
    this.meetingMode,
    this.meetingLink,
    this.meetingId,
    this.meetingNotes,
    this.userNotes,
    this.amount,
    this.timeSlotId,
    this.consultantId,
    this.consultantName,
    this.userId,
    this.clientName,
    this.slotDate,
    this.timeRange,
    this.createdAt,
  });

  // Convenience getter for status (some code uses .status)
  String get status => bookingStatus;

  factory Booking.fromJson(Map<String, dynamic> json) {
    String? extractConsultantName(Map<String, dynamic> j) {
      if (j['consultantName'] != null) return j['consultantName'];
      if (j['consultant'] is Map) return j['consultant']['name'];
      return null;
    }
    String? extractClientName(Map<String, dynamic> j) {
      if (j['clientName'] != null) return j['clientName'];
      if (j['userName'] != null) return j['userName'];
      if (j['user'] is Map) return j['user']['name'];
      return null;
    }
    String? extractSlotDate(Map<String, dynamic> j) {
      if (j['slotDate'] != null) return j['slotDate'].toString();
      if (j['timeSlot'] is Map) return j['timeSlot']['slotDate']?.toString();
      return j['date']?.toString() ?? j['bookingDate']?.toString();
    }
    String? extractTimeRange(Map<String, dynamic> j) {
      if (j['timeRange'] != null) return j['timeRange'];
      if (j['timeSlot'] is Map) return j['timeSlot']['timeRange'];
      return j['startTime'] ?? j['slotStartTime'];
    }

    return Booking(
      id: json['id'] ?? 0,
      bookingStatus: json['bookingStatus'] ?? json['status'] ?? 'PENDING',
      paymentStatus: json['paymentStatus'],
      meetingMode: json['meetingMode'],
      meetingLink: json['meetingLink'] ?? json['joinUrl'],
      meetingId: json['meetingId'],
      meetingNotes: json['meetingNotes'],
      userNotes: json['userNotes'],
      amount: (json['amount'] ?? 0).toDouble(),
      timeSlotId: json['timeSlotId'] ?? json['slotId'],
      consultantId: json['consultantId'],
      consultantName: extractConsultantName(json),
      userId: json['userId'],
      clientName: extractClientName(json),
      slotDate: extractSlotDate(json),
      timeRange: extractTimeRange(json),
      createdAt: json['createdAt']?.toString(),
    );
  }

  bool get isExpired {
    if (slotDate == null) return false;
    try {
      return DateTime.parse(slotDate!).isBefore(DateTime.now().subtract(const Duration(days: 1)));
    } catch (_) { return false; }
  }

  bool get isPending => bookingStatus == 'PENDING';
  bool get isConfirmed => bookingStatus == 'CONFIRMED';
  bool get isCompleted => bookingStatus == 'COMPLETED';
  bool get isCancelled => bookingStatus == 'CANCELLED';
}

// ─── TICKET ───────────────────────────────────────────────────────────────────
// API: POST /api/tickets  body (multipart): { userId, category, description, priority, consultantId? }
//      PATCH /api/tickets/{id}  body: { status }
//      GET /api/tickets/user/{userId}
//      GET /api/tickets/consultant/{id}
//      GET /api/tickets/sla-breached
//      GET /api/tickets/escalated

class Ticket {
  final int id;
  final String category;         // API uses 'category' not 'title'
  final String? description;
  final String status;           // NEW | OPEN | IN_PROGRESS | PENDING | RESOLVED | CLOSED | ESCALATED
  final String priority;         // LOW | MEDIUM | HIGH | URGENT | CRITICAL
  final int? userId;
  final String? userName;
  final int? consultantId;
  final String? consultantName;
  final String? createdAt;
  final String? updatedAt;
  final String? slaRespondBy;    // ISO datetime string
  final String? slaResolveBy;    // ISO datetime string
  final bool slaBreached;
  final bool escalated;
  final int? slaHours;
  final List<TicketComment> comments;

  Ticket({
    required this.id,
    required this.category,
    this.description,
    required this.status,
    required this.priority,
    this.userId,
    this.userName,
    this.consultantId,
    this.consultantName,
    this.createdAt,
    this.updatedAt,
    this.slaRespondBy,
    this.slaResolveBy,
    this.slaBreached = false,
    this.escalated = false,
    this.slaHours,
    this.comments = const [],
  });

  // Backward compat — title = category
  String get title => category;

  factory Ticket.fromJson(Map<String, dynamic> json) => Ticket(
        id: json['id'] ?? 0,
        category: json['category'] ?? json['title'] ?? json['subject'] ?? 'General',
        description: json['description'] ?? json['body'],
        status: json['status'] ?? 'NEW',
        priority: json['priority'] ?? 'MEDIUM',
        userId: json['userId'] ?? json['user']?['id'],
        userName: json['userName'] ?? json['user']?['name'] ?? json['clientName'],
        consultantId: json['consultantId'] ?? json['assignedTo'],
        consultantName: json['consultantName'] ?? json['assignedToName'],
        createdAt: json['createdAt']?.toString(),
        updatedAt: json['updatedAt']?.toString(),
        slaRespondBy: json['slaRespondBy']?.toString(),
        slaResolveBy: json['slaResolveBy']?.toString(),
        slaBreached: json['slaBreached'] ?? false,
        escalated: json['escalated'] ?? false,
        slaHours: json['slaHours'],
        comments: (json['comments'] as List<dynamic>? ?? [])
            .map((c) => TicketComment.fromJson(c))
            .toList(),
      );

  SlaInfo getSlaInfo() {
    // Use backend-provided slaResolveBy if available
    if (slaResolveBy != null) {
      try {
        final deadline = DateTime.parse(slaResolveBy!);
        final now = DateTime.now();
        final remaining = deadline.difference(now).inHours;
        if (slaBreached || now.isAfter(deadline)) return SlaInfo(status: 'breached', hoursRemaining: remaining);
        final slaMap = {'LOW': 72, 'MEDIUM': 48, 'HIGH': 24, 'URGENT': 8, 'CRITICAL': 4};
        final maxHours = slaHours ?? slaMap[priority.toUpperCase()] ?? 48;
        if (remaining <= maxHours * 0.25) return SlaInfo(status: 'warning', hoursRemaining: remaining);
        return SlaInfo(status: 'ok', hoursRemaining: remaining);
      } catch (_) {}
    }
    // Fallback: calculate from createdAt
    if (createdAt == null) return SlaInfo(status: 'unknown', hoursRemaining: null);
    try {
      final slaMap = {'LOW': 72, 'MEDIUM': 48, 'HIGH': 24, 'URGENT': 8, 'CRITICAL': 4};
      final maxHours = slaHours ?? slaMap[priority.toUpperCase()] ?? 48;
      final created = DateTime.parse(createdAt!);
      final deadline = created.add(Duration(hours: maxHours));
      final now = DateTime.now();
      final remaining = deadline.difference(now).inHours;
      if (now.isAfter(deadline)) return SlaInfo(status: 'breached', hoursRemaining: remaining);
      if (remaining <= maxHours * 0.25) return SlaInfo(status: 'warning', hoursRemaining: remaining);
      return SlaInfo(status: 'ok', hoursRemaining: remaining);
    } catch (_) {
      return SlaInfo(status: 'unknown', hoursRemaining: null);
    }
  }
}

class SlaInfo {
  final String status;       // ok | warning | breached | unknown
  final int? hoursRemaining;
  SlaInfo({required this.status, this.hoursRemaining});
}

// ─── TICKET COMMENT ───────────────────────────────────────────────────────────
// API: POST /api/tickets/comments  body: { ticketId, senderId, message, isConsultantReply }
//      GET /api/tickets/{id}/notes

class TicketComment {
  final int id;
  final int? ticketId;
  final String message;
  final int? senderId;
  final String? authorName;
  final String? authorRole;
  final bool isConsultantReply;   // API field name
  final String? createdAt;

  TicketComment({
    required this.id,
    this.ticketId,
    required this.message,
    this.senderId,
    this.authorName,
    this.authorRole,
    this.isConsultantReply = false,
    this.createdAt,
  });

  // Backward compat
  bool get isInternal => isConsultantReply;

  factory TicketComment.fromJson(Map<String, dynamic> json) => TicketComment(
        id: json['id'] ?? 0,
        ticketId: json['ticketId'],
        message: json['message'] ?? json['content'] ?? json['body'] ?? '',
        senderId: json['senderId'],
        authorName: json['authorName'] ?? json['senderName'] ?? json['author']?['name'],
        authorRole: json['authorRole'] ?? json['role'],
        isConsultantReply: json['isConsultantReply'] ?? json['isInternal'] ?? json['internal'] ?? false,
        createdAt: json['createdAt']?.toString(),
      );
}

// ─── TICKET NOTE ──────────────────────────────────────────────────────────────
// API: GET/POST /api/tickets/{id}/notes  body: { content }

class TicketNote {
  final int id;
  final String content;
  final String? authorName;
  final String? createdAt;

  TicketNote({required this.id, required this.content, this.authorName, this.createdAt});

  factory TicketNote.fromJson(Map<String, dynamic> json) => TicketNote(
        id: json['id'] ?? 0,
        content: json['content'] ?? json['message'] ?? '',
        authorName: json['authorName'] ?? json['author']?['name'],
        createdAt: json['createdAt']?.toString(),
      );
}

// ─── FEEDBACK ─────────────────────────────────────────────────────────────────
// API: POST /api/feedbacks  body: { userId, consultantId, meetingId, bookingId, rating, comments }
//      GET /api/feedbacks/consultant/{id}
//      GET /api/feedbacks/booking/{id}

class Feedback {
  final int id;
  final int rating;          // 1-5
  final String? comments;    // API field: comments (not comment)
  final String? clientName;
  final int? userId;
  final int? consultantId;
  final int? bookingId;
  final int? meetingId;
  final String? createdAt;

  Feedback({
    required this.id,
    required this.rating,
    this.comments,
    this.clientName,
    this.userId,
    this.consultantId,
    this.bookingId,
    this.meetingId,
    this.createdAt,
  });

  factory Feedback.fromJson(Map<String, dynamic> json) => Feedback(
        id: json['id'] ?? 0,
        rating: json['rating'] ?? 0,
        comments: json['comments'] ?? json['comment'] ?? json['review'],
        clientName: json['clientName'] ?? json['userName'] ?? json['user']?['name'],
        userId: json['userId'],
        consultantId: json['consultantId'],
        bookingId: json['bookingId'],
        meetingId: json['meetingId'],
        createdAt: json['createdAt']?.toString(),
      );
}

// ─── DASHBOARD / ANALYTICS ────────────────────────────────────────────────────
// API: GET /api/dashboard/analytics?period=WEEKLY
//      GET /api/dashboard/summaries?period=WEEKLY

class DashboardAnalytics {
  final int totalTickets;
  final int openTickets;
  final int resolvedTickets;
  final int slaBreaches;
  final double avgResponseTime;
  final double avgResolutionTime;
  final double avgRating;
  final Map<String, int> ticketsByStatus;
  final Map<String, int> ticketsByPriority;
  final Map<String, int> ticketsByCategory;

  DashboardAnalytics({
    required this.totalTickets,
    required this.openTickets,
    required this.resolvedTickets,
    required this.slaBreaches,
    required this.avgResponseTime,
    required this.avgResolutionTime,
    required this.avgRating,
    required this.ticketsByStatus,
    required this.ticketsByPriority,
    required this.ticketsByCategory,
  });

  factory DashboardAnalytics.fromJson(Map<String, dynamic> json) => DashboardAnalytics(
        totalTickets: json['totalTickets'] ?? 0,
        openTickets: json['openTickets'] ?? 0,
        resolvedTickets: json['resolvedTickets'] ?? 0,
        slaBreaches: json['slaBreaches'] ?? 0,
        avgResponseTime: (json['avgResponseTime'] ?? 0).toDouble(),
        avgResolutionTime: (json['avgResolutionTime'] ?? 0).toDouble(),
        avgRating: (json['avgRating'] ?? 0).toDouble(),
        ticketsByStatus: Map<String, int>.from(json['ticketsByStatus'] ?? {}),
        ticketsByPriority: Map<String, int>.from(json['ticketsByPriority'] ?? {}),
        ticketsByCategory: Map<String, int>.from(json['ticketsByCategory'] ?? {}),
      );
}

class DashboardSummary {
  final String label;
  final int count;

  DashboardSummary({required this.label, required this.count});

  factory DashboardSummary.fromJson(Map<String, dynamic> json) => DashboardSummary(
        label: json['label']?.toString() ?? '',
        count: json['count'] ?? 0,
      );
}

// ─── NOTIFICATION ─────────────────────────────────────────────────────────────
// API: GET /api/notifications
//      PUT /api/notifications/{id}/read

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type;        // ticket | booking | system
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic>? data;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.isRead = false,
    required this.createdAt,
    this.data,
  });

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        title: title,
        body: body,
        type: type,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
        data: data,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'type': type,
        'isRead': isRead,
        'createdAt': createdAt.toIso8601String(),
        if (data != null) 'data': data,
      };

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id']?.toString() ?? '',
        title: json['title'] ?? '',
        body: json['body'] ?? json['message'] ?? '',
        type: json['type'] ?? 'system',
        isRead: json['isRead'] ?? json['read'] ?? false,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
            : DateTime.now(),
        data: json['data'] is Map ? Map<String, dynamic>.from(json['data']) : null,
      );
}

// ─── SUBSCRIPTION PLAN ────────────────────────────────────────────────────────
// API: GET/POST /api/subscription-plans
//      PUT/DELETE /api/subscription-plans/{id}

class SubscriptionPlan {
  final int id;
  final String name;
  final double originalPrice;
  final double? discountPrice;
  final String? features;
  final String? tag;

  SubscriptionPlan({
    required this.id,
    required this.name,
    required this.originalPrice,
    this.discountPrice,
    this.features,
    this.tag,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) => SubscriptionPlan(
        id: json['id'] ?? 0,
        name: json['name'] ?? '',
        originalPrice: (json['originalPrice'] ?? json['price'] ?? 0).toDouble(),
        discountPrice: json['discountPrice'] != null ? (json['discountPrice']).toDouble() : null,
        features: json['features'],
        tag: json['tag'],
      );

  double get effectivePrice => discountPrice ?? originalPrice;
}

// ─── CANNED RESPONSE ──────────────────────────────────────────────────────────
// API: GET/POST /api/admin/config/canned-responses
//      DELETE /api/admin/config/canned-responses/{id}

class CannedResponse {
  final int id;
  final String title;
  final String content;      // API field: content (not message)
  final String? category;
  final String? createdAt;

  CannedResponse({
    required this.id,
    required this.title,
    required this.content,
    this.category,
    this.createdAt,
  });

  // Backward compat
  String get message => content;

  factory CannedResponse.fromJson(Map<String, dynamic> json) => CannedResponse(
        id: json['id'] ?? 0,
        title: json['title'] ?? '',
        content: json['content'] ?? json['message'] ?? '',
        category: json['category'],
        createdAt: json['createdAt']?.toString(),
      );
}

// ─── CATEGORY ─────────────────────────────────────────────────────────────────
// API: GET/POST /api/admin/config/categories
//      PATCH /api/admin/config/categories/{id}/toggle

class TicketCategory {
  final int id;
  final String name;
  final bool isActive;
  final String? description;

  TicketCategory({required this.id, required this.name, this.isActive = true, this.description});

  factory TicketCategory.fromJson(Map<String, dynamic> json) => TicketCategory(
        id: json['id'] ?? 0,
        name: json['name'] ?? '',
        isActive: json['isActive'] ?? json['active'] ?? true,
        description: json['description'],
      );
}

// ─── BUSINESS HOURS ───────────────────────────────────────────────────────────
// API: GET/POST /api/admin/settings/business-hours

class BusinessHours {
  final int id;
  final String dayOfWeek;   // MONDAY | TUESDAY | ...
  final String openTime;    // "09:00"
  final String closeTime;   // "18:00"
  final bool isOpen;

  BusinessHours({
    required this.id,
    required this.dayOfWeek,
    required this.openTime,
    required this.closeTime,
    this.isOpen = true,
  });

  factory BusinessHours.fromJson(Map<String, dynamic> json) => BusinessHours(
        id: json['id'] ?? 0,
        dayOfWeek: json['dayOfWeek'] ?? '',
        openTime: json['openTime'] ?? '09:00',
        closeTime: json['closeTime'] ?? '18:00',
        isOpen: json['isOpen'] ?? json['open'] ?? true,
      );
}

// ─── HOLIDAY ──────────────────────────────────────────────────────────────────
// API: GET/POST /api/admin/settings/holidays
//      DELETE /api/admin/settings/holidays/{id}

class Holiday {
  final int id;
  final String name;
  final String date;   // "2026-01-26"

  Holiday({required this.id, required this.name, required this.date});

  factory Holiday.fromJson(Map<String, dynamic> json) => Holiday(
        id: json['id'] ?? 0,
        name: json['name'] ?? '',
        date: json['date']?.toString() ?? '',
      );
}

// ─── ONBOARDING ───────────────────────────────────────────────────────────────
// API: POST /api/onboarding  (multipart/form-data)
//      GET/PUT/DELETE /api/onboarding/{id}

class OnboardingProfile {
  final int id;
  final String name;
  final String? dob;
  final String? identifier;     // PAN or Aadhaar
  final String? email;
  final String? phoneNumber;
  final String? location;
  final bool subscribed;
  final int? subscriptionPlanId;
  final List<Map<String, dynamic>> incomeItems;
  final List<Map<String, dynamic>> expenseItems;
  final String? photoUrl;

  OnboardingProfile({
    required this.id,
    required this.name,
    this.dob,
    this.identifier,
    this.email,
    this.phoneNumber,
    this.location,
    this.subscribed = false,
    this.subscriptionPlanId,
    this.incomeItems = const [],
    this.expenseItems = const [],
    this.photoUrl,
  });

  factory OnboardingProfile.fromJson(Map<String, dynamic> json) => OnboardingProfile(
        id: json['id'] ?? 0,
        name: json['name'] ?? '',
        dob: json['dob']?.toString(),
        identifier: json['identifier']?.toString(),
        email: json['email'],
        phoneNumber: json['phoneNumber']?.toString(),
        location: json['location'],
        subscribed: json['subscribed'] ?? false,
        subscriptionPlanId: json['subscriptionPlanId'],
        incomeItems: (json['incomeItems'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e))
            .toList(),
        expenseItems: (json['expenseItems'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e))
            .toList(),
        photoUrl: json['photoUrl'] ?? json['profilePicture'],
      );
}