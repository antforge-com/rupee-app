// lib/main.dart
// ════════════════════════════════════════════════════════════════════════════
// Updated to match full web app routing:
//   /login     → LoginScreen
//   /register  → RegisterScreen
//   /home      → UserDashboard
//   /admin     → AdminDashboard
//   /consultant→ ConsultantDashboard
//   SplashScreen → auto-detects role + requiresPasswordChange flag
// ════════════════════════════════════════════════════════════════════════════

import 'package:finadvise/admin-dashboard.dart';
import 'package:finadvise/app_theme.dart';
import 'package:finadvise/services/services.dart';
import 'package:finadvise/consultant-dashboard.dart';
import 'package:finadvise/force_password_change_screen.dart';
import 'package:finadvise/login_screen.dart';
import 'package:finadvise/meet_the_masters_brand.dart';
import 'package:finadvise/public_contact_screen.dart';
import 'package:finadvise/register_screen.dart';
import 'package:finadvise/user-dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NotificationService()),
      ],
      child: const FinAdviseApp(),
    ),
  );
}

class FinAdviseApp extends StatelessWidget {
  const FinAdviseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meet The Masters',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
      routes: {
        '/contact': (context) => const PublicContactScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const UserDashboard(),
        '/admin': (context) => const AdminDashboard(),
        '/consultant': (context) => const ConsultantDashboard(),
      },
    );
  }
}

// ─── SPLASH SCREEN ────────────────────────────────────────────────────────────

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0, 0.6, curve: Curves.easeOut)));
    _scaleAnim = Tween<double>(begin: 0.7, end: 1).animate(CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0, 0.6, curve: Curves.elasticOut)));
    _ctrl.forward();
    _checkAuth();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(seconds: 2));

    final authService = AuthService();
    final isLoggedIn = await authService.isLoggedIn();

    if (!mounted) return;

    Widget nextScreen;
    if (isLoggedIn) {
      final role = await authService.getUserRole();
      final userId = await authService.getUserId();
      final requiresPwChange = await authService.requiresPasswordChange();

      // Init notifications
      if (role != null && userId != null) {
        final parsedUserId = int.tryParse(userId);
        if (parsedUserId != null) {
          context.read<NotificationService>().initialize(role, parsedUserId);
        }
      }

      // Force password change check (matches ForcePasswordChangeModal logic)
      if (requiresPwChange) {
        nextScreen = ForcePasswordChangeScreen(
          onPasswordChanged: () => _navigateByRole(role ?? 'USER'),
        );
      } else {
        nextScreen = _screenForRole(role ?? 'USER');
      }
    } else {
      nextScreen = const LoginScreen();
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => nextScreen,
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  Widget _screenForRole(String role) {
    final clean = role.toUpperCase().replaceFirst(RegExp(r'^ROLE_'), '');
    switch (clean) {
      case 'ADMIN': return const AdminDashboard();
      case 'CONSULTANT':
      case 'ADVISOR':
      case 'AGENT': return const ConsultantDashboard();
      default: return const UserDashboard();
    }
  }

  void _navigateByRole(String role) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => _screenForRole(role)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
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
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: ScaleTransition(
              scale: _scaleAnim,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  MeetTheMastersBrand(
                    onDark: true,
                    logoSize: 122,
                    logoPadding: 16,
                    titleSize: 29,
                    subtitleSize: 13.5,
                    titleLetterSpacing: 4.0,
                    gap: 18,
                    showAmbientGlow: true,
                  ),
                  SizedBox(height: 56),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
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
}
