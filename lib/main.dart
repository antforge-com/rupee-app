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
import 'package:finadvise/public_contact_screen.dart';
import 'package:finadvise/register_screen.dart';
import 'package:finadvise/user-dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 112,
                    height: 112,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.3), width: 2),
                    ),
                    child: Image.asset(
                      'assets/images/meet_the_masters_logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'MEET THE MASTERS',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Experience the Experience',
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.78),
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 64),
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
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
