import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/features/dashboard/presentation/screens/distributor_dashboard.dart';
import 'package:salesarmy/features/profile/presentation/screens/profile_and_settings_screen.dart';
import 'package:salesarmy/features/shops/presentation/screens/create_shop_screen.dart';
import 'package:salesarmy/features/inventory/presentation/screens/inventory_tab.dart';
import 'package:salesarmy/features/orders/presentation/screens/order_taker_flow.dart';
import 'package:salesarmy/features/billing/presentation/screens/reports_screen.dart';
import 'package:salesarmy/features/collections/presentation/dialogs/ledger_report_modal.dart';

void main() {
  group('Verification of 8 User Requirements', () {
    // 1. Inhand Cash option on Dashboard Upper Left
    testWidgets('1. Inhand Cash is displayed prominently in dashboard upper left bar', (tester) async {
      final appState = AppState(loadMockData: true);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(
            home: DistributorDashboard(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check for In-Hand Cash card & Update button
      expect(find.text('IN-HAND CASH'), findsWidgets);
      expect(find.text('₹18,450'), findsWidgets);
      expect(find.text('Update'), findsWidgets);
    });

    // 2. Expenses option in Profile
    testWidgets('2. Expenses option is present in Profile & Settings', (tester) async {
      final appState = AppState(loadMockData: true);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(
            home: ProfileAndSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check for Expense in quick actions and settings list
      expect(find.text('Expense'), findsWidgets);
      expect(find.text('Daily operational expenses & receipts'), findsOneWidget);
    });

    // 3. Reports screen provides download options for Khata, Orders, and GST
    testWidgets('3. Reports screen provides download options for Khata, Orders, and GST', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final appState = AppState(loadMockData: true);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(
            home: ReportsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Statements & Exports tab
      await tester.tap(find.text('Statements & Exports'));
      await tester.pumpAndSettle();

      // Check for report titles and download buttons
      expect(find.text('Khata Ledger & Accounts Statement'), findsOneWidget);
      expect(find.text('Orders & Sales Register'), findsOneWidget);
      expect(find.text('Inventory & Stock Valuation Report'), findsOneWidget);
      expect(find.text('GST Tax Liability Summary'), findsOneWidget);

      // Verify direct 1-tap download buttons on cards (4 report cards: Khata, Orders, Inventory, GST/Sales)
      expect(find.text('Download CSV'), findsNWidgets(4));
      expect(find.text('Share via WA'), findsNWidgets(4));
    });

    // 4. All pages, no popups (CreateShopScreen, LedgerReportScreen, GstTaxSummaryScreen)
    testWidgets('4. Reports and Shop Create open as full-screen Scaffold pages', (tester) async {
      final appState = AppState(loadMockData: true);

      // Verify LedgerReportScreen is a full Scaffold page
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(
            home: LedgerReportScreen(initialIsKhata: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.text('Download Ledger & Khata'), findsOneWidget);

      // Verify GstTaxSummaryScreen is a full Scaffold page
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(
            home: GstTaxSummaryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.text('GST Tax Liability Statement'), findsOneWidget);
    });

    // 5. New Shop Create Photo Upload & Preview
    testWidgets('5. CreateShopScreen has camera/gallery photo upload and preview', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final appState = AppState(loadMockData: true);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(
            home: CreateShopScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Register New Party'), findsOneWidget);
      expect(find.text('Camera'), findsOneWidget);
      expect(find.text('Gallery'), findsOneWidget);
      expect(find.text('+ Paste Image URL'), findsOneWidget);
      expect(find.text('Or Select Category Storefront Preset:'), findsOneWidget);
      expect(find.text('Kirana'), findsWidgets);
    });

    // 6. Dark theme option
    testWidgets('6. Dark theme toggle updates AppState themeMode', (tester) async {
      final appState = AppState(loadMockData: true);
      expect(appState.isDarkMode, false);

      appState.toggleTheme();
      expect(appState.isDarkMode, true);
      expect(appState.themeMode, ThemeMode.dark);

      appState.toggleTheme();
      expect(appState.isDarkMode, false);
      expect(appState.themeMode, ThemeMode.light);
    });

    // 7. Inventory Round Product Add Button
    testWidgets('7. InventoryTab has a circular FloatingActionButton with + icon', (tester) async {
      final appState = AppState(loadMockData: true);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(
            home: Scaffold(
              body: InventoryTab(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final fabFinder = find.byType(FloatingActionButton);
      expect(fabFinder, findsOneWidget);

      final fab = tester.widget<FloatingActionButton>(fabFinder);
      expect(fab.shape, isA<CircleBorder>());
      expect(find.descendant(of: fabFinder, matching: find.byIcon(Icons.add_rounded)), findsOneWidget);
    });

    // 8. Product Variant Modal in Order Flow (e.g. 5kg vs 10kg Atta)
    testWidgets('8. OrderTakerFlow opens variant & quantity selector with 5kg / 10kg options', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final appState = AppState(loadMockData: true);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp(
            home: OrderTakerFlow(
              initialShop: appState.shops.first,
              onOrderCompleted: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the specific Atta product name in the catalog
      final attaFinder = find.text('Aashirvaad Shudh Chakki Atta');
      expect(attaFinder, findsOneWidget);

      // Tap the Atta card
      await tester.tap(attaFinder);
      await tester.pumpAndSettle();

      // Check variant modal title and options
      expect(find.text('Choose variant size & order quantity'), findsOneWidget);
      expect(find.text('SELECT SIZE / VARIANT'), findsOneWidget);
      expect(find.textContaining('5 Kg'), findsWidgets);
      expect(find.textContaining('10 Kg'), findsWidgets);
      expect(find.text('Confirm & Add to Order'), findsOneWidget);
    });

    testWidgets('9. Order page Add button is circular (shape: BoxShape.circle)', (tester) async {
      final appState = AppState(loadMockData: true);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp(
            home: OrderTakerFlow(
              initialShop: appState.shops.first,
              onOrderCompleted: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the circular Add button (Icons.add_rounded)
      final addIconFinder = find.byIcon(Icons.add_rounded);
      expect(addIconFinder, findsWidgets);

      // Verify the container decoration has shape: BoxShape.circle
      final containerFinder = find.ancestor(
        of: addIconFinder.first,
        matching: find.byType(Container),
      );
      expect(containerFinder, findsWidgets);

      final containerWidget = tester.widget<Container>(containerFinder.first);
      final decoration = containerWidget.decoration as BoxDecoration?;
      expect(decoration?.shape, equals(BoxShape.circle));
    });
  });
}

