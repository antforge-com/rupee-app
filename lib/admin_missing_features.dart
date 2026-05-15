// lib/features/admin/admin_missing_features.dart
// ════════════════════════════════════════════════════════════════════════════
// MISSING FEATURES — Covers every gap from OpenAPI spec analysis
//
// EXPORTS (add to admin_dashboard.dart imports):
//   import 'admin_missing_features.dart';
//
// SECTIONS:
//   1.  Bug Fixes          — getAnalytics alias, offer approval, skill fields
//   2.  AdminProfileSettingsScreen
//         • Profile tab    — photo upload (multipart PUT /api/onboarding/{id})
//         • Security tab   — change password (PUT /api/users/change-password)
//         • Notifications  — real backend (GET/PUT /api/notifications)
//   3.  AdminUserManagementScreen
//         • GET /api/users  +  GET /api/users/role/{role}
//         • DELETE /api/users/{id}
//   4.  TicketExportService  — real CSV export via share_plus
//   5.  SlaBreachedScreen    — GET /api/tickets/sla-breached
//   6.  EscalatedScreen      — GET /api/tickets/escalated
//   7.  ContactPublicSubmit  — POST /api/contact/public/submit widget
//
// HOW TO WIRE INTO admin-dashboard.dart:
//   • Settings tile  → Navigator.push(AdminProfileSettingsScreen)
//   • New drawer item→ AdminSection.userManagement → AdminUserManagementScreen
//   • Export button  → TicketExportService.exportToCsv(tickets)
//   • SLA / Escalated cards → dedicated screens
// ════════════════════════════════════════════════════════════════════════════

// ignore_for_file: curly_braces_in_flow_control_structures, use_build_context_synchronously

import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:finadvise/api_client.dart';
import 'package:finadvise/app_theme.dart';
import 'package:finadvise/models/models.dart';
import 'package:finadvise/shared_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SHARED HELPERS
// ─────────────────────────────────────────────────────────────────────────────

final _dio = ApiClient().dio;
const _storage = FlutterSecureStorage();

void _snack(BuildContext ctx, String msg, {bool error = false}) {
  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
    content: Text(msg),
    backgroundColor: error ? AppColors.danger : AppColors.success,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    margin: const EdgeInsets.all(12),
  ));
}

InputDecoration _inp(String label,
        {IconData? icon, String? hint, Widget? suffix}) =>
    InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null
          ? Icon(icon, size: 20, color: AppColors.textSecondary)
          : null,
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.surfaceVariant,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.primaryLight, width: 2)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );

final _leadingLetterFormatter = TextInputFormatter.withFunction(
  (oldValue, newValue) {
    final text = newValue.text;
    if (text.trimLeft().isEmpty) return newValue;
    final first = text.trimLeft()[0];
    return RegExp(r'[A-Za-z]').hasMatch(first) ? newValue : oldValue;
  },
);

String? _capitalizedTextError(
  String? value, {
  required String field,
  bool requiredField = true,
}) {
  final text = (value ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
  if (text.isEmpty) return requiredField ? '$field is required' : null;
  if (!RegExp(r'[A-Za-z]').hasMatch(text[0])) {
    return '$field must start with a letter';
  }
  if (!RegExp(r'[A-Z]').hasMatch(text[0])) {
    return '$field must start with a capital letter';
  }
  return null;
}

String _cleanRole(dynamic raw) =>
    raw.toString().toUpperCase().replaceAll('ROLE_', '').trim();

Future<List<Map<String, dynamic>>> _mergeUsersWithProfiles(
  List<Map<String, dynamic>> users,
) async {
  final merged = users
      .map((user) => Map<String, dynamic>.from(user))
      .toList(growable: false);
  final ids = merged
      .map((user) => user['id'])
      .whereType<num>()
      .map((id) => id.toInt())
      .where((id) => id > 0)
      .toList(growable: false);

  final results = await Future.wait<MapEntry<int, Map<String, dynamic>>?>(
    ids.map((id) async {
      try {
        final response = await _dio.get('/api/onboarding/$id');
        if (response.data is! Map) return null;
        return MapEntry(id, Map<String, dynamic>.from(response.data as Map));
      } catch (_) {
        return null;
      }
    }),
  );

  final profileMap = <int, Map<String, dynamic>>{
    for (final entry in results.whereType<MapEntry<int, Map<String, dynamic>>>())
      entry.key: entry.value,
  };

  return merged.map((user) {
    final id = (user['id'] as num?)?.toInt();
    final profile = id != null ? profileMap[id] : null;
    if (profile == null) return user;
    return {
      ...user,
      'profileName': profile['name'],
      'profileEmail': profile['email'],
      'profilePhone': profile['phoneNumber'],
      'profileLocation': profile['location'],
      'profileImageUrl': profile['profileImageUrl'],
      'designation': profile['designation'],
      'organizationName': profile['organizationName'],
      'memberSince': profile['memberSince'],
    };
  }).toList(growable: false);
}

// ═════════════════════════════════════════════════════════════════════════════
// SECTION 1 — BUG FIXES
// ═════════════════════════════════════════════════════════════════════════════

/// ── FIX 1: AnalyticsService.getAnalytics() alias ─────────────────────────
/// admin_dashboard.dart calls `_analyticsService.getAnalytics()` but the
/// method is named `getFullDashboard()` in analytics_service.dart.
/// Add this extension to AnalyticsService to fix the compile error.
///
/// PASTE THIS into analytics_service.dart INSIDE the AnalyticsService class:
///
///   Future<DashboardAnalytics> getAnalytics({String period = 'WEEKLY'}) =>
///       getFullDashboard(period: period);
///

/// ── FIX 2: Offer Approval endpoint ───────────────────────────────────────
/// WRONG  : PUT /api/offers/$id/approve   or   PUT /api/offers/$id/reject
/// CORRECT: PUT /api/offers/$id/status?status=APPROVED
///          PUT /api/offers/$id/status?status=REJECTED
///
/// Replace _AdminOfferApprovalsTabState._action() with:
///
///   Future<void> _action(int id, String action) async {
///     setState(() => _processing = id);
///     final status = action == 'approve' ? 'APPROVED' : 'REJECTED';
///     try {
///       await _dio.put('/api/offers/$id/status', queryParameters: {'status': status});
///       ...
///     }
///   }
///
/// The fixed widget _AdminOfferApprovalsTabFixed is provided below.

/// ── FIX 3: Skill create/update field name ─────────────────────────────────
/// WRONG  : {'name': ..., 'description': ...}
/// CORRECT: {'skillName': ..., 'description': ...}   ← SkillRequest schema
///
/// The fixed methods are inside _AdminSkillsQuestionsTabFixed below.

/// ── FIX 4: OfferRequest schema ────────────────────────────────────────────
/// OfferRequest only accepts: title, description, discount(String), validFrom,
/// validTo, consultantId, active(boolean).
/// Remove discountValue, discountType, isActive from the payload.
/// Use 'active' not 'isActive'.

/// ── FIX 5: TicketResponse field names ────────────────────────────────────
/// Backend returns: escalated (not isEscalated), slaBreached (not isSlaBreached)
/// The Ticket model should map: isEscalated → escalated, isSlaBreached → slaBreached

// ═════════════════════════════════════════════════════════════════════════════
// SECTION 2 — ADMIN PROFILE SETTINGS SCREEN
// ═════════════════════════════════════════════════════════════════════════════

class AdminProfileSettingsScreen extends StatefulWidget {
  const AdminProfileSettingsScreen({super.key});

  @override
  State<AdminProfileSettingsScreen> createState() =>
      _AdminProfileSettingsScreenState();
}

class _AdminProfileSettingsScreenState extends State<AdminProfileSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: AppColors.border,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Account Settings',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primaryLight,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.primaryLight,
          indicatorWeight: 2.5,
          labelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          unselectedLabelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
          tabs: const [
            Tab(
                icon: Icon(Icons.person_outline_rounded, size: 18),
                text: 'Profile'),
            Tab(
                icon: Icon(Icons.lock_outline_rounded, size: 18),
                text: 'Security'),
            Tab(
                icon: Icon(Icons.notifications_outlined, size: 18),
                text: 'Alerts'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _ProfileTab(),
          _SecurityTab(),
          _NotificationsTab(),
        ],
      ),
    );
  }
}

