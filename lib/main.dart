import 'package:finadvise/admin-dashboard.dart';
import 'package:finadvise/app_theme.dart';
import 'package:finadvise/auth_service.dart';
import 'package:finadvise/consultant-dashboard.dart';
import 'package:finadvise/login_screen.dart';
import 'package:finadvise/services/notification_service.dart';
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
      title: 'FINADVISE',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
      // 👇 ROUTES ADDED HERE
      // Yahan hum map kar rahe hain ki kis naam se kaunsi screen khulegi
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const UserDashboard(), // '/home' route ko UserDashboard se map kar diya
        '/admin': (context) => const AdminDashboard(),
        '/consultant': (context) => const ConsultantDashboard(),
      },
    );
  }
}

// ─── SPLASH SCREEN ─────────────────────────────────────────────────────────────

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.6, curve: Curves.easeOut)));
    _scaleAnim = Tween<double>(begin: 0.7, end: 1).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.6, curve: Curves.elasticOut)));
    _ctrl.forward();
    _checkAuth();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _checkAuth() async {
    // Minimum splash display
    await Future.delayed(const Duration(seconds: 2));

    final authService = AuthService();
    final isLoggedIn = await authService.isLoggedIn();

    if (!mounted) return;

    Widget nextScreen;
    if (isLoggedIn) {
      final role = await authService.getUserRole();
      final userId = await authService.getUserId();
      // final consultantId = await authService.getConsultantId(); // User ne upload ki file mein tha but unused

      // Initialize notifications
      if (role != null && userId != null) {
        context.read<NotificationService>().initialize(role, userId as int);
      }

      switch (role) {
        case 'ADMIN':
          nextScreen = const AdminDashboard();
          break;
        case 'ADVISOR':
        case 'CONSULTANT':
          nextScreen = const ConsultantDashboard();
          break;
        default:
          nextScreen = const UserDashboard();
          break;
      }
    } else {
      nextScreen = const LoginScreen(); // ← Landing page dikhao, login nahi
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => nextScreen,
          transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E3A8A), Color(0xFF2563EB), Color(0xFF3B82F6)],
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
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                    ),
                    child: const Icon(Icons.account_balance_rounded, size: 52, color: Colors.white),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'FINADVISE',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'SEBI Certified Financial Advisory',
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 64),
                  const SizedBox(
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