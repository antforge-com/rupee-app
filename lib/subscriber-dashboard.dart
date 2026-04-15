import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'login_screen.dart';

class SubscriberDashboard extends StatelessWidget {
  const SubscriberDashboard({super.key});

  void _logout(BuildContext context) async {
    await AuthService().logout();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Premium Subscriber', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () => _logout(context),
          )
        ],
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star_rounded, size: 80, color: Color(0xFFF59E0B)), // Premium Gold
            SizedBox(height: 16),
            Text(
              'Premium Dashboard',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Your premium features are available here.')
          ],
        ),
      ),
    );
  }
}