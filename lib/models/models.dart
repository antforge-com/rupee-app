// lib/core/models/models.dart
// ════════════════════════════════════════════════════════════════════════════
// ALL MODELS — Swagger spec ke exact field names ke saath
// Base URL: http://52.55.178.31:8081
// ════════════════════════════════════════════════════════════════════════════

// ─── USER ─────────────────────────────────────────────────────────────────────

class UserModel {
  final int id;
  final String name;
  final String email;
  final String role;
  final String? createdAt;
  final String? phone;
  final String? photoUrl;
  final String? identifier;
  final int? consultantId;
  final double? offerAmount;
  final bool requiresPasswordChange;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.createdAt,
    this.phone,
    this.photoUrl,
    this.identifier,
    this.consultantId,
    this.offerAmount,
    this.requiresPasswordChange = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] ?? 0,
        name: _cleanText(
          json['name'] ??
              json['fullName'] ??
              json['displayName'] ??
              json['username'] ??
              json['userName'] ??
              json['identifier'] ??
              json['email'],
          fallback: '',
        ),
        email: _cleanText(json['email'], fallback: ''),
        role: _cleanText(json['role'], fallback: 'USER'),
        createdAt: json['createdAt']?.toString(),
        phone: _cleanNullableText(
          json['phone']?.toString() ?? json['phoneNumber']?.toString(),
        ),
        photoUrl:
            _cleanNullableText(json['photoUrl'] ?? json['profilePicture']),
        identifier: _cleanNullableText(json['identifier']),
        consultantId: json['consultantId'],
        offerAmount: _asDouble(json['offerAmount']),
        requiresPasswordChange: json['requiresPasswordChange'] == true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        if (createdAt != null) 'createdAt': createdAt,
        if (phone != null) 'phone': phone,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (identifier != null) 'identifier': identifier,
        if (consultantId != null) 'consultantId': consultantId,
        if (offerAmount != null) 'offerAmount': offerAmount,
        'requiresPasswordChange': requiresPasswordChange,
      };
}

// ─── CONSULTANT ───────────────────────────────────────────────────────────────
// API: GET/POST/PUT/DELETE /api/consultants

double? _asDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

bool _toBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' ||
        normalized == '1' ||
        normalized == 'yes' ||
        normalized == 'y') {
      return true;
    }
    if (normalized == 'false' ||
        normalized == '0' ||
        normalized == 'no' ||
        normalized == 'n') {
      return false;
    }
  }
  return fallback;
}

Map<String, dynamic>? _timeToMap(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is String && value.trim().isNotEmpty) {
    final raw = value.trim();
    final upper = raw.toUpperCase();

    final twentyFour =
        RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?$').firstMatch(upper);
    if (twentyFour != null) {
      final hour = int.tryParse(twentyFour.group(1) ?? '');
      final minute = int.tryParse(twentyFour.group(2) ?? '');
      final second = int.tryParse(twentyFour.group(3) ?? '0') ?? 0;
      if (hour != null && minute != null) {
        return {
          'hour': hour,
          'minute': minute,
          'second': second,
          'nano': 0,
        };
      }
    }

    final ampm =
        RegExp(r'^(\d{1,2})(?::(\d{2}))?\s*(AM|PM)$').firstMatch(upper);
    if (ampm != null) {
      var hour = int.tryParse(ampm.group(1) ?? '') ?? 0;
      final minute = int.tryParse(ampm.group(2) ?? '0') ?? 0;
      final period = ampm.group(3) ?? 'AM';
      if (period == 'PM' && hour != 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;
      return {
        'hour': hour,
        'minute': minute,
        'second': 0,
        'nano': 0,
      };
    }
  }
  return null;
}

