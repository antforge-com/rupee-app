// lib/features/auth/reset_password_screen.dart
// ════════════════════════════════════════════════════════════════════════════
// Matches ResetPasswordPage.tsx exactly:
//   Step 1 "email"  → send OTP  (POST /users/forgot-password)
//   Step 2 "otp"    → enter 6-digit OTP + new password + confirm password
//                     (POST /users/reset-password)
//   Step 3 "done"   → success + back to login
//   - 60-second countdown with Resend
//   - OTP expiry / mismatch error handling
// ════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:finadvise/app_theme.dart';
import 'package:finadvise/meet_the_masters_brand.dart';
import 'package:finadvise/services/services.dart';
import 'package:google_fonts/google_fonts.dart';

typedef _ForgotStep = String;
const _stepEmail = 'email';
const _stepOtp = 'otp';
const _stepDone = 'done';

class ResetPasswordScreen extends StatefulWidget {
  final String initialEmail;
  final VoidCallback onBackToLogin;

  const ResetPasswordScreen({
    super.key,
    required this.initialEmail,
    required this.onBackToLogin,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final AuthService _auth = AuthService();

  _ForgotStep _step = _stepEmail;
  bool _loading = false;
  String _error = '';

  late final TextEditingController _emailCtrl;
  final _otpCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _showNewPass = false;
  bool _showConfirm = false;

  int _countdown = 0;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmCtrl.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    setState(() => _countdown = 60);
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_countdown <= 1) { _countdown = 0; t.cancel(); }
        else _countdown--;
      });
    });
  }

  Future<void> _handleSendOtp() async {
    if (_emailCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your email address.');
      return;
    }
    setState(() { _loading = true; _error = ''; });
    try {
      final result = await _auth.forgotPassword(email: _emailCtrl.text.trim().toLowerCase());
      if (!result.success) throw Exception(result.error);
      _otpCtrl.clear();
      setState(() => _step = _stepOtp);
      _startCountdown();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleResendOtp() async {
    if (_countdown > 0) return;
    setState(() { _loading = true; _error = ''; });
    try {
      final result = await _auth.forgotPassword(email: _emailCtrl.text.trim().toLowerCase());
      if (!result.success) throw Exception(result.error);
      _otpCtrl.clear();
      _startCountdown();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleResetPassword() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length != 6) {
      setState(() => _error = 'Please enter the 6-digit OTP.');
      return;
    }
    if (_newPassCtrl.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    if (_newPassCtrl.text != _confirmCtrl.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    setState(() { _loading = true; _error = ''; });
    try {
      final result = await _auth.resetPassword(
        email: _emailCtrl.text.trim().toLowerCase(),
        otp: otp,
        newPassword: _newPassCtrl.text,
      );
      if (!result.success) throw Exception(result.error);
      setState(() => _step = _stepDone);
    } catch (e) {
      final raw = e.toString().toLowerCase();
      String msg;
      if (raw.contains('expired')) {
        msg = 'Your OTP has expired. Please request a new one.';
      } else if (raw.contains('otp') || raw.contains('invalid') || raw.contains('incorrect')) {
        msg = 'The OTP you entered is incorrect. Please enter the correct OTP.';
      } else {
        msg = e.toString().replaceFirst('Exception: ', '');
      }
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: widget.onBackToLogin,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 440),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 40,
                              offset: const Offset(0, 20),
                            )
                          ],
                        ),
                        padding: const EdgeInsets.all(28),
                        child: _buildContent(),
                      ),
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

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Center(
          child: Column(
            children: [
              const MeetTheMastersBrand(
                subtitle: '',
                logoSize: 60,
                logoPadding: 9,
                titleSize: 18,
                titleLetterSpacing: 2.8,
                gap: 8,
                titleColor: AppColors.primary,
                showAmbientGlow: false,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_step == _stepDone)
                    const Icon(Icons.check_circle, size: 16, color: Color(0xFF16A34A)),
                  const SizedBox(width: 4),
                  Text(
                    _step == _stepDone ? 'Password Reset!' : 'Reset Your Password',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _step == _stepEmail
                    ? 'Enter your registered email address'
                    : _step == _stepOtp
                        ? 'Enter OTP sent to ${_emailCtrl.text.trim().toLowerCase()} and your new password'
                        : 'You can now log in with your new password',
                style: GoogleFonts.inter(
                    fontSize: 12, color: const Color(0xFF64748B)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Progress bar (email + otp steps)
        if (_step != _stepDone) ...[
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: _step == _stepOtp
                        ? AppColors.primaryLight
                        : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],

        // Step content
        if (_step == _stepEmail) _buildEmailStep(),
        if (_step == _stepOtp) _buildOtpStep(),
        if (_step == _stepDone) _buildDoneStep(),
      ],
    );
  }

  Widget _buildEmailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label('EMAIL ADDRESS'),
        const SizedBox(height: 6),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          onChanged: (_) => setState(() => _error = ''),
          onSubmitted: (_) => _handleSendOtp(),
          autofocus: true,
          decoration: _inputDeco(hint: 'you@example.com'),
        ),
        if (_error.isNotEmpty) ...[
          const SizedBox(height: 12),
          _errorBanner(_error),
        ],
        const SizedBox(height: 16),
        _primaryBtn(
          label: _loading ? 'Sending OTP…' : 'Send Reset OTP',
          onTap: _loading || _emailCtrl.text.trim().isEmpty ? null : _handleSendOtp,
          loading: _loading,
        ),
      ],
    );
  }

  Widget _buildOtpStep() {
    final mismatch = _confirmCtrl.text.isNotEmpty &&
        _confirmCtrl.text != _newPassCtrl.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Email badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            border: Border.all(color: const Color(0xFF93C5FD)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.mail_outline, size: 16, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Check your inbox at ${_emailCtrl.text.trim().toLowerCase()}',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        _label('6-DIGIT OTP'),
        const SizedBox(height: 6),
        TextField(
          controller: _otpCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
          textAlign: TextAlign.center,
          autofocus: true,
          onChanged: (_) => setState(() => _error = ''),
          style: GoogleFonts.inter(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.w800),
          decoration: _inputDeco(hint: '000000'),
        ),

        // Resend
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _countdown > 0 || _loading ? null : _handleResendOtp,
            child: Text(
              _loading
                  ? 'Sending…'
                  : _countdown > 0
                      ? 'Resend in ${_countdown}s'
                      : 'Resend OTP',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _countdown > 0
                      ? AppColors.textSecondary
                      : AppColors.primaryLight),
            ),
          ),
        ),

        // Reminder badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            border: Border.all(color: const Color(0xFFFCD34D)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.lock_outline, size: 16, color: Color(0xFFD97706)),
              const SizedBox(width: 8),
              Text('New password must be different',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFD97706))),
            ],
          ),
        ),
        const SizedBox(height: 16),

        _label('NEW PASSWORD'),
        const SizedBox(height: 6),
        TextField(
          controller: _newPassCtrl,
          obscureText: !_showNewPass,
          onChanged: (_) => setState(() => _error = ''),
          decoration: _inputDeco(
            hint: 'Min. 6 characters',
            suffix: IconButton(
              icon: Icon(
                  _showNewPass ? Icons.visibility_off : Icons.visibility,
                  size: 20,
                  color: AppColors.textSecondary),
              onPressed: () => setState(() => _showNewPass = !_showNewPass),
            ),
          ),
        ),
        const SizedBox(height: 16),

        _label('CONFIRM PASSWORD'),
        const SizedBox(height: 6),
        TextField(
          controller: _confirmCtrl,
          obscureText: !_showConfirm,
          onChanged: (_) => setState(() => _error = ''),
          onSubmitted: (_) => _handleResetPassword(),
          decoration: _inputDeco(
            hint: 'Re-enter password',
            hasError: mismatch,
            suffix: IconButton(
              icon: Icon(
                  _showConfirm ? Icons.visibility_off : Icons.visibility,
                  size: 20,
                  color: AppColors.textSecondary),
              onPressed: () => setState(() => _showConfirm = !_showConfirm),
            ),
          ),
        ),
        if (mismatch)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFDC2626)),
                const SizedBox(width: 4),
                Text("Passwords don't match",
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFDC2626))),
              ],
            ),
          ),

        if (_error.isNotEmpty) ...[
          const SizedBox(height: 12),
          _errorBanner(_error),
        ],
        const SizedBox(height: 24),

        _primaryBtn(
          label: _loading ? 'Verifying…' : 'Verify OTP & Reset Password',
          loading: _loading,
          onTap: _loading ||
                  _otpCtrl.text.length != 6 ||
                  _newPassCtrl.text.isEmpty ||
                  _newPassCtrl.text != _confirmCtrl.text
              ? null
              : _handleResetPassword,
        ),
      ],
    );
  }

  Widget _buildDoneStep() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_rounded,
              size: 40, color: Color(0xFF16A34A)),
        ),
        const SizedBox(height: 12),
        Text('Password Reset!',
            style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF16A34A))),
        const SizedBox(height: 8),
        Text('OTP verified. Your password has been updated successfully.',
            style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.6),
            textAlign: TextAlign.center),
        const SizedBox(height: 28),
        _primaryBtn(
          label: 'Go to Login',
          onTap: widget.onBackToLogin,
          icon: Icons.arrow_forward,
        ),
      ],
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  Widget _label(String text) => Text(text,
      style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF64748B),
          letterSpacing: 0.5));

  InputDecoration _inputDeco({
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
          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: hasError ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.primaryLight, width: 1.5),
        ),
      );

  Widget _primaryBtn({
    required String label,
    VoidCallback? onTap,
    bool loading = false,
    IconData? icon,
  }) =>
      SizedBox(
        height: 50,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: onTap == null
                ? const Color(0xFFE2E8F0)
                : AppColors.primaryLight,
            foregroundColor:
                onTap == null ? const Color(0xFF94A3B8) : Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(label,
                        style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                    if (icon != null) ...[
                      const SizedBox(width: 6),
                      Icon(icon, size: 18),
                    ]
                  ],
                ),
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
                      fontSize: 13, color: const Color(0xFFB91C1C))),
            ),
          ],
        ),
      );
}
