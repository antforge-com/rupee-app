// lib/core/services/notification_service.dart
// ════════════════════════════════════════════════════════════════════════════
// Swagger spec ke exact endpoints:
//   GET /api/notifications              → unread notifications (array)
//   PUT /api/notifications/{id}/read    → id = int64
//   POST /api/notifications/booking-confirmation
//
// FIX: Notification.id swagger mein int64 hai — String nahi!
//      AppNotification.id int hona chahiye
// ════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'package:finadvise/api_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/models.dart';

class NotificationService extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  final List<AppNotification> _notifications = [];
  Timer? _pollTimer;
  String? _role;
  int? _userId;   // FIX: int (nahi String)
  bool _isLoading = false;

  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  bool get isLoading => _isLoading;

  // ── INIT ──────────────────────────────────────────────────────────────────

  void initialize(String role, int userId) {  // FIX: userId int
    _role = role;
    _userId = userId;
    _fetchFromApi();
    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _fetchFromApi(),
    );
  }

  // ── API FETCH ─────────────────────────────────────────────────────────────

  /// GET /api/notifications — Unread notifications fetch karo
  Future<void> _fetchFromApi() async {
    if (_role == null || _userId == null) return;
    try {
      final response = await _apiClient.dio.get('/api/notifications');
      final data = response.data;
      final list = data is List ? data : (data is Map ? (data['content'] ?? data['data'] ?? []) : []);

      // Local read states preserve karo
      final readIds = _notifications.where((n) => n.isRead).map((n) => n.id).toSet();

      final fetched = (list as List).map((e) {
        final notif = AppNotification.fromJson(e);
        return readIds.contains(notif.id)
            ? notif.copyWith(isRead: true)
            : notif;
      }).toList();

      _notifications
        ..clear()
        ..addAll(fetched);

      notifyListeners();
      await _saveToStorage();
    } catch (_) {
      await _loadFromStorage();
    }
  }

  // ── LOCAL STORAGE (offline fallback) ─────────────────────────────────────

  String get _storageKey => 'fin_notifs_${_role}_$_userId';

  Future<void> _loadFromStorage() async {
    if (_role == null || _userId == null) return;
    try {
      final raw = await _storage.read(key: _storageKey);
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        final loaded = list.map((e) => AppNotification.fromJson(e)).toList();
        _notifications
          ..clear()
          ..addAll(loaded);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _saveToStorage() async {
    if (_role == null || _userId == null) return;
    try {
      final raw = jsonEncode(_notifications.map((n) => n.toJson()).toList());
      await _storage.write(key: _storageKey, value: raw);
    } catch (_) {}
  }

  // ── MARK AS READ ──────────────────────────────────────────────────────────

  /// PUT /api/notifications/{id}/read
  /// FIX: id = int (swagger int64), String nahi
  Future<void> markAsRead(int id) async {  // FIX: int nahi String
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx == -1) return;

    _notifications[idx] = _notifications[idx].copyWith(isRead: true);
    notifyListeners();
    await _saveToStorage();

    try {
      await _apiClient.dio.put('/api/notifications/$id/read');
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    final unreadIds = _notifications
        .where((n) => !n.isRead)
        .map((n) => n.id)
        .toList();

    for (int i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
    }
    notifyListeners();
    await _saveToStorage();

    for (final id in unreadIds) {
      _apiClient.dio.put('/api/notifications/$id/read').catchError((_) {});
    }
  }

  // ── LOCAL ADD ─────────────────────────────────────────────────────────────

  Future<void> addLocalNotification(AppNotification notification) async {
    _notifications.insert(0, notification);
    notifyListeners();
    await _saveToStorage();
  }

  // ── BOOKING CONFIRMATION ─────────────────────────────────────────────────

  /// POST /api/notifications/booking-confirmation
  /// body: { bookingId, ... other optional fields }
  Future<bool> sendBookingConfirmation(int bookingId) async {
    try {
      await _apiClient.dio.post(
        '/api/notifications/booking-confirmation',
        data: {'bookingId': bookingId},
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── CLEAR / REFRESH ───────────────────────────────────────────────────────

  Future<void> clearAll() async {
    _notifications.clear();
    notifyListeners();
    await _saveToStorage();
  }

  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();
    await _fetchFromApi();
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
