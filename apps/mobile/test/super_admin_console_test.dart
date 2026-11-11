import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/features/admin/presentation/screens/super_admin_console.dart';

void main() {
  Widget consoleApp({required Widget home}) => ChangeNotifierProvider(
    create: (_) => AppState(loadMockData: true),
    child: MaterialApp(home: home),
  );
  testWidgets('SuperAdminConsole renders royal blue header, KPI cards, revenue, and subscribers matching screenshots', (tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    bool exited = false;

    await tester.pumpWidget(
      consoleApp(
        home: Scaffold(
          body: SuperAdminConsole(
            onExitConsole: () => exited = true,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Royal Blue Header Banner (Screenshot 1 & 3)
    expect(find.text('SaaS Super Admin'), findsOneWidget);
    expect(find.text('CONSOLE'), findsOneWidget);
    expect(find.text('SalesArmy SaaS Technologies Pvt Ltd'), findsOneWidget);
    expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    // 2. Navigation Tabs (5 tabs matching Screenshots 1-5)
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Features'), findsOneWidget);
    expect(find.text('Subscriber'), findsOneWidget);
    expect(find.text('Plan'), findsOneWidget);
    expect(find.text('Setting'), findsOneWidget);

    // 3. Top Metrics & KPI Cards (Screenshot 1 & 3)
    expect(find.text('App Download Users'), findsOneWidget);
    expect(find.text('7 Users'), findsOneWidget);
    expect(find.text('+3 new'), findsOneWidget);
    expect(find.text('Registered app accounts'), findsOneWidget);

    expect(find.text('Paid Subscribers'), findsOneWidget);
    expect(find.text('3 Users'), findsOneWidget);
    expect(find.text('ACTIVE'), findsWidgets);
    expect(find.text('42% conversion rate'), findsOneWidget);

    // 4. Total Platform Revenue Card (Screenshot 3)
    expect(find.text('Total Platform Revenue'), findsOneWidget);
    expect(find.text('Lifetime Sales'), findsOneWidget);
    expect(find.text('₹26758'), findsOneWidget);
    expect(find.text('Subscription Sales'), findsOneWidget);
    expect(find.text('₹13180'), findsOneWidget);
    expect(find.text('Hardware (Printers)'), findsOneWidget);
    expect(find.text('₹9497 (3 orders)'), findsOneWidget);
    expect(find.text('GST Collected'), findsOneWidget);
    expect(find.text('₹4081 (18%)'), findsOneWidget);

    // 5. One-Click Report Download Card (Screenshot 3)
    expect(find.text('One-Click Report Download'), findsOneWidget);
    expect(find.text('INSTANT CSV / WA'), findsOneWidget);
    expect(find.text('Payment Details'), findsOneWidget);
    expect(find.text('GST Bills Report'), findsOneWidget);
    expect(find.text('Open Full Export & WhatsApp Hub'), findsOneWidget);

    // 6. Subscriber Base Breakdown (Screenshot 1)
    expect(find.text('Subscriber Base Breakdown'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Paused'), findsOneWidget);
    expect(find.text('Cancelled'), findsOneWidget);
    expect(find.text('Printers'), findsOneWidget);

    // 7. Recent Subscribed Users (Screenshots 1 & 4)
    expect(find.text('Recent Subscribed Users'), findsOneWidget);
    expect(find.text('View All (7)'), findsOneWidget);

    // Rahul Sharma card
    expect(find.text('Rahul Sharma (You)'), findsOneWidget);
    expect(find.text('SUB-2026-001'), findsOneWidget);
    expect(find.text('₹4009'), findsNWidgets(2)); // Rahul Sharma & Suresh Patil
    expect(find.text('15 days left'), findsOneWidget);
    expect(find.text('Printer Ordered'), findsNWidgets(3));

    // Amit Kumar Verma card
    expect(find.text('Amit Kumar Verma'), findsOneWidget);
    expect(find.text('SUB-2026-002'), findsOneWidget);
    expect(find.text('₹13790'), findsOneWidget);
    expect(find.text('305 days left'), findsOneWidget);

    // Suresh Patil card
    expect(find.text('Suresh Patil'), findsOneWidget);
    expect(find.text('SUB-2026-003'), findsOneWidget);
    expect(find.text('PENDING'), findsOneWidget);
    expect(find.text('28 days left'), findsOneWidget);

    // Deepak Joshi card
    expect(find.text('Deepak Joshi'), findsOneWidget);
    expect(find.text('SUB-2026-004'), findsOneWidget);
    expect(find.text('CANCELLED'), findsOneWidget);
    expect(find.text('Free / Unpaid'), findsOneWidget);
    expect(find.text('0 days left'), findsOneWidget);

    // 8. Test Exit Console button
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(exited, isTrue);
  });

  testWidgets('SuperAdminConsole opens Download SaaS Reports modal matching Screenshot 2', (tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      consoleApp(
        home: Scaffold(
          body: SuperAdminConsole(onExitConsole: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap Open Full Export & WhatsApp Hub
    await tester.tap(find.text('Open Full Export & WhatsApp Hub'));
    await tester.pumpAndSettle();

    // Verify modal elements (Screenshot 2)
    expect(find.text('Download SaaS Reports'), findsOneWidget);
    expect(find.text('Export ready-to-use CSV registers and formatted WhatsApp summaries.'), findsOneWidget);
    expect(find.text('1. Subscriber Payments Register'), findsOneWidget);
    expect(find.text('All received fees, gateway IDs, payment modes'), findsOneWidget);
    expect(find.text('CSV'), findsOneWidget);

    expect(find.text('2. SaaS GST Tax Invoices Register'), findsOneWidget);
    expect(find.text('B2B/B2C Tax invoices, SAC 997331 & HSN 8443'), findsOneWidget);
    expect(find.text('GST CSV'), findsOneWidget);

    expect(find.text('3. Share Summary to WhatsApp'), findsOneWidget);
    expect(find.text('Send executive revenue & subscriber briefing'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);

    // Tap CSV button and verify dismiss + feedback snackbar
    await tester.tap(find.text('CSV'));
    await tester.pumpAndSettle();
    expect(find.text('Subscriber Payments Register CSV generated & downloaded!'), findsOneWidget);
  });

  testWidgets('SuperAdminConsole opens Subscriber Details modal matching Screenshot 5', (tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      consoleApp(
        home: Scaffold(
          body: SuperAdminConsole(onExitConsole: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap on Rahul Sharma card
    await tester.tap(find.text('Rahul Sharma (You)'));
    await tester.pumpAndSettle();

    // Verify modal header & copy badge (Screenshot 5)
    expect(find.text('Subscriber Details'), findsOneWidget);
    expect(find.text('SUB-2026-001'), findsWidgets);
    expect(find.text('Sharma FMCG & Grocery Distribution'), findsWidgets);

    // Verify Card 1 Contact Details
    expect(find.text('Contact Name:'), findsOneWidget);
    expect(find.text('+91 98765 43210'), findsOneWidget);
    expect(find.text('rahul@sharmadistributors.in'), findsOneWidget);
    expect(find.text('27AABCS1429E1ZG'), findsOneWidget);
    expect(find.text('Mumbai Central & Suburban'), findsOneWidget);

    // Verify Card 2 Purchased Plan
    expect(find.text('Purchased Plan'), findsOneWidget);
    expect(find.text('Monthly (₹899/mo)'), findsWidgets);
    expect(find.text('20 Aug 2026 to 19 Sep 2026'), findsOneWidget);
    expect(find.text('INV-SAAS-2026-001'), findsOneWidget);
    expect(find.text('RZP_TXN_999827'), findsOneWidget);

    // Verify Card 3 Thermal Printer Hardware
    expect(find.text('Thermal Printer Hardware'), findsOneWidget);
    expect(find.text('PURCHASED (₹2499)'), findsOneWidget);
    expect(find.text('POS-58 Bluetooth Thermal Printer'), findsOneWidget);
    expect(find.text('Delivered (DTDC-99218201)'), findsOneWidget);
    expect(find.text('Shop 14, APMC Market Yard, Pune - 411037'), findsOneWidget);

    // Verify Action buttons
    expect(find.text('Send GST Tax Invoice on WhatsApp'), findsOneWidget);
    expect(find.text('Approv'), findsOneWidget);
    expect(find.text('Pause'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // Verify Account protection controls (Screenshot 1)
    expect(find.text('Subscriber Data & Account Controls'), findsOneWidget);
    expect(find.text('Delete Cash Orders History'), findsOneWidget);
    expect(find.text('Purges cash orders with 1-click ledger download'), findsOneWidget);
    expect(find.text('Reset User Account'), findsOneWidget);
    expect(find.text('Wipes history for new setup with 1-click full backup'), findsOneWidget);

    // Tap WhatsApp Send
    await tester.tap(find.text('Send GST Tax Invoice on WhatsApp'));
    await tester.pumpAndSettle();
    expect(find.text('GST Tax Invoice sent to WhatsApp for +91 98765 43210'), findsOneWidget);
  });

  testWidgets('SuperAdminConsole opens Delete Cash History modal matching Screenshots 4 & 5', (tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      consoleApp(
        home: Scaffold(
          body: SuperAdminConsole(onExitConsole: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap on Rahul Sharma card to open detail modal
    await tester.tap(find.text('Rahul Sharma (You)'));
    await tester.pumpAndSettle();

    // Scroll down modal to reveal action cards and tap Delete Cash Orders History
    await tester.ensureVisible(find.text('Delete Cash Orders History'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete Cash Orders History'));
    await tester.pumpAndSettle();

    // Verify modal header (Screenshots 4 & 5)
    expect(find.text('Delete Cash History'), findsOneWidget);
    expect(find.text('User: Rahul Sharma (You) (SUB-2026-001)'), findsOneWidget);

    // Verify Caution Banner
    expect(find.text('Caution: Irreversible Cash History Purge'), findsOneWidget);
    expect(find.textContaining('permanently delete all order history and payment records received in Cash'), findsOneWidget);

    // Verify Download cards
    expect(find.text('Download Reports Before Deleting (1-Click)'), findsOneWidget);
    expect(find.text('1. All Orders Detailed Report'), findsOneWidget);
    expect(find.text('2. Complete Customer Ledger'), findsOneWidget);

    // Verify Action buttons
    expect(find.text('Copy Ledger'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('Permanently Delete Cash History'), findsOneWidget);
    expect(find.text('Cancel / Keep History'), findsOneWidget);

    // Tap WhatsApp
    await tester.tap(find.text('WhatsApp'));
    await tester.pumpAndSettle();
    expect(find.text('Ledger summary shared to WhatsApp!'), findsOneWidget);

    // Tap Cancel / Keep History to dismiss
    await tester.tap(find.text('Cancel / Keep History'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Cash History'), findsNothing);
  });

  testWidgets('SuperAdminConsole opens Reset User Account modal matching Screenshot 3', (tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      consoleApp(
        home: Scaffold(
          body: SuperAdminConsole(onExitConsole: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap on Rahul Sharma card to open detail modal
    await tester.tap(find.text('Rahul Sharma (You)'));
    await tester.pumpAndSettle();

    // Scroll down modal to reveal action cards and tap Reset User Account
    await tester.ensureVisible(find.text('Reset User Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset User Account'));
    await tester.pumpAndSettle();

    // Verify modal header (Screenshot 3)
    expect(find.text('Reset User Account'), findsWidgets); // Title and button
    expect(find.text('User: Rahul Sharma (You) (SUB-2026-001)'), findsOneWidget);

    // Verify Caution Banner
    expect(find.text('Account Factory Reset & Re-Setup Mode'), findsOneWidget);
    expect(find.textContaining('After reset, all order history, cash/online payments'), findsOneWidget);

    // Verify 3 Download cards
    expect(find.text('Download All Data Before Reset (1-Click)'), findsOneWidget);
    expect(find.text('1. All Orders History (Detailed)'), findsOneWidget);
    expect(find.text('2. Payments (Cash & Online)'), findsOneWidget);
    expect(find.text('3. Bills & GST Tax Invoices'), findsOneWidget);

    // Verify Action buttons
    expect(find.text('Copy Backup'), findsOneWidget);
    expect(find.text('All-In-One ZIP/File'), findsOneWidget);
    expect(find.text('Confirm & Reset User Account'), findsOneWidget);
    expect(find.text('Cancel / Keep Account Intact'), findsOneWidget);

    // Tap All-In-One ZIP/File
    await tester.tap(find.text('All-In-One ZIP/File'));
    await tester.pumpAndSettle();
    expect(find.text('Downloading All-In-One ZIP Backup file...'), findsOneWidget);

    // Tap Cancel / Keep Account Intact to dismiss
    await tester.tap(find.text('Cancel / Keep Account Intact'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm & Reset User Account'), findsNothing);
  });

  testWidgets('SuperAdminConsole switches tabs to Subscriber, Features, and Plans with filter pills', (tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      consoleApp(
        home: Scaffold(
          body: SuperAdminConsole(onExitConsole: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap Features tab (Images 2, 3, 4, 5)
    await tester.tap(find.text('Features'));
    await tester.pumpAndSettle();
    expect(find.text('Third-Party SMS & OTP Provider'), findsOneWidget);
    expect(find.text('LIVE SMS'), findsOneWidget);
    expect(find.text('Payment Gateway Configuration'), findsOneWidget);
    expect(find.text('Company Details for Tax Invoices'), findsOneWidget);

    // Tap Subscriber tab (Screenshot 2)
    await tester.tap(find.text('Subscriber'));
    await tester.pumpAndSettle();
    expect(find.text('Found 7 Subscribers'), findsOneWidget);
    expect(find.text('Tap user card for details & actions'), findsOneWidget);
    expect(find.text('Search by Subscriber ID, Name, Business,'), findsOneWidget);

    // Filter pills present
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Active'), findsWidgets);
    expect(find.text('Pending'), findsWidgets);
    expect(find.text('Paused'), findsWidgets);
    expect(find.text('Cancelled'), findsWidgets);

    // Filter by Pending using key (2 pending: Suresh Patil and Vikram Malhotra)
    await tester.tap(find.byKey(const ValueKey('filter_pill_pending')));
    await tester.pumpAndSettle();
    expect(find.text('Found 2 Subscribers'), findsOneWidget);
    expect(find.text('Suresh Patil'), findsOneWidget);
    expect(find.text('Vikram Malhotra'), findsOneWidget);
    expect(find.text('Amit Kumar Verma'), findsNothing);

    // Reset to All using key
    await tester.tap(find.byKey(const ValueKey('filter_pill_all')));
    await tester.pumpAndSettle();
    expect(find.text('Found 7 Subscribers'), findsOneWidget);
    expect(find.text('Amit Kumar Verma'), findsOneWidget);

    // Tap Plan tab (Screenshots 2, 3, 4)
    await tester.tap(find.text('Plan'));
    await tester.pumpAndSettle();
    expect(find.text('SaaS Subscription Plans'), findsOneWidget);
    expect(find.text('Monthly Plan'), findsOneWidget);
    expect(find.text('Annual Pro (Save 33%)'), findsOneWidget);
    expect(find.text('Hardware & Printer Management'), findsOneWidget);
    expect(find.text('Add Printer'), findsOneWidget);
    expect(find.text('Promo Coupons & Demo Passes'), findsOneWidget);

    // Tap Setting tab (Tab 5)
    await tester.tap(find.text('Setting'));
    await tester.pumpAndSettle();
    expect(find.text('SaaS Platform & Security Settings'), findsOneWidget);
    expect(find.text('Platform Maintenance Mode'), findsOneWidget);
  });

  testWidgets('SuperAdminConsole Plan tab renders Card 1, Card 2, Card 3 matching Screenshots 2, 3, 4', (tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      consoleApp(
        home: Scaffold(
          body: SuperAdminConsole(onExitConsole: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Switch to Plan tab
    await tester.tap(find.text('Plan'));
    await tester.pumpAndSettle();

    // 1. Card 1: SaaS Subscription Plans (Screenshot 2)
    expect(find.text('SaaS Subscription Plans'), findsOneWidget);
    expect(find.text('Edit Pricing'), findsOneWidget);
    expect(find.text('Monthly Plan'), findsOneWidget);
    expect(find.text('₹899/mo'), findsOneWidget);
    expect(find.text('Billed monthly'), findsOneWidget);
    expect(find.text('Annual Pro (Save 33%)'), findsOneWidget);
    expect(find.text('₹599/mo'), findsOneWidget);
    expect(find.text('₹7188 / yr (599×12)'), findsOneWidget);
    expect(find.text('+18% GST'), findsWidgets);

    // The hardware card is populated from the shared checkout catalog.
    expect(find.text('Hardware & Printer Management'), findsOneWidget);
    expect(find.text('Add Printer'), findsOneWidget);
    expect(find.text('Add Hardware Pack'), findsOneWidget);
    final state = tester.element(find.byType(SuperAdminConsole)).read<AppState>();
    for (final printer in state.printerOptions) {
      expect(find.text(printer.name), findsOneWidget);
      expect(find.text('₹${printer.price.toInt()} + ${printer.gstRate.toInt()}% GST • ${printer.connectivity}'), findsOneWidget);
    }

    // 3. Card 3: Promo Coupons & Demo Passes (Screenshot 4)
    expect(find.text('Promo Coupons & Demo Passes'), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
    expect(find.text('DEMO1DAY'), findsOneWidget);
    expect(find.text('1 Day Free Full App Demo Access'), findsOneWidget);
    expect(find.text('FREE1WEEK'), findsOneWidget);
    expect(find.text('1 Week (7 Days) Free Full App Demo Access'), findsOneWidget);
    expect(find.text('DEMO1MONTH'), findsOneWidget);
    expect(find.text('1 Month (30 Days) Free Full App Demo Access'), findsOneWidget);
    expect(find.text('FREE100'), findsOneWidget);
    expect(find.text('100% Off Lifetime Fee Waiver'), findsOneWidget);
    expect(find.text('SAVE50'), findsOneWidget);
    expect(find.text('50% Off Subscription'), findsOneWidget);
  });

  testWidgets('SuperAdminConsole opens Edit SaaS & Printer Pricing modal, recalculates annual, and saves pricing matching Screenshot 5', (tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      consoleApp(
        home: Scaffold(
          body: SuperAdminConsole(onExitConsole: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Switch to Plan tab
    await tester.tap(find.text('Plan'));
    await tester.pumpAndSettle();

    // Tap Edit Pricing button
    await tester.tap(find.text('Edit Pricing'));
    await tester.pumpAndSettle();

    // Verify Modal Contents (Screenshot 5)
    expect(find.text('Edit SaaS & Printer Pricing'), findsOneWidget);
    expect(find.text('1. Subscription Plans (₹ / month)'), findsOneWidget);
    expect(find.text('Monthly (₹)'), findsOneWidget);
    expect(find.text('Annual (₹/mo)'), findsOneWidget);
    expect(find.text('Yr: ₹7188'), findsOneWidget);
    expect(find.text('Plan GST Rate (%)'), findsOneWidget);

    expect(find.text('2. Thermal Bluetooth Printer (58mm)'), findsOneWidget);
    expect(find.text('Printer Price (₹)'), findsOneWidget);
    expect(find.text('Printer GST (%)'), findsOneWidget);

    expect(find.text('Apply GST Tax on Invoices'), findsOneWidget);
    expect(find.text('Save All Pricing & Tax Rates'), findsOneWidget);

    // Change annual price to 499 using Key
    final annualFinder = find.byKey(const ValueKey('pricing_annual_input'));
    await tester.enterText(annualFinder, '499');
    await tester.pumpAndSettle();
    expect(find.text('Yr: ₹5988'), findsOneWidget);

    // Tap Save All Pricing & Tax Rates
    await tester.tap(find.byKey(const ValueKey('pricing_save_btn')));
    await tester.pumpAndSettle();

    // Verify snackbar feedback and updated price on card
    expect(find.text('All pricing and tax rates updated successfully!'), findsOneWidget);
    expect(find.text('₹499/mo'), findsOneWidget);
    expect(find.text('₹5988 / yr (499×12)'), findsOneWidget);
  });

  testWidgets('SuperAdminConsole pauses and deletes coupons, and creates new coupon', (tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      consoleApp(
        home: Scaffold(
          body: SuperAdminConsole(onExitConsole: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Switch to Plan tab
    await tester.tap(find.text('Plan'));
    await tester.pumpAndSettle();

    // Tap pause button for DEMO1DAY
    await tester.ensureVisible(find.byTooltip('Pause Coupon').first);
    await tester.tap(find.byTooltip('Pause Coupon').first);
    await tester.pumpAndSettle();
    expect(find.text('Coupon DEMO1DAY is now paused.'), findsOneWidget);
    expect(find.text('PAUSED'), findsOneWidget);

    // Tap delete button for DEMO1DAY
    await tester.ensureVisible(find.byTooltip('Delete Coupon').first);
    await tester.tap(find.byTooltip('Delete Coupon').first);
    await tester.pumpAndSettle();
    expect(find.text('Coupon DEMO1DAY deleted permanently.'), findsOneWidget);
    expect(find.text('DEMO1DAY'), findsNothing);

    // Tap New button to add coupon (Image 1)
    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();
    expect(find.text('Create Promo Coupon'), findsOneWidget);
    expect(find.text('Choose coupon benefit type'), findsOneWidget);
    expect(find.text('Select Coupon Type'), findsOneWidget);
    expect(find.text('Free Duration'), findsOneWidget);
    expect(find.byKey(const ValueKey('coupon_type_trial')), findsOneWidget);

    // Tap 14 Days preset
    await tester.tap(find.text('14 Days'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('coupon_code_input')), 'DIWALI90');
    await tester.enterText(find.byKey(const ValueKey('coupon_desc_input')), '90% Off Festive');
    await tester.tap(find.byKey(const ValueKey('coupon_type_trial')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Percentage discount').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Discount percent'), '90');
    await tester.tap(find.byKey(const ValueKey('coupon_create_btn')));
    await tester.pumpAndSettle();

    expect(find.text('Coupon DIWALI90 created successfully!'), findsOneWidget);
    expect(find.text('DIWALI90'), findsOneWidget);
    expect(find.text('90% Off Festive'), findsOneWidget);
    final coupon = tester.element(find.byType(SuperAdminConsole)).read<AppState>().findCoupon('DIWALI90');
    expect(coupon?.type.name, 'percentage');
    expect(coupon?.value, 90);
  });

  testWidgets('SuperAdminConsole Setting tab allows toggling maintenance mode and triggering backup', (tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      consoleApp(
        home: Scaffold(
          body: SuperAdminConsole(onExitConsole: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Switch to Setting tab
    await tester.tap(find.text('Setting'));
    await tester.pumpAndSettle();

    expect(find.text('SaaS Platform & Security Settings'), findsOneWidget);
    expect(find.text('Platform Maintenance Mode'), findsOneWidget);
    expect(find.text('Super Admin Security & Passcode'), findsOneWidget);
    expect(find.text('Cloud Database Backup Schedule'), findsOneWidget);

    // Toggle Maintenance Mode switch
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(find.text('Maintenance mode ENABLED.'), findsOneWidget);

    // Tap Trigger Instant Backup Now
    await tester.ensureVisible(find.text('Trigger Instant Backup Now'));
    await tester.tap(find.text('Trigger Instant Backup Now'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Backup failed:'), findsOneWidget);
    expect(find.textContaining('platform server URL is not configured'), findsOneWidget);
    expect(find.text('Database snapshot saved and verified on the platform server.'), findsNothing);

    // Card 4: Super Admin Session & Logout
    expect(find.text('Super Admin Session & Logout'), findsOneWidget);
    expect(find.text('End administrative session and securely sign out to the login screen.'), findsOneWidget);
    expect(find.text('Logout from Super Admin Console'), findsOneWidget);

    // Tap Logout button and verify confirmation dialog
    await tester.ensureVisible(find.text('Logout from Super Admin Console'));
    await tester.tap(find.text('Logout from Super Admin Console'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm Logout'), findsOneWidget);
    expect(find.text('Are you sure you want to log out of the Super Admin Console? Your current session will be closed.'), findsOneWidget);

    // Cancel logout
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm Logout'), findsNothing);
  });

  testWidgets('SuperAdminConsole Delete Cash History modal Copy Ledger button copies to clipboard', (tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SuperAdminConsole(onExitConsole: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rahul Sharma (You)'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Delete Cash Orders History'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete Cash Orders History'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Copy Ledger'));
    await tester.pumpAndSettle();
    expect(find.text('Customer ledger copied to clipboard!'), findsOneWidget);
  });

  testWidgets('SuperAdminConsole Reset User Account modal Copy Backup button copies to clipboard', (tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SuperAdminConsole(onExitConsole: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rahul Sharma (You)'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Reset User Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset User Account'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Copy Backup'));
    await tester.pumpAndSettle();
    expect(find.text('Backup summary copied to clipboard!'), findsOneWidget);
  });

  testWidgets('SuperAdminConsole Features tab renders SMS, Payment Gateway, and Company Details cards with interactive controls', (tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SuperAdminConsole(onExitConsole: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Switch to Features tab
    await tester.tap(find.text('Features'));
    await tester.pumpAndSettle();

    // 1. CARD 1: SMS & OTP Provider
    expect(find.text('Third-Party SMS & OTP Provider'), findsOneWidget);
    expect(find.text('LIVE SMS'), findsOneWidget);
    expect(find.text('Enforce Mobile OTP Verification'), findsOneWidget);
    expect(find.text('Select SMS Gateway Provider'), findsOneWidget);
    expect(find.text('Fast2SMS'), findsOneWidget);
    expect(find.text('MSG91'), findsOneWidget);
    expect(find.text('Twilio'), findsOneWidget);
    expect(find.text('Textlocal'), findsOneWidget);

    // Switch provider to MSG91
    await tester.tap(find.text('MSG91'));
    await tester.pumpAndSettle();
    expect(find.text('MSG91 API Key / Auth Token'), findsOneWidget);

    // Toggle Gateway Mode to Sandbox / Test
    await tester.tap(find.text('Sandbox / Test'));
    await tester.pumpAndSettle();

    // Tap Test SMS button
    await tester.ensureVisible(find.byKey(const ValueKey('sms_test_btn')));
    await tester.tap(find.byKey(const ValueKey('sms_test_btn')));
    await tester.pumpAndSettle();
    expect(find.text('Test OTP SMS successfully triggered! (Status: 200 OK)'), findsOneWidget);

    // Tap Save SMS Setup button
    await tester.ensureVisible(find.byKey(const ValueKey('sms_save_btn')));
    await tester.tap(find.byKey(const ValueKey('sms_save_btn')));
    await tester.pumpAndSettle();
    expect(find.text('SMS & DLT Gateway configuration saved successfully!'), findsOneWidget);

    // 2. CARD 2: Payment Gateway Configuration
    expect(find.text('Payment Gateway Configuration'), findsOneWidget);
    expect(find.text('Select Gateway Provider'), findsOneWidget);
    expect(find.text('Razorpay'), findsOneWidget);
    expect(find.text('Cashfree'), findsOneWidget);
    expect(find.text('PhonePe'), findsOneWidget);
    expect(find.text('Direct UPI'), findsOneWidget);
    expect(find.text('Live Production Mode (Real Payments)'), findsOneWidget);

    // Toggle Payment Mode switch
    await tester.ensureVisible(find.byKey(const ValueKey('payment_mode_switch')));
    await tester.tap(find.byKey(const ValueKey('payment_mode_switch')));
    await tester.pumpAndSettle();
    expect(find.text('Sandbox / Test Mode'), findsOneWidget);

    // 3. CARD 3: Company Details for Tax Invoices
    expect(find.text('Company Details for Tax Invoices'), findsOneWidget);
    expect(find.text('SaaS Company Legal Name'), findsOneWidget);
    expect(find.text('Admin Company GSTIN (15 Digits)'), findsOneWidget);
    expect(find.text('Bank Name'), findsOneWidget);
    expect(find.text('IFSC Code'), findsOneWidget);
    expect(find.text('Current Bank Account Number'), findsOneWidget);

    // Tap Save Gateway Setup button
    await tester.ensureVisible(find.byKey(const ValueKey('gateway_save_btn')));
    await tester.tap(find.byKey(const ValueKey('gateway_save_btn')));
    await tester.pumpAndSettle();
    expect(find.text('Payment Gateway & Tax Invoice Company Details saved!'), findsOneWidget);
  });

  testWidgets('SuperAdminConsole Logout Option in Setting tab triggers onSignOut when confirmed', (tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    bool signedOut = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SuperAdminConsole(
            onExitConsole: () {},
            onSignOut: () {
              signedOut = true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Switch to Setting tab
    await tester.tap(find.text('Setting'));
    await tester.pumpAndSettle();

    // Scroll to Logout button and tap
    await tester.ensureVisible(find.text('Logout from Super Admin Console'));
    await tester.tap(find.text('Logout from Super Admin Console'));
    await tester.pumpAndSettle();

    // Verify dialog opened
    expect(find.text('Confirm Logout'), findsOneWidget);

    // Tap Log Out button in dialog
    await tester.tap(find.widgetWithText(ElevatedButton, 'Log Out'));
    await tester.pumpAndSettle();

    // Verify onSignOut was called
    expect(signedOut, isTrue);
  });

  testWidgets('SuperAdminConsole Features tab renders Remote Feature Kill Switches card and toggles live modules', (tester) async {
    tester.view.physicalSize = const Size(1280, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final appState = AppState();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(
          home: Scaffold(
            body: SuperAdminConsole(
              onExitConsole: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Switch to Features tab
    await tester.tap(find.text('Features'));
    await tester.pumpAndSettle();

    // Ensure Card 4: Remote Feature Kill Switches is visible
    final cardTitleFinder = find.text('Remote Feature Kill Switches');
    await tester.ensureVisible(cardTitleFinder);
    await tester.pumpAndSettle();

    expect(cardTitleFinder, findsOneWidget);
    expect(find.text('Order Booking & Cart Checkout'), findsOneWidget);
    expect(find.text('58mm/80mm Thermal Receipt Printing'), findsOneWidget);

    // Toggle thermal_printer switch off
    final thermalSwitch = find.byKey(const ValueKey('feature_switch_thermal_printer'));
    await tester.ensureVisible(thermalSwitch);
    await tester.tap(thermalSwitch);
    await tester.pumpAndSettle();

    // Verify AppState was updated
    expect(appState.isFeatureEnabledRemotely('thermal_printer'), isFalse);
    expect(appState.isModuleRemotelyDisabled('thermal_printer'), isTrue);
  });
}