String _fixTextEncoding(String value) {
  var out = value;
  const replacements = <String, String>{
    'Ã¢â‚¬â€': '-',
    'Ã¢â‚¬â€œ': '-',
    'Ã¢â€ â€™': '->',
    'â€”': '-',
    'â€“': '-',
    'â€¦': '...',
    'â€¢': '-',
    'Â·': ' - ',
    'â€˜': "'",
    'â€™': "'",
    'â€œ': '"',
    'â€': '"',
    'â‚¹': 'Rs ',
    '₹': 'Rs ',
    'â‚¬': '',
    '€': '',
    'Â': '',
  };
  replacements.forEach((bad, good) {
    out = out.replaceAll(bad, good);
  });
  out = out
      .replaceAll(RegExp(r'[ÃÂ]+'), '')
      .replaceAll(RegExp(r'[€]+'), '')
      .replaceAll('\uFFFD', '');
  return out.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _cleanText(dynamic value, {String fallback = ''}) {
  final raw = value?.toString() ?? '';
  if (raw.trim().isEmpty) return fallback;
  final cleaned = _fixTextEncoding(raw);
  return cleaned.isEmpty ? fallback : cleaned;
}

String? _cleanNullableText(dynamic value) {
  final raw = value?.toString();
  if (raw == null || raw.trim().isEmpty) return null;
  final cleaned = _fixTextEncoding(raw);
  return cleaned.isEmpty ? null : cleaned;
}

class ConsultantModel {
  final int id;
  final String name;
  final String email;
  final String? designation; // API field: designation
  final String? description;
  final double? charges; // API field: charges (not feePerSession)
  final double? rating;
  final int? reviewCount;
  final String? photoUrl;
  final Map<String, dynamic>? shiftStartTime; // {hour, minute, second, nano}
  final Map<String, dynamic>? shiftEndTime;
  final double? yearsOfExperience;
  final int? slotsDuration;
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
    this.yearsOfExperience,
    this.slotsDuration,
    this.skills = const [],
    this.isActive = true,
  });

  factory ConsultantModel.fromJson(Map<String, dynamic> json) =>
      ConsultantModel(
        id: json['id'] ?? 0,
        name: _cleanText(json['name'] ?? json['fullName'], fallback: ''),
        email: _cleanText(json['email'], fallback: ''),
        designation: _cleanNullableText(json['designation'] ?? json['title']),
        description: _cleanNullableText(json['description']),
        charges: _asDouble(json['charges'] ??
            json['feePerSession'] ??
            json['fee'] ??
            json['totalAmount']),
        rating: _asDouble(json['rating']),
        reviewCount: json['reviewCount'] ?? json['totalReviews'] ?? 0,
        photoUrl: _cleanNullableText(
          json['photoUrl'] ?? json['profilePhoto'] ?? json['profilePicture'],
        ),
        shiftStartTime: _timeToMap(json['shiftStartTime']),
        shiftEndTime: _timeToMap(json['shiftEndTime']),
        yearsOfExperience: _asDouble(json['yearsOfExperience']),
        slotsDuration: json['slotsDuration'] is num
            ? (json['slotsDuration'] as num).toInt()
            : int.tryParse('${json['slotsDuration'] ?? ''}'),
        skills: (json['skills'] as List<dynamic>? ?? [])
            .map((s) => s.toString())
            .toList(),
        isActive: json['isActive'] ?? json['active'] ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        if (designation != null) 'designation': designation,
        if (description != null) 'description': description,
        if (charges != null) 'charges': charges,
        if (rating != null) 'rating': rating,
        if (reviewCount != null) 'reviewCount': reviewCount,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (shiftStartTime != null) 'shiftStartTime': shiftStartTime,
        if (shiftEndTime != null) 'shiftEndTime': shiftEndTime,
        if (yearsOfExperience != null) 'yearsOfExperience': yearsOfExperience,
        if (slotsDuration != null) 'slotsDuration': slotsDuration,
        'skills': skills,
        'isActive': isActive,
      };

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
  final String timeRange; // e.g. "9:00 AM - 10:00 AM"
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
  final String slotDate; // "2026-03-20"
  final int masterTimeSlotId;
  final String timeRange; // "9:00 AM - 10:00 AM"
  final int durationMinutes;
  final String status; // AVAILABLE | BOOKED | UNAVAILABLE

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
        slotDate:
            json['slotDate']?.toString() ?? json['date']?.toString() ?? '',
        masterTimeSlotId: json['masterTimeSlotId'] ?? 0,
        timeRange:
            json['timeRange'] ?? json['slotTime'] ?? json['startTime'] ?? '',
        durationMinutes: json['durationMinutes'] ?? 60,
        status: json['status'] ?? 'AVAILABLE',
      );

  bool get isAvailable => status == 'AVAILABLE';

  Map<String, dynamic> toJson() => {
        'id': id,
        'consultantId': consultantId,
        'slotDate': slotDate,
        'masterTimeSlotId': masterTimeSlotId,
        'timeRange': timeRange,
        'durationMinutes': durationMinutes,
        'status': status,
      };
}

// ─── BOOKING ──────────────────────────────────────────────────────────────────
// API: POST /api/bookings  body: { consultantId, timeSlotId, amount, meetingMode, userNotes? }
//      GET /api/bookings/me
//      GET /api/bookings/consultant/{id}
//      GET /api/bookings/status/{status}
//      PUT /api/bookings/{id}  body: BookingUpdateRequest

