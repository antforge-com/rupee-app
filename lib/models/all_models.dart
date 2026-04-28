// lib/models/all_models.dart
// ════════════════════════════════════════════════════════════════════════════
// COMPREHENSIVE MODEL DEFINITIONS FOR ALL BACKEND DTOs
// Auto-generated from backend controller specifications
// ════════════════════════════════════════════════════════════════════════════

// ─── PAGINATION SUPPORT ───────────────────────────────────────────────────

class PaginatedResponse<T> {
  final List<T> content;
  final int totalElements;
  final int totalPages;
  final int currentPage;
  final int pageSize;
  final bool hasNext;
  final bool hasPrevious;

  PaginatedResponse({
    required this.content,
    required this.totalElements,
    required this.totalPages,
    required this.currentPage,
    required this.pageSize,
    required this.hasNext,
    required this.hasPrevious,
  });

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    final content = json['content'] as List? ?? [];
    return PaginatedResponse(
      content: content
          .map((item) =>
              fromJsonT(item is Map ? Map<String, dynamic>.from(item) : {}))
          .toList(),
      totalElements: json['totalElements'] ?? 0,
      totalPages: json['totalPages'] ?? 0,
      currentPage: json['number'] ?? 0,
      pageSize: json['size'] ?? 0,
      hasNext: json['hasNext'] ?? false,
      hasPrevious: json['hasPrevious'] ?? false,
    );
  }
}

// ─── TICKET MODELS ────────────────────────────────────────────────────

class TicketModel {
  final int id;
  final String subject;
  final String description;
  final String status;
  final String priority;
  final int? userId;
  final int? consultantId;
  final int? categoryId;
  final String? categoryName;
  final int? slaTime;
  final String? createdAt;
  final String? updatedAt;
  final List<TicketCommentModel>? comments;
  final List<TicketNoteModel>? notes;

  TicketModel({
    required this.id,
    required this.subject,
    required this.description,
    required this.status,
    required this.priority,
    this.userId,
    this.consultantId,
    this.categoryId,
    this.categoryName,
    this.slaTime,
    this.createdAt,
    this.updatedAt,
    this.comments,
    this.notes,
  });

