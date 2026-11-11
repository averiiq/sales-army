import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salesarmy/features/auth/presentation/screens/splash_screen.dart';

void main() {
  group('SplashScreen UI & Flow Tests', () {
    testWidgets('Renders SalesArmy brand elements, tagline, and progress indicator', (tester) async {
      bool finishedCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            onFinished: () => finishedCalled = true,
          ),
        ),
      );

      // Verify immediate brand presence
      expect(find.text('SalesArmy'), findsOneWidget);
      expect(find.text('SALES TODAY  •  STRONGER TOMORROW'), findsOneWidget);
      expect(find.text('Smart FMCG & Distributor Operations Suite'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);

      // Advance animation slightly
      await tester.pump(const Duration(milliseconds: 500));
      expect(finishedCalled, isFalse);

      // Advance past splash auto-finish duration (2400ms)
      await tester.pump(const Duration(milliseconds: 2000));
      expect(finishedCalled, isTrue);
    });

    testWidgets('Tapping anywhere on splash screen dismisses it immediately', (tester) async {
      bool finishedCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            onFinished: () => finishedCalled = true,
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));
      expect(finishedCalled, isFalse);

      // Tap screen
      await tester.tap(find.byType(SplashScreen));
      await tester.pump();

      expect(finishedCalled, isTrue);
    });
  });
}
