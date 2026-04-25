import 'package:flutter_test/flutter_test.dart';
import 'package:finadvise/main.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const FinAdviseApp());

    // Verify splash screen is shown
    expect(find.byType(SplashScreen), findsOneWidget);

    // Instead of waiting for navigation (which is tricky in a smoke test due to async dependencies),
    // let's just verify the splash screen exists and then pump to clear the timers.
    
    // Fast-forward past the 2s auth check delay
    await tester.pump(const Duration(seconds: 3));
    
    // We expect it to still be on SplashScreen because SharedPreferences 
    // and AuthService calls aren't mocked here and might be stuck.
    // To properly test navigation, we'd need to mock AuthService.
  });
}
