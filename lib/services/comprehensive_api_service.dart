// lib/services/comprehensive_api_service.dart
// ════════════════════════════════════════════════════════════════════════════
// Comprehensive API Service - Maps ALL backend endpoints for easy integration
// Covers: Auth, Users, Bookings, Tickets, Consultants, etc.
// ════════════════════════════════════════════════════════════════════════════

import 'package:finadvise/api_client.dart';

class ComprehensiveApiService {
  final ApiClient _apiClient = ApiClient();

  // ─────────────────────────────────────────────────────────────────────────
  // AUTHENTICATION ENDPOINTS
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> authenticate(String email, String password) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/users/authenticate',
        data: {'email': email, 'password': password},
      );
      return response.data as Map<String, dynamic>?;
    } catch (e) {
      print('Error authenticating: $e');
      return null;
    }
  }

  Future<bool> sendRegistrationOtp(String email) async {
    try {
      await _apiClient.dio.post('/api/users/send-otp', data: {'email': email});
      return true;
    } catch (e) {
      print('Error sending OTP: $e');
      return false;
    }
  }

  Future<bool> checkOtp(String email, String otp) async {
    try {
      await _apiClient.dio.post(
        '/api/users/check-otp',
        data: {'email': email, 'otp': otp},
      );
      return true;
    } catch (e) {
      print('Error checking OTP: $e');
      return false;
    }
  }

  Future<bool> forgotPassword(String email) async {
    try {
      await _apiClient.dio.post(
        '/api/users/forgot-password',
        data: {'email': email},
      );
      return true;
    } catch (e) {
      print('Error initiating password reset: $e');
      return false;
    }
  }

  Future<bool> resetPassword(String email, String token, String newPassword) async {
    try {
      await _apiClient.dio.post(
        '/api/users/reset-password',
        data: {'email': email, 'token': token, 'newPassword': newPassword},
      );
      return true;
    } catch (e) {
      print('Error resetting password: $e');
      return false;
    }
  }

  Future<bool> changePassword(String oldPassword, String newPassword) async {
    try {
      await _apiClient.dio.put(
        '/api/users/change-password',
        data: {'oldPassword': oldPassword, 'newPassword': newPassword},
      );
      return true;
    } catch (e) {
      print('Error changing password: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // USER ENDPOINTS
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getUserProfile(int userId) async {
    try {
      final response = await _apiClient.dio.get('/api/users/$userId');
      return response.data as Map<String, dynamic>?;
    } catch (e) {
      print('Error fetching user profile: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> updateUserProfile(
    int userId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _apiClient.dio.put('/api/users/$userId', data: data);
      return response.data as Map<String, dynamic>?;
    } catch (e) {
      print('Error updating user profile: $e');
      return null;
    }
  }

  Future<List<dynamic>> getAllUsers({int page = 0, int size = 10}) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/users',
        queryParameters: {'page': page, 'size': size},
      );
      final list = response.data is List ? response.data : response.data['content'] ?? [];
      return list as List<dynamic>;
    } catch (e) {
      print('Error fetching users: $e');
      return [];
    }
  }

  Future<bool> deleteUser(int userId) async {
    try {
      await _apiClient.dio.delete('/api/users/$userId');
      return true;
    } catch (e) {
      print('Error deleting user: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // USER REGISTRATION ENDPOINTS
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> registerUser(Map<String, dynamic> registrationData) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/users/register',
        data: registrationData,
      );
      return response.data as Map<String, dynamic>?;
    } catch (e) {
      print('Error registering user: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> registerConsultant(
    Map<String, dynamic> registrationData,
  ) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/users/register-consultant',
        data: registrationData,
      );
      return response.data as Map<String, dynamic>?;
    } catch (e) {
      print('Error registering consultant: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> updateUserRegistration(
    int userId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _apiClient.dio.put(
        '/api/users/registration/$userId',
        data: data,
      );
      return response.data as Map<String, dynamic>?;
    } catch (e) {
      print('Error updating registration: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BOOKING ENDPOINTS
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<dynamic>> getAllBookings({
    int page = 0,
    int size = 10,
    String? status,
  }) async {
    try {
      final params = <String, dynamic>{'page': page, 'size': size};
      if (status != null) params['status'] = status;
      final response = await _apiClient.dio.get(
        '/api/bookings',
        queryParameters: params,
      );
      final list = response.data is List ? response.data : response.data['content'] ?? [];
      return list as List<dynamic>;
    } catch (e) {
      print('Error fetching bookings: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> createBooking(Map<String, dynamic> bookingData) async {
    try {
      final response = await _apiClient.dio.post('/api/bookings', data: bookingData);
      return response.data as Map<String, dynamic>?;
    } catch (e) {
      print('Error creating booking: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getBookingById(int bookingId) async {
    try {
      final response = await _apiClient.dio.get('/api/bookings/$bookingId');
      return response.data as Map<String, dynamic>?;
    } catch (e) {
      print('Error fetching booking: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> updateBooking(
    int bookingId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _apiClient.dio.put('/api/bookings/$bookingId', data: data);
      return response.data as Map<String, dynamic>?;
    } catch (e) {
      print('Error updating booking: $e');
      return null;
    }
  }

  Future<bool> cancelBooking(int bookingId) async {
    try {
      await _apiClient.dio.put('/api/bookings/$bookingId/cancel');
      return true;
    } catch (e) {
      print('Error cancelling booking: $e');
      return false;
    }
  }

  Future<List<dynamic>> getUserBookings(int userId) async {
    try {
      final response = await _apiClient.dio.get('/api/bookings/user/$userId');
      final list = response.data is List ? response.data : response.data['content'] ?? [];
      return list as List<dynamic>;
    } catch (e) {
      print('Error fetching user bookings: $e');
      return [];
    }
  }

  Future<List<dynamic>> getConsultantBookings(int consultantId) async {
    try {
      final response = await _apiClient.dio.get('/api/bookings/consultant/$consultantId');
      final list = response.data is List ? response.data : response.data['content'] ?? [];
      return list as List<dynamic>;
    } catch (e) {
      print('Error fetching consultant bookings: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CONSULTANT ENDPOINTS
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<dynamic>> getAllConsultants({
    int page = 0,
    int size = 10,
    String? skill,
  }) async {
    try {
      final params = <String, dynamic>{'page': page, 'size': size};
      if (skill != null) params['skill'] = skill;
      final response = await _apiClient.dio.get(
        '/api/consultants',
        queryParameters: params,
      );
      final list = response.data is List ? response.data : response.data['content'] ?? [];
      return list as List<dynamic>;
    } catch (e) {
      print('Error fetching consultants: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getConsultantById(int consultantId) async {
    try {
      final response = await _apiClient.dio.get('/api/consultants/$consultantId');
      return response.data as Map<String, dynamic>?;
    } catch (e) {
      print('Error fetching consultant: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> createConsultant(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.dio.post('/api/consultants', data: data);
      return response.data as Map<String, dynamic>?;
    } catch (e) {
      print('Error creating consultant: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> updateConsultant(
    int consultantId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _apiClient.dio.put(
        '/api/consultants/$consultantId',
        data: data,
      );
      return response.data as Map<String, dynamic>?;
    } catch (e) {
      print('Error updating consultant: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TICKET ENDPOINTS
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<dynamic>> getAllTickets({
    int page = 0,
    int size = 10,
    String? status,
  }) async {
    try {
      final params = <String, dynamic>{'page': page, 'size': size};
      if (status != null) params['status'] = status;
      final response = await _apiClient.dio.get(
        '/api/tickets',
        queryParameters: params,
      );
      final list = response.data is List ? response.data : response.data['content'] ?? [];
      return list as List<dynamic>;
    } catch (e) {
      print('Error fetching tickets: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getTicketById(int ticketId) async {
    try {
      final response = await _apiClient.dio.get('/api/tickets/$ticketId');
      return response.data as Map<String, dynamic>?;
    } catch (e) {
      print('Error fetching ticket: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> createTicket(Map<String, dynamic> ticketData) async {
    try {
      final response = await _apiClient.dio.post('/api/tickets', data: ticketData);
      return response.data as Map<String, dynamic>?;
    } catch (e) {
      print('Error creating ticket: $e');
      return null;
    }
  }

  Future<bool> updateTicketStatus(int ticketId, String status) async {
    try {
      await _apiClient.dio.put(
        '/api/tickets/$ticketId/status',
        data: {'status': status},
      );
      return true;
    } catch (e) {
      print('Error updating ticket status: $e');
      return false;
    }
  }

  Future<bool> addTicketComment(int ticketId, String comment, {String? internalNote}) async {
    try {
      await _apiClient.dio.post(
        '/api/tickets/$ticketId/comments',
        data: {'comment': comment, 'internalNote': internalNote},
      );
      return true;
    } catch (e) {
      print('Error adding ticket comment: $e');
      return false;
    }
  }

  Future<bool> assignTicket(int ticketId, int consultantId) async {
    try {
      await _apiClient.dio.put(
        '/api/tickets/$ticketId/assign',
        data: {'assignedTo': consultantId},
      );
      return true;
    } catch (e) {
      print('Error assigning ticket: $e');
      return false;
    }
  }

  Future<List<dynamic>> getTicketsByConsultant(int consultantId) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/tickets/consultant/$consultantId',
      );
      final list = response.data is List ? response.data : response.data['content'] ?? [];
      return list as List<dynamic>;
    } catch (e) {
      print('Error fetching consultant tickets: $e');
      return [];
    }
  }

  Future<List<dynamic>> getTicketsByUser(int userId) async {
    try {
      final response = await _apiClient.dio.get('/api/tickets/user/$userId');
      final list = response.data is List ? response.data : response.data['content'] ?? [];
      return list as List<dynamic>;
    } catch (e) {
      print('Error fetching user tickets: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FEEDBACK ENDPOINTS
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<dynamic>> getAllFeedback({int page = 0, int size = 10}) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/feedback',
        queryParameters: {'page': page, 'size': size},
      );
      final list = response.data is List ? response.data : response.data['content'] ?? [];
      return list as List<dynamic>;
    } catch (e) {
      print('Error fetching feedback: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> createFeedback(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.dio.post('/api/feedback', data: data);
      return response.data as Map<String, dynamic>?;
    } catch (e) {
      print('Error creating feedback: $e');
      return null;
    }
  }

  Future<bool> deleteFeedback(int feedbackId) async {
    try {
      await _apiClient.dio.delete('/api/feedback/$feedbackId');
      return true;
    } catch (e) {
      print('Error deleting feedback: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // NOTIFICATION ENDPOINTS
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<dynamic>> getNotifications({int page = 0, int size = 10}) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/notifications',
        queryParameters: {'page': page, 'size': size},
      );
      final list = response.data is List ? response.data : response.data['content'] ?? [];
      return list as List<dynamic>;
    } catch (e) {
      print('Error fetching notifications: $e');
      return [];
    }
  }

  Future<bool> markNotificationAsRead(int notificationId) async {
    try {
      await _apiClient.dio.put('/api/notifications/$notificationId/read');
      return true;
    } catch (e) {
      print('Error marking notification as read: $e');
      return false;
    }
  }

  Future<bool> deleteNotification(int notificationId) async {
    try {
      await _apiClient.dio.delete('/api/notifications/$notificationId');
      return true;
    } catch (e) {
      print('Error deleting notification: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // OFFERS ENDPOINTS
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<dynamic>> getAllOffers({int page = 0, int size = 10}) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/offers',
        queryParameters: {'page': page, 'size': size},
      );
      final list = response.data is List ? response.data : response.data['content'] ?? [];
      return list as List<dynamic>;
    } catch (e) {
      print('Error fetching offers: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> createOffer(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.dio.post('/api/offers', data: data);
      return response.data as Map<String, dynamic>?;
    } catch (e) {
      print('Error creating offer: $e');
      return null;
    }
  }

  Future<bool> updateOffer(int offerId, Map<String, dynamic> data) async {
    try {
      await _apiClient.dio.put('/api/offers/$offerId', data: data);
      return true;
    } catch (e) {
      print('Error updating offer: $e');
      return false;
    }
  }

  Future<bool> deleteOffer(int offerId) async {
    try {
      await _apiClient.dio.delete('/api/offers/$offerId');
      return true;
    } catch (e) {
      print('Error deleting offer: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SUBSCRIPTION PLAN ENDPOINTS
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<dynamic>> getAllSubscriptionPlans() async {
    try {
      final response = await _apiClient.dio.get('/api/subscription-plans');
      final list = response.data is List ? response.data : response.data['content'] ?? [];
      return list as List<dynamic>;
    } catch (e) {
      print('Error fetching subscription plans: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getSubscriptionPlanById(int planId) async {
    try {
      final response = await _apiClient.dio.get('/api/subscription-plans/$planId');
      return response.data as Map<String, dynamic>?;
    } catch (e) {
      print('Error fetching subscription plan: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> createSubscriptionPlan(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.dio.post('/api/subscription-plans', data: data);
      return response.data as Map<String, dynamic>?;
    } catch (e) {
      print('Error creating subscription plan: $e');
      return null;
    }
  }

  Future<bool> updateSubscriptionPlan(int planId, Map<String, dynamic> data) async {
    try {
      await _apiClient.dio.put('/api/subscription-plans/$planId', data: data);
      return true;
    } catch (e) {
      print('Error updating subscription plan: $e');
      return false;
    }
  }

  Future<bool> deleteSubscriptionPlan(int planId) async {
    try {
      await _apiClient.dio.delete('/api/subscription-plans/$planId');
      return true;
    } catch (e) {
      print('Error deleting subscription plan: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TIME SLOT ENDPOINTS
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<dynamic>> getAllTimeSlots({int page = 0, int size = 10}) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/timeslots',
        queryParameters: {'page': page, 'size': size},
      );
      final list = response.data is List ? response.data : response.data['content'] ?? [];
      return list as List<dynamic>;
    } catch (e) {
      print('Error fetching time slots: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> createTimeSlot(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.dio.post('/api/timeslots', data: data);
      return response.data as Map<String, dynamic>?;
    } catch (e) {
      print('Error creating time slot: $e');
      return null;
    }
  }

  Future<bool> updateTimeSlot(int slotId, Map<String, dynamic> data) async {
    try {
      await _apiClient.dio.put('/api/timeslots/$slotId', data: data);
      return true;
    } catch (e) {
      print('Error updating time slot: $e');
      return false;
    }
  }

  Future<bool> deleteTimeSlot(int slotId) async {
    try {
      await _apiClient.dio.delete('/api/timeslots/$slotId');
      return true;
    } catch (e) {
      print('Error deleting time slot: $e');
      return false;
    }
  }

  Future<List<dynamic>> getConsultantTimeSlots(int consultantId) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/timeslots/consultant/$consultantId',
      );
      final list = response.data is List ? response.data : response.data['content'] ?? [];
      return list as List<dynamic>;
    } catch (e) {
      print('Error fetching consultant time slots: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MASTER TIME SLOT ENDPOINTS
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<dynamic>> getMasterTimeSlots() async {
    try {
      final response = await _apiClient.dio.get('/api/master-timeslots');
      final list = response.data is List ? response.data : response.data['content'] ?? [];
      return list as List<dynamic>;
    } catch (e) {
      print('Error fetching master time slots: $e');
      return [];
    }
  }

  Future<bool> createMasterTimeSlot(Map<String, dynamic> data) async {
    try {
      await _apiClient.dio.post('/api/master-timeslots', data: data);
      return true;
    } catch (e) {
      print('Error creating master time slot: $e');
      return false;
    }
  }

  Future<bool> updateMasterTimeSlot(int slotId, Map<String, dynamic> data) async {
    try {
      await _apiClient.dio.put('/api/master-timeslots/$slotId', data: data);
      return true;
    } catch (e) {
      print('Error updating master time slot: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SKILL MASTER ENDPOINTS
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<dynamic>> getAllSkills() async {
    try {
      final response = await _apiClient.dio.get('/api/skills');
      final list = response.data is List ? response.data : response.data['content'] ?? [];
      return list as List<dynamic>;
    } catch (e) {
      print('Error fetching skills: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> createSkill(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.dio.post('/api/skills', data: data);
      return response.data as Map<String, dynamic>?;
    } catch (e) {
      print('Error creating skill: $e');
      return null;
    }
  }

  Future<bool> updateSkill(int skillId, Map<String, dynamic> data) async {
    try {
      await _apiClient.dio.put('/api/skills/$skillId', data: data);
      return true;
    } catch (e) {
      print('Error updating skill: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // QUESTIONS & ANSWERS ENDPOINTS
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<dynamic>> getAllQuestions({int page = 0, int size = 10}) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/questions',
        queryParameters: {'page': page, 'size': size},
      );
      final list = response.data is List ? response.data : response.data['content'] ?? [];
      return list as List<dynamic>;
    } catch (e) {
      print('Error fetching questions: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> createQuestion(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.dio.post('/api/questions', data: data);
      return response.data as Map<String, dynamic>?;
    } catch (e) {
      print('Error creating question: $e');
      return null;
    }
  }

  Future<bool> submitAnswers(Map<String, dynamic> data) async {
    try {
      await _apiClient.dio.post('/api/answers', data: data);
      return true;
    } catch (e) {
      print('Error submitting answers: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CONTACT MESSAGE ENDPOINTS
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> sendContactMessage(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.dio.post('/api/contact-messages', data: data);
      return response.data as Map<String, dynamic>?;
    } catch (e) {
      print('Error sending contact message: $e');
      return null;
    }
  }

  Future<List<dynamic>> getContactMessages({int page = 0, int size = 10}) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/contact-messages',
        queryParameters: {'page': page, 'size': size},
      );
      final list = response.data is List ? response.data : response.data['content'] ?? [];
      return list as List<dynamic>;
    } catch (e) {
      print('Error fetching contact messages: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EMAIL TO TICKET ENDPOINTS
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> createEmailToTicketMapping(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/email-to-ticket',
        data: data,
      );
      return response.data as Map<String, dynamic>?;
    } catch (e) {
      print('Error creating email to ticket mapping: $e');
      return null;
    }
  }

  Future<List<dynamic>> getEmailToTicketMappings() async {
    try {
      final response = await _apiClient.dio.get('/api/email-to-ticket');
      final list = response.data is List ? response.data : response.data['content'] ?? [];
      return list as List<dynamic>;
    } catch (e) {
      print('Error fetching email to ticket mappings: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SPECIAL BOOKING ENDPOINTS
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> createSpecialBooking(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.dio.post('/api/special-bookings', data: data);
      return response.data as Map<String, dynamic>?;
    } catch (e) {
      print('Error creating special booking: $e');
      return null;
    }
  }

  Future<List<dynamic>> getAllSpecialBookings({int page = 0, int size = 10}) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/special-bookings',
        queryParameters: {'page': page, 'size': size},
      );
      final list = response.data is List ? response.data : response.data['content'] ?? [];
      return list as List<dynamic>;
    } catch (e) {
      print('Error fetching special bookings: $e');
      return [];
    }
  }

  Future<bool> updateSpecialBookingStatus(int bookingId, String status) async {
    try {
      await _apiClient.dio.put(
        '/api/special-bookings/$bookingId/status',
        data: {'status': status},
      );
      return true;
    } catch (e) {
      print('Error updating special booking status: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STATIC CONTENT ENDPOINTS
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<dynamic>> getStaticContent({String? type}) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/static-content',
        queryParameters: type != null ? {'type': type} : null,
      );
      final list = response.data is List ? response.data : response.data['content'] ?? [];
      return list as List<dynamic>;
    } catch (e) {
      print('Error fetching static content: $e');
      return [];
    }
  }

  Future<bool> createOrUpdateStaticContent(Map<String, dynamic> data) async {
    try {
      await _apiClient.dio.post('/api/static-content', data: data);
      return true;
    } catch (e) {
      print('Error creating/updating static content: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ANALYTICS ENDPOINTS
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getAnalyticsDashboard() async {
    try {
      final response = await _apiClient.dio.get('/api/analytics/dashboard');
      return response.data as Map<String, dynamic>?;
    } catch (e) {
      print('Error fetching analytics dashboard: $e');
      return null;
    }
  }

  Future<List<dynamic>> getAnalyticsTickets({int page = 0, int size = 10}) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/analytics/tickets/all',
        queryParameters: {'page': page, 'size': size},
      );
      final list = response.data is List ? response.data : response.data['content'] ?? [];
      return list as List<dynamic>;
    } catch (e) {
      print('Error fetching analytics tickets: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getAnalyticsRevenue({String? period}) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/analytics/revenue',
        queryParameters: period != null ? {'period': period} : null,
      );
      return response.data as Map<String, dynamic>?;
    } catch (e) {
      print('Error fetching analytics revenue: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ADMIN CONFIG ENDPOINTS
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<dynamic>> getTicketCategories() async {
    try {
      final response = await _apiClient.dio.get('/api/admin/config/categories');
      final list = response.data is List ? response.data : response.data['content'] ?? [];
      return list as List<dynamic>;
    } catch (e) {
      print('Error fetching ticket categories: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> createTicketCategory(String name) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/admin/config/categories',
        data: {'name': name},
      );
      return response.data as Map<String, dynamic>?;
    } catch (e) {
      print('Error creating ticket category: $e');
      return null;
    }
  }

  Future<bool> updateTicketCategory(int categoryId, String name) async {
    try {
      await _apiClient.dio.put(
        '/api/admin/config/categories/$categoryId',
        data: {'name': name},
      );
      return true;
    } catch (e) {
      print('Error updating ticket category: $e');
      return false;
    }
  }

  Future<List<dynamic>> getSystemSettings() async {
    try {
      final response = await _apiClient.dio.get('/api/admin/settings');
      final list = response.data is List ? response.data : response.data['content'] ?? [];
      return list as List<dynamic>;
    } catch (e) {
      print('Error fetching system settings: $e');
      return [];
    }
  }

  Future<bool> updateSystemSettings(Map<String, dynamic> data) async {
    try {
      await _apiClient.dio.put('/api/admin/settings', data: data);
      return true;
    } catch (e) {
      print('Error updating system settings: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DASHBOARD ENDPOINTS
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getUserDashboard() async {
    try {
      final response = await _apiClient.dio.get('/api/dashboard/user');
      return response.data as Map<String, dynamic>?;
    } catch (e) {
      print('Error fetching user dashboard: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getConsultantDashboard() async {
    try {
      final response = await _apiClient.dio.get('/api/dashboard/consultant');
      return response.data as Map<String, dynamic>?;
    } catch (e) {
      print('Error fetching consultant dashboard: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getAdminDashboard() async {
    try {
      final response = await _apiClient.dio.get('/api/dashboard/admin');
      return response.data as Map<String, dynamic>?;
    } catch (e) {
      print('Error fetching admin dashboard: $e');
      return null;
    }
  }
}

