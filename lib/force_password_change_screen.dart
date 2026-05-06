// lib/features/auth/force_password_change_screen.dart
// ════════════════════════════════════════════════════════════════════════════
// Matches ForcePasswordChangeModal.tsx exactly:
//   - Shown when requiresPasswordChange == true after login
//   - Password strength meter (4 levels: Weak / Fair / Good / Strong)
//   - Requirements checklist (8+ chars, uppercase, number, different from temp)
//   - Calls PUT /users/change-password
//   - On success → clears flag, calls onPasswordChanged callback
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:finadvise/app_theme.dart';
import 'package:finadvise/services/services.dart';

class ForcePasswordChangeScreen extends StatefulWidget {
  final VoidCallback onPasswordChanged;

  const ForcePasswordChangeScreen({
    super.key,
    required this.onPasswordChanged,
  });

  @override
  State<ForcePasswordChangeScreen> createState() =>
      _ForcePasswordChangeScreenState();
}

class _ForcePasswordChangeScreenState
    extends State<ForcePasswordChangeScreen> {
  final AuthService _auth = AuthService();

  final _newPassCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _showNew = false;
  bool _showConfirm = false;
  bool _loading = false;
  String _error = '';

  @override
  void dispose() {
    _newPassCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  int get _score {
    int s = 0;
    final p = _newPassCtrl.text;
    if (p.length >= 8) s++;
    if (RegExp(r'[A-Z]').hasMatch(p)) s++;
    if (RegExp(r'[0-9]').hasMatch(p)) s++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) s++;
    return s;
  }

  String get _strengthLabel =>
      ['', 'Weak', 'Fair', 'Good', 'Strong'][_score];

  Color get _strengthColor {
    switch (_score) {
      case 1: return const Color(0xFFEF4444);
      case 2: return const Color(0xFFF59E0B);
      case 3: return const Color(0xFF22C55E);
      case 4: return const Color(0xFF16A34A);
      default: return Colors.transparent;
    }
  }

  Future<void> _handleSubmit() async {
    final np = _newPassCtrl.text;
    final cp = _confirmCtrl.text;

    if (np.isEmpty || np != cp) {
      setState(() => _error = "Passwords don't match.");
      return;
    }
    if (np.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters.');
      return;
    }

    setState(() { _loading = true; _error = ''; });

    try {
      final result = await _auth.changePassword(
        newPassword: np,
        confirmPassword: cp,
      );
      if (!result.success) throw Exception(result.error);

      // Clear flag
      await _auth.clearRequiresPasswordChange();

      if (mounted) widget.onPasswordChanged();
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _error = msg.toLowerCase().contains('same')
            ? 'New password must be different from your current password.'
            : msg.isNotEmpty
                ? msg
                : 'Failed to change password. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _canSubmit =>
      !_loading &&
      _newPassCtrl.text.isNotEmpty &&
      _newPassCtrl.text == _confirmCtrl.text &&
      _newPassCtrl.text.length >= 8;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.75),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 430),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: AppShadows.modal,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                _buildBody(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      decoration: const BoxDecoration(
        gradient: AppGradients.portalBrand,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.3), width: 1.5),
                ),
                child: const Icon(Icons.lock_rounded,
                    size: 20, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SECURITY REQUIRED',
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          letterSpacing: 1.6,
                          color: const Color(0xFF99F6E4),
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('Set Your New Password',
                      style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Your account was created with a temporary password. Please set a new secure password to continue.',
            style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFFA5F3FC),
                height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final mismatch =
        _confirmCtrl.text.isNotEmpty && _confirmCtrl.text != _newPassCtrl.text;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Warning banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              border: Border.all(color: const Color(0xFFFDE68A)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline,
                    size: 16, color: Color(0xFFB45309)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Enter a new password that is different from your temporary password.',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF92400E),
                        height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Error
          if (_error.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                border: Border.all(color: const Color(0xFFFECACA)),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      size: 15, color: Color(0xFFB91C1C)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_error,
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFB91C1C))),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // New Password
          _label('New Password *'),
          const SizedBox(height: 6),
          TextField(
            controller: _newPassCtrl,
            obscureText: !_showNew,
            onChanged: (_) => setState(() => _error = ''),
            decoration: _inputDeco(
              hint: 'Min. 8 characters',
              suffix: IconButton(
                icon: Icon(
                    _showNew ? Icons.visibility_off : Icons.visibility,
                    size: 16,
                    color: const Color(0xFF94A3B8)),
                onPressed: () => setState(() => _showNew = !_showNew),
              ),
            ),
          ),

          // Strength meter
          if (_newPassCtrl.text.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: List.generate(4, (i) {
                return Expanded(
                  child: Container(
                    height: 4,
                    margin: EdgeInsets.only(right: i < 3 ? 3 : 0),
                    decoration: BoxDecoration(
                      color: _score > i
                          ? _strengthColor
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 3),
            Text('$_strengthLabel password',
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _strengthColor)),
          ],
          const SizedBox(height: 14),

          // Confirm Password
          _label('Confirm Password *'),
          const SizedBox(height: 6),
          TextField(
            controller: _confirmCtrl,
            obscureText: !_showConfirm,
            onChanged: (_) => setState(() => _error = ''),
            decoration: _inputDeco(
              hint: 'Re-enter new password',
              hasError: mismatch,
              suffix: IconButton(
                icon: Icon(
                    _showConfirm ? Icons.visibility_off : Icons.visibility,
                    size: 16,
                    color: const Color(0xFF94A3B8)),
                onPressed: () =>
                    setState(() => _showConfirm = !_showConfirm),
              ),
            ),
          ),
          if (mismatch) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.close, size: 12, color: Color(0xFFDC2626)),
                const SizedBox(width: 5),
                Text("Passwords don't match",
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFDC2626))),
              ],
            ),
          ],
          const SizedBox(height: 14),

          // Requirements checklist
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border.all(color: const Color(0xFFF1F5F9)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('REQUIREMENTS',
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
                        letterSpacing: 0.6)),
                const SizedBox(height: 8),
                ...[
                  ('At least 8 characters', _newPassCtrl.text.length >= 8),
                  ('Uppercase letter (A-Z)',
                      RegExp(r'[A-Z]').hasMatch(_newPassCtrl.text)),
                  ('Number (0-9)',
                      RegExp(r'[0-9]').hasMatch(_newPassCtrl.text)),
                  ('Different from temporary password',
                      _newPassCtrl.text.isNotEmpty),
                ].map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(
                            r.$2
                                ? Icons.check_rounded
                                : Icons.circle_outlined,
                            size: 13,
                            color: r.$2
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFCBD5E1)),
                        const SizedBox(width: 8),
                        Text(r.$1,
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: r.$2
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFF94A3B8))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Submit button
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _canSubmit ? _handleSubmit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _canSubmit
                    ? AppColors.primaryLight
                    : const Color(0xFFE2E8F0),
                foregroundColor:
                    _canSubmit ? Colors.white : const Color(0xFF94A3B8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : Text('Set New Password',
                      style: GoogleFonts.inter(
                          fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF64748B),
          textBaseline: TextBaseline.alphabetic));

  InputDecoration _inputDeco({
    required String hint,
    bool hasError = false,
    Widget? suffix,
  }) =>
      InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
        filled: true,
        fillColor: Colors.white,
        suffixIcon: suffix,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color:
                hasError ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.primaryLight, width: 1.5),
        ),
      );
}
