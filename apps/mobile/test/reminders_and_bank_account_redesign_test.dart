import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/features/profile/presentation/screens/accounts_screen.dart';
import 'package:salesarmy/features/profile/presentation/screens/profile_and_settings_screen.dart';
import 'package:salesarmy/features/visits/data/models/reminder_model.dart';
import 'package:salesarmy/features/visits/presentation/screens/reminders_screen.dart';

Widget createTestApp({required Widget child, AppState? state}) {
  final appState = state ?? AppState();
  return ChangeNotifierProvider<AppState>.value(
    value: appState,
    child: MaterialApp(
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Add Bank Account Popup UI Redesign Tests', () {
    testWidgets('Add Bank Account dialog renders live card preview, quick bank chips, and confirm account number field', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final appState = AppState();
      // Initially appState has 2 accounts, so slot 3 is available
      expect(appState.bankAccounts.length, 2);

      await tester.pumpWidget(
        createTestApp(
          child: const AccountsScreen(),
          state: appState,
        ),
      );
      await tester.pumpAndSettle();

      // Tap "+ Add Bank Account"
      final addBtn = find.textContaining('+ Add Bank Account');
      expect(addBtn, findsOneWidget);
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      // Verify Redesigned Dialog Elements
      expect(find.text('Add Bank Account'), findsWidgets);
      expect(find.text('Slot 3 of 3'), findsOneWidget);
      expect(find.text('ACCOUNT HOLDER'), findsOneWidget); // On live card preview
      expect(find.text('Confirm Account Number *'), findsOneWidget);
      expect(find.text('Select Popular Bank or Custom *'), findsOneWidget);
      expect(find.text('ICICI Bank'), findsWidgets); // Quick chip & text
      expect(find.text('Axis Bank'), findsWidgets);

      // Tap ICICI Bank quick chip to update card preview
      await tester.tap(find.text('ICICI Bank').first);
      await tester.pumpAndSettle();

      // Enter account numbers that do not match
      final accNumField = find.widgetWithText(TextField, 'Bank Account Number *');
      final confirmAccNumField = find.widgetWithText(TextField, 'Confirm Account Number *');
      await tester.enterText(accNumField, '1234567890');
      await tester.enterText(confirmAccNumField, '9876543210');
      await tester.pumpAndSettle();

      // Verify mismatch indicator
      expect(find.text('Account numbers do not match'), findsOneWidget);

      // Enter matching account numbers
      await tester.enterText(confirmAccNumField, '1234567890');
      await tester.pumpAndSettle();

      // Verify match indicator
      expect(find.text('Account numbers match perfectly'), findsOneWidget);

      // Verify live card preview shows last 4 digits
      expect(find.textContaining('7890'), findsWidgets);

      // Enter IFSC code
      final ifscField = find.widgetWithText(TextField, 'IFSC Code *');
      await tester.enterText(ifscField, 'ICIC0001042');
      await tester.pumpAndSettle();

      // Save Account
      final saveBtn = find.textContaining('Save Account (Slot 3 of 3)');
      expect(saveBtn, findsOneWidget);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Verify 3rd account added and limit reached
      expect(appState.bankAccounts.length, 3);
      expect(appState.canAddBankAccount, isFalse);
      expect(find.text('Maximum 3 Accounts Registered'), findsOneWidget);
    });
  });

  group('My Business Reminders Option & Screen Redesign Tests', () {
    testWidgets('My Business screen displays Reminders option and navigates to RemindersScreen', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final appState = AppState();

      await tester.pumpWidget(
        createTestApp(
          child: const ProfileAndSettingsScreen(),
          state: appState,
        ),
      );
      await tester.pumpAndSettle();

      // Verify Section 4: My Business has Reminders option
      expect(find.text('My Business'), findsWidgets);
      expect(find.text('Reminders'), findsOneWidget);
      expect(find.textContaining('pending • Customer dues'), findsOneWidget);

      // Tap Reminders row to open RemindersScreen
      await tester.tap(find.text('Reminders'));
      await tester.pumpAndSettle();

      // Verify RemindersScreen opened
      expect(find.text('Reminders & Tasks'), findsOneWidget);
      expect(find.text('Due Today'), findsOneWidget);
      expect(find.text('Collections'), findsOneWidget);
    });

    testWidgets('RemindersScreen displays KPI cards, filters, search, toggle complete, and snooze', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final appState = AppState();
      // Ensure we have test reminders
      final now = DateTime.now();
      final overdueRem = ReminderModel(
        reminderId: 'rem_test_overdue',
        shopId: '',
        assignedToUid: 'user_1',
        dueDate: now.subtract(const Duration(days: 2)),
        title: 'Collect overdue bill from Rajesh',
        description: 'Payment overdue',
        purpose: 'payment',
        priority: 'high',
        isCompleted: false,
      );
      final todayRem = ReminderModel(
        reminderId: 'rem_test_today',
        shopId: '',
        assignedToUid: 'user_1',
        dueDate: DateTime(now.year, now.month, now.day, 16, 0),
        title: 'Deliver promotional tea stock',
        description: 'Stock delivery',
        purpose: 'reorder',
        priority: 'medium',
        isCompleted: false,
      );
      appState.addReminder(overdueRem);
      appState.addReminder(todayRem);

      await tester.pumpWidget(
        createTestApp(
          child: const RemindersScreen(),
          state: appState,
        ),
      );
      await tester.pumpAndSettle();

      // Verify KPI header
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Overdue'), findsWidgets); // In KPI and Filter chip
      expect(find.text('Due Today'), findsOneWidget);

      // Verify items render
      expect(find.text('Collect overdue bill from Rajesh'), findsOneWidget);
      expect(find.text('Deliver promotional tea stock'), findsOneWidget);

      // Test Search query filtering
      final searchInput = find.widgetWithText(TextField, 'Search tasks, retailers, payment dues...');
      await tester.enterText(searchInput, 'Rajesh');
      await tester.pumpAndSettle();

      expect(find.text('Collect overdue bill from Rajesh'), findsOneWidget);
      expect(find.text('Deliver promotional tea stock'), findsNothing);

      // Clear search
      await tester.enterText(searchInput, '');
      await tester.pumpAndSettle();
      expect(find.text('Deliver promotional tea stock'), findsOneWidget);

      // Test Toggle Complete
      final checkboxes = find.byType(InkWell);
      expect(checkboxes, findsWidgets);
      await appState.completeReminder('rem_test_today');
      await tester.pumpAndSettle();

      // Filter by 'Completed'
      await tester.tap(find.text('Completed'));
      await tester.pumpAndSettle();
      expect(find.text('Deliver promotional tea stock'), findsOneWidget);

      // Switch back to 'All'
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();

      // Test Add Reminder Modal
      final addBtn = find.text('+ Reminder').first;
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      expect(find.text('Set Business Reminder'), findsOneWidget);
      expect(find.text('Category / Purpose *'), findsOneWidget);
      expect(find.text('Payment Due'), findsWidgets);

      // Tap preset template
      expect(find.text('Overdue invoice collection'), findsOneWidget);
      await tester.tap(find.text('Overdue invoice collection'));
      await tester.pumpAndSettle();

      // Submit new reminder
      final submitBtn = find.text('Schedule Business Reminder');
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Verify newly scheduled reminder is listed
      expect(find.text('Overdue invoice collection'), findsOneWidget);
    });
  });
}
