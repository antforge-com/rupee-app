// lib/features/auth/login_screen.dart
// ════════════════════════════════════════════════════════════════════════════
// Matches LoginPage.tsx exactly:
//   - Email/mobile + password login
//   - Terms & Conditions checkbox (with shake animation)
//   - Forgot Password → ResetPasswordPage (inline navigation)
//   - Role-based routing: ADMIN → AdminDashboard, CONSULTANT → ConsultantDashboard, else → UserDashboard
//   - ForcePasswordChange detection (requiresPasswordChange flag)
//   - Error classification: auth / server / network
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'package:finadvise/services/services.dart';
import 'services/user_service.dart';
import 'meet_the_masters_brand.dart';
import 'reset_password_screen.dart';
import 'force_password_change_screen.dart';
import 'admin-dashboard.dart';
import 'consultant-dashboard.dart';
import 'user-dashboard.dart';

// ─── Error Type ──────────────────────────────────────────────────────────────
enum _ErrorType { none, auth, server, network, registered }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _auth = AuthService();

  final _credCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _passFocusNode = FocusNode();
  bool _passVisible = false;

  bool _loading = false;
  String _apiError = '';
  _ErrorType _errorType = _ErrorType.none;

  bool _termsAccepted = false;
  bool _termsShake = false;
  bool _showTermsModal = false;
  String _termsContent = _defaultTerms;
  bool _termsLoading = false;
  bool _termsLoaded = false;

  bool _showResetPage = false;
  String _resetInitialEmail = '';

  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _shakeAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _credCtrl.dispose();
    _passCtrl.dispose();
    _passFocusNode.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _shakeTerms() {
    setState(() => _termsShake = true);
    _shakeCtrl.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 600),
            () => mounted ? setState(() => _termsShake = false) : null);
  }

  Future<void> _loadTerms() async {
    if (_termsLoaded) return;
    setState(() => _termsLoading = true);
    try {
      // UserService.getTermsAndConditions() tries:
      //   1. GET /api/static-content/TERMS_AND_CONDITIONS
      //   2. GET /api/admin/terms-and-conditions (legacy fallback)
      // Returns '' when nothing is found — we fall back to _defaultTerms.
      final userSvc = UserService();
      final fetched = await userSvc.getTermsAndConditions();
      if (mounted && fetched.isNotEmpty) {
        setState(() => _termsContent = fetched);
      }
      // If empty, _termsContent stays as _defaultTerms (set in field initializer)
      _termsLoaded = true;
    } catch (_) {
      // Network/auth error — keep default terms visible
      _termsLoaded = true;
    } finally {
      if (mounted) setState(() => _termsLoading = false);
    }
  }

  ({String msg, _ErrorType type}) _classifyError(String raw) {
    final msg = raw.toLowerCase();
    if (msg.contains('cannot connect') ||
        msg.contains('failed to fetch') ||
        msg.contains('networkerror') ||
        msg.contains('socketexception') ||
        msg.contains('connection refused')) {
      return (
      msg: 'Cannot reach the server. Please check your connection.',
      type: _ErrorType.network
      );
    }
    if (msg.contains('500') || msg.contains('internal server')) {
      return (
      msg: 'Server error occurred. Please try again later.',
      type: _ErrorType.server
      );
    }
    if (msg.contains('already registered') ||
        msg.contains('already exists') ||
        msg.contains('conflict')) {
      return (
      msg: 'Email already registered. Please log in or reset password.',
      type: _ErrorType.registered
      );
    }
    if (msg.contains('401') ||
        msg.contains('403') ||
        msg.contains('unauthorized') ||
        msg.contains('invalid') ||
        msg.contains('bad credentials') ||
        msg.contains('incorrect')) {
      return (
      msg:
      'Incorrect email or password. If you recently changed your password, use Forgot Password.',
      type: _ErrorType.auth
      );
    }
    return (
    msg: raw.isNotEmpty
        ? raw
        : 'Login failed. Please try Forgot Password if you recently changed your password.',
    type: _ErrorType.auth
    );
  }

  Future<void> _handleLogin() async {
    if (_credCtrl.text.trim().isEmpty || _passCtrl.text.trim().isEmpty) {
      setState(() {
        _apiError = 'Please enter your email and password.';
        _errorType = _ErrorType.auth;
      });
      return;
    }
    if (!_termsAccepted) {
      _shakeTerms();
      return;
    }

    setState(() {
      _loading = true;
      _apiError = '';
      _errorType = _ErrorType.none;
    });

    try {
      final result = await _auth.login(
        identifier: _credCtrl.text.trim(),
        password: _passCtrl.text,
      );

      if (!result.success) {
        final classified = _classifyError(result.error ?? 'Login failed');
        setState(() {
          _apiError = classified.msg;
          _errorType = classified.type;
          _loading = false;
        });
        return;
      }

      // Persist session
      await _auth.persistSession(result);

      // Pre-fetch Terms & Conditions in background so the login-page
      // modal shows backend content next time (endpoint requires JWT auth).
      UserService().prefetchAndCacheTerms().ignore();

      if (!mounted) return;

      // Init notifications
      if (result.role != null && result.userId != null) {
        context
            .read<NotificationService>()
            .initialize(result.role!, result.userId!);
      }

      // Force password change
      if (result.requiresPasswordChange) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ForcePasswordChangeScreen(
              onPasswordChanged: () => _navigateByRole(result.role ?? 'USER'),
            ),
          ),
        );
        return;
      }

      _navigateByRole(result.role ?? 'USER');
    } catch (e) {
      final classified = _classifyError(e.toString());
      setState(() {
        _apiError = classified.msg;
        _errorType = classified.type;
        _loading = false;
      });
    }
  }

  void _navigateByRole(String role) {
    final clean = role.toUpperCase().replaceFirst(RegExp(r'^ROLE_'), '');
    Widget dest;
    switch (clean) {
      case 'ADMIN':
        dest = const AdminDashboard();
        break;
      case 'CONSULTANT':
      case 'ADVISOR':
      case 'AGENT':
        dest = const ConsultantDashboard();
        break;
      default:
        dest = const UserDashboard();
    }
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => dest,
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  void _openResetPage() {
    final cred = _credCtrl.text.trim();
    setState(() {
      _resetInitialEmail = cred.contains('@') ? cred : '';
      _showResetPage = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showResetPage) {
      return ResetPasswordScreen(
        initialEmail: _resetInitialEmail,
        onBackToLogin: () => setState(() => _showResetPage = false),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFEFF6FF),
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
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    _buildBrand(),
                    const SizedBox(height: 32),
                    _buildCard(),
                  ],
                ),
              ),
            ),
          ),
          if (_showTermsModal) _buildTermsModal(),
        ],
      ),
    );
  }

  Widget _buildBrand() {
    return const MeetTheMastersBrand(
      onDark: true,
      logoSize: 94,
      logoPadding: 13,
      titleSize: 23,
      subtitleSize: 12.5,
      titleLetterSpacing: 3.8,
      gap: 10,
      showAmbientGlow: true,
    );
  }

  Widget _buildCard() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 440),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 40,
              offset: const Offset(0, 20))
        ],
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Login to Account',
              style: GoogleFonts.inter(
                  fontSize: 22, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
          const SizedBox(height: 4),
          Text('Welcome back! Please enter your credentials.',
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
          const SizedBox(height: 24),

          // Email / Mobile
          _label('EMAIL OR MOBILE'),
          const SizedBox(height: 6),
          TextField(
            controller: _credCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {
              _apiError = '';
              _errorType = _ErrorType.none;
            }),
            onSubmitted: (_) => _passFocusNode.requestFocus(),
            decoration: _inputDecoration(
              hint: 'Enter your email or mobile',
              hasError: _apiError.isNotEmpty && _errorType == _ErrorType.auth,
            ),
          ),
          const SizedBox(height: 16),

          // Password
          _label('PASSWORD'),
          const SizedBox(height: 6),
          TextField(
            controller: _passCtrl,
            obscureText: !_passVisible,
            focusNode: _passFocusNode,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {
              _apiError = '';
              _errorType = _ErrorType.none;
            }),
            onSubmitted: (_) => _handleLogin(),
            decoration: _inputDecoration(
              hint: '••••••••',
              hasError: _apiError.isNotEmpty && _errorType == _ErrorType.auth,
              suffix: IconButton(
                icon: Icon(
                    _passVisible ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                    color: _passVisible
                        ? AppColors.primaryLight
                        : AppColors.textSecondary),
                onPressed: () => setState(() => _passVisible = !_passVisible),
              ),
            ),
          ),

          // Forgot password
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _openResetPage,
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: Text('Forgot Password?',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryLight)),
            ),
          ),

          // Terms checkbox with shake
          AnimatedBuilder(
            animation: _shakeAnim,
            builder: (_, child) => Transform.translate(
              offset: Offset(_shakeAnim.value, 0),
              child: child,
            ),
            child: _buildTermsBox(),
          ),
          const SizedBox(height: 16),

          // Error banner
          if (_apiError.isNotEmpty) _buildErrorBanner(),
          if (_apiError.isNotEmpty) const SizedBox(height: 16),

          // Login button
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryLight,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _loading
                  ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5))
                  : Text('Login to Account',
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 20),

          // Register link
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Don't have an account? ",
                  style: GoogleFonts.inter(
                      fontSize: 13, color: AppColors.textSecondary)),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/register'),
                child: Text('Create Account',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryLight)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTermsBox() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _termsAccepted
            ? const Color(0xFFF0FDF4)
            : _termsShake
            ? const Color(0xFFFEF2F2)
            : const Color(0xFFF8FAFC),
        border: Border.all(
          color: _termsAccepted
              ? const Color(0xFF86EFAC)
              : _termsShake
              ? const Color(0xFFFCA5A5)
              : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: _termsAccepted,
            onChanged: (v) => setState(() {
              _termsAccepted = v ?? false;
              _apiError = '';
            }),
            activeColor: AppColors.primaryLight,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_termsShake && !_termsAccepted)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            size: 13, color: Color(0xFFEF4444)),
                        const SizedBox(width: 4),
                        Text(
                            'Please accept the Terms & Conditions to continue',
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFEF4444))),
                      ],
                    ),
                  ),
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.inter(
                        fontSize: 13, color: const Color(0xFF334155)),
                    children: [
                      const TextSpan(text: 'I agree to the '),
                      WidgetSpan(
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _showTermsModal = true);
                            _loadTerms();
                          },
                          child: Text('Terms & Conditions',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryLight,
                                  decoration: TextDecoration.underline)),
                        ),
                      ),
                      const TextSpan(text: ' and '),
                      WidgetSpan(
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _showTermsModal = true);
                            _loadTerms();
                          },
                          child: Text('Privacy Policy',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryLight,
                                  decoration: TextDecoration.underline)),
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

  Widget _buildErrorBanner() {
    IconData icon;
    String title;
    switch (_errorType) {
      case _ErrorType.server:
        icon = Icons.settings;
        title = 'Server Error';
        break;
      case _ErrorType.network:
        icon = Icons.wifi_off;
        title = 'Connection Error';
        break;
      default:
        icon = Icons.warning_amber_rounded;
        title = 'Login Failed';
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        border: Border.all(color: const Color(0xFFFCA5A5)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFEF4444), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF991B1B),
                        fontSize: 13)),
                const SizedBox(height: 2),
                Text(_apiError,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: const Color(0xFFB91C1C))),
                if (_errorType == _ErrorType.auth)
                  GestureDetector(
                    onTap: _openResetPage,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.arrow_forward,
                              size: 13, color: AppColors.primaryLight),
                          const SizedBox(width: 4),
                          Text('Reset your password now',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryLight,
                                  decoration: TextDecoration.underline)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsModal() {
    return GestureDetector(
      onTap: () => setState(() => _showTermsModal = false),
      child: Container(
        color: Colors.black.withOpacity(0.6),
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              margin: const EdgeInsets.all(24),
              constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                    child: Row(
                      children: [
                        Text('Terms & Conditions',
                            style: GoogleFonts.inter(
                                fontSize: 18, fontWeight: FontWeight.w800)),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () =>
                              setState(() => _showTermsModal = false),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: _termsLoading
                        ? const Center(child: CircularProgressIndicator())
                        : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Text(_termsContent,
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.7)),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                setState(() => _showTermsModal = false),
                            child: const Text('Close'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _termsAccepted = true;
                                _showTermsModal = false;
                                _apiError = '';
                              });
                            },
                            icon: const Icon(Icons.check_circle, size: 18),
                            label: const Text('I Agree & Accept'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryLight,
                              foregroundColor: Colors.white,
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
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF64748B),
          letterSpacing: 0.5));

  InputDecoration _inputDecoration({
    required String hint,
    bool hasError = false,
    Widget? suffix,
  }) =>
      InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        suffixIcon: suffix,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
          const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: hasError
                ? const Color(0xFFFCA5A5)
                : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
          BorderSide(color: AppColors.primaryLight, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
          const BorderSide(color: Color(0xFFFCA5A5), width: 1.5),
        ),
      );
}

// ─── Default Terms ────────────────────────────────────────────────────────────
const _defaultTerms = '''1. Acceptance of Terms
By accessing and using Meet The Masters, you agree to these Terms & Conditions.

2. Use of Services
The platform provides access to financial consultants and may only be used for lawful purposes.

3. Confidentiality
Consultation details and shared information must be handled confidentially.

4. Booking & Payments
Bookings are confirmed after successful payment. Cancellation and refund rules apply as per platform policy.

5. Disclaimer
Guidance shared on the platform is informational and does not guarantee financial outcomes.

6. Privacy
Personal information is stored and processed according to applicable data-protection requirements.

7. Governing Law
These terms are governed by the laws of India.''';
