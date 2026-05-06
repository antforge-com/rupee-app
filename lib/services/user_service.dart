// lib/core/services/user_service.dart
// ════════════════════════════════════════════════════════════════════════════
// Endpoints:
//   GET /api/users/me
//   GET /api/users/{id}
//   PUT /api/users/{id}
//   DELETE /api/users/{id}
//   GET /api/users
//   GET /api/users/role/{role}
//   GET /api/onboarding/{id}              ← full profile (name, phone, etc.)
//   GET /api/static-content/{type}        ← Terms & Conditions (auth required)
//   GET /api/admin/terms-and-conditions   ← legacy fallback (auth required)
//
// NOTE: /api/static-content/TERMS_AND_CONDITIONS requires a JWT token.
//   • On the login page (no token) → returns 401 → falls back to cached copy.
//   • After login (token present in SharedPreferences) → fetches live.
//   • Successful fetch is cached under 'cached_terms' in SharedPreferences.
// ════════════════════════════════════════════════════════════════════════════
import 'package:finadvise/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

const _kCachedTerms = 'cached_terms';

class UserService {
  final ApiClient _apiClient = ApiClient();

  // ── BASIC USER ────────────────────────────────────────────────────────────

  /// GET /api/users/me — Basic info (id, identifier, role)
  Future<UserModel?> getMe() async {
    try {
      final response = await _apiClient.dio.get('/api/users/me');
      return UserModel.fromJson(response.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// GET /api/onboarding/{id} — Full profile: name, email, phone, location…
  /// This is the correct endpoint to get the user's real display name.
  Future<Map<String, dynamic>?> getOnboardingProfile(int userId) async {
    try {
      final response = await _apiClient.dio.get('/api/onboarding/$userId');
      if (response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// GET /api/users/{id}
  Future<UserModel?> getUserById(int userId) async {
    try {
      final response = await _apiClient.dio.get('/api/users/$userId');
      return UserModel.fromJson(response.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// PUT /api/users/{id}
  Future<bool> updateUser(int userId, {
    String? identifier,
    String? password,
    String? role,
    int? consultantId,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (identifier != null) body['identifier'] = identifier;
      if (password != null) body['password'] = password;
      if (role != null) body['role'] = role;
      if (consultantId != null) body['consultantId'] = consultantId;
      if (body.isEmpty) return true;
      await _apiClient.dio.put('/api/users/$userId', data: body);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// DELETE /api/users/{id}
  Future<bool> deleteUser(int userId) async {
    try {
      await _apiClient.dio.delete('/api/users/$userId');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// GET /api/users (Admin only)
  Future<List<UserModel>> getAllUsers({int page = 0, int size = 50}) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/users',
        queryParameters: {'page': page, 'size': size},
      );
      final data = response.data;
      final list = data is Map ? (data['content'] ?? data['data'] ?? []) : data;
      return (list as List).map((e) => UserModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// GET /api/users/role/{role}
  Future<List<UserModel>> getUsersByRole(String role) async {
    try {
      final response = await _apiClient.dio.get('/api/users/role/$role');
      final data = response.data;
      final list = data is Map ? (data['content'] ?? data['data'] ?? []) : data;
      return (list as List).map((e) => UserModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  // ── TERMS & CONDITIONS ────────────────────────────────────────────────────
  //
  // The backend endpoint requires a JWT token (not public).
  // Strategy:
  //   1. Try live fetch (works when user has a valid session token).
  //   2. On success → cache result in SharedPreferences.
  //   3. On failure (401 / network) → return cached copy if available.
  //   4. If no cache → return '' so caller uses hardcoded default text.

  /// Fetch T&C from backend and cache. Returns '' on total failure.
  Future<String> getTermsAndConditions() async {
    // ── 1. Try live endpoints ─────────────────────────────────────────────
    String? live;

    // Primary: /api/static-content/TERMS_AND_CONDITIONS
    try {
      final response = await _apiClient.dio
          .get('/api/static-content/TERMS_AND_CONDITIONS');
      final data = response.data;
      if (data is Map) {
        final text = (data['content'] ?? data['text'] ?? '').toString().trim();
        if (text.isNotEmpty) live = text;
      }
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (!msg.contains('404') && !msg.contains('401')) {
        // ignore: avoid_print
        print('[UserService] T&C primary failed: $e');
      }
    }

    // Fallback: /api/admin/terms-and-conditions
    if (live == null) {
      try {
        final response =
        await _apiClient.dio.get('/api/admin/terms-and-conditions');
        final data = response.data;
        String combined = '';
        if (data is List) {
          combined = data
              .map((r) => (r['content'] ?? r['text'] ?? '').toString().trim())
              .where((s) => s.isNotEmpty)
              .join('\n\n');
        } else if (data is Map) {
          combined = (data['content'] ?? data['text'] ?? '').toString().trim();
        }
        if (combined.isNotEmpty) live = combined;
      } catch (_) {}
    }

    // ── 2. Cache & return live result ─────────────────────────────────────
    if (live != null && live.isNotEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kCachedTerms, live);
      } catch (_) {}
      return live;
    }

    // ── 3. Return cached copy if fetch failed ─────────────────────────────
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_kCachedTerms);
      if (cached != null && cached.isNotEmpty) return cached;
    } catch (_) {}

    // ── 4. Nothing available → caller uses hardcoded default ──────────────
    return '';
  }

  /// Call this right after a successful login so that the terms are
  /// pre-cached for the next time the login-page modal is opened.
  Future<void> prefetchAndCacheTerms() async {
    await getTermsAndConditions(); // result is auto-cached inside
  }
}