class Booking {
  final int id;
  final String bookingStatus; // PENDING | CONFIRMED | COMPLETED | CANCELLED
  final String? paymentStatus; // PENDING | SUCCESS | FAILED
  final String? meetingMode; // PHYSICAL | ONLINE | PHONE
  final String? meetingLink;
  final String? meetingId;
  final String? meetingNotes;
  final String? userNotes;
  final double? amount;
  final double? discountAmount;
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
    this.discountAmount,
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
      if (j['consultantName'] != null)
        return _cleanNullableText(j['consultantName']);
      if (j['consultant'] is Map) {
        return _cleanNullableText(j['consultant']['name'] ??
            j['consultant']['fullName'] ??
            j['consultant']['username']);
      }
      return null;
    }

    String? extractClientName(Map<String, dynamic> j) {
      if (j['clientName'] != null) return _cleanNullableText(j['clientName']);
      if (j['userName'] != null) return _cleanNullableText(j['userName']);
      if (j['userIdentifier'] != null) {
        return _cleanNullableText(j['userIdentifier']);
      }
      if (j['userEmail'] != null) return _cleanNullableText(j['userEmail']);
      if (j['user'] is Map) {
        return _cleanNullableText(
          j['user']['name'] ??
              j['user']['fullName'] ??
              j['user']['identifier'] ??
              j['user']['email'],
        );
      }
      return null;
    }

    String? extractSlotDate(Map<String, dynamic> j) {
      final direct = j['slotDate'] ??
          j['slot_date'] ??
          j['date'] ??
          j['bookingDate'] ??
          j['booking_date'] ??
          j['scheduledDate'] ??
          j['scheduled_date'] ??
          j['timeSlotDate'] ??
          j['time_slot_date'] ??
          j['meetingDate'] ??
          j['sessionDate'] ??
          j['preferredDate'] ??
          j['preferred_date'];
      if (direct != null) return direct.toString().trim();
      final scheduledAt =
          (j['scheduledAt'] ?? j['scheduled_at'] ?? '').toString().trim();
      if (scheduledAt.isNotEmpty) {
        final parsed = DateTime.tryParse(scheduledAt);
        if (parsed != null) {
          return parsed.toIso8601String().split('T').first;
        }
      }
      if (j['timeSlot'] is Map) {
        return j['timeSlot']['slotDate']?.toString().trim() ??
            j['timeSlot']['slot_date']?.toString().trim() ??
            j['timeSlot']['date']?.toString().trim();
      }
      return null;
    }

    String? extractTimeRange(Map<String, dynamic> j) {
      String formatTimeValue(dynamic raw) {
        final fromMap = _timeToMap(raw);
        if (fromMap != null) {
          final hour = (fromMap['hour'] as num?)?.toInt() ?? 0;
          final minute = (fromMap['minute'] as num?)?.toInt() ?? 0;
          final period = hour >= 12 ? 'PM' : 'AM';
          final hour12 = hour % 12 == 0 ? 12 : hour % 12;
          return '$hour12:${minute.toString().padLeft(2, '0')} $period';
        }
        return raw?.toString().trim() ?? '';
      }

      String? mergeStartEnd(dynamic start, dynamic end) {
        final s = formatTimeValue(start);
        final e = formatTimeValue(end);
        if (s.isNotEmpty && e.isNotEmpty) return '$s - $e';
        if (s.isNotEmpty) return s;
        return e.isNotEmpty ? e : null;
      }

      final directRange = _cleanNullableText(
        j['timeRange'] ??
            j['scheduledTimeRange'] ??
            j['scheduled_time_range'] ??
            j['preferredTimeRange'] ??
            j['preferred_time_range'] ??
            j['slotTime'] ??
            j['slot_time'] ??
            j['meetingTime'] ??
            j['sessionTime'],
      );
      if (directRange != null) return directRange;

      final startEnd = mergeStartEnd(
        j['scheduledTime'] ?? j['scheduled_time'] ?? j['startTime'],
        j['endTime'] ?? j['slotEndTime'],
      );
      if (startEnd != null) return startEnd;

      if (j['timeSlot'] is Map) {
        final slot = j['timeSlot'] as Map;
        final slotRange = _cleanNullableText(
          slot['timeRange'] ??
              slot['scheduledTimeRange'] ??
              slot['slotTime'] ??
              slot['slot_time'],
        );
        if (slotRange != null) return slotRange;
        return mergeStartEnd(slot['startTime'], slot['endTime']);
      }
      return _cleanNullableText(j['startTime'] ?? j['slotStartTime']);
    }

    return Booking(
      id: json['id'] ?? 0,
      bookingStatus: _cleanText(
        json['bookingStatus'] ?? json['status'],
        fallback: 'PENDING',
      ),
      paymentStatus: _cleanNullableText(json['paymentStatus']),
      meetingMode: _cleanNullableText(json['meetingMode']),
      meetingLink: _cleanNullableText(json['meetingLink'] ?? json['joinUrl']),
      meetingId: _cleanNullableText(json['meetingId']),
      meetingNotes: _cleanNullableText(json['meetingNotes']),
      userNotes: _cleanNullableText(json['userNotes']),
      amount: _asDouble(
        json['totalAmount'] ??
            json['amount'] ??
            json['charges'] ??
            json['fee'] ??
            json['sessionAmount'] ??
            json['baseAmount'],
      ),
      discountAmount: _asDouble(json['discountAmount']),
      timeSlotId: json['timeSlotId'] ?? json['slotId'],
      consultantId: json['consultantId'],
      consultantName: extractConsultantName(json),
      userId: json['userId'],
      clientName: extractClientName(json),
      slotDate: _cleanNullableText(extractSlotDate(json)),
      timeRange: _cleanNullableText(extractTimeRange(json)),
      createdAt: json['createdAt']?.toString(),
    );
  }

  bool get isExpired {
    if (slotDate == null) return false;
    try {
      return DateTime.parse(slotDate!)
          .isBefore(DateTime.now().subtract(const Duration(days: 1)));
    } catch (_) {
      return false;
    }
  }

  bool get isPending => bookingStatus == 'PENDING';
  bool get isConfirmed => bookingStatus == 'CONFIRMED';
  bool get isCompleted => bookingStatus == 'COMPLETED';
  bool get isCancelled => bookingStatus == 'CANCELLED';

  Map<String, dynamic> toJson() => {
        'id': id,
        'bookingStatus': bookingStatus,
        'status': bookingStatus,
        if (paymentStatus != null) 'paymentStatus': paymentStatus,
        if (meetingMode != null) 'meetingMode': meetingMode,
        if (meetingLink != null) 'meetingLink': meetingLink,
        if (meetingId != null) 'meetingId': meetingId,
        if (meetingNotes != null) 'meetingNotes': meetingNotes,
        if (userNotes != null) 'userNotes': userNotes,
        if (amount != null) 'totalAmount': amount,
        if (discountAmount != null) 'discountAmount': discountAmount,
        if (timeSlotId != null) 'timeSlotId': timeSlotId,
        if (consultantId != null) 'consultantId': consultantId,
        if (consultantName != null) 'consultantName': consultantName,
        if (userId != null) 'userId': userId,
        if (clientName != null) 'clientName': clientName,
        if (slotDate != null) 'slotDate': slotDate,
        if (timeRange != null) 'timeRange': timeRange,
        if (createdAt != null) 'createdAt': createdAt,
      };
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
  final String? ticketNumber;
  final String category; // API uses 'category' not 'title'
  final String? description;
  final String? attachmentUrl;
  final String
      status; // NEW | OPEN | IN_PROGRESS | PENDING | RESOLVED | CLOSED | ESCALATED
  final String priority; // LOW | MEDIUM | HIGH | URGENT | CRITICAL
  final int? userId;
  final String? userName;
  final int? consultantId;
  final String? consultantName;
  final String? firstResponseAt;
  final String? resolvedAt;
  final String? closedAt;
  final int? feedbackRating;
  final String? feedbackText;
  final String? createdAt;
  final String? updatedAt;
  final String? slaRespondBy; // ISO datetime string
  final String? slaResolveBy; // ISO datetime string
  final bool slaBreached;
  final bool escalated;
  final int? slaHours;
  final List<TicketComment> comments;

  Ticket({
    required this.id,
    this.ticketNumber,
    required this.category,
    this.description,
    this.attachmentUrl,
    required this.status,
    required this.priority,
    this.userId,
    this.userName,
    this.consultantId,
    this.consultantName,
    this.firstResponseAt,
    this.resolvedAt,
    this.closedAt,
    this.feedbackRating,
    this.feedbackText,
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

  Map<String, dynamic> toJson() => {
        'id': id,
        if (ticketNumber != null) 'ticketNumber': ticketNumber,
        'category': category,
        'title': category,
        if (description != null) 'description': description,
        if (attachmentUrl != null) 'attachmentUrl': attachmentUrl,
        'status': status,
        'priority': priority,
        if (userId != null) 'userId': userId,
        if (userName != null) 'userName': userName,
        if (consultantId != null) 'consultantId': consultantId,
        if (consultantName != null) 'consultantName': consultantName,
        if (firstResponseAt != null) 'firstResponseAt': firstResponseAt,
        if (resolvedAt != null) 'resolvedAt': resolvedAt,
        if (closedAt != null) 'closedAt': closedAt,
        if (feedbackRating != null) 'feedbackRating': feedbackRating,
        if (feedbackText != null) 'feedbackText': feedbackText,
        if (createdAt != null) 'createdAt': createdAt,
        if (updatedAt != null) 'updatedAt': updatedAt,
        if (slaRespondBy != null) 'slaRespondBy': slaRespondBy,
        if (slaResolveBy != null) 'slaResolveBy': slaResolveBy,
        'slaBreached': slaBreached,
        'escalated': escalated,
        if (slaHours != null) 'slaHours': slaHours,
        'comments': comments.map((c) => c.toJson()).toList(),
      };

  static String _normalizeStatus(dynamic value) {
    final raw = _cleanText(value, fallback: 'NEW')
        .toUpperCase()
        .replaceAll('-', '_')
        .replaceAll(RegExp(r'\s+'), '_');
    const aliases = <String, String>{
      'NEW': 'NEW',
      'OPEN': 'OPEN',
      'IN_PROGRESS': 'IN_PROGRESS',
      'INPROGRESS': 'IN_PROGRESS',
      'PENDING': 'PENDING',
      'RESOLVED': 'RESOLVED',
      'CLOSED': 'CLOSED',
      'ESCALATED': 'ESCALATED',
      'ESCALATE': 'ESCALATED',
    };
    return aliases[raw] ?? raw;
  }

  static String _normalizePriority(dynamic value) {
    final raw = _cleanText(value, fallback: 'MEDIUM')
        .toUpperCase()
        .replaceAll('-', '_')
        .replaceAll(RegExp(r'\s+'), '_');
    const aliases = <String, String>{
      'LOW': 'LOW',
      'MEDIUM': 'MEDIUM',
      'NORMAL': 'MEDIUM',
      'HIGH': 'HIGH',
      'URGENT': 'URGENT',
      'CRITICAL': 'CRITICAL',
    };
    return aliases[raw] ?? raw;
  }

  factory Ticket.fromJson(Map<String, dynamic> json) => Ticket(
        id: json['id'] ?? 0,
        ticketNumber: _cleanNullableText(
          json['ticketNumber'] ?? json['ticketNo'] ?? json['referenceNumber'],
        ),
        category: _cleanText(
          json['categoryName'] ??
              json['category'] ??
              json['title'] ??
              json['subject'] ??
              (json['ticketCategory'] is Map
                  ? json['ticketCategory']['name']
                  : null) ??
              (json['category'] is Map ? json['category']['name'] : null),
          fallback: 'General',
        ),
        description: _cleanNullableText(json['description'] ?? json['body']),
        attachmentUrl: _cleanNullableText(
          json['attachmentUrl'] ?? json['attachment'] ?? json['fileUrl'],
        ),
        status: _normalizeStatus(json['status']),
        priority: _normalizePriority(json['priority']),
        userId: json['userId'] ?? json['user']?['id'],
        userName: _cleanNullableText(
          json['userName'] ??
              json['user']?['name'] ??
              json['user']?['fullName'] ??
              json['user']?['identifier'] ??
              json['clientName'],
        ),
        consultantId: json['consultantId'] ?? json['assignedTo'],
        consultantName: _cleanNullableText(
          json['consultantName'] ??
              json['assignedToName'] ??
              json['consultant']?['name'] ??
              json['consultant']?['fullName'],
        ),
        firstResponseAt:
            (json['firstResponseAt'] ?? json['firstRespondedAt'])?.toString(),
        resolvedAt: json['resolvedAt']?.toString(),
        closedAt: json['closedAt']?.toString(),
        feedbackRating: json['feedbackRating'] is num
            ? (json['feedbackRating'] as num).toInt()
            : int.tryParse('${json['feedbackRating'] ?? ''}'),
        feedbackText: _cleanNullableText(
          json['feedbackText'] ?? json['feedbackComment'] ?? json['review'],
        ),
        createdAt: json['createdAt']?.toString(),
        updatedAt: json['updatedAt']?.toString(),
        slaRespondBy: json['slaRespondBy']?.toString(),
        slaResolveBy: json['slaResolveBy']?.toString(),
        slaBreached: _toBool(
          json['slaBreached'] ?? json['isSlaBreached'],
          fallback: false,
        ),
        escalated: _toBool(
          json['escalated'] ?? json['isEscalated'],
          fallback: false,
        ),
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
        if (slaBreached || now.isAfter(deadline))
          return SlaInfo(status: 'breached', hoursRemaining: remaining);
        final slaMap = {
          'LOW': 72,
          'MEDIUM': 24,
          'HIGH': 8,
          'URGENT': 4,
          'CRITICAL': 2
        };
        final maxHours = slaHours ?? slaMap[priority.toUpperCase()] ?? 48;
        if (remaining <= maxHours * 0.25)
          return SlaInfo(status: 'warning', hoursRemaining: remaining);
        return SlaInfo(status: 'ok', hoursRemaining: remaining);
      } catch (_) {}
    }
    // Fallback: calculate from createdAt
    if (createdAt == null)
      return SlaInfo(status: 'unknown', hoursRemaining: null);
    try {
      final slaMap = {
        'LOW': 72,
        'MEDIUM': 24,
        'HIGH': 8,
        'URGENT': 4,
        'CRITICAL': 2
      };
      final maxHours = slaHours ?? slaMap[priority.toUpperCase()] ?? 48;
      final created = DateTime.parse(createdAt!);
      final deadline = created.add(Duration(hours: maxHours));
      final now = DateTime.now();
      final remaining = deadline.difference(now).inHours;
      if (now.isAfter(deadline))
        return SlaInfo(status: 'breached', hoursRemaining: remaining);
      if (remaining <= maxHours * 0.25)
        return SlaInfo(status: 'warning', hoursRemaining: remaining);
      return SlaInfo(status: 'ok', hoursRemaining: remaining);
    } catch (_) {
      return SlaInfo(status: 'unknown', hoursRemaining: null);
    }
  }
}

