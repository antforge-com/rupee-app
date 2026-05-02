// lib/features/auth/register_screen.dart
// ════════════════════════════════════════════════════════════════════════════
// Matches RegisterPage.tsx exactly:
//   - Full Name, Mobile (+91), Email + OTP verification, Location (optional)
//   - 6-box OTP entry with paste support, resend countdown (60s)
//   - Subscription plan selection (fetched from /subscription-plans)
//   - POST /users/send-otp → optional POST /users/check-otp → POST /onboarding
//   - Guests (discountPrice == 0) vs Premium plans
//   - On success → redirect to login after 2.5s
// ════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_theme.dart';
import 'meet_the_masters_brand.dart';
import 'package:finadvise/services/services.dart';
import 'services/onboarding_service.dart';
import 'services/subscription_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final AuthService _auth = AuthService();
  final OnboardingService _onboarding = OnboardingService();
  final SubscriptionService _subSvc = SubscriptionService();

  // Form controllers
  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  Map<String, String> _errors = {};
  bool _submitting = false;
  bool _success = false;
  String _apiError = '';

  // OTP state
  bool _emailVerified = false;
  bool _otpBoxVisible = false;
  bool _sendingOtp = false;
  String _sendOtpError = '';
  List<String> _otp = List.filled(6, '');
  String _otpError = '';
  bool _verifyingOtp = false;
  int _resendTimer = 0;
  bool _resending = false;
  String _otpSentTo = '';
  String _confirmedOtp = '';

  final List<TextEditingController> _otpCtrl =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocus = List.generate(6, (_) => FocusNode());
  Timer? _resendCountdown;

  // Plans
  List<Map<String, dynamic>> _plans = [];
  bool _plansLoading = true;
  Map<String, dynamic>? _selectedPlan;

  @override
  void initState() {
    super.initState();
    _fetchPlans();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _locationCtrl.dispose();
    for (final c in _otpCtrl) c.dispose();
    for (final f in _otpFocus) f.dispose();
    _resendCountdown?.cancel();
    super.dispose();
  }

  bool _isFree(Map<String, dynamic> plan) =>
      (plan['discountPrice'] ?? 0) == 0;

  String _planDisplayName(Map<String, dynamic> plan) {
    if (_isFree(plan)) return 'Guest';
    final name = (plan['name'] ?? '').toString().trim();
    return name.isEmpty ? 'Premium' : _capitalizeFirst(name);
  }

  String _capitalizeFirst(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  String _formatPlanAmount(dynamic value) {
    final amount = double.tryParse(value?.toString() ?? '0') ?? 0;
    return amount.toStringAsFixed(2);
  }

  Future<void> _fetchPlans() async {
    setState(() => _plansLoading = true);
    try {
      final plans = await _subSvc.getSubscriptionPlans();
      setState(() {
        _plans = plans;
        _selectedPlan = plans.firstWhere(
          (p) => !_isFree(p),
          orElse: () => plans.isNotEmpty ? plans[0] : {},
        );
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _plansLoading = false);
    }
  }

  void _startResendTimer() {
    setState(() => _resendTimer = 60);
    _resendCountdown?.cancel();
    _resendCountdown = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_resendTimer <= 1) { _resendTimer = 0; t.cancel(); }
        else _resendTimer--;
      });
    });
  }

  void _resetEmailVerification() {
    setState(() {
      _emailVerified = false;
      _otpBoxVisible = false;
      _otp = List.filled(6, '');
      for (final c in _otpCtrl) c.clear();
      _otpError = '';
      _sendOtpError = '';
      _otpSentTo = '';
      _confirmedOtp = '';
      _resendTimer = 0;
    });
  }

  Future<void> _handleSendEmailOtp() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (email.isEmpty || !RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
      setState(() => _errors = {..._errors, 'email': 'Enter a valid email address first'});
      return;
    }
    setState(() { _sendingOtp = true; _sendOtpError = ''; _errors = {..._errors, 'email': ''}; });
    try {
      final mobile = _mobileCtrl.text.replaceAll(RegExp(r'\D'), '');
      final result = await _auth.sendRegistrationOtp(
        email: email,
        phoneNumber: mobile.isNotEmpty ? mobile : null,
      );
      if (!result.success) throw Exception(result.error);
      setState(() {
        _otpSentTo = email;
        _otp = List.filled(6, '');
        for (final c in _otpCtrl) c.clear();
        _otpError = '';
        _otpBoxVisible = true;
      });
      _startResendTimer();
      Future.delayed(const Duration(milliseconds: 80),
          () => _otpFocus[0].requestFocus());
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '').toLowerCase();
      if (msg.contains('already') || msg.contains('registered') ||
          msg.contains('exist') || msg.contains('duplicate')) {
        setState(() => _errors = {
          ..._errors,
          'email': 'This email is already registered. Please log in instead.'
        });
      } else {
        setState(() => _sendOtpError = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _sendingOtp = false);
    }
  }

  void _handleOtpDigitChange(int index, String value) {
    final digit = value.replaceAll(RegExp(r'\D'), '');
    final next = [..._otp];
    next[index] = digit.isNotEmpty ? digit[digit.length - 1] : '';
    setState(() { _otp = next; _otpError = ''; });
    if (digit.isNotEmpty && index < 5) {
      _otpFocus[index + 1].requestFocus();
    }
  }

  Future<void> _handleVerifyOtp() async {
    final combined = _otp.join('');
    if (combined.length < 6) {
      setState(() => _otpError = 'Enter the complete 6-digit OTP.');
      return;
    }
    setState(() { _verifyingOtp = true; _otpError = ''; });
    try {
      final result = await _auth.checkOtp(
        email: _emailCtrl.text.trim().toLowerCase(),
        otp: combined,
      );
      if (!result.success) throw Exception(result.error);
      setState(() {
        _confirmedOtp = combined;
        _emailVerified = true;
        _otpBoxVisible = false;
        _errors = {..._errors, 'email': ''};
      });
    } catch (e) {
      final raw = e.toString().toLowerCase();
      String msg;
      if (raw.contains('expired')) {
        msg = 'This OTP has expired. Please request a new one.';
      } else if (raw.contains('attempt') || raw.contains('maximum')) {
        msg = 'Too many incorrect attempts. Please request a new OTP.';
      } else {
        msg = e.toString().replaceFirst('Exception: ', '');
      }
      setState(() => _otpError = msg);
    } finally {
      if (mounted) setState(() => _verifyingOtp = false);
    }
  }

  bool _validate() {
    final errs = <String, String>{};
    final name = _nameCtrl.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    final mobile = _mobileCtrl.text.replaceAll(RegExp(r'\D'), '');
    final email = _emailCtrl.text.trim().toLowerCase();
    final location = _locationCtrl.text.trim();

    if (name.isEmpty) errs['name'] = 'Full name is required';
    else if (RegExp(r'^\d').hasMatch(name)) errs['name'] = 'Full name cannot start with a number';
    else if (name.length < 2) errs['name'] = 'Enter your full name';

    if (mobile.isEmpty) errs['mobile'] = 'Mobile number is required';
    else if (!RegExp(r'^[6-9]\d{9}$').hasMatch(mobile)) errs['mobile'] = 'Enter a valid 10-digit mobile number';

    if (email.isEmpty) errs['email'] = 'Email is required';
    else if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) errs['email'] = 'Enter a valid email address';

    if (location.isNotEmpty && RegExp(r'^\d').hasMatch(location)) errs['location'] = 'Location cannot start with a number';
    if (location.isNotEmpty && location.length < 2) errs['location'] = 'Enter a valid location';

    if (_selectedPlan == null) errs['plan'] = 'Please select a subscription plan';

    setState(() => _errors = errs);
    return errs.isEmpty;
  }

  Future<void> _handleSubmit() async {
    if (!_emailVerified) {
      setState(() {
        _otpBoxVisible = true;
        _otpError = 'Please enter the OTP before registering.';
      });
      return;
    }
    if (!_validate()) return;

    setState(() { _submitting = true; _apiError = ''; });

    try {
      final mobile = _mobileCtrl.text.replaceAll(RegExp(r'\D'), '');
      final email = _emailCtrl.text.trim().toLowerCase();
      final planId = _selectedPlan != null && !_isFree(_selectedPlan!)
          ? _selectedPlan!['id'] as int?
          : null;

      final result = await _onboarding.register(
        name: _nameCtrl.text.trim().replaceAll(RegExp(r'\s+'), ' '),
        email: email,
        phoneNumber: mobile,
        otp: _confirmedOtp,
        location: _locationCtrl.text.trim().isNotEmpty
            ? _locationCtrl.text.trim()
            : null,
        subscribed: _selectedPlan != null && !_isFree(_selectedPlan!),
        subscriptionPlanId: planId,
      );

      if (result == null) throw Exception('Registration failed. Please try again.');

      setState(() => _success = true);
      await Future.delayed(const Duration(milliseconds: 2500));
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      final raw = e.toString().toLowerCase();
      if (raw.contains('otp') || raw.contains('expired') ||
          raw.contains('invalid') || raw.contains('incorrect')) {
        setState(() {
          _emailVerified = false;
          _otpBoxVisible = true;
          _confirmedOtp = '';
          _otp = List.filled(6, '');
          for (final c in _otpCtrl) c.clear();
          _otpError = raw.contains('expired')
              ? 'Your OTP has expired. Please request a new one.'
              : 'The OTP you entered is incorrect. Please enter the correct OTP.';
        });
        Future.delayed(const Duration(milliseconds: 80),
            () => _otpFocus[0].requestFocus());
      } else {
        setState(() => _apiError = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0F766E),
                  Color(0xFF2563EB),
                  Color(0xFF93C5FD),
                  Color(0xFFEFF6FF),
                ],
                stops: [0.0, 0.28, 0.64, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                _buildTopBar(),
                const SizedBox(height: 16),
                _buildPersonalSection(),
                const SizedBox(height: 16),
                _buildPlansSection(),
                const SizedBox(height: 16),
                _buildEmailBanner(),
                if (_apiError.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _errorBanner(_apiError),
                ],
                const SizedBox(height: 16),
                _buildSubmitBtn(),
                const SizedBox(height: 16),
                _buildFooter(),
                const SizedBox(height: 32),
              ],
            ),
          ),
          if (_success) _buildSuccessOverlay(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back, size: 20),
            ),
          ),
          Expanded(
            child: _buildRegisterBrand(),
          ),
          const SizedBox(width: 36),
        ],
      ),
    );
  }

  Widget _buildRegisterBrand() {
    return const MeetTheMastersBrand(
      subtitle: 'Create Your Account',
      logoSize: 40,
      logoPadding: 6,
      titleSize: 12.5,
      subtitleSize: 9.5,
      titleLetterSpacing: 2.1,
      gap: 6,
      titleColor: AppColors.brandBlue,
      showAmbientGlow: false,
    );
  }

  Widget _buildPersonalSection() {
    final mobile = _mobileCtrl.text.replaceAll(RegExp(r'\D'), '');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline,
                  size: 20, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Text('Personal Details',
                  style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 20),

          // Full name
          _sectionLabel('FULL NAME', required: true),
          const SizedBox(height: 6),
          TextField(
            controller: _nameCtrl,
            onChanged: (_) => setState(() => _errors = {..._errors, 'name': ''}),
            textCapitalization: TextCapitalization.words,
            decoration: _inputDeco(
              hint: 'Enter your full name',
              hasError: (_errors['name'] ?? '').isNotEmpty,
            ),
          ),
          if ((_errors['name'] ?? '').isNotEmpty) _fieldError(_errors['name']!),
          const SizedBox(height: 16),

          // Mobile
          _sectionLabel('MOBILE NUMBER', required: true),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  border: Border(
                    top: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                    bottom: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                    left: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                  ),
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
                ),
                child: Text('+91',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B))),
              ),
              Expanded(
                child: TextField(
                  controller: _mobileCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  onChanged: (_) =>
                      setState(() => _errors = {..._errors, 'mobile': ''}),
                  decoration: _inputDeco(
                    hint: '10-digit mobile number',
                    hasError: (_errors['mobile'] ?? '').isNotEmpty,
                    borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
          if (mobile.isNotEmpty && mobile.length < 10 && (_errors['mobile'] ?? '').isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 12, color: Color(0xFFD97706)),
                  const SizedBox(width: 4),
                  Text('Enter ${10 - mobile.length} more digit${10 - mobile.length != 1 ? 's' : ''}',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFD97706), fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          if (mobile.length == 10 && (_errors['mobile'] ?? '').isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, size: 12, color: Color(0xFF16A34A)),
                  const SizedBox(width: 4),
                  Text('Valid mobile number',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF16A34A), fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          if ((_errors['mobile'] ?? '').isNotEmpty) _fieldError(_errors['mobile']!),
          const SizedBox(height: 16),

          // Email + OTP
          _sectionLabel('EMAIL ADDRESS', required: true),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_emailVerified,
                  onChanged: (_) {
                    if (_emailVerified || _otpBoxVisible) {
                      _resetEmailVerification();
                    } else {
                      setState(() {
                        _errors = {..._errors, 'email': ''};
                      });
                    }
                  },
                  decoration: _inputDeco(
                    hint: 'you@example.com',
                    hasError: (_errors['email'] ?? '').isNotEmpty,
                    fillColor: _emailVerified ? const Color(0xFFEFF6FF) : null,
                    borderColor: _emailVerified ? AppColors.primaryLight : null,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _emailVerified
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        border: Border.all(color: const Color(0xFF93C5FD)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.shield_rounded, size: 16, color: Color(0xFF2563EB)),
                          const SizedBox(width: 4),
                          Text('OTP Added',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF2563EB))),
                        ],
                      ),
                    )
                  : SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _sendingOtp ||
                                !RegExp(r'^[^@]+@[^@]+\.[^@]+$')
                                    .hasMatch(_emailCtrl.text.trim())
                            ? null
                            : _handleSendEmailOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryLight,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: _sendingOtp
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : Text(_otpBoxVisible ? 'Resend' : 'Send OTP',
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                      ),
                    ),
            ],
          ),
          if ((_errors['email'] ?? '').isNotEmpty) _fieldError(_errors['email']!),
          if (_emailVerified)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'The OTP will be checked when you create the account.',
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
              ),
            ),

          // OTP Box
          if (_otpBoxVisible && !_emailVerified) ...[
            const SizedBox(height: 16),
            _buildOtpBox(),
          ],
          const SizedBox(height: 16),

          // Location
          _sectionLabel('LOCATION', optional: true),
          const SizedBox(height: 6),
          TextField(
            controller: _locationCtrl,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() => _errors = {..._errors, 'location': ''}),
            decoration: _inputDeco(hint: 'City, State').copyWith(
              prefixIcon: const Icon(Icons.location_on_outlined, size: 18, color: Color(0xFF94A3B8)),
            ),
          ),
          if ((_errors['location'] ?? '').isNotEmpty) _fieldError(_errors['location']!),
        ],
      ),
    );
  }

  Widget _buildOtpBox() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        border: Border.all(color: const Color(0xFF93C5FD)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.mail_outline, size: 16, color: Color(0xFF2563EB)),
                        const SizedBox(width: 6),
                        Text('Verify Email',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF2563EB),
                                fontSize: 14)),
                      ],
                    ),
                    Text('OTP sent to $_otpSentTo',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _otpBoxVisible = false),
                child: const Icon(Icons.close, size: 18, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 6 boxes
          LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth;
              final boxWidth = ((maxWidth - 5 * 8) / 6).clamp(40.0, 50.0);
              return Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: List.generate(6, (i) {
                  return SizedBox(
                    width: boxWidth,
                    height: 54,
                    child: TextField(
                      controller: _otpCtrl[i],
                      focusNode: _otpFocus[i],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800),
                      onChanged: (val) => _handleOtpDigitChange(i, val),
                      onSubmitted: (_) {
                        if (i < 5) _otpFocus[i + 1].requestFocus();
                      },
                      decoration: InputDecoration(
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: AppColors.primaryLight, width: 1.5),
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),

          if (_otpError.isNotEmpty) ...[
            const SizedBox(height: 12),
            _errorBanner(_otpError),
          ],
          const SizedBox(height: 12),

          SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: _verifyingOtp || _otp.join('').length < 6
                  ? null
                  : _handleVerifyOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryLight,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: Text(_verifyingOtp ? 'Saving OTP...' : 'Use OTP',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 8),

          Center(
            child: _resendTimer > 0
                ? Text('Resend in ${_resendTimer}s',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary))
                : TextButton(
                    onPressed: _resending ? null : () async {
                      setState(() => _resending = true);
                      await _handleSendEmailOtp();
                      setState(() => _resending = false);
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.refresh, size: 12),
                        const SizedBox(width: 4),
                        Text('Resend OTP',
                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.primaryLight)),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlansSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, size: 20, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Text('Subscription Plan',
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 16),

          // Badge row
          Row(
            children: [
              Expanded(
                child: _planBadge(
                    'Subscribed - Full access', !_isFree(_selectedPlan ?? {}), false),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _planBadge(
                    'Guest - Limited access', _isFree(_selectedPlan ?? {}), true),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_plansLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_plans.isEmpty)
            _errorBanner('No plans found. Please retry.')
          else
            ..._plans.map((plan) => _buildPlanCard(plan)),

          if ((_errors['plan'] ?? '').isNotEmpty) _fieldError(_errors['plan']!),
        ],
      ),
    );
  }

  Widget _planBadge(String label, bool active, bool isGuest) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active
            ? (isGuest ? const Color(0xFFF0FDF4) : const Color(0xFFEFF6FF))
            : Colors.white,
        border: Border.all(
          color: active
              ? (isGuest ? const Color(0xFF86EFAC) : AppColors.primaryLight)
              : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isGuest ? Icons.person_outline : Icons.verified_user_outlined,
            size: 14,
            color: active
                ? (isGuest ? const Color(0xFF16A34A) : AppColors.primaryLight)
                : AppColors.textSecondary,
          ),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: active
                      ? (isGuest ? const Color(0xFF16A34A) : AppColors.primaryLight)
                      : AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    final isSelected = _selectedPlan?['id'] == plan['id'];
    final isFree = _isFree(plan);
    final activeColor = isFree ? const Color(0xFF16A34A) : AppColors.primaryLight;
    final activeBg = isFree ? const Color(0xFFF0FDF4) : const Color(0xFFEFF6FF);

    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = plan),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : Colors.white,
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFFE2E8F0),
            width: 2.5,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: isSelected
              ? [BoxShadow(color: activeColor.withOpacity(0.15), blurRadius: 20)]
              : [const BoxShadow(color: Color(0x0A000000), blurRadius: 4)],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(_planDisplayName(plan),
                          style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isSelected ? activeColor : const Color(0xFF0F172A))),
                      if (!isFree) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('PREMIUM',
                              style: TextStyle(fontSize: 9, color: Color(0xFF16A34A), fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                  if ((plan['tag'] ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(plan['tag'],
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isFree ? 'Free' : 'Rs ${_formatPlanAmount(plan['discountPrice'])}',
                  style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: isSelected ? activeColor : AppColors.primaryLight),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? activeColor : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? activeColor : const Color(0xFFE2E8F0),
                      width: 2.5,
                    ),
                  ),
                  child: isSelected
                      ? const Center(
                          child: CircleAvatar(
                              radius: 4, backgroundColor: Colors.white))
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        border: Border.all(color: const Color(0xFF86EFAC)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.mail_outline, size: 18, color: Color(0xFF16A34A)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your login credentials will be sent to your email after registration.',
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF166534)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitBtn() {
    final isFree = _selectedPlan != null && _isFree(_selectedPlan!);
    String label;
    if (_submitting) {
      label = 'Creating Account...';
    } else if (!_emailVerified) {
      label = 'Enter OTP to Continue';
    } else if (!isFree && _selectedPlan != null) {
      label =
          'Subscribe & Register (Rs ${_formatPlanAmount(_selectedPlan!['discountPrice'])})';
    } else {
      label = 'Create Guest Account';
    }

    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: _submitting || _plans.isEmpty || !_emailVerified
            ? null
            : _handleSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryLight,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: _submitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5))
            : Text(label,
                style: GoogleFonts.inter(
                    fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Already have an account? ',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white70)),
        GestureDetector(
          onTap: () => Navigator.pushReplacementNamed(context, '/login'),
          child: Text('Sign In',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildSuccessOverlay() {
    final isFree = _selectedPlan != null && _isFree(_selectedPlan!);
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFFF0FDF4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded,
                    size: 40, color: Color(0xFF16A34A)),
              ),
              const SizedBox(height: 16),
              Text(isFree ? 'Account Created!' : 'Subscribed!',
                  style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryLight)),
              const SizedBox(height: 8),
              Text(
                'Login credentials sent to your email. Redirecting to login...',
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  Widget _sectionLabel(String text, {bool required = false, bool optional = false}) {
    return Row(
      children: [
        Text(text,
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF64748B),
                letterSpacing: 0.5)),
        if (required)
          const Text(' *', style: TextStyle(color: Color(0xFFEF4444), fontSize: 11)),
        if (optional)
          Text(' (Optional)',
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }

  InputDecoration _inputDeco({
    required String hint,
    bool hasError = false,
    BorderRadius? borderRadius,
    Color? fillColor,
    Color? borderColor,
  }) {
    final bRadius = borderRadius ?? BorderRadius.circular(10);
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
      filled: true,
      fillColor: fillColor ?? const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: bRadius,
          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
      enabledBorder: OutlineInputBorder(
        borderRadius: bRadius,
        borderSide: BorderSide(
          color: hasError
              ? const Color(0xFFFCA5A5)
              : borderColor ?? const Color(0xFFE2E8F0),
          width: 1.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: bRadius,
        borderSide: BorderSide(color: AppColors.primaryLight, width: 1.5),
      ),
    );
  }

  Widget _fieldError(String msg) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFEF4444)),
            const SizedBox(width: 4),
            Expanded(
                child: Text(msg,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: const Color(0xFFEF4444)))),
          ],
        ),
      );

  Widget _errorBanner(String msg) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          border: Border.all(color: const Color(0xFFFCA5A5)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 16, color: Color(0xFFEF4444)),
            const SizedBox(width: 8),
            Expanded(
                child: Text(msg,
                    style: GoogleFonts.inter(
                        fontSize: 13, color: const Color(0xFFB91C1C)))),
          ],
        ),
      );
}
