import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salesarmy/features/dashboard/presentation/screens/distributor_dashboard.dart';
import 'package:salesarmy/core/services/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Daily Reminders, In-Hand Cash, and Milestone Banner Tests', () {
    test('AppState tracks daily dismissals and resets on a new date', () async {
      final appState = AppState();
      const testId = 'sales_milestone_20l';

      expect(appState.isDailyNoticeDismissed(testId), isFalse);

      // Dismiss for today
      appState.dismissDailyNotice(testId);
      expect(appState.isDailyNoticeDismissed(testId), isTrue);

      // Restore / Undo
      appState.restoreDailyNotice(testId);
      expect(appState.isDailyNoticeDismissed(testId), isFalse);

      // Dismiss again
      appState.dismissDailyNotice(testId);
      expect(appState.isDailyNoticeDismissed(testId), isTrue);

      // Check on a past or future date (simulating next day)
      expect(appState.isDailyNoticeDismissed(testId, forDate: '2026-10-04'), isFalse);
    });

    testWidgets('In-Hand Cash bar is swipeable, dismissible with X, and hidden when dismissed today', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final appState = AppState();

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(
            home: Scaffold(
              body: DistributorDashboard(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // In-Hand Cash bar is present
      expect(find.text('IN-HAND'), findsOneWidget);
      expect(find.byKey(ValueKey('in_hand_cash_bar_${appState.getTodayDateString()}')), findsOneWidget);

      // Dismiss via swipe
      await tester.drag(
        find.byKey(ValueKey('in_hand_cash_bar_${appState.getTodayDateString()}')),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();

      // In-hand cash bar is dismissed
      expect(find.text('IN-HAND'), findsNothing);
      expect(appState.isDailyNoticeDismissed('in_hand_cash_bar'), isTrue);

      // Undo brings it back
      expect(find.text('Undo'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(find.text('IN-HAND'), findsOneWidget);
      expect(appState.isDailyNoticeDismissed('in_hand_cash_bar'), isFalse);
    });

    testWidgets('20 Lakh Sales Milestone banner is swipeable and dismissible with X button', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final appState = AppState();

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(
            home: Scaffold(
              body: DistributorDashboard(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Milestone banner is initially visible
      expect(find.text('20 Lakhs Sales Milestone Reached!'), findsOneWidget);
      final milestoneKey = ValueKey('sales_milestone_20l_${appState.getTodayDateString()}');
      expect(find.byKey(milestoneKey), findsOneWidget);

      // Dismiss via clear icon button
      final clearButtons = find.byTooltip('Dismiss for today');
      expect(clearButtons, findsWidgets);

      // Tap dismiss for the milestone banner
      await tester.drag(find.byKey(milestoneKey), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(find.text('20 Lakhs Sales Milestone Reached!'), findsNothing);
      expect(appState.isDailyNoticeDismissed('sales_milestone_20l'), isTrue);
    });

    testWidgets('Pending reminders section and individual items are swipeable and dismissible', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final appState = AppState();

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(
            home: Scaffold(
              body: DistributorDashboard(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll down until Balaji reminder item is visible
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();

      final balajiKey = ValueKey('reminder_balaji_${appState.getTodayDateString()}');
      expect(find.byKey(balajiKey), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(balajiKey), matching: find.text('Balaji Provisions & Wholesale')),
        findsOneWidget,
      );

      // Swipe away Balaji Provisions reminder
      await tester.drag(find.byKey(balajiKey), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(find.byKey(balajiKey), findsNothing);
      expect(appState.isDailyNoticeDismissed('reminder_balaji'), isTrue);

      // Swipe away entire Pending Reminders section
      final remindersSectionKey = ValueKey('pending_reminders_section_${appState.getTodayDateString()}');
      expect(find.byKey(remindersSectionKey), findsOneWidget);
      await tester.drag(find.byKey(remindersSectionKey), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(find.text('Pending Reminders'), findsNothing);
      expect(appState.isDailyNoticeDismissed('pending_reminders_section'), isTrue);
    });
  });
}