class SlaInfo {
  final String status; // ok | warning | breached | unknown
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
  final bool isConsultantReply; // API field name
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
        message: _cleanText(
          json['message'] ?? json['content'] ?? json['body'],
          fallback: '',
        ),
        senderId: json['senderId'],
        authorName: _cleanNullableText(
          json['authorName'] ??
              json['senderName'] ??
              json['userName'] ??
              json['consultantName'] ??
              json['author']?['name'],
        ),
        authorRole: _cleanNullableText(json['authorRole'] ?? json['role']),
        isConsultantReply: json['isConsultantReply'] ??
            json['consultantReply'] ??
            json['isInternal'] ??
            json['internal'] ??
            false,
        createdAt: (json['createdAt'] ??
                json['timestamp'] ??
                json['createdDate'] ??
                json['date'])
            ?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'ticketId': ticketId,
        'message': message,
        'senderId': senderId,
        'authorName': authorName,
        'authorRole': authorRole,
        'isConsultantReply': isConsultantReply,
        'createdAt': createdAt,
        'timestamp': createdAt,
      };
}

// ─── TICKET NOTE ──────────────────────────────────────────────────────────────
// API: GET/POST /api/tickets/{id}/notes  body: { content }

class TicketNote {
  final int id;
  final String content;
  final int? authorId;
  final String? authorName;
  final String? createdAt;

