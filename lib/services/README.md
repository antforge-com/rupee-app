# Frontend API Services Documentation
## Overview
This directory contains comprehensive Flutter services for all backend API endpoints. Each service is a specialized client that handles requests and responses for specific domains.
## Services Overview
### Core Services
#### 1. **Authentication Service** (uth.service.dart)
- Login/Logout
- OTP verification
- Password reset
- Password change
- Session management
#### 2. **Booking Service** (ooking_service_ext.dart)
- Create, read, update, delete bookings
- Get user and consultant bookings
- Cancel bookings
- Booking status management
#### 3. **Feedback Service** (eedback_service_ext.dart)
- Submit and retrieve feedback
- Get feedback by booking or consultant
- Update/delete feedback
- Calculate average ratings
#### 4. **Offer Service** (offer_service_ext.dart)
- List all offers
- Create/update/delete offers
- Get active offers
- Offer management
#### 5. **Notification Service** (
otification_service_ext.dart)
- Get notifications for users
- Mark notifications as read
- Get unread count
- Delete notifications
#### 6. **TimeSlot Service** (	imeslot_service_ext.dart)
- Get available time slots
- Create/delete time slots
- Get consultant and date-based slots
- Slot management
#### 7. **Question & Answer Service** (question_service_ext.dart)
- Get all questions
- Submit answers
- Get answers by question
- Delete answers
- Q&A management
#### 8. **Special Booking Service** (special_booking_service_ext.dart)
- Create special bookings
- Get user special bookings
- Update/cancel special bookings
- Special booking management
#### 9. **Analytics Service** (nalytics_service_ext.dart)
- Dashboard analytics
- Booking statistics
- Revenue reports
- Ticket statistics
- Consultant analytics
- Generate reports
#### 10. **Contact Message Service** (contact_message_service_ext.dart)
- Submit contact messages
- Get all messages
- Mark as resolved
- Delete messages
#### 11. **Email to Ticket Service** (email_to_ticket_service_ext.dart)
- Manage email to ticket mappings
- Create/update/delete mappings
- Get all mappings
#### 12. **Skill Master Service** (skill_master_service_ext.dart)
- Get all skills
- Create/update/delete skills
- Skill management
#### 13. **Master TimeSlot Service** (master_timeslot_service_ext.dart)
- Get master time slots
- Create/update/delete master slots
- Master slot configuration
#### 14. **Subscription Service** (subscription_service_ext.dart)
- Get all subscription plans
- Create/update/delete plans
- Subscription management
#### 15. **System Settings Service** (system_settings_service_ext.dart)
- Get all settings
- Get/update settings by key
- Configuration management
#### 16. **Dashboard Service** (dashboard_service_ext.dart)
- Get dashboard stats
- User/admin/consultant dashboards
- Recent activity
- Dashboard data
#### 17. **User Service** (user_service_ext.dart)
- Get current user profile
- Update user profile
- Upload profile picture
- Search users
- User management
#### 18. **Consultant Service** (consultant_service_ext.dart)
- Get all consultants
- Search consultants
- Filter by skill
- Update consultant profile
## Models
All data models are defined in ../models/all_models.dart:
- Pagination support with PaginatedResponse<T>
- Generic API response wrapper ApiResponse<T>
- All DTOs for requests and responses
## Usage Examples
### Basic Pattern
All services follow a consistent pattern:
\\\dart
import 'package:finadvise/services/all_services.dart';
import 'package:finadvise/models/all_models.dart';
// Create service instance
final bookingService = BookingServiceExtended();
// Make API call
try {
  final bookings = await bookingService.getAllBookings();
  if (bookings != null && bookings.isNotEmpty) {
    print('Found \ bookings');
  }
} catch (e) {
  print('Error: \');
}
\\\
### Create a Booking
\\\dart
final bookingService = BookingServiceExtended();
final request = BookingRequest(
  consultantId: 1,
  startTime: '09:00',
  endTime: '10:00',
  bookingDate: '2026-05-01',
  notes: 'Initial consultation',
);
final booking = await bookingService.createBooking(request);
if (booking != null) {
  print('Booking created: \');
}
\\\
### Get Notifications
\\\dart
final notificationService = NotificationServiceExtended();
final notifications = await notificationService.getNotifications(userId: 123);
final unreadCount = await notificationService.getUnreadCount(userId: 123);
print('Unread notifications: \');
\\\
### Get Dashboard Stats
\\\dart
final dashboardService = DashboardServiceExtended();
final stats = await dashboardService.getDashboardStats();
if (stats != null) {
  print('Total bookings: \');
  print('Average rating: \');
}
\\\
## Error Handling
All services implement error handling with try-catch blocks:
\\\dart
Future<List<BookingModel>> getUserBookings(int userId) async {
  try {
    final response = await _apiClient.dio.get('/api/bookings/user/\');
    // Process response
    return bookings;
  } catch (e) {
    print('Error fetching bookings: \');
    return []; // Return empty list on error
  }
}
\\\
## API Base Configuration
The API base URL is configured in pi_client.dart:
- Default: \http://52.55.178.31:8081\
- Configurable via environment variables
## Authentication
JWT tokens are automatically injected by \ApiClient\:
- Tokens stored in \SharedPreferences\ with key \in_token\
- Automatically added to all requests
- 401 errors trigger \onUnauthorized\ callback
## Pagination
For paginated endpoints:
\\\dart
final response = await ticketService.getAllTickets(
  page: 0,
  size: 20,
  status: 'OPEN',
);
print('Total pages: \');
print('Has next: \');
\\\
## File Uploads
For file uploads (e.g., profile pictures):
\\\dart
final userService = UserServiceExtended();
final success = await userService.uploadProfilePicture('/path/to/image.jpg');
\\\
## Status Codes
- 200-201: Success
- 400: Bad request (validation error)
- 401: Unauthorized (invalid/expired token)
- 403: Forbidden (insufficient permissions)
- 404: Not found
- 500: Server error
## Notes
- All services use singleton \ApiClient\ instance
- Timestamps are string-formatted (ISO 8601)
- IDs are integers
- All monetary values are doubles
- Empty lists returned on errors (not null)
- Null returned on single item errors
## Future Enhancements
- Caching layer
- Offline support
- Request retries
- Rate limiting
- WebSocket support for real-time updates
