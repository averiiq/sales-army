import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/features/profile/presentation/screens/profile_screen.dart';
import 'package:salesarmy/features/settings/presentation/screens/settings_screen.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  Widget createTestWidget({required Widget child, AppState? state}) {
    final appState = state ?? AppState();
    return ChangeNotifierProvider<AppState>.value(
      value: appState,
      child: MaterialApp(
        home: child,
      ),
    );
  }

  testWidgets('ProfileAndSettingsScreen renders single-page Blinkit-style account screen without tabs', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final appState = AppState();

    await tester.pumpWidget(
      createTestWidget(
        child: const ProfileAndSettingsScreen(),
        state: appState,
      ),
    );
    await tester.pumpAndSettle();

    // 1. App Bar and Headline
    expect(find.text('My Business'), findsWidgets);
    expect(find.text(appState.tenant.firmName ?? 'SalesArmy Agency'), findsOneWidget);
    expect(find.text('Save'), findsNothing);

    // 2. Quick Action Cards (Home, Sales, Orders)
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Sales'), findsWidgets);
    expect(find.text('Orders'), findsWidgets);

    // 3. "My Business" Section
    expect(find.text('Profile & Business Details'), findsOneWidget);
    expect(find.text('Export Reports & Statements'), findsOneWidget);
    expect(find.text('Have a Sales Advisor Plan and Subscription'), findsOneWidget);

    // 4. "Banking and GST" Section
    expect(find.text('Banking and GST'), findsOneWidget);
    expect(find.text('Bank Details'), findsOneWidget);
    expect(find.text('Payment & Preferences'), findsOneWidget);
    expect(find.text('GST Details'), findsOneWidget);

    // 5. "Hardware" Section
    expect(find.text('Hardware'), findsOneWidget);
    expect(find.text('Printer'), findsOneWidget);

    // 6. "Staff & Team" Section
    expect(find.text('Staff & Team'), findsOneWidget);
    expect(find.text('Staff'), findsOneWidget);

    // 7. "App Preferences" Section (Strictly Notification, Reminder, and Backup)
    expect(find.text('App Preferences'), findsOneWidget);
    expect(find.text('Notification'), findsOneWidget);
    expect(find.text('Reminders'), findsOneWidget);
    expect(find.text('Backup & Cloud Sync'), findsOneWidget);
    expect(find.text('Sync Now'), findsOneWidget);

    // 8. "Support & Account" Section
    expect(find.text('Support & Account'), findsOneWidget);
    expect(find.text('Help & Support'), findsOneWidget);
    expect(find.text('Delete Account'), findsOneWidget);
    expect(find.text('Reset Account Data'), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);

    // 9. "Feedback for Us" Section
    expect(find.text('Feedback for Us'), findsOneWidget);
    expect(find.text('Share Your Feedback'), findsOneWidget);
  });

  testWidgets('Interactive modals: Plan, Support, Company Profile, and GST Details', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    int? navigatedTab;

    await tester.pumpWidget(
      createTestWidget(
        child: ProfileAndSettingsScreen(
          onNavigateToTab: (tabIdx) => navigatedTab = tabIdx,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Test quick action navigation callbacks: Home, Sales, Orders
    await tester.tap(find.text('Sales').first);
    await tester.pumpAndSettle();
    expect(navigatedTab, 2);

    await tester.tap(find.text('Home').first);
    await tester.pumpAndSettle();
    expect(navigatedTab, 0);

    await tester.tap(find.text('Orders').first);
    await tester.pumpAndSettle();
    expect(navigatedTab, 3);

    // Re-render screen for further tests
    await tester.pumpWidget(
      createTestWidget(
        child: const ProfileAndSettingsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // 2. Test Plan & Subscription modal / screen
    await tester.tap(find.text('Have a Sales Advisor Plan and Subscription').first);
    await tester.pumpAndSettle();
    expect(find.text('Plan & Subscription'), findsOneWidget);
    expect(find.text('CURRENT ACTIVE PLAN'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    // 3. Test Help & Support modal
    await tester.tap(find.text('Help & Support'));
    await tester.pumpAndSettle();
    expect(find.text('Help & Support Desk'), findsOneWidget);
    expect(find.text('WhatsApp Support'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    // 4. Test Unified Profile modal
    await tester.tap(find.text('Profile & Business Details'));
    await tester.pumpAndSettle();
    expect(find.text('UNIQUE USER ID / CUSTOMER ID'), findsOneWidget);
    expect(find.text('SA-USR-8821'), findsWidgets);
    expect(find.text('Company / Firm Name'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    // 5. Test GST Details modal
    await tester.tap(find.text('GST Details'));
    await tester.pumpAndSettle();
    expect(find.text('GSTIN (15-Digit Number)'), findsOneWidget);
    expect(find.text('PAN Number'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
  });

  testWidgets('Backwards compatibility: ProfileScreen and SettingsScreen wrappers render unified screen', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final appState = AppState();

    // Test ProfileScreen wrapper
    await tester.pumpWidget(
      createTestWidget(
        child: const ProfileScreen(),
        state: appState,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('My Business'), findsWidgets);
    expect(find.text(appState.tenant.firmName ?? 'SalesArmy Agency'), findsWidgets);

    // Test SettingsScreen wrapper
    await tester.pumpWidget(
      createTestWidget(
        child: const SettingsScreen(),
        state: appState,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('My Business'), findsWidgets);
    expect(find.text(appState.tenant.firmName ?? 'SalesArmy Agency'), findsWidgets);
    expect(find.text('Printer'), findsOneWidget);
  });

  testWidgets('Banking & Hardware contains Payment & Preferences and Printer', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      createTestWidget(
        child: const ProfileAndSettingsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify Payment & Preferences exists under Banking & Hardware
    expect(find.text('Payment & Preferences'), findsOneWidget);
    expect(find.text('UPI QR code, soundbox & payment gateways'), findsOneWidget);

    // Tap "Payment & Preferences"
    await tester.tap(find.text('Payment & Preferences'));
    await tester.pumpAndSettle();

    // Verify Payment & Preferences modal opens with UPI QR and Gateway, but NO Printer
    expect(find.text('Payment & Preferences'), findsWidgets); // Header + row
    expect(find.text('UPI QR'), findsOneWidget);
    expect(find.text('Gateway'), findsOneWidget);
    expect(find.text('Thermal Printer Settings'), findsNothing);

    // Close Payment & Preferences modal
    await tester.tap(find.byIcon(Icons.close_rounded).last);
    await tester.pumpAndSettle();

    // 2. Verify Printer under Banking & Hardware
    expect(find.text('Printer'), findsOneWidget);
    expect(find.text('ESC/POS 58mm & 80mm wireless receipt printing'), findsOneWidget);

    // Tap "Printer"
    await tester.tap(find.text('Printer'));
    await tester.pumpAndSettle();

    // Verify Printer modal opens with Thermal Printer Settings and NO UPI QR or Gateway tabs
    expect(find.text('Thermal Printer Settings'), findsOneWidget);
    expect(find.text('UPI QR'), findsNothing);
    expect(find.text('Gateway'), findsNothing);

    // Close Printer modal
    await tester.tap(find.byIcon(Icons.close_rounded).last);
    await tester.pumpAndSettle();
  });
}

