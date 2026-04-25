import 'dart:io';

import 'package:dio/dio.dart';
import 'package:finadvise/api_client.dart';
import 'package:finadvise/app_theme.dart';
import 'package:finadvise/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _authService = AuthService();
  final _userService = UserService();
  final _onboardingService = OnboardingService();
  final _subscriptionService = SubscriptionService();

  bool _isLoading = false;
  bool _isSaving = false;
  bool _isEditing = false;

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _identifierCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  List<Map<String, dynamic>> _incomes = [];
  List<Map<String, dynamic>> _expenses = [];
  int? _userId;
  String? _profileImageUrl;
  String? _role;
  XFile? _pickedImage;
  bool _isChangingPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  static const List<Map<String, dynamic>> _fallbackPlans = [
    {'name': 'Elite', 'price': 999, 'isPremium': true},
    {'name': 'Pro', 'price': 499, 'isPremium': true},
    {'name': 'Guest', 'price': 0, 'isPremium': false},
  ];
  List<Map<String, dynamic>> _plans = [];

  String _selectedPlan = 'Elite';
  String _currentPlan = 'Elite';
  String _memberSince = '14 Feb 2026';

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _locationCtrl.dispose();
    _identifierCtrl.dispose();
    _dobCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    try {
      final rawUserId = await _authService.getUserId();
      final userId = int.tryParse(rawUserId ?? '');
      final me = await _userService.getMe();
      final rawOnboarding = userId != null
          ? await _userService.getOnboardingProfile(userId)
          : null;
      final onboarding =
          userId != null ? await _onboardingService.getProfile(userId) : null;
      final plans = await _subscriptionService.getSubscriptionPlans();

      _userId = userId ?? me?.id;
      _nameCtrl.text = onboarding?.name ?? me?.name ?? '';
      _emailCtrl.text = onboarding?.email ?? me?.email ?? '';
      _phoneCtrl.text = onboarding?.phoneNumber ?? me?.phone ?? '';
      _locationCtrl.text = onboarding?.location ?? '';
      _identifierCtrl.text = onboarding?.identifier ?? '';
      _dobCtrl.text = _formatDateForInput(onboarding?.dob);
      _profileImageUrl = onboarding?.photoUrl;
      _role = me?.role;

      final planId = onboarding?.subscriptionPlanId;
      final planName = _planNameFromId(
        planId,
        subscribed: rawOnboarding?['subscribed'] == true,
        plans: plans,
      );

      final memberSince = _formatMemberSince(
        (rawOnboarding?['memberSince'] ??
                rawOnboarding?['createdAt'] ??
                rawOnboarding?['updatedAt'])
            ?.toString(),
      );

      setState(() {
        _currentPlan = planName;
        _selectedPlan = planName;
        _memberSince = memberSince;
        _plans = plans;
        _incomes = _normalizeFinanceItems(onboarding?.incomeItems ?? const []);
        _expenses =
            _normalizeFinanceItems(onboarding?.expenseItems ?? const []);
      });
    } catch (_) {
      _showSnackBar('Failed to load profile', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveProfileData() async {
    FocusScope.of(context).unfocus();
    if (_nameCtrl.text.trim().isEmpty) {
      _showSnackBar('Full name is required', isError: true);
      return;
    }
    if (_emailCtrl.text.trim().isEmpty || !_emailCtrl.text.contains('@')) {
      _showSnackBar('Enter a valid email', isError: true);
      return;
    }
    if (!RegExp(r'^\d{10}$').hasMatch(_phoneCtrl.text.trim())) {
      _showSnackBar('Phone number must be 10 digits', isError: true);
      return;
    }
    setState(() => _isSaving = true);
    try {
      final userId =
          _userId ?? int.tryParse(await _authService.getUserId() ?? '');
      if (userId == null || userId == 0) throw Exception('Missing user id');
      MultipartFile? profilePhoto;
      if (_pickedImage != null) {
        profilePhoto = await MultipartFile.fromFile(
          _pickedImage!.path,
          filename: _pickedImage!.name,
        );
      }

      final ok = await _onboardingService.updateProfile(
        userId,
        {
          'name': _nameCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'phoneNumber': _phoneCtrl.text.trim(),
          'location': _locationCtrl.text.trim(),
          'identifier': _identifierCtrl.text.trim(),
          if (_dobCtrl.text.trim().isNotEmpty) 'dob': _dobCtrl.text.trim(),
          'subscriptionPlanId': _planIdFromName(_selectedPlan),
          'incomeItems': _serializeFinanceItems(_incomes),
          'expenseItems': _serializeFinanceItems(_expenses),
        },
        profilePhoto: profilePhoto,
      );

      if (!ok) throw Exception('Update failed');

      setState(() {
        _isEditing = false;
        _currentPlan = _selectedPlan;
        if (_pickedImage != null) {
          _profileImageUrl = _pickedImage!.path;
        }
        _pickedImage = null;
      });
      _showSnackBar('Profile updated successfully!');
      await _loadProfileData();
    } catch (_) {
      _showSnackBar('Error saving profile', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: isError ? AppColors.danger : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image == null || !mounted) return;
    setState(() => _pickedImage = image);
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initialDate =
        DateTime.tryParse(_dobCtrl.text) ?? DateTime(now.year - 25, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1950, 1, 1),
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    setState(() => _dobCtrl.text = _formatDateForInput(picked.toIso8601String()));
  }

  Future<void> _changePassword() async {
    FocusScope.of(context).unfocus();
    if (_newPasswordCtrl.text.length < 8) {
      _showSnackBar('Password must be at least 8 characters', isError: true);
      return;
    }
    if (_newPasswordCtrl.text != _confirmPasswordCtrl.text) {
      _showSnackBar('Passwords do not match', isError: true);
      return;
    }

    setState(() => _isChangingPassword = true);
    try {
      final result = await _authService.changePassword(
        newPassword: _newPasswordCtrl.text,
        confirmPassword: _confirmPasswordCtrl.text,
      );
      if (!result.success) {
        throw Exception(result.error ?? 'Password change failed');
      }
      _newPasswordCtrl.clear();
      _confirmPasswordCtrl.clear();
      _showSnackBar('Password changed successfully!');
    } catch (e) {
      _showSnackBar(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isChangingPassword = false);
      }
    }
  }

  void _showAddFinanceDialog(bool isIncome) {
    final labelCtrl = TextEditingController();
    final amountCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isIncome ? 'Add Income' : 'Add Expense',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelCtrl,
              decoration: InputDecoration(
                labelText: 'Label',
                hintText: isIncome ? 'Salary' : 'Rent',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '₹ ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (labelCtrl.text.trim().isEmpty ||
                  amountCtrl.text.trim().isEmpty) {
                return;
              }
              setState(() {
                final item = {
                  'label': labelCtrl.text.trim(),
                  'amount': double.tryParse(amountCtrl.text.trim()) ?? 0,
                };
                if (isIncome) {
                  _incomes.add(item);
                } else {
                  _expenses.add(item);
                }
              });
              Navigator.pop(ctx);
            },
            child: Text(
              'Add',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  double get _totalIncome => _incomes.fold<double>(
        0,
        (sum, item) => sum + _financeAmount(item),
      );

  double get _totalExpense => _expenses.fold<double>(
        0,
        (sum, item) => sum + _financeAmount(item),
      );

  bool get _isSubscribedType => _selectedPlan.toLowerCase() != 'guest';

  List<Map<String, dynamic>> get _planOptions =>
      _plans.isEmpty ? _fallbackPlans : _plans;

  String get _initials {
    final parts = _nameCtrl.text
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'U';
    return parts.take(2).map((e) => e[0]).join().toUpperCase();
  }

  double _financeAmount(Map<String, dynamic> item) {
    final raw = item['amount'] ?? item['incomeAmount'] ?? item['expenseAmount'];
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString() ?? '0') ?? 0;
  }

  List<Map<String, dynamic>> _normalizeFinanceItems(
      List<Map<String, dynamic>> items) {
    return items
        .map((item) => {
              'label': (item['label'] ?? item['name'] ?? item['title'] ?? '')
                  .toString(),
              'amount': _financeAmount(item),
            })
        .where((item) => (item['label'] ?? '').toString().isNotEmpty)
        .toList();
  }

  List<Map<String, dynamic>> _serializeFinanceItems(
      List<Map<String, dynamic>> items) {
    return items
        .map((item) => {
              'label': (item['label'] ?? '').toString().trim(),
              'amount': _financeAmount(item),
            })
        .where((item) => (item['label'] ?? '').toString().isNotEmpty)
        .toList();
  }

  String _planNameFromId(
    int? planId, {
    bool subscribed = false,
    List<Map<String, dynamic>> plans = const [],
  }) {
    if (planId != null) {
      for (final plan in plans) {
        final id = _asInt(plan['id']);
        if (id == planId) {
          final name = (plan['name'] ?? '').toString().trim();
          if (name.isNotEmpty) return name;
        }
      }
    }
    switch (planId) {
      case 1:
        return 'Elite';
      case 2:
        return 'Pro';
      default:
        return subscribed ? 'Elite' : 'Guest';
    }
  }

  int? _planIdFromName(String planName) {
    for (final plan in _plans) {
      final name = (plan['name'] ?? '').toString().trim().toLowerCase();
      if (name == planName.toLowerCase()) {
        return _asInt(plan['id']);
      }
    }
    switch (planName.toLowerCase()) {
      case 'elite':
        return 1;
      case 'pro':
        return 2;
      default:
        return null;
    }
  }

  String _formatMemberSince(String? rawDate) {
    if (rawDate == null || rawDate.trim().isEmpty) return '—';
    final parsed = DateTime.tryParse(rawDate);
    if (parsed == null) return '—';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${parsed.day.toString().padLeft(2, '0')} ${months[parsed.month - 1]} ${parsed.year}';
  }

  String _formatDateForInput(String? rawDate) {
    final parsed = rawDate == null ? null : DateTime.tryParse(rawDate);
    if (parsed == null) return '';
    return '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  num _planPrice(Map<String, dynamic> plan) {
    final raw = plan['discountPrice'] ?? plan['price'] ?? plan['originalPrice'];
    if (raw is num) return raw;
    return num.tryParse(raw?.toString() ?? '0') ?? 0;
  }

  ImageProvider? _profileImageProvider() {
    if (_pickedImage != null) {
      return FileImage(File(_pickedImage!.path));
    }
    final raw = _profileImageUrl?.trim();
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http')) return NetworkImage(raw);
    if (raw.startsWith('/') || raw.contains('uploads')) {
      return NetworkImage(ApiClient.buildBackendAssetUrl(raw));
    }
    return FileImage(File(raw));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.brandBlue),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Account Profile',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _isEditing
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: _isSaving
                            ? null
                            : () => setState(() => _isEditing = false),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.inter(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isSaving ? null : _saveProfileData,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          backgroundColor: AppColors.brandBlue,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Save',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ],
                  )
                : OutlinedButton(
                    onPressed: () => setState(() => _isEditing = true),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                          color: AppColors.brandBlue, width: 1.5),
                      backgroundColor: const Color(0xFFEFF6FF),
                    ),
                    child: Text(
                      'Edit',
                      style: GoogleFonts.inter(
                        color: AppColors.brandBlue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileHeader(),
              const SizedBox(height: 16),
              _buildDetailsCard(),
              const SizedBox(height: 16),
              _buildSubscriptionCard(),
              const SizedBox(height: 16),
              _buildSecurityCard(),
              const SizedBox(height: 16),
              _buildFinanceSummary(),
              const SizedBox(height: 16),
              _buildFinanceSection(
                title: 'Income Sources',
                items: _incomes,
                isIncome: true,
              ),
              const SizedBox(height: 16),
              _buildFinanceSection(
                title: 'Monthly Expenses',
                items: _expenses,
                isIncome: false,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A5F), AppColors.brandBlue],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppShadows.xl,
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.35),
                    width: 3,
                  ),
                  image: _profileImageProvider() != null
                      ? DecorationImage(
                          image: _profileImageProvider()!,
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                alignment: Alignment.center,
                child: _profileImageProvider() == null
                    ? Text(
                        _initials,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    : null,
              ),
              if (_isEditing)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: InkWell(
                    onTap: _pickProfileImage,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.brandBlue,
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.camera_alt_outlined,
                        size: 16,
                        color: AppColors.brandBlue,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _nameCtrl.text.isEmpty ? 'User' : _nameCtrl.text,
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _emailCtrl.text,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                if ((_role ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    _role!,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.88),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withOpacity(0.28)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isSubscribedType
                            ? Icons.verified_rounded
                            : Icons.person_outline,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isSubscribedType
                            ? '$_currentPlan Member'
                            : 'Guest Account',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    return _buildSectionCard(
      title: 'Personal Details',
      icon: Icons.person_outline,
      child: _isEditing ? _buildEditFields() : _buildDetailsGrid(),
    );
  }

  Widget _buildEditFields() {
    return Column(
      children: [
        _buildInputField('Full Name', _nameCtrl,
            keyboardType: TextInputType.name),
        const SizedBox(height: 14),
        _buildInputField('Email', _emailCtrl,
            keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 14),
        _buildInputField('Location', _locationCtrl,
            keyboardType: TextInputType.streetAddress),
        const SizedBox(height: 14),
        _buildInputField('Phone', _phoneCtrl,
            keyboardType: TextInputType.phone),
        const SizedBox(height: 14),
        _buildInputField('Identifier (PAN/Aadhaar)', _identifierCtrl,
            keyboardType: TextInputType.text),
        const SizedBox(height: 14),
        _buildDateField(),
      ],
    );
  }

  Widget _buildDateField() {
    return TextField(
      controller: _dobCtrl,
      readOnly: true,
      onTap: _pickDob,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: 'Date of Birth',
        labelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
        filled: true,
        fillColor: const Color(0xFFF8FBFF),
        suffixIcon: IconButton(
          onPressed: _pickDob,
          icon: const Icon(Icons.calendar_month_outlined),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFBFDBFE), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.brandBlue, width: 1.6),
        ),
      ),
    );
  }

  Widget _buildInputField(
    String label,
    TextEditingController controller, {
    required TextInputType keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
        filled: true,
        fillColor: const Color(0xFFF8FBFF),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFBFDBFE), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.brandBlue, width: 1.6),
        ),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildDetailsGrid() {
    final items = [
      {'label': 'Email', 'value': _emailCtrl.text},
      {'label': 'Location', 'value': _locationCtrl.text},
      {'label': 'Phone', 'value': _phoneCtrl.text},
      {'label': 'Identifier', 'value': _identifierCtrl.text},
      {'label': 'Date of Birth', 'value': _dobCtrl.text},
      {'label': 'Plan', 'value': _currentPlan},
      {'label': 'Member Since', 'value': _memberSince},
      {'label': 'Role', 'value': _role ?? '—'},
    ];

    return Wrap(
      spacing: 0,
      runSpacing: 0,
      children: items.map((item) {
        return SizedBox(
          width: MediaQuery.of(context).size.width > 560
              ? (MediaQuery.of(context).size.width - 64) / 2
              : double.infinity,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: const BorderSide(color: Color(0xFFF1F5F9)),
                right: MediaQuery.of(context).size.width > 560
                    ? const BorderSide(color: Color(0xFFF1F5F9))
                    : BorderSide.none,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['label']!,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  item['value']!,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSubscriptionCard() {
    return _buildSectionCard(
      title: 'Subscription Plan',
      icon: Icons.shield_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatusPill(
                label: 'SUBSCRIBED - FULL ACCESS',
                active: _isSubscribedType,
                activeColor: AppColors.brandBlue,
                activeBackground: const Color(0xFFEFF6FF),
              ),
              _buildStatusPill(
                label: 'GUEST - LIMITED ACCESS',
                active: !_isSubscribedType,
                activeColor: AppColors.danger,
                activeBackground: const Color(0xFFFEF2F2),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._planOptions.map(_buildPlanTile),
        ],
      ),
    );
  }

  Widget _buildStatusPill({
    required String label,
    required bool active,
    required Color activeColor,
    required Color activeBackground,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: active ? activeBackground : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active ? activeColor : const Color(0xFFCBD5E1),
          width: 1.5,
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: active ? activeColor : AppColors.textMuted,
        ),
      ),
    );
  }

  Widget _buildPlanTile(Map<String, dynamic> plan) {
    final name = (plan['name'] ?? 'Plan').toString();
    final int price = _planPrice(plan).round();
    final bool isPremium = plan['isPremium'] == true || price > 0;
    final bool isSelected = _selectedPlan == name;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _selectedPlan = name),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppColors.brandBlue : AppColors.border,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isSelected
                            ? AppColors.brandBlue
                            : AppColors.textPrimary,
                      ),
                    ),
                    if (isPremium) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: Text(
                          'PREMIUM',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF16A34A),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                price == 0 ? 'Guest' : '₹$price',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: price == 0
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.brandBlue
                        : const Color(0xFFCBD5E1),
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: isSelected
                    ? Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.brandBlue,
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFinanceSummary() {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryTile(
            title: 'Total Income',
            amount: _totalIncome,
            color: const Color(0xFF16A34A),
            background: const Color(0xFFF0FDF4),
            border: const Color(0xFFBBF7D0),
            icon: Icons.south_west_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryTile(
            title: 'Total Expenses',
            amount: _totalExpense,
            color: const Color(0xFFDC2626),
            background: const Color(0xFFFEF2F2),
            border: const Color(0xFFFECACA),
            icon: Icons.north_east_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityCard() {
    return _buildSectionCard(
      title: 'Security',
      icon: Icons.lock_outline_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_outlined,
                    color: AppColors.brandBlue),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Change your password using the secured account endpoint.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildPasswordField(
            label: 'New Password',
            controller: _newPasswordCtrl,
            obscure: !_showNewPassword,
            onToggle: () =>
                setState(() => _showNewPassword = !_showNewPassword),
          ),
          const SizedBox(height: 14),
          _buildPasswordField(
            label: 'Confirm Password',
            controller: _confirmPasswordCtrl,
            obscure: !_showConfirmPassword,
            onToggle: () =>
                setState(() => _showConfirmPassword = !_showConfirmPassword),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isChangingPassword ? null : _changePassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _isChangingPassword
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Update Password',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      inputFormatters: [LengthLimitingTextInputFormatter(64)],
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
        filled: true,
        fillColor: const Color(0xFFF8FBFF),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFBFDBFE), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.brandBlue, width: 1.6),
        ),
      ),
    );
  }

  Widget _buildSummaryTile({
    required String title,
    required double amount,
    required Color color,
    required Color background,
    required Color border,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                title.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinanceSection({
    required String title,
    required List<Map<String, dynamic>> items,
    required bool isIncome,
  }) {
    return _buildSectionCard(
      title: title,
      icon: isIncome
          ? Icons.account_balance_wallet_outlined
          : Icons.receipt_long_outlined,
      trailing: IconButton(
        onPressed: () => _showAddFinanceDialog(isIncome),
        icon: const Icon(Icons.add_circle_outline, color: AppColors.brandBlue),
      ),
      child: items.isEmpty
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                'No items added yet',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          : Column(
              children: List.generate(items.length, (index) {
                final item = items[index];
                return Container(
                  margin: EdgeInsets.only(
                      bottom: index == items.length - 1 ? 0 : 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: isIncome
                              ? const Color(0xFFF0FDF4)
                              : const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isIncome
                              ? Icons.south_west_rounded
                              : Icons.north_east_rounded,
                          color: isIncome
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFDC2626),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['label'].toString(),
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isIncome ? 'Income item' : 'Expense item',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '₹${item['amount']}',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            if (isIncome) {
                              _incomes.removeAt(index);
                            } else {
                              _expenses.removeAt(index);
                            }
                          });
                        },
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
            child: Row(
              children: [
                Icon(icon, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}