// ── PROFILE TAB ──────────────────────────────────────────────────────────────
// Uses: GET /api/onboarding/{userId}
//       PUT /api/onboarding/{userId}  (multipart/form-data)
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileTab extends StatefulWidget {
  const _ProfileTab();
  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _designationCtrl = TextEditingController();
  final _organizationCtrl = TextEditingController();

  String? _photoUrl;
  String? _memberSince;
  File? _pickedImage;
  bool _loading = true;
  bool _saving = false;
  int? _userId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _locationCtrl.dispose();
    _designationCtrl.dispose();
    _organizationCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final idStr = await _storage.read(key: 'user_id');
      _userId = int.tryParse(idStr ?? '');
      if (_userId == null) return;

      // GET /api/onboarding/{id}  → UserRegistrationResponse
      final res = await _dio.get('/api/onboarding/$_userId');
      final d = res.data as Map<String, dynamic>;

      _nameCtrl.text = d['name'] ?? '';
      _emailCtrl.text = d['email'] ?? '';
      _phoneCtrl.text = d['phoneNumber'] ?? '';
      _locationCtrl.text = d['location'] ?? '';
      _designationCtrl.text = d['designation'] ?? '';
      _organizationCtrl.text = d['organizationName'] ?? '';
      _memberSince = d['memberSince']?.toString();
      setState(() => _photoUrl =
          d['profileImageUrl']?.toString() ?? d['photoUrl']?.toString());
    } catch (_) {
      // Load from secure storage as fallback
      _nameCtrl.text = await _storage.read(key: 'user_name') ?? '';
      _emailCtrl.text = await _storage.read(key: 'user_email') ?? '';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final xFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (xFile != null) {
        setState(() => _pickedImage = File(xFile.path));
      }
    } catch (_) {
      if (mounted) _snack(context, 'Could not open gallery', error: true);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_userId == null) {
      _snack(context, 'User ID not found. Please re-login.', error: true);
      return;
    }
    setState(() => _saving = true);

    try {
      // Build UpdateUserRegistrationRequest JSON
      final payload = {
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phoneNumber': _phoneCtrl.text.trim(),
        'location': _locationCtrl.text.trim(),
        'designation': _designationCtrl.text.trim(),
        'organizationName': _organizationCtrl.text.trim(),
      };

      final formData = FormData.fromMap({
        'data': MultipartFile.fromString(
          jsonEncode(payload),
          filename: 'data.json',
          contentType: DioMediaType.parse('application/json'),
        ),
      });

      if (_pickedImage != null) {
        formData.files.add(MapEntry(
          'file',
          await MultipartFile.fromFile(
            _pickedImage!.path,
            filename: 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
          ),
        ));
      }

      final res = await _dio.put(
        '/api/onboarding/$_userId',
        data: formData,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
        ),
      );

      final d = res.data as Map<String, dynamic>;
      if (d['profileImageUrl'] != null) {
        setState(() => _photoUrl = d['profileImageUrl']);
      }

      // Persist to secure storage
      await _storage.write(key: 'user_name', value: _nameCtrl.text.trim());
      await _storage.write(key: 'user_email', value: _emailCtrl.text.trim());

      if (mounted) _snack(context, 'Profile updated successfully');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to update profile';
      if (mounted) _snack(context, msg, error: true);
    } catch (_) {
      if (mounted) _snack(context, 'Something went wrong', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: MeetTheMastersLoadingIndicator(label: 'Loading profile'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Avatar Section ─────────────────────────────────────────────
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.primaryLight, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                  color: AppColors.primaryLight
                                      .withValues(alpha: 0.2),
                                  blurRadius: 16,
                                  spreadRadius: 2)
                            ],
                          ),
                          child: ClipOval(
                            child: _pickedImage != null
                                ? Image.file(_pickedImage!, fit: BoxFit.cover)
                                : (_photoUrl != null && _photoUrl!.isNotEmpty
                                    ? Image.network(_photoUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            _avatarFallback())
                                    : _avatarFallback()),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 6)
                              ],
                            ),
                            child: const Icon(Icons.camera_alt_rounded,
                                size: 16, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('Tap to change photo',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.primaryLight)),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Form Fields ────────────────────────────────────────────────
            _FormSection(
              title: 'Personal Info',
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: [_leadingLetterFormatter],
                  decoration:
                      _inp('Full Name', icon: Icons.person_outline_rounded),
                  validator: (v) =>
                      _capitalizedTextError(v, field: 'Full name') ??
                      ((v ?? '').trim().length < 2
                          ? 'Minimum 2 characters'
                          : null),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _inp('Email Address', icon: Icons.email_outlined),
                  validator: (v) =>
                      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v ?? '')
                          ? null
                          : 'Enter a valid email',
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: _inp('Phone Number',
                      icon: Icons.phone_outlined, hint: '10-digit mobile'),
                  validator: (v) => RegExp(r'^[6-9]\d{9}$')
                          .hasMatch((v ?? '').trim())
                      ? null
                      : 'Enter a valid 10-digit Indian number',
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _locationCtrl,
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: [_leadingLetterFormatter],
                  decoration: _inp('Location',
                      icon: Icons.location_on_outlined, hint: 'City, State'),
                  validator: (v) => _capitalizedTextError(
                    v,
                    field: 'Location',
                    requiredField: false,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _designationCtrl,
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: [_leadingLetterFormatter],
                  decoration:
                      _inp('Designation', icon: Icons.work_outline_rounded),
                  validator: (v) => _capitalizedTextError(
                    v,
                    field: 'Designation',
                    requiredField: false,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _organizationCtrl,
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: [_leadingLetterFormatter],
                  decoration: _inp('Organization Name',
                      icon: Icons.business_outlined),
                  validator: (v) => _capitalizedTextError(
                    v,
                    field: 'Organization name',
                    requiredField: false,
                  ),
                ),
              ],
            ),
            if ((_memberSince ?? '').isNotEmpty) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_outlined,
                        color: AppColors.textSecondary, size: 18),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Member Since', style: AppTextStyles.caption),
                        const SizedBox(height: 2),
                        Text(_memberSince!, style: AppTextStyles.label),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 28),

            // ── Save Button ────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined,
                        color: Colors.white, size: 18),
                label: Text(
                  _saving ? 'Saving...' : 'Save Profile',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryLight,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarFallback() => Container(
        color: AppColors.primary.withValues(alpha: 0.1),
        child: Center(
          child: Text(
            _nameCtrl.text.isNotEmpty ? _nameCtrl.text[0].toUpperCase() : 'A',
            style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: AppColors.primary),
          ),
        ),
      );
}

// ── SECURITY TAB ──────────────────────────────────────────────────────────────
// Uses: PUT /api/users/change-password
//       Body: UpdatePasswordRequest { newPassword, confirmPassword }
// ─────────────────────────────────────────────────────────────────────────────

class _SecurityTab extends StatefulWidget {
  const _SecurityTab();
  @override
  State<_SecurityTab> createState() => _SecurityTabState();
}

class _SecurityTabState extends State<_SecurityTab> {
  final _formKey = GlobalKey<FormState>();
  final _newPassCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _showNew = false;
  bool _showConfirm = false;
  bool _saving = false;