  factory TicketModel.fromJson(Map<String, dynamic> json) => TicketModel(
        id: json['id'] ?? 0,
        subject: json['subject'] ?? '',
        description: json['description'] ?? '',
        status: json['status'] ?? 'OPEN',
        priority: json['priority'] ?? 'MEDIUM',
        userId: json['userId'],
        consultantId: json['consultantId'],
        categoryId: json['categoryId'],
        categoryName: json['categoryName'],
        slaTime: json['slaTime'],
        createdAt: json['createdAt']?.toString(),
        updatedAt: json['updatedAt']?.toString(),
        comments: (json['comments'] as List?)
            ?.map((c) => TicketCommentModel.fromJson(c as Map<String, dynamic>))
            .toList(),
        notes: (json['notes'] as List?)
            ?.map((n) => TicketNoteModel.fromJson(n as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'subject': subject,
        'description': description,
        'status': status,
        'priority': priority,
        if (userId != null) 'userId': userId,
        if (consultantId != null) 'consultantId': consultantId,
        if (categoryId != null) 'categoryId': categoryId,
        if (categoryName != null) 'categoryName': categoryName,
        if (slaTime != null) 'slaTime': slaTime,
        if (createdAt != null) 'createdAt': createdAt,
        if (updatedAt != null) 'updatedAt': updatedAt,
      };
}

class TicketRequest {
  final String subject;
  final String description;
  final String priority;
  final int? categoryId;

  TicketRequest({
    required this.subject,
    required this.description,
    required this.priority,
    this.categoryId,
  });

  Map<String, dynamic> toJson() => {
        'subject': subject,
        'description': description,
        'priority': priority,
        if (categoryId != null) 'categoryId': categoryId,
      };
}

class TicketCommentModel {
  final int id;
  final String comment;
  final int? userId;
  final String? userName;
  final String? createdAt;

  TicketCommentModel({
    required this.id,
    required this.comment,
    this.userId,
    this.userName,
    this.createdAt,
  });

  factory TicketCommentModel.fromJson(Map<String, dynamic> json) =>
      TicketCommentModel(
        id: json['id'] ?? 0,
        comment: json['comment'] ?? '',
        userId: json['userId'],
        userName: json['userName'],
        createdAt: json['createdAt']?.toString(),
      );
}

class TicketNoteModel {
  final int id;
  final String note;
  final int? userId;
  final String? userName;
  final String? createdAt;

  TicketNoteModel({
    required this.id,
    required this.note,
    this.userId,
    this.userName,
    this.createdAt,
  });

  factory TicketNoteModel.fromJson(Map<String, dynamic> json) =>
      TicketNoteModel(
        id: json['id'] ?? 0,
        note: json['note'] ?? '',
        userId: json['userId'],
        userName: json['userName'],
        createdAt: json['createdAt']?.toString(),
      );
}

class TicketCategoryModel {
  final int id;
  final String name;
  final String? description;

  TicketCategoryModel({
    required this.id,
    required this.name,
    this.description,
  });

  factory TicketCategoryModel.fromJson(Map<String, dynamic> json) =>
      TicketCategoryModel(
        id: json['id'] ?? 0,
        name: json['name'] ?? '',
        description: json['description'],
      );
}

// ─── BOOKING MODELS ───────────────────────────────────────────────────

class BookingModel {
  final int id;
  final int userId;
  final int consultantId;
  final String status;
  final String? startTime;
  final String? endTime;
  final String? bookingDate;
  final String? createdAt;
  final String? updatedAt;
  final double? amount;
  final String? notes;

  BookingModel({
    required this.id,
    required this.userId,
    required this.consultantId,
    required this.status,
    this.startTime,
    this.endTime,
    this.bookingDate,
    this.createdAt,
    this.updatedAt,
    this.amount,
    this.notes,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) => BookingModel(
        id: json['id'] ?? 0,
        userId: json['userId'] ?? 0,
        consultantId: json['consultantId'] ?? 0,
        status: json['status'] ?? 'PENDING',
        startTime: json['startTime']?.toString(),
        endTime: json['endTime']?.toString(),
        bookingDate: json['bookingDate']?.toString(),
        createdAt: json['createdAt']?.toString(),
        updatedAt: json['updatedAt']?.toString(),
        amount: (json['amount'] as num?)?.toDouble(),
        notes: json['notes'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'consultantId': consultantId,
        'status': status,
        if (startTime != null) 'startTime': startTime,
        if (endTime != null) 'endTime': endTime,
        if (bookingDate != null) 'bookingDate': bookingDate,
        if (amount != null) 'amount': amount,
        if (notes != null) 'notes': notes,
      };
}

class BookingRequest {
  final int consultantId;
  final String? startTime;
  final String? endTime;
  final String? bookingDate;
  final String? notes;

  BookingRequest({
    required this.consultantId,
    this.startTime,
    this.endTime,
    this.bookingDate,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'consultantId': consultantId,
        if (startTime != null) 'startTime': startTime,
        if (endTime != null) 'endTime': endTime,
        if (bookingDate != null) 'bookingDate': bookingDate,
        if (notes != null) 'notes': notes,
      };
}

// ─── FEEDBACK MODELS ──────────────────────────────────────────────────

class FeedbackModel {
  final int id;
  final int bookingId;
  final int? userId;
  final int? consultantId;
  final int rating;
  final String? comment;
  final String? createdAt;

  FeedbackModel({
    required this.id,
    required this.bookingId,
    this.userId,
    this.consultantId,
    required this.rating,
    this.comment,
    this.createdAt,
  });

  factory FeedbackModel.fromJson(Map<String, dynamic> json) => FeedbackModel(
        id: json['id'] ?? 0,
        bookingId: json['bookingId'] ?? 0,
        userId: json['userId'],
        consultantId: json['consultantId'],
        rating: json['rating'] ?? 0,
        comment: json['comment'],
        createdAt: json['createdAt']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'bookingId': bookingId,
        'rating': rating,
        if (comment != null) 'comment': comment,
      };
}

// ─── OFFER MODELS ─────────────────────────────────────────────────────

class OfferModel {
  final int id;
  final String title;
  final String description;
  final double discount;
  final String? startDate;
  final String? endDate;
  final String status;
  final String? createdAt;

  OfferModel({
    required this.id,
    required this.title,
    required this.description,
    required this.discount,
    this.startDate,
    this.endDate,
    required this.status,
    this.createdAt,
  });

  factory OfferModel.fromJson(Map<String, dynamic> json) => OfferModel(
        id: json['id'] ?? 0,
        title: json['title'] ?? '',
        description: json['description'] ?? '',
        discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
        startDate: json['startDate']?.toString(),
        endDate: json['endDate']?.toString(),
        status: json['status'] ?? 'ACTIVE',
        createdAt: json['createdAt']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'discount': discount,
        if (startDate != null) 'startDate': startDate,
        if (endDate != null) 'endDate': endDate,
        'status': status,
      };
}

// ─── NOTIFICATION MODELS ──────────────────────────────────────────────

class NotificationModel {
  final int id;
  final int userId;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final String? createdAt;
  final Map<String, dynamic>? data;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    this.createdAt,
    this.data,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      NotificationModel(
        id: json['id'] ?? 0,
        userId: json['userId'] ?? 0,
        title: json['title'] ?? '',
        message: json['message'] ?? '',
        type: json['type'] ?? 'INFO',
        isRead: json['isRead'] ?? false,
        createdAt: json['createdAt']?.toString(),
        data: json['data'] is Map ? Map<String, dynamic>.from(json['data']) : null,
      );
}

// ─── TIMESLOT MODELS ──────────────────────────────────────────────────

class TimeSlotModel {
  final int id;
  final int consultantId;
  final String startTime;
  final String endTime;
  final String date;
  final bool available;
  final String? createdAt;

  TimeSlotModel({
    required this.id,
    required this.consultantId,
    required this.startTime,
    required this.endTime,
    required this.date,
    required this.available,
    this.createdAt,
  });

  factory TimeSlotModel.fromJson(Map<String, dynamic> json) => TimeSlotModel(
        id: json['id'] ?? 0,
        consultantId: json['consultantId'] ?? 0,
        startTime: json['startTime'] ?? '',
        endTime: json['endTime'] ?? '',
        date: json['date'] ?? '',
        available: json['available'] ?? true,
        createdAt: json['createdAt']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'consultantId': consultantId,
        'startTime': startTime,
        'endTime': endTime,
        'date': date,
        'available': available,
      };
}

class TimeSlotRequest {
  final String startTime;
  final String endTime;
  final String date;

  TimeSlotRequest({
    required this.startTime,
    required this.endTime,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'startTime': startTime,
        'endTime': endTime,
        'date': date,
      };
}

// ─── QUESTION & ANSWER MODELS ────────────────────────────────────────

class QuestionModel {
  final int id;
  final String question;
  final String? category;
  final String? createdAt;
  final List<AnswerModel>? answers;

  QuestionModel({
    required this.id,
    required this.question,
    this.category,
    this.createdAt,
    this.answers,
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json) => QuestionModel(
        id: json['id'] ?? 0,
        question: json['question'] ?? '',
        category: json['category'],
        createdAt: json['createdAt']?.toString(),
        answers: (json['answers'] as List?)
            ?.map((a) => AnswerModel.fromJson(a as Map<String, dynamic>))
            .toList(),
      );
}

class AnswerModel {
  final int id;
  final int questionId;
  final String answer;
  final int? userId;
  final String? userName;
  final String? createdAt;

  AnswerModel({
    required this.id,
    required this.questionId,
    required this.answer,
    this.userId,
    this.userName,
    this.createdAt,
  });

  factory AnswerModel.fromJson(Map<String, dynamic> json) => AnswerModel(
        id: json['id'] ?? 0,
        questionId: json['questionId'] ?? 0,
        answer: json['answer'] ?? '',
        userId: json['userId'],
        userName: json['userName'],
        createdAt: json['createdAt']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'questionId': questionId,
        'answer': answer,
      };
}

// ─── SPECIAL BOOKING MODELS ───────────────────────────────────────────

class SpecialBookingModel {
  final int id;
  final int userId;
  final int consultantId;
  final String status;
  final String? startDate;
  final String? endDate;
  final String? startTime;
  final String? endTime;
  final double? amount;
  final String? notes;
  final String? createdAt;

  SpecialBookingModel({
    required this.id,
    required this.userId,
    required this.consultantId,
    required this.status,
    this.startDate,
    this.endDate,
    this.startTime,
    this.endTime,
    this.amount,
    this.notes,
    this.createdAt,
  });

  factory SpecialBookingModel.fromJson(Map<String, dynamic> json) =>
      SpecialBookingModel(
        id: json['id'] ?? 0,
        userId: json['userId'] ?? 0,
        consultantId: json['consultantId'] ?? 0,
        status: json['status'] ?? 'PENDING',
        startDate: json['startDate']?.toString(),
        endDate: json['endDate']?.toString(),
        startTime: json['startTime']?.toString(),
        endTime: json['endTime']?.toString(),
        amount: (json['amount'] as num?)?.toDouble(),
        notes: json['notes'],
        createdAt: json['createdAt']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'consultantId': consultantId,
        'status': status,
        if (startDate != null) 'startDate': startDate,
        if (endDate != null) 'endDate': endDate,
        if (startTime != null) 'startTime': startTime,
        if (endTime != null) 'endTime': endTime,
        if (amount != null) 'amount': amount,
        if (notes != null) 'notes': notes,
      };
}

// ─── ANALYTICS MODELS ─────────────────────────────────────────────────

class AnalyticsModel {
  final int totalBookings;
  final int totalRevenue;
  final int totalTickets;
  final int resolvedTickets;
  final int totalConsultants;
  final int activeUsers;
  final Map<String, dynamic>? chartData;

  AnalyticsModel({
    required this.totalBookings,
    required this.totalRevenue,
    required this.totalTickets,
    required this.resolvedTickets,
    required this.totalConsultants,
    required this.activeUsers,
    this.chartData,
  });

  factory AnalyticsModel.fromJson(Map<String, dynamic> json) =>
      AnalyticsModel(
        totalBookings: json['totalBookings'] ?? 0,
        totalRevenue: json['totalRevenue'] ?? 0,
        totalTickets: json['totalTickets'] ?? 0,
        resolvedTickets: json['resolvedTickets'] ?? 0,
        totalConsultants: json['totalConsultants'] ?? 0,
        activeUsers: json['activeUsers'] ?? 0,
        chartData: json['chartData'] is Map
            ? Map<String, dynamic>.from(json['chartData'])
            : null,
      );
}

// ─── SYSTEM SETTINGS MODELS ───────────────────────────────────────────

class SystemSettingsModel {
  final int id;
  final String key;
  final String value;
  final String? description;

  SystemSettingsModel({
    required this.id,
    required this.key,
    required this.value,
    this.description,
  });

  factory SystemSettingsModel.fromJson(Map<String, dynamic> json) =>
      SystemSettingsModel(
        id: json['id'] ?? 0,
        key: json['key'] ?? '',
        value: json['value'] ?? '',
        description: json['description'],
      );

  Map<String, dynamic> toJson() => {
        'key': key,
        'value': value,
        if (description != null) 'description': description,
      };
}

// ─── SUBSCRIPTION PLAN MODELS ─────────────────────────────────────────

class SubscriptionPlanModel {
  final int id;
  final String name;
  final String description;
  final double price;
  final int duration; // in months
  final List<String> features;
  final String? createdAt;

  SubscriptionPlanModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.duration,
    required this.features,
    this.createdAt,
  });

  factory SubscriptionPlanModel.fromJson(Map<String, dynamic> json) =>
      SubscriptionPlanModel(
        id: json['id'] ?? 0,
        name: json['name'] ?? '',
        description: json['description'] ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        duration: json['duration'] ?? 1,
        features: List<String>.from(json['features'] ?? []),
        createdAt: json['createdAt']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'price': price,
        'duration': duration,
        'features': features,
      };
}

// ─── CONTACT MESSAGE MODELS ───────────────────────────────────────────

class ContactMessageModel {
  final int id;
  final String name;
  final String email;
  final String message;
  final String? phone;
  final bool isResolved;
  final String? createdAt;

  ContactMessageModel({
    required this.id,
    required this.name,
    required this.email,
    required this.message,
    this.phone,
    required this.isResolved,
    this.createdAt,
  });

  factory ContactMessageModel.fromJson(Map<String, dynamic> json) =>
      ContactMessageModel(
        id: json['id'] ?? 0,
        name: json['name'] ?? '',
        email: json['email'] ?? '',
        message: json['message'] ?? '',
        phone: json['phone'],
        isResolved: json['isResolved'] ?? false,
        createdAt: json['createdAt']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'message': message,
        if (phone != null) 'phone': phone,
      };
}

// ─── STATIC CONTENT MODELS ────────────────────────────────────────────

class StaticContentModel {
  final int id;
  final String key;
  final String content;
  final String? createdAt;

  StaticContentModel({
    required this.id,
    required this.key,
    required this.content,
    this.createdAt,
  });

  factory StaticContentModel.fromJson(Map<String, dynamic> json) =>
      StaticContentModel(
        id: json['id'] ?? 0,
        key: json['key'] ?? '',
        content: json['content'] ?? '',
        createdAt: json['createdAt']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'key': key,
        'content': content,
      };
}

// ─── SKILL MASTER MODELS ──────────────────────────────────────────────

class SkillMasterModel {
  final int id;
  final String name;
  final String? description;
  final String? createdAt;

  SkillMasterModel({
    required this.id,
    required this.name,
    this.description,
    this.createdAt,
  });

  factory SkillMasterModel.fromJson(Map<String, dynamic> json) =>
      SkillMasterModel(
        id: json['id'] ?? 0,
        name: json['name'] ?? '',
        description: json['description'],
        createdAt: json['createdAt']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        if (description != null) 'description': description,
      };
}

// ─── MASTER TIME SLOT MODELS ──────────────────────────────────────────

class MasterTimeSlotModel {
  final int id;
  final String startTime;
  final String endTime;
  final String? createdAt;

  MasterTimeSlotModel({
    required this.id,
    required this.startTime,
    required this.endTime,
    this.createdAt,
  });

  factory MasterTimeSlotModel.fromJson(Map<String, dynamic> json) =>
      MasterTimeSlotModel(
        id: json['id'] ?? 0,
        startTime: json['startTime'] ?? '',
        endTime: json['endTime'] ?? '',
        createdAt: json['createdAt']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'startTime': startTime,
        'endTime': endTime,
      };
}

// ─── ERROR & VALIDATION MODELS ────────────────────────────────────────

class ApiErrorResponse {
  final String message;
  final String? error;
  final int statusCode;
  final Map<String, dynamic>? fieldErrors;

  ApiErrorResponse({
    required this.message,
    this.error,
    required this.statusCode,
    this.fieldErrors,
  });

  factory ApiErrorResponse.fromJson(Map<String, dynamic> json) =>
      ApiErrorResponse(
        message: json['message'] ?? 'An error occurred',
        error: json['error'],
        statusCode: json['statusCode'] ?? 500,
        fieldErrors: json['fieldErrors'] is Map
            ? Map<String, dynamic>.from(json['fieldErrors'])
            : null,
      );
}

// ─── GENERIC RESPONSE WRAPPER ─────────────────────────────────────────

class ApiResponse<T> {
  final bool success;
  final String? message;
  final T? data;
  final List<T>? items;
  final Map<String, dynamic>? rawData;

  ApiResponse({
    required this.success,
    this.message,
    this.data,
    this.items,
    this.rawData,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    final data = json['data'];
    final dataList = json['items'] ?? json['data'];

    return ApiResponse(
      success: json['success'] ?? true,
      message: json['message'],
      data: data is Map ? fromJsonT(Map<String, dynamic>.from(data)) : null,
      items: dataList is List
          ? dataList
              .map((item) =>
                  fromJsonT(item is Map ? Map<String, dynamic>.from(item) : {}))
              .toList()
          : null,
      rawData: Map<String, dynamic>.from(json),
    );
  }
}

// ─── EMAIL TO TICKET MAPPING ──────────────────────────────────────────

class EmailToTicketMappingModel {
  final int id;
  final String email;
  final int? categoryId;
  final String? categoryName;
  final bool active;
  final String? createdAt;

  EmailToTicketMappingModel({
    required this.id,
    required this.email,
    this.categoryId,
    this.categoryName,
    required this.active,
    this.createdAt,
  });

  factory EmailToTicketMappingModel.fromJson(Map<String, dynamic> json) =>
      EmailToTicketMappingModel(
        id: json['id'] ?? 0,
        email: json['email'] ?? '',
        categoryId: json['categoryId'],
        categoryName: json['categoryName'],
        active: json['active'] ?? true,
        createdAt: json['createdAt']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'email': email,
        if (categoryId != null) 'categoryId': categoryId,
        'active': active,
      };
}

// ─── DASHBOARD MODELS ─────────────────────────────────────────────────

class DashboardStatsModel {
  final int totalBookings;
  final int completedBookings;
  final int pendingBookings;
  final int totalRevenue;
  final int totalTickets;
  final int openTickets;
  final int resolvedTickets;
  final double averageRating;

  DashboardStatsModel({
    required this.totalBookings,
    required this.completedBookings,
    required this.pendingBookings,
    required this.totalRevenue,
    required this.totalTickets,
    required this.openTickets,
    required this.resolvedTickets,
    required this.averageRating,
  });

  factory DashboardStatsModel.fromJson(Map<String, dynamic> json) =>
      DashboardStatsModel(
        totalBookings: json['totalBookings'] ?? 0,
        completedBookings: json['completedBookings'] ?? 0,
        pendingBookings: json['pendingBookings'] ?? 0,
        totalRevenue: json['totalRevenue'] ?? 0,
        totalTickets: json['totalTickets'] ?? 0,
        openTickets: json['openTickets'] ?? 0,
        resolvedTickets: json['resolvedTickets'] ?? 0,
        averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0.0,
      );
}