  TicketNote({
    required this.id,
    required this.content,
    this.authorId,
    this.authorName,
    this.createdAt,
  });

  factory TicketNote.fromJson(Map<String, dynamic> json) => TicketNote(
        id: json['id'] ?? 0,
        content: _cleanText(
          json['content'] ?? json['message'] ?? json['noteText'],
          fallback: '',
        ),
        authorId: json['authorId'] is num
            ? (json['authorId'] as num).toInt()
            : int.tryParse('${json['authorId'] ?? ''}'),
        authorName: _cleanNullableText(
          json['authorName'] ??
              json['userName'] ??
              json['consultantName'] ??
              json['author']?['name'],
        ),
        createdAt: (json['createdAt'] ??
                json['timestamp'] ??
                json['createdDate'] ??
                json['date'])
            ?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        if (authorId != null) 'authorId': authorId,
        'authorName': authorName,
        'createdAt': createdAt,
        'timestamp': createdAt,
        'noteText': content, // for backward compat in UI
      };
}

// ─── FEEDBACK ─────────────────────────────────────────────────────────────────
// API: POST /api/feedbacks  body: { userId, consultantId, meetingId, bookingId, rating, comments }
//      GET /api/feedbacks/consultant/{id}
//      GET /api/feedbacks/booking/{id}

