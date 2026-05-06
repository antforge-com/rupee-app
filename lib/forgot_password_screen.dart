import 'package:finadvise/app_theme.dart';
import 'package:flutter/material.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  int _step = 1; // 1: Email, 2: OTP, 3: New Pass, 4: Done
  bool _loading = false;

  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  void _sendOtp() async {
    if (_emailCtrl.text.isEmpty) return;
    setState(() => _loading = true);
    await Future.delayed(const Duration(seconds: 1));
    bool success = true;
    setState(() {
      _loading = false;
      if (success) _step = 2;
    });
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not send OTP. Please try again.')));
    }
  }

  void _verifyOtp() {
    if (_otpCtrl.text.length == 6) setState(() => _step = 3);
  }

  void _resetPassword() async {
    if (_passCtrl.text != _confirmPassCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwords do not match!')));
      return;
    }
    setState(() => _loading = true);
    await Future.delayed(const Duration(seconds: 1));
    bool success = true;
    setState(() {
      _loading = false;
      if (success) _step = 4;
    });
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Password reset failed. Please try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Password Reset')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20)
                ]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_step == 1) ...[
                  const Text('Forgot Password?',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text(
                      'Enter your registered email. We will send you an OTP.',
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 24),
                  TextField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Email Address',
                          border: OutlineInputBorder())),
                  const SizedBox(height: 24),
                  ElevatedButton(
                      onPressed: _loading ? null : _sendOtp,
                      child: _loading
                          ? const CircularProgressIndicator()
                          : const Text('Send OTP')),
                ] else if (_step == 2) ...[
                  const Text('Verify OTP',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  TextField(
                      controller: _otpCtrl,
                      decoration: const InputDecoration(
                          labelText: '6-digit OTP',
                          border: OutlineInputBorder()),
                      maxLength: 6,
                      keyboardType: TextInputType.number),
                  const SizedBox(height: 24),
                  ElevatedButton(
                      onPressed: _verifyOtp, child: const Text('Verify')),
                ] else if (_step == 3) ...[
                  const Text('Set New Password',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  TextField(
                      controller: _passCtrl,
                      decoration: const InputDecoration(
                          labelText: 'New Password',
                          border: OutlineInputBorder()),
                      obscureText: true),
                  const SizedBox(height: 16),
                  TextField(
                      controller: _confirmPassCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Confirm Password',
                          border: OutlineInputBorder()),
                      obscureText: true),
                  const SizedBox(height: 24),
                  ElevatedButton(
                      onPressed: _loading ? null : _resetPassword,
                      child: _loading
                          ? const CircularProgressIndicator()
                          : const Text('Reset Password')),
                ] else if (_step == 4) ...[
                  const Icon(Icons.check_circle,
                      color: AppColors.success, size: 64),
                  const SizedBox(height: 16),
                  const Text('Password Reset Successful!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success)),
                  const SizedBox(height: 24),
                  ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Back to Login')),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