  @override
  void dispose() {
    _newPassCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // Password strength score 0–4
  _PasswordStrength _strength(String p) {
    if (p.isEmpty) return const _PasswordStrength(0, '', AppColors.border);
    int score = 0;
    if (p.length >= 8) score++;
    if (p.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(p)) score++;
    if (RegExp(r'[0-9]').hasMatch(p)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) score++;
    if (score <= 1) return const _PasswordStrength(1, 'Weak', AppColors.danger);
    if (score == 2)
      return const _PasswordStrength(2, 'Fair', AppColors.warning);
    if (score == 3) return const _PasswordStrength(3, 'Good', AppColors.info);
    return const _PasswordStrength(4, 'Strong', AppColors.success);
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      // PUT /api/users/change-password
      // Body: { "newPassword": "...", "confirmPassword": "..." }
      await _dio.put('/api/users/change-password', data: {
        'newPassword': _newPassCtrl.text,
        'confirmPassword': _confirmCtrl.text,
      });

      _newPassCtrl.clear();
      _confirmCtrl.clear();
      if (mounted) {
        _snack(context,
            'Password changed successfully! Please log in again if prompted.');
        setState(() {});
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      final fieldErr = (data is Map)
          ? (data['fieldErrors'] as Map?)?.values.join(', ')
          : null;
      final msg = fieldErr ??
          (data is Map ? data['message'] : null) ??
          'Password change failed';
      if (mounted) _snack(context, msg, error: true);
    } catch (_) {
      if (mounted) _snack(context, 'Something went wrong', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _strength(_newPassCtrl.text);
    final mismatch =
        _confirmCtrl.text.isNotEmpty && _confirmCtrl.text != _newPassCtrl.text;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Info Banner ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: AppColors.info.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: AppColors.info, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Choose a strong password. Your session remains active after the change.',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.info),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _FormSection(
              title: 'Change Password',
              children: [
                // New Password
                TextFormField(
                  controller: _newPassCtrl,
                  obscureText: !_showNew,
                  onChanged: (_) => setState(() {}),
                  decoration: _inp(
                    'New Password',
                    icon: Icons.lock_outline_rounded,
                    suffix: _eyeBtn(
                        _showNew, () => setState(() => _showNew = !_showNew)),
                  ),
                  validator: (v) {
                    if ((v ?? '').length < 8) return 'Minimum 8 characters';
                    return null;
                  },
                ),
                // Strength meter
                if (_newPassCtrl.text.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _StrengthMeter(strength: s),
                ],
                const SizedBox(height: 14),

                // Confirm Password
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: !_showConfirm,
                  onChanged: (_) => setState(() {}),
                  decoration: _inp(
                    'Confirm New Password',
                    icon: Icons.lock_outline_rounded,
                    suffix: _eyeBtn(_showConfirm,
                        () => setState(() => _showConfirm = !_showConfirm)),
                  ).copyWith(
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: mismatch
                            ? AppColors.danger
                            : AppColors.primaryLight,
                        width: 2,
                      ),
                    ),
                  ),
                  validator: (v) {
                    if (v != _newPassCtrl.text) return 'Passwords do not match';
                    return null;
                  },
                ),
                if (mismatch)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            size: 14, color: AppColors.danger),
                        const SizedBox(width: 4),
                        Text('Passwords do not match',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.danger)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Password Requirements
            _PasswordRequirements(password: _newPassCtrl.text),
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: (_saving || _newPassCtrl.text.length < 8 || mismatch)
                    ? null
                    : _changePassword,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.lock_reset_rounded,
                        color: Colors.white, size: 18),
                label: Text(
                  _saving ? 'Updating...' : 'Update Password',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _eyeBtn(bool visible, VoidCallback onTap) => IconButton(
        icon: Icon(
            visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: AppColors.textMuted,
            size: 20),
        onPressed: onTap,
        splashRadius: 18,
      );
}

class _PasswordStrength {
  final int score;
  final String label;
  final Color color;
  const _PasswordStrength(this.score, this.label, this.color);
}

class _StrengthMeter extends StatelessWidget {
  final _PasswordStrength strength;
  const _StrengthMeter({required this.strength});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(4, (i) {
            final filled = i < strength.score;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                height: 4,
                decoration: BoxDecoration(
                  color: filled ? strength.color : AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }),
        ),
        if (strength.label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(strength.label,
                style: AppTextStyles.caption.copyWith(
                    color: strength.color, fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }
}

class _PasswordRequirements extends StatelessWidget {
  final String password;
  const _PasswordRequirements({required this.password});

  @override
  Widget build(BuildContext context) {
    final rules = [
      _Req('At least 8 characters', password.length >= 8),
      _Req('One uppercase letter', RegExp(r'[A-Z]').hasMatch(password)),
      _Req('One number', RegExp(r'[0-9]').hasMatch(password)),
      _Req('One special character (!@#\$…)',
          RegExp(r'[^A-Za-z0-9]').hasMatch(password)),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Requirements',
              style: AppTextStyles.label.copyWith(letterSpacing: 0.4)),
          const SizedBox(height: 10),
          ...rules.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        r.met
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        key: ValueKey(r.met),
                        size: 16,
                        color: r.met ? AppColors.success : AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(r.label,
                        style: AppTextStyles.bodySmall.copyWith(
                            color: r.met
                                ? AppColors.textPrimary
                                : AppColors.textMuted)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _Req {
  final String label;
  final bool met;
  const _Req(this.label, this.met);
}

// ── NOTIFICATIONS TAB ─────────────────────────────────────────────────────────
// Uses: GET /api/notifications  (real backend, returns Notification[])
//       PUT /api/notifications/{id}/read
//
// Notification types: TICKET_UPDATED | NEW_ASSIGNMENT | ESCALATION
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationsTab extends StatefulWidget {
  const _NotificationsTab();
  @override
  State<_NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<_NotificationsTab> {
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // GET /api/notifications  → Notification[]
      // { id, userId, ticketId, message, type, createdAt, read }
      final res = await _dio.get('/api/notifications');
      _notifications = List<Map<String, dynamic>>.from(
        res.data is List ? res.data : [],
      )..sort((a, b) {
          final ta = DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime(2000);
          final tb = DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime(2000);
          return tb.compareTo(ta);
        });
    } catch (_) {
      _notifications = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _markRead(int id) async {
    // PUT /api/notifications/{id}/read
    setState(() {
      _notifications = _notifications
          .map((n) => n['id'] == id ? {...n, 'read': true} : n)
          .toList();
    });
    try {
      await _dio.put('/api/notifications/$id/read');
    } catch (_) {}
  }

  Future<void> _markAllRead() async {
    final unread = _notifications.where((n) => n['read'] != true).toList();
    setState(() {
      _notifications = _notifications.map((n) => {...n, 'read': true}).toList();
    });
    for (final n in unread) {
      try {
        await _dio.put('/api/notifications/${n['id']}/read');
      } catch (_) {}
    }
    if (mounted) _snack(context, 'All notifications marked as read');
  }

  List<Map<String, dynamic>> get _visible {
    if (_filter == 'unread')
      return _notifications.where((n) => n['read'] != true).toList();
    if (_filter == 'escalation')
      return _notifications.where((n) => n['type'] == 'ESCALATION').toList();
    return _notifications;
  }

  int get _unreadCount => _notifications.where((n) => n['read'] != true).length;

  @override
  Widget build(BuildContext context) {
    final visible = _visible;

    return Column(
      children: [
        // ── Toolbar ──────────────────────────────────────────────────────
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            children: [
              // Unread count banner
              if (_unreadCount > 0)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.only(bottom: 12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.primaryLight.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('$_unreadCount new',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(
                              'unread notification${_unreadCount != 1 ? 's' : ''}',
                              style: AppTextStyles.bodySmall)),
                      TextButton(
                        onPressed: _markAllRead,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primaryLight,
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Mark all read',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),

              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip('all', 'All (${_notifications.length})'),
                    const SizedBox(width: 8),
                    _filterChip('unread', 'Unread ($_unreadCount)'),
                    const SizedBox(width: 8),
                    _filterChip('escalation', 'Escalations'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        const Divider(height: 1),

        // ── List ─────────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : visible.isEmpty
                  ? const EmptyState(
                      icon: Icons.notifications_none_rounded,
                      title: 'No notifications',
                      subtitle: 'System notifications will appear here',
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: visible.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _NotifCard(
                          notif: visible[i],
                          onMarkRead: () => _markRead(visible[i]['id']),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _filterChip(String value, String label) => FilterChip(
        label: Text(label),
        selected: _filter == value,
        onSelected: (_) => setState(() => _filter = value),
        selectedColor: AppColors.primaryLight.withValues(alpha: 0.12),
        checkmarkColor: AppColors.primaryLight,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _filter == value
              ? AppColors.primaryLight
              : AppColors.textSecondary,
        ),
        side: BorderSide(
          color: _filter == value
              ? AppColors.primaryLight.withValues(alpha: 0.4)
              : AppColors.border,
        ),
      );
}

class _NotifCard extends StatelessWidget {
  final Map<String, dynamic> notif;
  final VoidCallback onMarkRead;
  const _NotifCard({required this.notif, required this.onMarkRead});

  Color get _typeColor {
    switch (notif['type']) {
      case 'ESCALATION':
        return AppColors.danger;
      case 'NEW_ASSIGNMENT':
        return AppColors.primaryLight;
      default:
        return AppColors.info;
    }
  }

  IconData get _typeIcon {
    switch (notif['type']) {
      case 'ESCALATION':
        return Icons.warning_amber_rounded;
      case 'NEW_ASSIGNMENT':
        return Icons.assignment_ind_outlined;
      default:
        return Icons.confirmation_number_outlined;
    }
  }

  String _fmt(String? iso) {
    if (iso == null) return '';
    try {
      final d = DateTime.parse(iso);
      return DateFormat('d MMM • h:mm a').format(d.toLocal());
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRead = notif['read'] == true;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isRead
            ? AppColors.surface
            : AppColors.primaryLight.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isRead
              ? AppColors.border
              : AppColors.primaryLight.withValues(alpha: 0.3),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: isRead ? null : onMarkRead,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _typeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_typeIcon, color: _typeColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notif['message'] ?? '',
                            style: AppTextStyles.body.copyWith(
                              fontWeight:
                                  isRead ? FontWeight.w400 : FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 8, top: 4),
                            decoration: const BoxDecoration(
                              color: AppColors.primaryLight,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _typeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            (notif['type'] ?? 'INFO')
                                .toString()
                                .replaceAll('_', ' '),
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _typeColor),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(_fmt(notif['createdAt']),
                            style: AppTextStyles.caption),
                        if (notif['ticketId'] != null) ...[
                          const SizedBox(width: 6),
                          Text('• Ticket #${notif['ticketId']}',
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.primaryLight)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SECTION 3 — ADMIN USER MANAGEMENT SCREEN
// Uses: GET /api/users             → UserResponse[]
//       GET /api/users/role/{role} → UserResponse[] (GUEST|MEMBER|SUBSCRIBER|CONSULTANT|ADMIN)
//       DELETE /api/users/{id}
// ═════════════════════════════════════════════════════════════════════════════

class AdminUserManagementScreen extends StatefulWidget {
  const AdminUserManagementScreen({super.key});

  @override
  State<AdminUserManagementScreen> createState() =>
      _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState extends State<AdminUserManagementScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String _roleFilter = 'ALL';
  String _search = '';
  int? _deletingId;

  static const _roles = [
    'ALL',
    'MEMBER',
    'SUBSCRIBER',
    'CONSULTANT',
    'ADMIN',
    'GUEST'
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      if (_roleFilter == 'ALL') {
        // GET /api/users
        final res = await _dio.get('/api/users');
        _users =
            List<Map<String, dynamic>>.from(res.data is List ? res.data : []);
      } else {
        // GET /api/users/role/{role}
        final res = await _dio.get('/api/users/role/$_roleFilter');
        _users =
            List<Map<String, dynamic>>.from(res.data is List ? res.data : []);
      }
      _users = await _mergeUsersWithProfiles(_users);
    } catch (_) {
      _users = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _delete(Map<String, dynamic> user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: 'Delete User?',
        body:
            'Delete "${user['identifier']}"? This action cannot be undone and will remove all data linked to this account.',
        confirmLabel: 'Delete',
        confirmColor: AppColors.danger,
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _deletingId = user['id']);
    try {
      // DELETE /api/users/{id}
      await _dio.delete('/api/users/${user['id']}');
      setState(() => _users.removeWhere((u) => u['id'] == user['id']));
      if (mounted) _snack(context, 'User deleted successfully');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Delete failed';
      if (mounted) _snack(context, msg, error: true);
    } finally {
      if (mounted) setState(() => _deletingId = null);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.trim().isEmpty) return _users;
    final q = _search.toLowerCase();
    return _users
        .where((u) =>
            (u['profileName'] ?? u['name'] ?? '')
                .toString()
                .toLowerCase()
                .contains(q) ||
            (u['identifier'] ?? '').toString().toLowerCase().contains(q) ||
            (u['id'] ?? '').toString().contains(q) ||
            (u['role'] ?? '').toString().toLowerCase().contains(q))
        .toList();
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'ADMIN':
        return AppColors.danger;
      case 'CONSULTANT':
        return AppColors.primaryLight;
      case 'SUBSCRIBER':
        return AppColors.accent;
      case 'MEMBER':
        return AppColors.success;
      default:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Users (${_users.length})',
            style: const TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.surface,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _load,
              tooltip: 'Refresh'),
        ],
      ),
      body: Column(
        children: [
          // ── Search & Role Filter ──────────────────────────────────────
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: _inp('Search by name, email, ID or role',
                      icon: Icons.search_rounded),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _roles.map((r) {
                      final active = _roleFilter == r;
                      final color =
                          r == 'ALL' ? AppColors.primaryLight : _roleColor(r);
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _roleFilter = r);
                            _load();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: active
                                  ? color.withValues(alpha: 0.12)
                                  : AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: active
                                    ? color.withValues(alpha: 0.5)
                                    : AppColors.border,
                                width: active ? 1.5 : 1,
                              ),
                            ),
                            child: Text(
                              r,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight:
                                    active ? FontWeight.w700 : FontWeight.w500,
                                color: active ? color : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── User List ─────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: 6,
                    itemBuilder: (_, __) => const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: ShimmerCard(),
                    ),
                  )
                : filtered.isEmpty
                    ? const EmptyState(
                        icon: Icons.people_outline_rounded,
                        title: 'No users found',
                        subtitle: 'Try adjusting the filter or search',
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(14),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final u = filtered[i];
                            final role = _cleanRole(u['role'] ?? 'GUEST');
                            final id = u['id'] as int?;
                            final identifier =
                                (u['identifier'] ?? '—').toString();
                            final name = (u['profileName'] ??
                                        u['name'] ??
                                        u['fullName'] ??
                                        '')
                                    .toString()
                                    .trim();
                            final email = (u['profileEmail'] ??
                                        u['email'] ??
                                        u['identifier'] ??
                                        '')
                                    .toString()
                                    .trim();
                            final requiresPwChange =
                                u['requiresPasswordChange'] == true;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    // Avatar
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: _roleColor(role)
                                            .withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          (name.isNotEmpty
                                                  ? name
                                                  : identifier)
                                              .characters
                                              .first
                                              .toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: _roleColor(role),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                    name.isNotEmpty
                                                        ? name
                                                        : identifier,
                                                    style: AppTextStyles.label
                                                        .copyWith(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color:
                                                          AppColors.textPrimary,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis),
                                              ),
                                              if (requiresPwChange)
                                                Container(
                                                  margin: const EdgeInsets.only(
                                                      left: 6),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.warning
                                                        .withValues(alpha: 0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                  ),
                                                  child: const Text('PW Reset',
                                                      style: TextStyle(
                                                          fontSize: 9,
                                                          color:
                                                              AppColors.warning,
                                                          fontWeight:
                                                              FontWeight.w700)),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 6,
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: _roleColor(role)
                                                      .withValues(alpha: 0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Text(role,
                                                    style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color:
                                                            _roleColor(role))),
                                              ),
                                              if (id != null)
                                                Text('ID: $id',
                                                    style:
                                                        AppTextStyles.caption),
                                              if (u['consultantId'] != null)
                                                Text(
                                                    'Cid: ${u['consultantId']}',
                                                    style: AppTextStyles.caption
                                                        .copyWith(
                                                            color: AppColors
                                                                .primaryLight)),
                                              if (email.isNotEmpty)
                                                Text(
                                                  email,
                                                  style: AppTextStyles.caption,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Delete
                                    if (role != 'ADMIN')
                                      _deletingId == id
                                          ? const SizedBox(
                                              width: 36,
                                              height: 36,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2),
                                            )
                                          : IconButton(
                                              icon: const Icon(
                                                  Icons.delete_outline_rounded,
                                                  color: AppColors.danger,
                                                  size: 20),
                                              onPressed: () => _delete(u),
                                              tooltip: 'Delete user',
                                              splashRadius: 20,
                                            ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SECTION 4 — TICKET EXPORT SERVICE
// Generates a real CSV file and shares it via share_plus
// ═════════════════════════════════════════════════════════════════════════════

class TicketExportService {
  /// Exports tickets to a CSV file and opens the share sheet.
  /// Add `share_plus` and `path_provider` to pubspec.yaml.
  static Future<void> exportToCsv(
    List<Ticket> tickets,
    BuildContext context, {
    String filename = 'tickets_export',
  }) async {
    if (tickets.isEmpty) {
      _snack(context, 'No tickets to export', error: true);
      return;
    }

    try {
      // Build CSV rows — use only fields confirmed in Ticket model
      final rows = <String>[
        'ID,Category,Status,Priority,Description,User,Created At',
        ...tickets.map((t) {
          String esc(String? s) =>
              '"${(s ?? '').replaceAll('"', '""').replaceAll('\n', ' ')}"';
          return [
            t.id,
            esc(t.category),
            esc(t.status),
            esc(t.priority),
            esc(t.description),
            esc(t.userName),
            esc(t.createdAt),
          ].join(',');
        }),
      ];

      final csv = rows.join('\n');
      final bytes = const Utf8Encoder().convert(csv);

      final dir = await getTemporaryDirectory();
      final ts = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final file = File('${dir.path}/${filename}_$ts.csv');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: 'Ticket Export — ${tickets.length} records',
      );
    } catch (e) {
      if (context.mounted) _snack(context, 'Export failed: $e', error: true);
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SECTION 5 — SLA BREACHED TICKETS SCREEN
// Uses: GET /api/tickets/sla-breached
// ═════════════════════════════════════════════════════════════════════════════

// ═════════════════════════════════════════════════════════════════════════════
// SECTION 5 — SLA BREACHED TICKETS SCREEN
// Uses: GET /api/tickets/sla-breached → TicketResponse[]
// Parsed as raw Map to avoid Ticket model field uncertainty
// ═════════════════════════════════════════════════════════════════════════════

class SlaBreachedScreen extends StatefulWidget {
  const SlaBreachedScreen({super.key});

  @override
  State<SlaBreachedScreen> createState() => _SlaBreachedScreenState();
}

class _SlaBreachedScreenState extends State<SlaBreachedScreen> {
  List<Map<String, dynamic>> _tickets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _dio.get('/api/tickets/sla-breached');
      final raw = res.data;
      _tickets = List<Map<String, dynamic>>.from(
        raw is List ? raw : (raw['content'] ?? []),
      );
    } catch (_) {
      _tickets = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.timer_off_rounded,
                  color: AppColors.danger, size: 18),
            ),
            const SizedBox(width: 10),
            Text('SLA Breached (${_tickets.length})',
                style: const TextStyle(
                    color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
          ],
        ),
        backgroundColor: AppColors.surface,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load)
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tickets.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline_rounded,
                          size: 72,
                          color: AppColors.success.withValues(alpha: 0.6)),
                      const SizedBox(height: 14),
                      const Text('No SLA breaches',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 6),
                      Text('All active tickets are within SLA windows',
                          style: AppTextStyles.caption),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: _tickets.length,
                    itemBuilder: (_, i) => _SlaTicketCard(ticket: _tickets[i]),
                  ),
                ),
    );
  }
}

class _SlaTicketCard extends StatelessWidget {
  final Map<String, dynamic> ticket;
  const _SlaTicketCard({required this.ticket});

  String _hoursAgo() {
    final createdAt = ticket['createdAt']?.toString();
    if (createdAt == null || createdAt.isEmpty) return '';
    try {
      final d = DateTime.parse(createdAt);
      final diff = DateTime.now().difference(d);
      if (diff.inDays > 0) return '${diff.inDays}d overdue';
      return '${diff.inHours}h overdue';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = ticket['id'];
    final category = ticket['category']?.toString() ?? 'General';
    final description = ticket['description']?.toString() ?? '';
    final status = ticket['status']?.toString() ?? 'OPEN';
    final priority = ticket['priority']?.toString() ?? 'MEDIUM';
    final userName = ticket['userName']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFFFCDD2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('#$id · $category',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.danger,
                              fontSize: 13)),
                      const SizedBox(height: 3),
                      Text(description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (_hoursAgo().isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer_off_rounded,
                            color: AppColors.danger, size: 13),
                        const SizedBox(width: 4),
                        Text(_hoursAgo(),
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.danger)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                _pill(status, getStatusColor(status)),
                const SizedBox(width: 8),
                _pill('⚑ $priority', getPriorityColor(priority)),
                const Spacer(),
                if (userName != null && userName.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_outline,
                          size: 13, color: AppColors.textMuted),
                      const SizedBox(width: 3),
                      Text(userName, style: AppTextStyles.caption),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String label, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: color)));
}

// ═════════════════════════════════════════════════════════════════════════════
// SECTION 6 — ESCALATED TICKETS SCREEN
// Uses: GET /api/tickets/escalated → TicketResponse[]
// Parsed as raw Map to avoid Ticket model field uncertainty
// ═════════════════════════════════════════════════════════════════════════════

class EscalatedTicketsScreen extends StatefulWidget {
  const EscalatedTicketsScreen({super.key});

  @override
  State<EscalatedTicketsScreen> createState() => _EscalatedTicketsScreenState();
}

class _EscalatedTicketsScreenState extends State<EscalatedTicketsScreen> {
  List<Map<String, dynamic>> _tickets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _dio.get('/api/tickets/escalated');
      final raw = res.data;
      _tickets = List<Map<String, dynamic>>.from(
        raw is List ? raw : (raw['content'] ?? []),
      );
    } catch (_) {
      _tickets = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.warning_amber_rounded,
                  color: AppColors.danger, size: 18),
            ),
            const SizedBox(width: 10),
            Text('Escalated (${_tickets.length})',
                style: const TextStyle(
                    color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
          ],
        ),
        backgroundColor: AppColors.surface,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load)
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tickets.isEmpty
              ? const EmptyState(
                  icon: Icons.check_circle_outline_rounded,
                  title: 'No escalated tickets',
                  subtitle: 'Escalated tickets will appear here',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: _tickets.length,
                    itemBuilder: (_, i) => _EscalatedCard(ticket: _tickets[i]),
                  ),
                ),
    );
  }
}

class _EscalatedCard extends StatelessWidget {
  final Map<String, dynamic> ticket;
  const _EscalatedCard({required this.ticket});

  @override
  Widget build(BuildContext context) {
    final id = ticket['id'];
    final category = ticket['category']?.toString() ?? 'General';
    final description = ticket['description']?.toString() ?? '';
    final priority = ticket['priority']?.toString() ?? 'HIGH';
    final userName = ticket['userName']?.toString();
    final reason = ticket['escalationReason']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFFFCDD2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.warning_amber_rounded,
                      color: AppColors.danger, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('#$id — $category',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              fontSize: 14)),
                      const SizedBox(height: 3),
                      Text(description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall),
                      if (reason != null && reason.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('Reason: $reason',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.danger),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20)),
                  child: const Text('🚨 ESCALATED',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.danger)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: getPriorityColor(priority).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text('⚑ $priority',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: getPriorityColor(priority))),
                ),
                const Spacer(),
                if (userName != null && userName.isNotEmpty)
                  Text(userName, style: AppTextStyles.caption),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SECTION 7 — CONTACT PUBLIC SUBMIT WIDGET
// Uses: POST /api/contact/public/submit
//       Body: ContactMessageRequest { name, email, message }
// ═════════════════════════════════════════════════════════════════════════════

class ContactPublicSubmitWidget extends StatefulWidget {
  const ContactPublicSubmitWidget({super.key});

  @override
  State<ContactPublicSubmitWidget> createState() =>
      _ContactPublicSubmitWidgetState();
}

class _ContactPublicSubmitWidgetState extends State<ContactPublicSubmitWidget> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  bool _saving = false;
  bool _submitted = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      // POST /api/contact/public/submit
      await _dio.post('/api/contact/public/submit', data: {
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'message': _msgCtrl.text.trim(),
      });
      if (mounted) setState(() => _submitted = true);
    } catch (_) {
      if (mounted)
        _snack(context, 'Message could not be sent. Please try again.',
            error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded,
                  color: AppColors.success, size: 30),
            ),
            const SizedBox(height: 14),
            const Text('Message Sent!',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Text('Our team will respond within 24 hours.',
                style: AppTextStyles.bodySmall, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: () => setState(() {
                _submitted = false;
                _nameCtrl.clear();
                _emailCtrl.clear();
                _msgCtrl.clear();
              }),
              style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryLight,
                  side: const BorderSide(color: AppColors.primaryLight),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              child: const Text('Send Another Message'),
            ),
          ],
        ),
      );
    }

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: _inp('Full Name *', icon: Icons.person_outline_rounded),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: _inp('Email Address *', icon: Icons.email_outlined),
            validator: (v) =>
                RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v ?? '')
                    ? null
                    : 'Valid email required',
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _msgCtrl,
            maxLines: 5,
            maxLength: 2000,
            decoration: _inp('Message *',
                icon: Icons.message_outlined, hint: 'How can we help you?'),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 18),
              label: Text(_saving ? 'Sending...' : 'Send Message',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryLight,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SECTION 8 — FIXED OFFER APPROVALS TAB
// Uses correct endpoint: PUT /api/offers/{id}/status?status=APPROVED|REJECTED
// ═════════════════════════════════════════════════════════════════════════════

class AdminOfferApprovalsTabFixed extends StatefulWidget {
  const AdminOfferApprovalsTabFixed({super.key});

  @override
  State<AdminOfferApprovalsTabFixed> createState() =>
      _AdminOfferApprovalsTabFixedState();
}

class _AdminOfferApprovalsTabFixedState
    extends State<AdminOfferApprovalsTabFixed> {
  List<Map<String, dynamic>> _offers = [];
  bool _loading = true;
  String _filter = 'PENDING';
  int? _processing;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // Try consultant-submitted offers endpoint first
      final res = await _dio.get('/api/offers/consultant-offers');
      final raw = res.data;
      _offers = List<Map<String, dynamic>>.from(
          raw is List ? raw : (raw['content'] ?? []));
    } catch (_) {
      try {
        // Fallback: all offers, filter by consultantId
        final res = await _dio.get('/api/offers/admin');
        final raw = res.data;
        final all = List<Map<String, dynamic>>.from(
            raw is List ? raw : (raw['content'] ?? []));
        _offers = all.where((o) => o['consultantId'] != null).toList();
      } catch (_) {
        _offers = [];
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  String _st(Map o) => (o['status'] ?? 'PENDING').toString().toUpperCase();
  List<Map<String, dynamic>> get _filtered => _filter == 'ALL'
      ? _offers
      : _offers.where((o) => _st(o) == _filter).toList();

  Future<void> _action(int id, String action) async {
    setState(() => _processing = id);
    // ✅ CORRECT endpoint: PUT /api/offers/{id}/status?status=APPROVED|REJECTED
    final status = action == 'approve' ? 'APPROVED' : 'REJECTED';
    try {
      await _dio.put(
        '/api/offers/$id/status',
        queryParameters: {'status': status},
      );
      if (!mounted) return;
      _snack(
          context, action == 'approve' ? 'Offer approved ✓' : 'Offer rejected');
      setState(() {
        _offers = _offers
            .map((o) => o['id'] == id ? {...o, 'status': status} : o)
            .toList();
      });
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Action failed';
      if (mounted) _snack(context, msg, error: true);
    } finally {
      if (mounted) setState(() => _processing = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _offers.where((o) => _st(o) == 'PENDING').length;
    final filtered = _filtered;

    return Column(
      children: [
        // Pending alert banner
        if (pendingCount > 0)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.pending_actions_rounded,
                    color: AppColors.warning, size: 20),
                const SizedBox(width: 10),
                Text(
                  '$pendingCount offer${pendingCount != 1 ? 's' : ''} awaiting review',
                  style: const TextStyle(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
              ],
            ),
          ),

        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: ['PENDING', 'APPROVED', 'REJECTED', 'ALL'].map((f) {
              final count = f == 'ALL'
                  ? _offers.length
                  : _offers.where((o) => _st(o) == f).length;
              final color = f == 'APPROVED'
                  ? AppColors.success
                  : f == 'REJECTED'
                      ? AppColors.danger
                      : f == 'PENDING'
                          ? AppColors.warning
                          : AppColors.primaryLight;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text('$f ($count)'),
                  selected: _filter == f,
                  selectedColor: color.withValues(alpha: 0.12),
                  checkmarkColor: color,
                  onSelected: (_) => setState(() => _filter = f),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _filter == f ? color : AppColors.textSecondary,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),

        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? const EmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'No offers found')
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final o = filtered[i];
                          final st = _st(o);
                          final isPending = st == 'PENDING';
                          final stColor = st == 'APPROVED'
                              ? AppColors.success
                              : st == 'REJECTED'
                                  ? AppColors.danger
                                  : AppColors.warning;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: isPending
                                    ? AppColors.warning.withValues(alpha: 0.4)
                                    : AppColors.border,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(o['title'] ?? 'Untitled',
                                                style: AppTextStyles.h4),
                                            if (o['description'] != null)
                                              Text(o['description'],
                                                  style: AppTextStyles.caption,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis),
                                          ],
                                        ),
                                      ),
                                      if (o['discount'] != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.danger,
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(o['discount'].toString(),
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w800)),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(spacing: 8, runSpacing: 6, children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                          color: stColor.withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(20)),
                                      child: Text(st,
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: stColor,
                                              fontWeight: FontWeight.w700)),
                                    ),
                                    if (o['consultantId'] != null)
                                      Text('Consultant #${o['consultantId']}',
                                          style: AppTextStyles.caption),
                                  ]),
                                  if (isPending) ...[
                                    const SizedBox(height: 14),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: _processing == o['id']
                                                ? null
                                                : () =>
                                                    _action(o['id'], 'reject'),
                                            icon: const Icon(
                                                Icons.close_rounded,
                                                size: 16),
                                            label: const Text('Reject'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: AppColors.danger,
                                              side: const BorderSide(
                                                  color: AppColors.danger),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          10)),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: _processing == o['id']
                                                ? null
                                                : () =>
                                                    _action(o['id'], 'approve'),
                                            icon: _processing == o['id']
                                                ? const SizedBox(
                                                    width: 14,
                                                    height: 14,
                                                    child:
                                                        CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            color:
                                                                Colors.white))
                                                : const Icon(
                                                    Icons.check_rounded,
                                                    size: 16,
                                                    color: Colors.white),
                                            label: const Text('Approve',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight:
                                                        FontWeight.w700)),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.success,
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          10)),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SECTION 9 — FIXED SKILLS & QUESTIONS TAB
// Fixes: SkillRequest uses 'skillName' (not 'name')
// ═════════════════════════════════════════════════════════════════════════════