class Feedback {
  final int id;
  final int rating; // 1-5
  final String? comments; // API field: comments (not comment)
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
        rating: json['rating'] is num
            ? (json['rating'] as num).toInt()
            : int.tryParse('${json['rating'] ?? ''}') ?? 0,
        comments: _cleanNullableText(
          json['comments'] ?? json['comment'] ?? json['review'],
        ),
        clientName: _cleanNullableText(
          json['clientName'] ??
              json['userName'] ??
              json['name'] ??
              json['user']?['name'] ??
              json['user']?['fullName'] ??
              json['user']?['identifier'],
        ),
        userId: json['userId'],
        consultantId: json['consultantId'],
        bookingId: json['bookingId'],
        meetingId: json['meetingId'],
        createdAt: json['createdAt']?.toString(),
      );

  Feedback copyWith({
    int? id,
    int? rating,
    String? comments,
    String? clientName,
    int? userId,
    int? consultantId,
    int? bookingId,
    int? meetingId,
    String? createdAt,
  }) =>
      Feedback(
        id: id ?? this.id,
        rating: rating ?? this.rating,
        comments: comments ?? this.comments,
        clientName: clientName ?? this.clientName,
        userId: userId ?? this.userId,
        consultantId: consultantId ?? this.consultantId,
        bookingId: bookingId ?? this.bookingId,
        meetingId: meetingId ?? this.meetingId,
        createdAt: createdAt ?? this.createdAt,
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

  factory DashboardAnalytics.fromJson(Map<String, dynamic> json) =>
      DashboardAnalytics(
        totalTickets: json['totalTickets'] ?? 0,
        openTickets: json['openTickets'] ?? 0,
        resolvedTickets: json['resolvedTickets'] ?? 0,
        slaBreaches: json['slaBreaches'] ?? 0,
        avgResponseTime: (json['avgResponseTime'] ?? 0).toDouble(),
        avgResolutionTime: (json['avgResolutionTime'] ?? 0).toDouble(),
        avgRating: (json['avgRating'] ?? 0).toDouble(),
        ticketsByStatus: Map<String, int>.from(json['ticketsByStatus'] ?? {}),
        ticketsByPriority:
            Map<String, int>.from(json['ticketsByPriority'] ?? {}),
        ticketsByCategory:
            Map<String, int>.from(json['ticketsByCategory'] ?? {}),
      );
}

