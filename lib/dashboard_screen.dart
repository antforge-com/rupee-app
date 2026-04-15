import 'package:finadvise/auth_service.dart';
import 'package:finadvise/login_screen.dart';
import 'package:flutter/material.dart';
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // Logout karein aur wapas Login par bhejein
              await AuthService().logout();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              }
            },
          )
        ],
      ),
      body: const Center(
        child: Text('Welcome to Rupee App!', style: TextStyle(fontSize: 24)),
      ),
    );
  }
}