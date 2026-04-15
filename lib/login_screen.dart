import 'package:finadvise/services/auth.service.dart';
import 'package:finadvise/services/onboarding_service.dart';
import 'package:finadvise/api_client.dart'; // <-- Direct API Client import kiya hai
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'analytics_service.dart';

// Services — apne actual import path se match karo
// ============================================================
//  MEET THE MASTERS — Premium Auth Screen
//  Real API integrated: login + OTP + register + role routing
// ============================================================

enum AuthMode { login, register }
enum SubscriptionTier { elite, pro, guest }
enum AccessType { subscribed, guest }
enum RegisterStep { personalDetails, subscriptionPlan, otpVerification }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  // ─── Services ──────────────────────────────────────────────
  final _authService   = AuthService();
  final _onboarding    = OnboardingService();
  final _apiClient     = ApiClient(); // <-- AdminService ki jagah direct ApiClient
  final _secureStorage = const FlutterSecureStorage();

  // ─── State ─────────────────────────────────────────────────
  AuthMode      _authMode     = AuthMode.login;
  RegisterStep  _registerStep = RegisterStep.personalDetails;
  bool          _isLoading    = false;
  bool          _obscurePassword = true;
  bool          _rememberMe   = false;
  bool          _agreeTerms   = false;
  String?       _errorMessage;
  int           _strengthScore = 0;
  SubscriptionTier _selectedPlan = SubscriptionTier.elite;
  AccessType    _accessType   = AccessType.subscribed;
  bool          _otpSent      = false;

  // ─── Subscription Plans (from API) ────────────────────────
  List<Map<String, dynamic>> _apiPlans  = [];  // loaded from /api/subscription-plans
  int?  _selectedPlanId;                        // actual ID sent to API
  bool  _isLoadingPlans = false;

  // ─── Controllers ───────────────────────────────────────────
  final _loginFormKey    = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();
  final _nameCtrl        = TextEditingController();
  final _emailCtrl       = TextEditingController();
  final _loginIdentifierCtrl = TextEditingController(); // email OR phone
  final _phoneCtrl       = TextEditingController();
  final _locationCtrl    = TextEditingController();
  final _passwordCtrl    = TextEditingController();
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes =
      List.generate(6, (_) => FocusNode());

  // ─── Animation ─────────────────────────────────────────────
  late final AnimationController _pageAnimCtrl;
  late final Animation<double>   _fadeAnim;
  late final Animation<Offset>   _slideAnim;

  // ─── Design Tokens ─────────────────────────────────────────
  static const Color _navy      = Color(0xFF0B1D51);
  static const Color _blue      = Color(0xFF1347CC);
  static const Color _blueLight = Color(0xFF3D72F5);
  static const Color _gold      = Color(0xFFD4A017);
  static const Color _goldLight = Color(0xFFFAEFCB);
  static const Color _bg        = Color(0xFFEDF1FA);
  static const Color _white     = Colors.white;
  static const Color _textDark  = Color(0xFF0B1124);
  static const Color _textMid   = Color(0xFF1E3050);
  static const Color _textSub   = Color(0xFF5B6F91);
  static const Color _border    = Color(0xFFD4DCF0);
  static const Color _fill      = Color(0xFFF3F6FC);
  static const Color _errorRed  = Color(0xFFD93025);
  static const Color _amber     = Color(0xFFE08A00);
  static const Color _green     = Color(0xFF0A8A5C);
  static const Color _violet    = Color(0xFF5B21B6);

  // ─── Init ──────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _passwordCtrl.addListener(_updateStrength);

    _pageAnimCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(
        parent: _pageAnimCtrl, curve: Curves.easeOut);
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
            .animate(CurvedAnimation(
                parent: _pageAnimCtrl, curve: Curves.easeOut));

    _pageAnimCtrl.forward();

    // API plans silently load karo background mein
    _loadSubscriptionPlans();
  }

  @override
  void dispose() {
    _pageAnimCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _loginIdentifierCtrl.dispose();
    _phoneCtrl.dispose();
    _locationCtrl.dispose();
    _passwordCtrl.dispose();
    for (final c in _otpControllers) c.dispose();
    for (final f in _otpFocusNodes) f.dispose();
    super.dispose();
  }

  void _updateStrength() {
    if (_authMode == AuthMode.login) return;
    int s = 0;
    final p = _passwordCtrl.text;
    if (p.length > 7) s++;
    if (RegExp(r'[A-Z]').hasMatch(p)) s++;
    if (RegExp(r'[0-9]').hasMatch(p)) s++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) s++;
    setState(() => _strengthScore = s);
  }

  void _runTransition() {
    _pageAnimCtrl.reset();
    _pageAnimCtrl.forward();
    setState(() => _errorMessage = null);
  }

  // ─── Navigation helpers ────────────────────────────────────
  void _toRegister() {
    setState(() => _authMode = AuthMode.register);
    _runTransition();
  }

  void _toLogin() {
    setState(() {
      _authMode = AuthMode.login;
      _registerStep = RegisterStep.personalDetails;
      _otpSent = false;
    });
    _runTransition();
  }

  void _goBack() {
    if (_registerStep == RegisterStep.personalDetails) {
      _toLogin();
    } else if (_registerStep == RegisterStep.subscriptionPlan) {
      setState(() => _registerStep = RegisterStep.personalDetails);
      _runTransition();
    } else if (_registerStep == RegisterStep.otpVerification) {
      setState(() => _registerStep = RegisterStep.subscriptionPlan);
      _runTransition();
    }
  }

  // ════════════════════════════════════════════════════════════
  //  REAL API — SESSION HELPERS
  // ════════════════════════════════════════════════════════════

  /// Token + user info secure storage mein save karo
  Future<void> _saveSession(AuthResult result) async {
    if (result.token != null) {
      await _secureStorage.write(key: 'jwt_token',     value: result.token);
    }
    await _secureStorage.write(key: 'user_role',       value: result.role ?? '');
    await _secureStorage.write(key: 'user_id',         value: result.userId?.toString() ?? '');
    await _secureStorage.write(key: 'consultant_id',   value: result.consultantId?.toString() ?? '');
    await _secureStorage.write(key: 'identifier',      value: result.identifier ?? '');
  }

  /// Role ke hisaab se correct screen pe navigate karo
  void _navigateByRole(String role, {bool requiresPasswordChange = false}) {
    if (!mounted) return;

    if (requiresPasswordChange) {
      Navigator.pushReplacementNamed(context, '/change-password');
      return;
    }

    switch (role.toUpperCase()) {
      case 'ADMIN':
        Navigator.pushReplacementNamed(context, '/admin');
        break;
      case 'CONSULTANT':
        Navigator.pushReplacementNamed(context, '/consultant');
        break;
      case 'MEMBER':
      case 'SUBSCRIBER':
      case 'GUEST':
      default:
        Navigator.pushReplacementNamed(context, '/home');
    }
  }

  // ════════════════════════════════════════════════════════════
  //  REAL API — SUBSCRIPTION PLANS
  // ════════════════════════════════════════════════════════════

  Future<void> _loadSubscriptionPlans() async {
    if (_isLoadingPlans) return;
    setState(() => _isLoadingPlans = true);
    try {
      // Direct API call without using AdminService
      final response = await _apiClient.dio.get('/api/subscription-plans');
      final plans = response.data as List<dynamic>;

      if (!mounted) return;
      if (plans.isNotEmpty) {
        // Map to simple maps for easy rendering
        final mapped = plans.map((p) => {
          'id':            p['id'],
          'name':          p['name'] ?? 'Plan',
          'originalPrice': (p['originalPrice'] as num?)?.toDouble() ?? 0.0,
          'discountPrice': (p['discountPrice'] as num?)?.toDouble() ?? 0.0,
          'features':      p['features'] ?? '',
          'tag':           p['tag'] ?? '',
        }).toList();

        setState(() {
          _apiPlans = mapped;
          // Default: pehla plan select karo
          if (mapped.isNotEmpty) {
            _selectedPlanId = mapped.first['id'] as int?;
          }
        });
      }
    } catch (e) {
      print("Error fetching plans: $e");
      // Fallback: static plans — koi crash nahi
    }
    if (mounted) setState(() => _isLoadingPlans = false);
  }

  // ════════════════════════════════════════════════════════════
  //  REAL API — ACTION HANDLERS
  // ════════════════════════════════════════════════════════════

  /// LOGIN — POST /api/users/authenticate
  Future<void> _handleLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMessage = null; });

    final result = await _authService.login(
      identifier: _loginIdentifierCtrl.text.trim(),
      password: _passwordCtrl.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      await _saveSession(result);
      _navigateByRole(
        result.role ?? '',
        requiresPasswordChange: result.requiresPasswordChange,
      );
    } else {
      setState(() =>
          _errorMessage = result.error ?? 'Invalid credentials. Please try again.');
    }
  }

  /// REGISTER — Multi-step handler
  Future<void> _handleNextStep() async {
    setState(() => _errorMessage = null);

    // ── Step 1: Personal Details → validate only ──────────────
    if (_registerStep == RegisterStep.personalDetails) {
      if (!_registerFormKey.currentState!.validate()) return;
      setState(() => _registerStep = RegisterStep.subscriptionPlan);
      _runTransition();

    // ── Step 2: Subscription → send OTP → go to OTP screen ───
    } else if (_registerStep == RegisterStep.subscriptionPlan) {
      if (!_agreeTerms) {
        setState(() =>
            _errorMessage = "Please agree to our Terms & Privacy Policy.");
        return;
      }
      setState(() { _isLoading = true; });

      // OTP bhejo — POST /api/users/send-otp
      final otpResult = await _authService.sendRegistrationOtp(
        email: _emailCtrl.text.trim(),
        phoneNumber: _phoneCtrl.text.trim().isNotEmpty
            ? _phoneCtrl.text.trim()
            : null,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (otpResult.success) {
        setState(() => _registerStep = RegisterStep.otpVerification);
        _runTransition();
        ScaffoldMessenger.of(context).showSnackBar(
            _snack('Verification code sent to ${_emailCtrl.text.trim()}', _blue));
      } else {
        setState(() =>
            _errorMessage = otpResult.error ?? 'Could not send OTP. Check your email.');
      }

    // ── Step 3: OTP → register → go to login ─────────────────
    } else if (_registerStep == RegisterStep.otpVerification) {
      final otp = _otpControllers.map((c) => c.text).join();
      if (otp.length < 6) {
        setState(() =>
            _errorMessage = "Please enter the complete 6-digit code.");
        return;
      }
      setState(() { _isLoading = true; });

      // POST /api/onboarding — JSON body (multipart nahi)
      final profile = await _onboarding.register(
        name:               _nameCtrl.text.trim(),
        email:              _emailCtrl.text.trim(),
        phoneNumber:        _phoneCtrl.text.trim(),
        otp:                otp,
        location:           _locationCtrl.text.trim().isNotEmpty
                                ? _locationCtrl.text.trim()
                                : null,
        subscribed:         _accessType == AccessType.subscribed,
        subscriptionPlanId: _accessType == AccessType.subscribed
                                ? _selectedPlanId
                                : null,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (profile != null) {
        ScaffoldMessenger.of(context).showSnackBar(
            _snack('Account created! Please sign in.', _green));
        _clearRegisterFields();
        _toLogin();
      } else {
        setState(() =>
            _errorMessage = 'Incorrect OTP or registration failed. Try again.');
      }
    }
  }

  /// SEND OTP (from Step 1 email field button)
  /// POST /api/users/send-otp
  Future<void> _sendOTP() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !RegExp(r'\S+@\S+\.\S+').hasMatch(email)) {
      setState(() => _errorMessage = "Please enter a valid email first.");
      return;
    }
    setState(() { _isLoading = true; _errorMessage = null; });

    final result = await _authService.sendRegistrationOtp(
      email: email,
      phoneNumber: _phoneCtrl.text.trim().isNotEmpty
          ? _phoneCtrl.text.trim()
          : null,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      setState(() => _otpSent = true);
      ScaffoldMessenger.of(context)
          .showSnackBar(_snack('OTP sent to $email', _blue));
    } else {
      setState(() =>
          _errorMessage = result.error ?? 'Failed to send OTP. Try again.');
    }
  }

  /// RESEND OTP (from step 3)
  Future<void> _resendOTP() async {
    setState(() { _isLoading = true; _errorMessage = null; });

    final result = await _authService.sendRegistrationOtp(
      email: _emailCtrl.text.trim(),
      phoneNumber: _phoneCtrl.text.trim().isNotEmpty
          ? _phoneCtrl.text.trim()
          : null,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      // Clear existing OTP boxes
      for (final c in _otpControllers) c.clear();
      _otpFocusNodes.first.requestFocus();
      ScaffoldMessenger.of(context)
          .showSnackBar(_snack('New OTP sent to ${_emailCtrl.text.trim()}', _blue));
    } else {
      setState(() =>
          _errorMessage = result.error ?? 'Failed to resend OTP.');
    }
  }

  void _clearRegisterFields() {
    _nameCtrl.clear();
    _emailCtrl.clear();
    _phoneCtrl.clear();
    _locationCtrl.clear();
    for (final c in _otpControllers) c.clear();
    setState(() {
      _otpSent       = false;
      _agreeTerms    = false;
      _selectedPlan  = SubscriptionTier.elite;
      _accessType    = AccessType.subscribed;
    });
  }

  // ─── SnackBar helper ───────────────────────────────────────
  SnackBar _snack(String msg, Color color) => SnackBar(
        content: Text(msg,
            style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      );

  // ─── Password Strength ─────────────────────────────────────
  Color _strengthColor(int level) {
    if (_strengthScore >= level) {
      if (_strengthScore == 1) return _errorRed;
      if (_strengthScore == 2) return _amber;
      if (_strengthScore == 3) return _green;
      return const Color(0xFF059669);
    }
    return _border;
  }

  String _strengthLabel() {
    switch (_strengthScore) {
      case 1: return 'Weak';
      case 2: return 'Fair';
      case 3: return 'Good';
      case 4: return 'Strong ✓';
      default: return '';
    }
  }

  // ============================================================
  //  BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          Positioned(
            top: -100, right: -100,
            child: _blob(300, _blue.withOpacity(0.09)),
          ),
          Positioned(
            bottom: -80, left: -80,
            child: _blob(240, _navy.withOpacity(0.07)),
          ),
          Positioned(
            top: MediaQuery.of(context).size.height * 0.4,
            left: MediaQuery.of(context).size.width * 0.6,
            child: _blob(160, _gold.withOpacity(0.10)),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: _authMode == AuthMode.login
                    ? _loginView()
                    : _registerView(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blob(double size, Color color) => Container(
        width: size, height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );

  // ============================================================
  //  LOGIN VIEW
  // ============================================================
  Widget _loginView() {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Form(
            key: _loginFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _brandHeader(),
                const SizedBox(height: 36),
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Welcome back',
                          style: GoogleFonts.playfairDisplay(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: _textDark)),
                      const SizedBox(height: 4),
                      Text('Sign in to continue your journey',
                          style: GoogleFonts.dmSans(
                              fontSize: 14, color: _textSub)),
                      const SizedBox(height: 24),

                      if (_errorMessage != null) ...[
                        _errorBanner(_errorMessage!),
                        const SizedBox(height: 16),
                      ],

                      _reqLabel('EMAIL / PHONE'),
                      const SizedBox(height: 6),
                      // ── REAL: email ya phone number dono accept karo ──
                      _inputField(
                        ctrl: _loginIdentifierCtrl,
                        hint: 'Email or 10-digit phone',
                        icon: Icons.person_outline,
                        type: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty)
                            return 'Email or phone is required';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _reqLabel('PASSWORD'),
                          GestureDetector(
                            onTap: _showForgotPassword,
                            child: Text('Forgot password?',
                                style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _blue)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _passwordField(isLogin: true),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          _checkbox(
                              value: _rememberMe,
                              onChange: (v) =>
                                  setState(() => _rememberMe = v ?? false)),
                          const SizedBox(width: 8),
                          Text('Remember me for 30 days',
                              style: GoogleFonts.dmSans(
                                  fontSize: 13, color: _textMid)),
                        ],
                      ),
                      const SizedBox(height: 24),

                      _primaryBtn(
                          label: 'Sign In',
                          icon: Icons.arrow_forward_rounded,
                          onPress: _handleLogin),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                _footerRow(
                    msg: "Don't have an account? ",
                    action: 'Create account',
                    onTap: _toRegister),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Forgot Password dialog ─────────────────────────────────
  void _showForgotPassword() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Forgot Password',
            style: GoogleFonts.playfairDisplay(
                fontSize: 20, fontWeight: FontWeight.w700, color: _textDark)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Enter your registered email to receive an OTP.",
                style: GoogleFonts.dmSans(fontSize: 13, color: _textSub)),
            const SizedBox(height: 16),
            TextFormField(
              controller: ctrl,
              keyboardType: TextInputType.emailAddress,
              style: GoogleFonts.dmSans(fontSize: 14, color: _textDark),
              decoration: _inputDeco(
                hint: 'you@example.com',
                prefix: const Icon(Icons.email_outlined,
                    color: Color(0xFF94A3B8), size: 20),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.dmSans(color: _textSub)),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = ctrl.text.trim();
              if (email.isEmpty) return;
              Navigator.pop(ctx);
              setState(() { _isLoading = true; });

              // POST /api/users/forgot-password
              final res = await _authService.forgotPassword(email: email);
              if (!mounted) return;
              setState(() => _isLoading = false);

              ScaffoldMessenger.of(context).showSnackBar(_snack(
                res.success
                    ? 'OTP sent to $email'
                    : res.error ?? 'Failed to send OTP.',
                res.success ? _green : _errorRed,
              ));

              if (res.success) {
                _showResetPassword(email);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _navy,
              foregroundColor: _white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Send OTP',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showResetPassword(String email) {
    final otpCtrl  = TextEditingController();
    final passCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Reset Password',
            style: GoogleFonts.playfairDisplay(
                fontSize: 20, fontWeight: FontWeight.w700, color: _textDark)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: otpCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              style: GoogleFonts.dmSans(fontSize: 14, color: _textDark),
              decoration: _inputDeco(
                hint: '6-digit OTP',
                prefix: const Icon(Icons.pin_outlined,
                    color: Color(0xFF94A3B8), size: 20),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: passCtrl,
              obscureText: true,
              style: GoogleFonts.dmSans(fontSize: 14, color: _textDark),
              decoration: _inputDeco(
                hint: 'New password (min 8 chars)',
                prefix: const Icon(Icons.lock_outline,
                    color: Color(0xFF94A3B8), size: 20),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.dmSans(color: _textSub)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (otpCtrl.text.length < 6 || passCtrl.text.length < 8) return;
              Navigator.pop(ctx);
              setState(() => _isLoading = true);

              // POST /api/users/reset-password
              final res = await _authService.resetPassword(
                email: email,
                otp: otpCtrl.text.trim(),
                newPassword: passCtrl.text,
              );
              if (!mounted) return;
              setState(() => _isLoading = false);

              ScaffoldMessenger.of(context).showSnackBar(_snack(
                res.success
                    ? 'Password reset successful! Please sign in.'
                    : res.error ?? 'Reset failed. Try again.',
                res.success ? _green : _errorRed,
              ));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _navy,
              foregroundColor: _white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Reset',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ============================================================
  //  REGISTER VIEWS (multi-step)
  // ============================================================
  Widget _registerView() {
    switch (_registerStep) {
      case RegisterStep.personalDetails:
        return _personalDetailsView();
      case RegisterStep.subscriptionPlan:
        return _subscriptionView();
      case RegisterStep.otpVerification:
        return _otpView();
    }
  }

  // ─── Step 1: Personal Details ──────────────────────────────
  Widget _personalDetailsView() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _topNav(title: 'MEET THE MASTERS', sub: 'CREATE YOUR ACCOUNT'),
            const SizedBox(height: 16),
            _stepBar(step: 1),
            const SizedBox(height: 24),

            _card(
              child: Form(
                key: _registerFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sectionHeader(
                        icon: Icons.person_outline,
                        label: 'Personal Details'),
                    const SizedBox(height: 24),

                    if (_errorMessage != null) ...[
                      _errorBanner(_errorMessage!),
                      const SizedBox(height: 16),
                    ],

                    _reqLabel('FULL NAME'),
                    const SizedBox(height: 6),
                    _inputField(
                      ctrl: _nameCtrl,
                      hint: 'Enter your full name',
                      icon: Icons.person_outline,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Full name is required' : null,
                    ),
                    const SizedBox(height: 16),

                    _reqLabel('MOBILE NUMBER'),
                    const SizedBox(height: 6),
                    _phoneField(),
                    const SizedBox(height: 16),

                    _reqLabel('EMAIL ADDRESS'),
                    const SizedBox(height: 6),
                    _emailWithOTP(),
                    const SizedBox(height: 16),

                    _optLabel('LOCATION'),
                    const SizedBox(height: 6),
                    _inputField(
                      ctrl: _locationCtrl,
                      hint: 'City, State',
                      icon: Icons.location_on_outlined,
                    ),
                    const SizedBox(height: 24),

                    _primaryBtn(
                        label: 'Continue',
                        icon: Icons.arrow_forward_rounded,
                        onPress: _handleNextStep),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
            _footerRow(
                msg: 'Already have an account? ',
                action: 'Sign In',
                onTap: _toLogin),
          ],
        ),
      ),
    );
  }

  // ─── Step 2: Subscription Plan ─────────────────────────────
  Widget _subscriptionView() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _topNav(title: 'MEET THE MASTERS', sub: 'CHOOSE YOUR PLAN'),
            const SizedBox(height: 16),
            _stepBar(step: 2),
            const SizedBox(height: 24),

            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _sectionHeader(
                      icon: Icons.verified_user_outlined,
                      label: 'Subscription Plan'),
                  const SizedBox(height: 20),

                  _accessToggle(),
                  const SizedBox(height: 20),

                  if (_errorMessage != null) ...[
                    _errorBanner(_errorMessage!),
                    const SizedBox(height: 16),
                  ],

                  // ── REAL: API plans ya fallback static ──────
                  if (_isLoadingPlans)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: CircularProgressIndicator(color: _blue),
                      ),
                    )
                  else if (_accessType == AccessType.subscribed) ...[
                    // API plans loaded hain → show them
                    if (_apiPlans.isNotEmpty)
                      ..._apiPlans.map((plan) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _apiPlanCard(plan),
                          ))
                    else ...[
                      // Fallback: static plans (API fail ya no internet)
                      _planCard(
                        tier: SubscriptionTier.elite,
                        name: 'Elite',
                        price: '₹999',
                        period: '/year',
                        badge: 'PREMIUM',
                        badgeColor: _gold,
                        features: const [
                          'Full access to all content',
                          'Priority 1-on-1 support',
                          'Exclusive live masterclasses',
                          'Certificate of completion',
                          'Lifetime updates',
                        ],
                      ),
                      const SizedBox(height: 10),
                      _planCard(
                        tier: SubscriptionTier.pro,
                        name: 'Pro',
                        price: '₹499',
                        period: '/year',
                        badge: 'POPULAR',
                        badgeColor: _blue,
                        features: const [
                          'Access to most content',
                          'Standard email support',
                          'Group sessions included',
                          'Digital certificate',
                        ],
                      ),
                    ],
                  ] else ...[
                    // Guest option
                    _planCard(
                      tier: SubscriptionTier.guest,
                      name: 'Guest',
                      price: 'Free',
                      period: '',
                      badge: 'FREE',
                      badgeColor: _green,
                      features: const [
                        'Limited content access',
                        'Community forum access',
                        'Sample preview lessons',
                      ],
                    ),
                  ],

                  const SizedBox(height: 20),

                  _infoBanner(
                    icon: Icons.email_outlined,
                    msg: 'Your login credentials will be sent to your email after registration.',
                    bg: const Color(0xFFECFDF5),
                    border: const Color(0xFFA7F3D0),
                    iconColor: _green,
                    textColor: const Color(0xFF065F46),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _checkbox(
                          value: _agreeTerms,
                          onChange: (v) =>
                              setState(() => _agreeTerms = v ?? false)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: GoogleFonts.dmSans(
                                fontSize: 12,
                                color: _textSub,
                                height: 1.5),
                            children: [
                              const TextSpan(text: 'I agree to the '),
                              TextSpan(
                                  text: 'Terms of Service',
                                  style: const TextStyle(
                                      color: _blue,
                                      fontWeight: FontWeight.w700)),
                              const TextSpan(text: ' and '),
                              TextSpan(
                                  text: 'Privacy Policy',
                                  style: const TextStyle(
                                      color: _blue,
                                      fontWeight: FontWeight.w700)),
                              const TextSpan(text: '.'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _primaryBtn(
                      label: 'Verify Email to Continue',
                      icon: Icons.verified_outlined,
                      onPress: _handleNextStep),
                ],
              ),
            ),

            const SizedBox(height: 20),
            _footerRow(
                msg: 'Already have an account? ',
                action: 'Sign In',
                onTap: _toLogin),
          ],
        ),
      ),
    );
  }

  // ─── Step 3: OTP Verification ──────────────────────────────
  Widget _otpView() {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _topNav(title: 'MEET THE MASTERS', sub: 'VERIFY YOUR EMAIL'),
              const SizedBox(height: 16),
              _stepBar(step: 3),
              const SizedBox(height: 24),

              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFF1347CC), Color(0xFF0B1D51)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: _blue.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8))
                          ],
                        ),
                        child: const Icon(Icons.mark_email_read_outlined,
                            color: _white, size: 36),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Check your inbox',
                        style: GoogleFonts.playfairDisplay(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: _textDark),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(
                        "We've sent a 6-digit verification code to\n${_emailCtrl.text}",
                        style: GoogleFonts.dmSans(
                            fontSize: 14, color: _textSub, height: 1.6),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 32),

                    if (_errorMessage != null) ...[
                      _errorBanner(_errorMessage!),
                      const SizedBox(height: 16),
                    ],

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(6, (i) => _otpBox(i)),
                    ),
                    const SizedBox(height: 32),

                    _primaryBtn(
                        label: 'Verify & Create Account',
                        icon: Icons.check_circle_outline,
                        onPress: _handleNextStep),
                    const SizedBox(height: 16),

                    // ── REAL: Resend OTP ──────────────────────
                    Center(
                      child: GestureDetector(
                        onTap: _isLoading ? null : _resendOTP,
                        child: RichText(
                          text: TextSpan(
                            style: GoogleFonts.dmSans(
                                fontSize: 14, color: _textSub),
                            children: [
                              const TextSpan(text: "Didn't receive? "),
                              TextSpan(
                                  text: 'Resend OTP',
                                  style: TextStyle(
                                      color: _isLoading
                                          ? _textSub
                                          : _blue,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
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

  // ============================================================
  //  REUSABLE COMPONENTS (design unchanged)
  // ============================================================

  Widget _brandHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF1347CC), Color(0xFF0B1D51)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: _blue.withOpacity(0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 10))
            ],
          ),
          child: const Icon(Icons.school_rounded, color: _white, size: 36),
        ),
        const SizedBox(height: 16),
        Text('MEET THE MASTERS',
            style: GoogleFonts.playfairDisplay(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: _navy,
                letterSpacing: 1.2)),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
                width: 18, height: 2,
                decoration: BoxDecoration(
                    color: _gold, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            Text('Your gateway to excellence',
                style: GoogleFonts.dmSans(
                    fontSize: 13, color: _textSub, letterSpacing: 0.5)),
            const SizedBox(width: 8),
            Container(
                width: 18, height: 2,
                decoration: BoxDecoration(
                    color: _gold, borderRadius: BorderRadius.circular(2))),
          ],
        ),
      ],
    );
  }

  Widget _topNav({required String title, required String sub}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _goBack,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _bg, borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 16, color: _textDark),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                Text(title,
                    style: GoogleFonts.playfairDisplay(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _navy)),
                const SizedBox(height: 2),
                Text(sub,
                    style: GoogleFonts.dmSans(
                        fontSize: 9,
                        letterSpacing: 1.5,
                        color: _textSub,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _stepBar({required int step}) {
    const total = 3;
    final labels = ['Details', 'Plan', 'Verify'];
    return Row(
      children: List.generate(total, (i) {
        final done = i + 1 <= step;
        final cur  = i + 1 == step;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      height: 4,
                      decoration: BoxDecoration(
                        gradient: done
                            ? const LinearGradient(
                                colors: [Color(0xFF1347CC), Color(0xFF3D72F5)])
                            : null,
                        color: done ? null : _border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(labels[i],
                        style: GoogleFonts.dmSans(
                            fontSize: 10,
                            fontWeight: cur ? FontWeight.w700 : FontWeight.w500,
                            color: done ? _blue : _textSub)),
                  ],
                ),
              ),
              if (i < total - 1) const SizedBox(width: 4),
            ],
          ),
        );
      }),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border.withOpacity(0.7), width: 1),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF0B1D51).withOpacity(0.08),
              blurRadius: 32,
              offset: const Offset(0, 6)),
          BoxShadow(
              color: const Color(0xFF1347CC).withOpacity(0.05),
              blurRadius: 60,
              offset: const Offset(0, 20)),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionHeader({required IconData icon, required String label}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _navy.withOpacity(0.09),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _blue, size: 20),
        ),
        const SizedBox(width: 10),
        Text(label,
            style: GoogleFonts.dmSans(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _textDark)),
      ],
    );
  }

  Widget _reqLabel(String text) => RichText(
        text: TextSpan(children: [
          TextSpan(
              text: text,
              style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _textMid,
                  letterSpacing: 0.8)),
          TextSpan(
              text: ' *',
              style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _errorRed)),
        ]),
      );

  Widget _optLabel(String text) => Text(
        '$text  (OPTIONAL)',
        style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _textMid,
            letterSpacing: 0.8),
      );

  InputDecoration _inputDeco({
    required String hint,
    Widget? prefix,
    Widget? suffix,
  }) =>
      InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.dmSans(
            color: const Color(0xFFCBD5E1), fontSize: 14),
        prefixIcon: prefix,
        suffixIcon: suffix,
        filled: true,
        fillColor: _fill,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _border, width: 1.5)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _navy, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _errorRed, width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _errorRed, width: 2)),
        errorStyle: GoogleFonts.dmSans(fontSize: 12, color: _errorRed),
      );

  Widget _inputField({
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
    TextInputType type = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      style: GoogleFonts.dmSans(fontSize: 14, color: _textDark),
      decoration: _inputDeco(
          hint: hint,
          prefix: Icon(icon, color: const Color(0xFF94A3B8), size: 20)),
      validator: validator,
    );
  }

  Widget _phoneField() {
    return TextFormField(
      controller: _phoneCtrl,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
      style: GoogleFonts.dmSans(fontSize: 14, color: _textDark),
      decoration: _inputDeco(
        hint: '10-digit mobile number',
        prefix: Container(
          width: 56,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: _blue.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text('+91',
                style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _blue)),
          ),
        ),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Mobile number is required';
        if (v.length != 10) return 'Enter a valid 10-digit mobile number';
        return null;
      },
    );
  }

  Widget _emailWithOTP() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            style: GoogleFonts.dmSans(fontSize: 14, color: _textDark),
            decoration: _inputDeco(
              hint: 'you@example.com',
              prefix: const Icon(Icons.email_outlined,
                  color: Color(0xFF94A3B8), size: 20),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Email is required';
              if (!RegExp(r'\S+@\S+\.\S+').hasMatch(v))
                return 'Enter a valid email';
              return null;
            },
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _sendOTP,
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue,
              foregroundColor: _white,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        color: _white, strokeWidth: 2))
                : Text(_otpSent ? 'Resend' : 'Send OTP',
                    style: GoogleFonts.dmSans(
                        fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _passwordField({bool isLogin = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _passwordCtrl,
          obscureText: _obscurePassword,
          style: GoogleFonts.dmSans(fontSize: 14, color: _textDark),
          decoration: _inputDeco(
            hint: isLogin ? '••••••••' : 'Create a strong password',
            prefix: const Icon(Icons.lock_outline,
                color: Color(0xFF94A3B8), size: 20),
            suffix: IconButton(
              icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: const Color(0xFF94A3B8), size: 20),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Password is required';
            if (!isLogin && _strengthScore < 2) return 'Password is too weak';
            return null;
          },
        ),
        if (!isLogin && _passwordCtrl.text.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(
            children: List.generate(
              4,
              (i) => Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                  height: 4,
                  decoration: BoxDecoration(
                    color: _strengthColor(i + 1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(_strengthLabel(),
              style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _strengthColor(_strengthScore))),
        ],
      ],
    );
  }

  // ─── API Plan Card (dynamic from server) ──────────────────
  Widget _apiPlanCard(Map<String, dynamic> plan) {
    final id       = plan['id'] as int?;
    final name     = plan['name'] as String? ?? 'Plan';
    final origPrice= (plan['originalPrice'] as num?)?.toDouble() ?? 0;
    final discPrice= (plan['discountPrice'] as num?)?.toDouble() ?? origPrice;
    final featuresRaw = plan['features'] as String? ?? '';
    final tag      = plan['tag'] as String? ?? '';
    final features = featuresRaw.isNotEmpty
        ? featuresRaw.split(',').map((f) => f.trim()).where((f) => f.isNotEmpty).toList()
        : <String>[];
    final selected = _selectedPlanId == id;
    final isFree   = discPrice == 0;
    final badgeColor = tag.toUpperCase() == 'POPULAR' ? _blue
        : tag.toUpperCase() == 'BEST VALUE' ? _gold
        : _violet;

    return GestureDetector(
      onTap: () => setState(() {
        _selectedPlanId = id;
        _accessType     = AccessType.subscribed;
        // Sync enum for visual (first plan = elite, rest = pro)
        final idx = _apiPlans.indexWhere((p) => p['id'] == id);
        _selectedPlan = idx == 0 ? SubscriptionTier.elite : SubscriptionTier.pro;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEAF0FF) : _white,
          border: Border.all(
              color: selected ? _blue : _border,
              width: selected ? 2 : 1.5),
          borderRadius: BorderRadius.circular(14),
          boxShadow: selected
              ? [BoxShadow(
                    color: _navy.withOpacity(0.09),
                    blurRadius: 12,
                    offset: const Offset(0, 4))]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(name,
                          style: GoogleFonts.dmSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: selected ? _blue : _textDark)),
                      if (tag.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: badgeColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(tag.toUpperCase(),
                              style: GoogleFonts.dmSans(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: badgeColor,
                                  letterSpacing: 0.5)),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (origPrice != discPrice)
                      Text('₹${origPrice.toStringAsFixed(0)}',
                          style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: _textSub,
                              decoration: TextDecoration.lineThrough)),
                    Text(
                      isFree
                          ? 'Free'
                          : '₹${discPrice.toStringAsFixed(0)}',
                      style: GoogleFonts.dmSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isFree ? _green : _textDark),
                    ),
                    if (!isFree)
                      Text('/year',
                          style: GoogleFonts.dmSans(
                              fontSize: 10, color: _textSub)),
                  ],
                ),
                const SizedBox(width: 12),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: selected ? _blue : _border, width: 2),
                    color: selected ? _blue : Colors.transparent,
                  ),
                  child: selected
                      ? const Icon(Icons.circle, color: _white, size: 10)
                      : null,
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              child: selected && features.isNotEmpty
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 10),
                        ...features.map(
                          (f) => Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded,
                                    size: 14, color: _blue),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(f,
                                      style: GoogleFonts.dmSans(
                                          fontSize: 12, color: _textSub)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Static Plan Card (fallback) ───────────────────────────
  Widget _planCard({
    required SubscriptionTier tier,
    required String name,
    required String price,
    required String period,
    required String badge,
    required Color badgeColor,
    required List<String> features,
  }) {
    final selected = _selectedPlan == tier;
    final isFree   = tier == SubscriptionTier.guest;

    return GestureDetector(
      onTap: () => setState(() {
        _selectedPlan  = tier;
        _selectedPlanId = null; // API plans nahi loaded
        _accessType    = isFree ? AccessType.guest : AccessType.subscribed;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEAF0FF) : _white,
          border: Border.all(
              color: selected ? _blue : _border,
              width: selected ? 2 : 1.5),
          borderRadius: BorderRadius.circular(14),
          boxShadow: selected
              ? [BoxShadow(
                    color: _navy.withOpacity(0.09),
                    blurRadius: 12,
                    offset: const Offset(0, 4))]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(name,
                          style: GoogleFonts.dmSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: selected ? _blue : _textDark)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(badge,
                            style: GoogleFonts.dmSans(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: badgeColor,
                                letterSpacing: 0.5)),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(price,
                        style: GoogleFonts.dmSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isFree ? _green : _textDark)),
                    if (period.isNotEmpty)
                      Text(period,
                          style: GoogleFonts.dmSans(
                              fontSize: 10, color: _textSub)),
                  ],
                ),
                const SizedBox(width: 12),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: selected ? _blue : _border, width: 2),
                    color: selected ? _blue : Colors.transparent,
                  ),
                  child: selected
                      ? const Icon(Icons.circle, color: _white, size: 10)
                      : null,
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              child: selected
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 10),
                        ...features.map(
                          (f) => Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded,
                                    size: 14, color: _blue),
                                const SizedBox(width: 6),
                                Text(f,
                                    style: GoogleFonts.dmSans(
                                        fontSize: 12, color: _textSub)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Access Toggle ─────────────────────────────────────────
  Widget _accessToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _toggleTab(
            icon: Icons.verified_user_outlined,
            label: 'SUBSCRIBED — FULL ACCESS',
            active: _accessType == AccessType.subscribed,
            onTap: () => setState(() {
              _accessType   = AccessType.subscribed;
              _selectedPlan = SubscriptionTier.elite;
              if (_apiPlans.isNotEmpty) {
                _selectedPlanId = _apiPlans.first['id'] as int?;
              }
            }),
          ),
          _toggleTab(
            icon: Icons.person_outline,
            label: 'GUEST — LIMITED ACCESS',
            active: _accessType == AccessType.guest,
            onTap: () => setState(() {
              _accessType     = AccessType.guest;
              _selectedPlan   = SubscriptionTier.guest;
              _selectedPlanId = null;
            }),
          ),
        ],
      ),
    );
  }

  Widget _toggleTab({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: active ? _white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: active
                ? [BoxShadow(
                      color: Colors.black.withOpacity(0.07),
                      blurRadius: 8,
                      offset: const Offset(0, 2))]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: active ? _navy : _textSub),
              const SizedBox(width: 4),
              Flexible(
                child: Text(label,
                    style: GoogleFonts.dmSans(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        color: active ? _navy : _textSub,
                        letterSpacing: 0.2),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── OTP Box ────────────────────────────────────────────────
  Widget _otpBox(int i) {
    return SizedBox(
      width: 46, height: 58,
      child: TextFormField(
        controller: _otpControllers[i],
        focusNode: _otpFocusNodes[i],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(1),
        ],
        style: GoogleFonts.dmSans(
            fontSize: 22, fontWeight: FontWeight.w700, color: _textDark),
        decoration: InputDecoration(
          filled: true,
          fillColor: _fill,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _border, width: 1.5)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _border, width: 1.5)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _navy, width: 2)),
        ),
        onChanged: (v) {
          if (v.isNotEmpty && i < 5) {
            _otpFocusNodes[i + 1].requestFocus();
          } else if (v.isEmpty && i > 0) {
            _otpFocusNodes[i - 1].requestFocus();
          }
        },
      ),
    );
  }

  // ─── Misc UI ────────────────────────────────────────────────
  Widget _errorBanner(String msg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        border: Border.all(color: const Color(0xFFFECACA)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: _errorRed, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(msg,
                style: GoogleFonts.dmSans(
                    color: const Color(0xFF991B1B),
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _infoBanner({
    required IconData icon,
    required String msg,
    required Color bg,
    required Color border,
    required Color iconColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(msg,
                style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: textColor,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _checkbox(
      {required bool value, required ValueChanged<bool?> onChange}) {
    return SizedBox(
      width: 24, height: 24,
      child: Checkbox(
        value: value,
        onChanged: onChange,
        activeColor: _navy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        side: const BorderSide(color: _border, width: 1.5),
      ),
    );
  }

  Widget _primaryBtn({
    required String label,
    required IconData icon,
    required VoidCallback onPress,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPress,
        style: ElevatedButton.styleFrom(
          backgroundColor: _navy,
          foregroundColor: _white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 3,
          shadowColor: const Color(0xFF1347CC).withOpacity(0.45),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          disabledBackgroundColor: _navy.withOpacity(0.55),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(
                    color: _white, strokeWidth: 2.5))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style: GoogleFonts.dmSans(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  Icon(icon, size: 18),
                ],
              ),
      ),
    );
  }

  Widget _footerRow({
    required String msg,
    required String action,
    required VoidCallback onTap,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(msg, style: GoogleFonts.dmSans(fontSize: 14, color: _textSub)),
        GestureDetector(
          onTap: onTap,
          child: Row(
            children: [
              Text(action,
                  style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _blue)),
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right_rounded, size: 18, color: _blue),
            ],
          ),
        ),
      ],
    );
  }
}