class DashboardSummary {
  final String label;
  final int count;

  DashboardSummary({required this.label, required this.count});

  factory DashboardSummary.fromJson(Map<String, dynamic> json) =>
      DashboardSummary(
        label: json['label']?.toString() ?? '',
        count: json['count'] ?? 0,
      );
}

// ─── NOTIFICATION ─────────────────────────────────────────────────────────────
// API: GET /api/notifications
//      PUT /api/notifications/{id}/read

bool _notificationIsRead(dynamic raw) {
  if (raw is bool) return raw;
  if (raw is num) return raw != 0;
  final value = raw?.toString().trim().toLowerCase() ?? '';
  return value == 'true' ||
      value == '1' ||
      value == 'yes' ||
      value == 'read' ||
      value == 'opened' ||
      value == 'seen' ||
      value == 'viewed';
}

class AppNotification {
  final int id;
  final String title;
  final String body;
  final String type; // ticket | booking | system
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
        'message': body,
        'type': type,
        'isRead': isRead,
        'read': isRead,
        'createdAt': createdAt.toIso8601String(),
        if (data != null) 'data': data,
      };

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] is num
            ? (json['id'] as num).toInt()
            : int.tryParse('${json['id'] ?? 0}') ?? 0,
        title: (json['title'] ??
                    json['subject'] ??
                    json['heading'] ??
                    json['notificationTitle'] ??
                    (json['data'] is Map
                        ? (json['data']['title'] ??
                            json['data']['subject'] ??
                            json['data']['heading'])
                        : null) ??
                    '')
                .toString()
                .trim()
                .isNotEmpty
            ? (json['title'] ??
                    json['subject'] ??
                    json['heading'] ??
                    json['notificationTitle'] ??
                    (json['data'] is Map
                        ? (json['data']['title'] ??
                            json['data']['subject'] ??
                            json['data']['heading'])
                        : ''))
                .toString()
            : _notificationTitle(
                json['type']?.toString() ?? 'system', json['ticketId']),
        body: (json['body'] ??
                json['message'] ??
                json['content'] ??
                json['description'] ??
                json['text'] ??
                json['notificationMessage'] ??
                (json['data'] is Map
                    ? (json['data']['body'] ??
                        json['data']['message'] ??
                        json['data']['content'] ??
                        json['data']['description'] ??
                        json['data']['text'])
                    : null) ??
                '')
            .toString(),
        type: json['type']?.toString() ?? 'system',
        isRead: _notificationIsRead(
          json['isRead'] ??
              json['read'] ??
              json['opened'] ??
              json['seen'] ??
              json['viewed'] ??
              json['status'],
        ),
        createdAt: (json['createdAt'] ??
                    json['updatedAt'] ??
                    json['timestamp'] ??
                    json['createdOn']) !=
                null
            ? DateTime.tryParse((json['createdAt'] ??
                        json['updatedAt'] ??
                        json['timestamp'] ??
                        json['createdOn'])
                    .toString()) ??
                DateTime.now()
            : DateTime.now(),
        data: json['data'] is Map
            ? Map<String, dynamic>.from(json['data'])
            : json['payload'] is Map
                ? Map<String, dynamic>.from(json['payload'])
                : {
                    if (json['ticketId'] != null)
                      'ticketId': json['ticketId'] is num
                          ? (json['ticketId'] as num).toInt()
                          : int.tryParse('${json['ticketId']}'),
                    if (json['bookingId'] != null)
                      'bookingId': json['bookingId'] is num
                          ? (json['bookingId'] as num).toInt()
                          : int.tryParse('${json['bookingId']}'),
                  },
      );
}

String _notificationTitle(String type, dynamic ticketId) {
  final normalized = type.toLowerCase();
  final suffix = ticketId != null ? ' #$ticketId' : '';
  if (normalized.contains('assignment')) return 'New Assignment$suffix';
  if (normalized.contains('booking')) return 'Booking Update$suffix';
  if (normalized.contains('ticket')) return 'Ticket Update$suffix';
  if (normalized.contains('escalat')) return 'Escalation Alert$suffix';
  return 'Notification$suffix';
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

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) =>
      SubscriptionPlan(
        id: json['id'] ?? 0,
        name: json['name'] ?? '',
        originalPrice: (json['originalPrice'] ?? json['price'] ?? 0).toDouble(),
        discountPrice: json['discountPrice'] != null
            ? (json['discountPrice']).toDouble()
            : null,
        features: json['features'],
        tag: json['tag'],
      );

  double get effectivePrice => discountPrice ?? originalPrice;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'originalPrice': originalPrice,
        if (discountPrice != null) 'discountPrice': discountPrice,
        if (features != null) 'features': features,
        if (tag != null) 'tag': tag,
      };
}