/// Drop-in replacement for _AdminSkillsQuestionsTab in admin_dashboard.dart
class AdminSkillsQuestionsTabFixed extends StatefulWidget {
  const AdminSkillsQuestionsTabFixed({super.key});

  @override
  State<AdminSkillsQuestionsTabFixed> createState() =>
      _AdminSkillsQuestionsTabFixedState();
}

class _AdminSkillsQuestionsTabFixedState
    extends State<AdminSkillsQuestionsTabFixed>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Map<String, dynamic>> _skills = [], _questions = [];
  bool _loading = true;
  int? _filterSkillId;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // GET /api/skills  → SkillResponse[] { id, skillName, active }
      final sr = await _dio.get('/api/skills');
      _skills = List<Map<String, dynamic>>.from(
        sr.data is List ? sr.data : (sr.data['content'] ?? []),
      );

      if (_skills.isNotEmpty) {
        final ids = _skills.map((s) => s['id'].toString()).join('&skillIds=');
        final qr = await _dio.get('/api/questions?skillIds=$ids');
        final raw = qr.data;
        final qList = List<Map<String, dynamic>>.from(
            raw is List ? raw : (raw['content'] ?? []));
        final sm = {
          for (final s in _skills) s['id']: s['skillName'] ?? 'Skill'
        };
        _questions =
            qList.map((q) => {...q, '_sn': sm[q['skillId']] ?? ''}).toList();
      } else {
        _questions = [];
      }
    } catch (e) {
      _skills = [];
      _questions = [];
      if (mounted) _snack(context, 'Failed to load: $e', error: true);
    }
    if (mounted) setState(() => _loading = false);
  }

  void _showSkillForm([Map<String, dynamic>? s]) {
    // ✅ FIX: use 'skillName' field from existing skill
    final nc = TextEditingController(text: s?['skillName'] ?? '');
    final dc = TextEditingController(text: s?['description'] ?? '');
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (_, ss) {
        return Padding(
          padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2)))),
              Row(children: [
                Expanded(
                    child: Text(s != null ? 'Edit Skill' : 'New Skill',
                        style: AppTextStyles.h3)),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx)),
              ]),
              const SizedBox(height: 16),
              TextField(
                  controller: nc,
                  style: const TextStyle(color: AppColors.textPrimary),
                  cursorColor: AppColors.primaryLight,
                  decoration:
                      _inp('Skill name *', icon: Icons.category_outlined)),
              const SizedBox(height: 12),
              TextField(
                  controller: dc,
                  decoration: _inp('Description (optional)'),
                  maxLines: 2),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (nc.text.trim().isEmpty) return;
                          ss(() => saving = true);
                          try {
                            // ✅ FIX: SkillRequest schema uses 'skillName', not 'name'
                            final payload = {'skillName': nc.text.trim()};
                            if (s != null) {
                              await _dio.put('/api/skills/${s['id']}',
                                  data: payload);
                            } else {
                              await _dio.post('/api/skills', data: payload);
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                            _load();
                          } on DioException catch (e) {
                            final msg =
                                e.response?.data?['message'] ?? 'Save failed';
                            if (ctx.mounted) _snack(ctx, msg, error: true);
                            ss(() => saving = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryLight,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  child: Text(s != null ? 'Update Skill' : 'Create Skill',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Future<void> _deleteSkill(Map<String, dynamic> s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: 'Delete Skill?',
        body:
            'Delete "${s['skillName'] ?? 'this skill'}"? All linked questions will also be removed.',
        confirmLabel: 'Delete',
        confirmColor: AppColors.danger,
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _dio.delete('/api/skills/${s['id']}');
      if (!mounted) return;
      _snack(context, 'Skill deleted');
      _load();
    } catch (_) {
      if (mounted) _snack(context, 'Delete failed', error: true);
    }
  }

  void _showQForm([Map<String, dynamic>? q]) {
    final tc = TextEditingController(text: q?['text'] ?? '');
    int? selSkill = q != null ? q['skillId'] as int? : null;
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (_, ss) {
        return Padding(
          padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2)))),
              Row(children: [
                Expanded(
                    child: Text(q != null ? 'Edit Question' : 'New Question',
                        style: AppTextStyles.h3)),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx)),
              ]),
              const SizedBox(height: 16),
              if (_skills.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Text(
                      'Create skills first before adding questions.',
                      style: TextStyle(color: AppColors.warning)),
                ),
              DropdownButtonFormField<int>(
                initialValue: selSkill,
                decoration:
                    _inp('Skill category *', icon: Icons.category_outlined),
                items: _skills
                    .map((s) => DropdownMenuItem(
                          value: s['id'] as int,
                          child: Text(s['skillName'] ?? 'Skill',
                              style: AppTextStyles.body),
                        ))
                    .toList(),
                onChanged: (v) => ss(() => selSkill = v),
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: tc,
                  decoration:
                      _inp('Question text *', icon: Icons.help_outline_rounded),
                  maxLines: 3),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: (saving || selSkill == null)
                      ? null
                      : () async {
                          if (tc.text.trim().isEmpty) return;
                          ss(() => saving = true);
                          try {
                            // QuestionRequest: { skillId, text }
                            final payload = {
                              'skillId': selSkill,
                              'text': tc.text.trim()
                            };
                            if (q != null) {
                              await _dio.put('/api/questions/${q['id']}',
                                  data: payload);
                            } else {
                              await _dio.post('/api/questions', data: payload);
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                            _load();
                          } on DioException catch (e) {
                            final msg =
                                e.response?.data?['message'] ?? 'Save failed';
                            if (ctx.mounted) _snack(ctx, msg, error: true);
                            ss(() => saving = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryLight,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  child: Text(q != null ? 'Update Question' : 'Create Question',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Future<void> _deleteQ(Map<String, dynamic> q) async {
    try {
      await _dio.delete('/api/questions/${q['id']}');
      if (!mounted) return;
      _snack(context, 'Question deleted');
      _load();
    } catch (_) {
      if (mounted) _snack(context, 'Delete failed', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredQ = _filterSkillId == null
        ? _questions
        : _questions.where((q) => q['skillId'] == _filterSkillId).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Skills & Questions',
            style: TextStyle(color: AppColors.textPrimary)),
        backgroundColor: AppColors.surface,
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primaryLight,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.primaryLight,
          tabs: [
            Tab(text: 'Skills (${_skills.length})'),
            Tab(text: 'Questions (${_questions.length})'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _tabs.index == 0 ? _showSkillForm() : _showQForm(),
          ),
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                // ── Skills tab ─────────────────────────────────────────────
                _skills.isEmpty
                    ? const EmptyState(
                        icon: Icons.category_outlined,
                        title: 'No skills yet',
                        subtitle: 'Tap + to create your first skill category')
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _skills.length,
                        itemBuilder: (_, i) {
                          final s = _skills[i];
                          final name = s['skillName'] ?? 'Skill';
                          final qCount = _questions
                              .where((q) => q['skillId'] == s['id'])
                              .length;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: const BorderSide(color: Color(0xFFDDD6FE)),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEDE9FE),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.category_rounded,
                                    color: Color(0xFF7C3AED), size: 20),
                              ),
                              title: Text(name, style: AppTextStyles.h4),
                              subtitle: Text(
                                  '$qCount question${qCount != 1 ? 's' : ''}',
                                  style: AppTextStyles.caption),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined,
                                        size: 18,
                                        color: AppColors.primaryLight),
                                    onPressed: () => _showSkillForm(s),
                                    splashRadius: 18,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        size: 18, color: AppColors.danger),
                                    onPressed: () => _deleteSkill(s),
                                    splashRadius: 18,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                // ── Questions tab ──────────────────────────────────────────
                Column(
                  children: [
                    if (_skills.isNotEmpty)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text('All (${_questions.length})'),
                                selected: _filterSkillId == null,
                                onSelected: (_) =>
                                    setState(() => _filterSkillId = null),
                              ),
                            ),
                            ..._skills.map((s) {
                              final id = s['id'] as int;
                              final cnt = _questions
                                  .where((q) => q['skillId'] == id)
                                  .length;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  label: Text('${s['skillName']} ($cnt)'),
                                  selected: _filterSkillId == id,
                                  onSelected: (_) =>
                                      setState(() => _filterSkillId = id),
                                  selectedColor: const Color(0xFFEDE9FE),
                                  checkmarkColor: const Color(0xFF7C3AED),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: filteredQ.isEmpty
                          ? const EmptyState(
                              icon: Icons.quiz_outlined,
                              title: 'No questions',
                              subtitle: 'Tap + to add questions for a skill')
                          : ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: filteredQ.length,
                              itemBuilder: (_, i) {
                                final q = filteredQ[i];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 4),
                                    leading: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                          color: const Color(0xFFEDE9FE),
                                          borderRadius:
                                              BorderRadius.circular(20)),
                                      child: Text(q['_sn'] ?? '',
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color: Color(0xFF7C3AED),
                                              fontWeight: FontWeight.w700)),
                                    ),
                                    title: Text(q['text'] ?? '',
                                        style: AppTextStyles.body),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined,
                                              size: 18,
                                              color: AppColors.primaryLight),
                                          onPressed: () => _showQForm(q),
                                          splashRadius: 18,
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline,
                                              size: 18,
                                              color: AppColors.danger),
                                          onPressed: () => _deleteQ(q),
                                          splashRadius: 18,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SHARED UI HELPERS (reused throughout this file)
// ═════════════════════════════════════════════════════════════════════════════

class _FormSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _FormSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 12),
          child: Text(
            title.toUpperCase(),
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: children),
        ),
      ],
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String body;
  final String confirmLabel;
  final Color confirmColor;
  const _ConfirmDialog({
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.confirmColor,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      title: Text(title, style: AppTextStyles.h3),
      content: Text(body, style: AppTextStyles.body.copyWith(height: 1.5)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(confirmLabel,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// INTEGRATION GUIDE — Copy-paste changes needed in admin_dashboard.dart
// ═════════════════════════════════════════════════════════════════════════════
//
// 1. ADD to AdminSection enum:
//    | userManagement
//
// 2. ADD to drawer _section() 'Management':
//    _tile(ctx, Icons.manage_accounts_rounded, 'User Management', AdminSection.userManagement),
//
// 3. ADD to AdminDashboard._body() switch:
//    case AdminSection.userManagement: return const AdminUserManagementScreen();
//
// 4. REPLACE in _body() switch:
//    case AdminSection.offerApprovals: return const AdminOfferApprovalsTabFixed();
//    case AdminSection.skillsQuestions: return const AdminSkillsQuestionsTabFixed();
//
// 5. UPDATE _AdminSettingsTab._tile() for settings:
//    Add:
//    _tile(ctx, Icons.account_circle_outlined, 'Profile & Security', 'Update your profile and password', AppColors.primaryLight,
//        () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const AdminProfileSettingsScreen()))),
//
// 6. ADD to pubspec.yaml dependencies:
//    image_picker: ^1.1.2
//    path_provider: ^2.1.3
//    share_plus: ^9.0.0
//
// 7. ADD AnalyticsService.getAnalytics() alias in analytics_service.dart:
//    Future<DashboardAnalytics> getAnalytics({String period = 'WEEKLY'}) =>
//        getFullDashboard(period: period);
//
// 8. QUICK ACTIONS in _AdminOverviewTab._quick():
//    Add case 'SLA Alerts' → SlaBreachedScreen
//    Add case 'Escalated'  → EscalatedTicketsScreen
//
// 9. EXPORT BUTTON in _AdminTicketsTab:
//    Replace SnackBar stub with:
//    TicketExportService.exportToCsv(_filtered, context);

// ═════════════════════════════════════════════════════════════════════════════
// SECTION 8 — ADMIN ADD MEMBER SCREEN
// Web parity: AdminPage.tsx → AddMemberPanel
// Endpoint: POST /api/onboarding/admin/member (multipart/form-data)
// Fields: name, email, phoneNumber, location
// Backend auto-generates password and emails login credentials to the member.
// ═════════════════════════════════════════════════════════════════════════════

class AdminAddMemberScreen extends StatefulWidget {
  const AdminAddMemberScreen({super.key});
  @override
  State<AdminAddMemberScreen> createState() => _AdminAddMemberScreenState();
}

class _AdminAddMemberScreenState extends State<AdminAddMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  bool _saving = false;

  // Recently added members shown in a list on the right (web parity)
  List<Map<String, dynamic>> _recentMembers = [];
  bool _loadingMembers = true;

  @override
  void initState() {
    super.initState();
    _loadRecentMembers();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _mobileCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRecentMembers() async {
    setState(() => _loadingMembers = true);
    try {
      final res = await _dio.get('/api/users');
      final list = res.data is List
          ? res.data as List
          : (res.data?['content'] as List? ?? []);
      final memberRoles = {
        'USER',
        'MEMBER',
        'CLIENT',
        'SUBSCRIBER',
        'SUBSCRIBED',
        'GUEST'
      };
      final mapped = list
          .where((u) {
            final role = _cleanRole(u['role'] ?? u['userRole'] ?? '');
            return memberRoles.contains(role);
          })
          .map((u) => Map<String, dynamic>.from(u as Map))
          .toList()
          .take(10)
          .toList();
      setState(() => _recentMembers = []);
      final enriched = await _mergeUsersWithProfiles(mapped);
      if (mounted) setState(() => _recentMembers = enriched);
    } catch (_) {
      setState(() => _recentMembers = []);
    }
    if (mounted) setState(() => _loadingMembers = false);
  }

  String _resolveName(Map<String, dynamic> u) {
    final raw = u['profileName'] ??
        u['name'] ??
        u['fullName'] ??
        u['firstName'] ??
        u['username'] ??
        '';
    if (raw.toString().isNotEmpty) return raw.toString().trim();
    final email = u['profileEmail']?.toString() ??
        u['email']?.toString() ??
        u['identifier']?.toString() ??
        '';
    if (email.contains('@'))
      return email.split('@')[0].replaceAll(RegExp(r'[._-]'), ' ').trim();
    return 'Member';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final payload = {
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim().toLowerCase(),
        'phoneNumber': _mobileCtrl.text.trim(),
        'location': _locationCtrl.text.trim(),
        'profileImageUrl': null,
      };

      final formData = FormData.fromMap({
        'data': MultipartFile.fromString(
          jsonEncode(payload),
          filename: 'data.json',
          contentType: DioMediaType.parse('application/json'),
        ),
      });

      await _dio.post('/api/onboarding/admin/member', data: formData);

      if (mounted) {
        _snack(context,
            'Member "${_nameCtrl.text.trim()}" added! Credentials sent to ${_emailCtrl.text.trim().toLowerCase()}.');
        _nameCtrl.clear();
        _emailCtrl.clear();
        _mobileCtrl.clear();
        _locationCtrl.clear();
        _loadRecentMembers();
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      String msg = 'Failed to add member.';
      if (e.response?.statusCode == 409)
        msg = 'Email or phone number already registered.';
      else if (e.response?.statusCode == 403)
        msg = 'Access denied. Admin role required.';
      else if (data is Map) msg = data['message'] ?? msg;
      if (mounted) _snack(context, msg, error: true);
    } catch (_) {
      if (mounted)
        _snack(context, 'Failed to add member. Please try again.', error: true);
    }

    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info banner — same as web
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.primaryLight.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: AppColors.primaryLight, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'A secure password is automatically created and the member\'s login details are sent to their email. They can log in immediately and update their password from their profile.',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.primaryLight),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Form card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Member Details', style: AppTextStyles.label),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: [_leadingLetterFormatter],
                      decoration: _inp('Full Name *',
                          icon: Icons.person_outline_rounded),
                      validator: (v) =>
                          _capitalizedTextError(v, field: 'Full name') ??
                          ((v ?? '').trim().length < 2
                              ? 'Enter a valid full name'
                              : null),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration:
                          _inp('Email Address *', icon: Icons.email_outlined),
                      validator: (v) {
                        if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                            .hasMatch(v ?? '')) return 'Valid email required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _mobileCtrl,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: _inp('Mobile Number *',
                          icon: Icons.phone_outlined, hint: '10-digit number'),
                      validator: (v) {
                        if (!RegExp(r'^[6-9]\d{9}$').hasMatch(v ?? ''))
                          return 'Valid 10-digit Indian mobile required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _locationCtrl,
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: [_leadingLetterFormatter],
                      decoration: _inp('Location',
                          icon: Icons.location_on_outlined,
                          hint: 'City, State'),
                      validator: (v) => _capitalizedTextError(
                        v,
                        field: 'Location',
                        requiredField: false,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              _formKey.currentState?.reset();
                              _nameCtrl.clear();
                              _emailCtrl.clear();
                              _mobileCtrl.clear();
                              _locationCtrl.clear();
                            },
                            child: const Text('Reset'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _submit,
                            style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primaryLight),
                            icon: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.person_add_rounded,
                                    color: Colors.white, size: 18),
                            label: Text(
                              _saving ? 'Adding…' : 'Add Member',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Recently added members
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recently Added Members', style: AppTextStyles.label),
                Text('(${_recentMembers.length})',
                    style: AppTextStyles.caption),
              ],
            ),
            const SizedBox(height: 10),
            if (_loadingMembers)
              const Center(
                child: MeetTheMastersLoadingIndicator(label: 'Loading members'),
              )
            else if (_recentMembers.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border)),
                child: const Center(
                    child: Text('No members added yet.',
                        style: TextStyle(color: AppColors.textMuted))),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _recentMembers.length,
                itemBuilder: (_, i) {
                  final m = _recentMembers[i];
                  final name = _resolveName(m);
                  final email = m['email']?.toString() ?? '';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.1),
                        child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name,
                                  style: AppTextStyles.h4,
                                  overflow: TextOverflow.ellipsis),
                              if (email.isNotEmpty)
                                Text(email,
                                    style: AppTextStyles.caption,
                                    overflow: TextOverflow.ellipsis),
                            ]),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color:
                                AppColors.primaryLight.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20)),
                        child: const Text('MEMBER',
                            style: TextStyle(
                                fontSize: 9,
                                color: AppColors.primaryLight,
                                fontWeight: FontWeight.w700)),
                      ),
                    ]),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}