// ─── CANNED RESPONSE ──────────────────────────────────────────────────────────
// API: GET/POST /api/admin/config/canned-responses
//      DELETE /api/admin/config/canned-responses/{id}

class CannedResponse {
  final int id;
  final String title;
  final String content; // API field: content (not message)
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

  TicketCategory(
      {required this.id,
      required this.name,
      this.isActive = true,
      this.description});

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
  final String dayOfWeek; // MONDAY | TUESDAY | ...
  final String openTime; // "09:00"
  final String closeTime; // "18:00"
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
        dayOfWeek: json['dayOfWeek']?.toString() ?? '',
        openTime: _timeToMap(json['startTime']) != null
            ? '${(_timeToMap(json['startTime'])!['hour'] ?? 9).toString().padLeft(2, '0')}:${(_timeToMap(json['startTime'])!['minute'] ?? 0).toString().padLeft(2, '0')}'
            : json['openTime']?.toString() ?? '09:00',
        closeTime: _timeToMap(json['endTime']) != null
            ? '${(_timeToMap(json['endTime'])!['hour'] ?? 18).toString().padLeft(2, '0')}:${(_timeToMap(json['endTime'])!['minute'] ?? 0).toString().padLeft(2, '0')}'
            : json['closeTime']?.toString() ?? '18:00',
        isOpen: json['isWorkingDay'] ??
            json['workingDay'] ??
            json['isOpen'] ??
            json['open'] ??
            true,
      );
}

// ─── HOLIDAY ──────────────────────────────────────────────────────────────────
// API: GET/POST /api/admin/settings/holidays
//      DELETE /api/admin/settings/holidays/{id}

class Holiday {
  final int id;
  final String name;
  final String date; // "2026-01-26"

  Holiday({required this.id, required this.name, required this.date});

  factory Holiday.fromJson(Map<String, dynamic> json) => Holiday(
        id: json['id'] ?? 0,
        name: json['name'] ?? '',
        date: json['holidayDate']?.toString() ?? json['date']?.toString() ?? '',
      );
}

// ─── ONBOARDING ───────────────────────────────────────────────────────────────
// API: POST /api/onboarding  (multipart/form-data)
//      GET/PUT/DELETE /api/onboarding/{id}

class OnboardingProfile {
  final int id;
  final String name;
  final String? dob;
  final String? identifier; // PAN or Aadhaar
  final String? email;
  final String? phoneNumber;
  final String? location;
  final bool subscribed;
  final int? subscriptionPlanId;
  final String? subscriptionPlanName;
  final List<Map<String, dynamic>> incomeItems;
  final List<Map<String, dynamic>> expenseItems;
  final String? photoUrl;
  final String? designation;
  final String? organizationName;
  final String? memberSince;

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
    this.subscriptionPlanName,
    this.incomeItems = const [],
    this.expenseItems = const [],
    this.photoUrl,
    this.designation,
    this.organizationName,
    this.memberSince,
  });

  factory OnboardingProfile.fromJson(Map<String, dynamic> json) =>
      OnboardingProfile(
        id: json['id'] ?? json['userId'] ?? 0,
        name: json['name'] ?? '',
        dob: json['dob']?.toString(),
        identifier: json['identifier']?.toString(),
        email: json['email'],
        phoneNumber: json['phoneNumber']?.toString(),
        location: json['location'],
        subscribed: json['subscribed'] ?? false,
        subscriptionPlanId: json['subscriptionPlanId'] ??
            (json['subscriptionPlan'] is Map
                ? json['subscriptionPlan']['id']
                : null),
        subscriptionPlanName: json['subscriptionPlanName']?.toString() ??
            (json['subscriptionPlan'] is Map
                ? json['subscriptionPlan']['name']?.toString()
                : null),
        incomeItems: (json['incomeItems'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e))
            .toList(),
        expenseItems: (json['expenseItems'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e))
            .toList(),
        photoUrl: json['profileImageUrl'] ??
            json['photoUrl'] ??
            json['profilePicture'],
        designation: json['designation']?.toString(),
        organizationName: json['organizationName']?.toString(),
        memberSince: json['memberSince']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': id,
        'name': name,
        if (dob != null) 'dob': dob,
        if (identifier != null) 'identifier': identifier,
        if (email != null) 'email': email,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
        if (location != null) 'location': location,
        'subscribed': subscribed,
        if (subscriptionPlanId != null)
          'subscriptionPlanId': subscriptionPlanId,
        if (subscriptionPlanName != null)
          'subscriptionPlanName': subscriptionPlanName,
        'incomeItems': incomeItems,
        'expenseItems': expenseItems,
        if (photoUrl != null) 'profileImageUrl': photoUrl,
        if (designation != null) 'designation': designation,
        if (organizationName != null) 'organizationName': organizationName,
        if (memberSince != null) 'memberSince': memberSince,
      };
}
