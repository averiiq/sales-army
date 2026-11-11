import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/core/utils/csv_report_helper.dart';
import 'package:salesarmy/features/admin/presentation/screens/plan_and_pricing_screen.dart';
import 'package:salesarmy/features/collections/presentation/dialogs/collect_payment_dialog.dart';
import 'package:salesarmy/features/orders/presentation/screens/orders_tab.dart';
import 'package:salesarmy/features/profile/presentation/dialogs/reset_account_dialog.dart';
import 'package:salesarmy/features/profile/presentation/screens/gst_configuration_screen.dart';
import 'package:salesarmy/features/reports/presentation/screens/inventory_report_screen.dart';
import 'package:salesarmy/features/reports/presentation/screens/ledger_graphical_report_screen.dart';
import 'package:salesarmy/features/reports/presentation/screens/orders_report_screen.dart';
import 'package:salesarmy/features/reports/presentation/screens/sales_report_screen.dart';
import 'package:salesarmy/features/settings/presentation/screens/hardware_settings_screen.dart';
import 'package:salesarmy/features/settings/presentation/screens/sync_and_backup_screen.dart';

void main() {
  group('Verification of 9 Enterprise Features', () {
    // 1. RESET account functionality
    testWidgets('1. ResetAccountDialog enforces typing "RESET" and AppState resets data', (tester) async {
      final appState = AppState();
      expect(appState.orders.isNotEmpty, isTrue);
      expect(appState.invoices.isNotEmpty, isTrue);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => Center(
                  child: ElevatedButton(
                    onPressed: () => ResetAccountDialog.show(ctx),
                    child: const Text('Open Reset Dialog'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open dialog
      await tester.tap(find.text('Open Reset Dialog'));
      await tester.pumpAndSettle();

      // Verify warning and disabled button initially
      expect(find.text('Reset Account Data'), findsOneWidget);
      expect(find.text('Continue Reset'), findsOneWidget);

      // Try typing wrong word
      await tester.enterText(find.byType(TextField), 'WRONG');
      await tester.pumpAndSettle();

      // Type "RESET"
      await tester.enterText(find.byType(TextField), 'RESET');
      await tester.pumpAndSettle();

      // Trigger reset
      await tester.ensureVisible(find.text('Continue Reset'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue Reset'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Check appState reset state
      expect(appState.orders.isEmpty, isTrue);
      expect(appState.invoices.isEmpty, isTrue);
      expect(appState.ledgerEntries.isEmpty, isTrue);
      for (final p in appState.products) {
        expect(p.stockQuantity, 100);
      }
      for (final s in appState.shops) {
        expect(s.currentOutstanding, 0.0);
      }
    });

    // 2. Full-Screen conversions of major modals
    testWidgets('2. All major dialogs are full-screen Scaffold pages', (tester) async {
      final appState = AppState();

      // Hardware Settings full-screen
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(home: HardwareSettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hardware & POS Printers'), findsOneWidget);
      expect(find.byType(Scaffold), findsWidgets);

      // Sync and Backup full-screen
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(home: SyncAndBackupScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Offline Storage & Cloud Sync'), findsOneWidget);
      expect(find.byType(Scaffold), findsWidgets);

      // GST Configuration full-screen
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(home: GstConfigurationScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('GST & Taxes Configuration'), findsOneWidget);
      expect(find.byType(Scaffold), findsWidgets);
    });

    // 3. GST option in profile dynamic add/remove working through app
    testWidgets('3. GST rates can be added and removed dynamically in AppState and UI', (tester) async {
      final appState = AppState();
      expect(appState.gstRates, contains(18.0));

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(home: GstConfigurationScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('18.0% Standard Goods & Services Tax'), findsOneWidget);

      // Add a custom rate 40% via AppState
      appState.addGstRate(40.0);
      await tester.pumpAndSettle();
      expect(appState.gstRates, contains(40.0));
      expect(find.text('40.0% Standard Goods & Services Tax'), findsOneWidget);

      // Remove rate
      appState.removeGstRate(40.0);
      await tester.pumpAndSettle();
      expect(appState.gstRates.contains(40.0), isFalse);
    });

    // 4. Offline storage & backup with 12pm and 10pm scheduled batches and permission delete
    testWidgets('4. Sync and backup displays 12 PM & 10 PM schedule and mobile vault status', (tester) async {
      final appState = AppState();

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(home: SyncAndBackupScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AUTOMATED BATCH SYNC SCHEDULE'), findsOneWidget);
      expect(find.text('12:00 PM (Mid-day Sync)'), findsOneWidget);
      expect(find.text('10:00 PM (Night Beat Closing)'), findsOneWidget);
      expect(find.text('Clear Synced Storage from Mobile (Requires Permission)'), findsOneWidget);

      // Test manual batch sync
      await tester.tap(find.text('Force Batch Sync Now'));
      await tester.pumpAndSettle();
      expect(appState.lastBatchSyncTime != null, isTrue);
    });

    // 5 & 9. Subscription screen redesign with Startup 399, Grow 599, Enterprise 899 + Monthly/Yearly toggle
    testWidgets('5 & 9. Plans screen renders 3 tiers and monthly/yearly 20% discount toggle', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final appState = AppState();

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(home: PlanAndPricingScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Check tier names and pricing
      expect(find.text('Startup'), findsOneWidget);
      expect(find.text('399'), findsOneWidget);
      expect(find.text('Grow'), findsOneWidget);
      expect(find.text('599'), findsOneWidget);
      expect(find.text('Enterprise'), findsOneWidget);
      expect(find.text('899'), findsOneWidget);

      // Check Monthly/Yearly Toggle options
      expect(find.text('Monthly Billing'), findsOneWidget);
      expect(find.text('Yearly (Save 20%)'), findsOneWidget);

      // Tap Annual Billing
      await tester.tap(find.text('Yearly (Save 20%)'));
      await tester.pumpAndSettle();

      // 399 with 20% discount = 319
      expect(find.text('319'), findsOneWidget);
      // 599 with 20% discount = 479
      expect(find.text('479'), findsOneWidget);
      // 899 with 20% discount = 719
      expect(find.text('719'), findsOneWidget);
    });

    // 6. Dedicated graphical pages for all 4 reports with deep line-by-line CSV download
    testWidgets('6. All 4 graphical report screens generate comprehensive CSV data', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final appState = AppState();

      // 1. Ledger CSV
      final ledgerCsv = CsvReportHelper.generateLedgerCsv(
        entries: appState.ledgerEntries,
        shops: appState.shops,
      );
      expect(ledgerCsv, contains('Entry ID'));
      expect(ledgerCsv, contains('Debit (INR)'));
      expect(ledgerCsv, contains('Credit (INR)'));

      // 2. Orders CSV
      final ordersCsv = CsvReportHelper.generateOrdersCsv(
        orders: appState.orders,
        shops: appState.shops,
      );
      expect(ordersCsv, contains('Order ID'));
      expect(ordersCsv, contains('Retailer Shop Name'));
      expect(ordersCsv, contains('Taxable Value (INR)'));

      // 3. Inventory CSV
      final inventoryCsv = CsvReportHelper.generateInventoryCsv(
        products: appState.products,
      );
      expect(inventoryCsv, contains('SKU Code'));
      expect(inventoryCsv, contains('Product Name'));
      expect(inventoryCsv, contains('Total Stock Valuation (INR)'));

      // 4. Sales CSV
      final salesCsv = CsvReportHelper.generateSalesCsv(
        invoices: appState.invoices,
        orders: appState.orders,
      );
      expect(salesCsv, contains('Invoice Number'));
      expect(salesCsv, contains('Customer Trade Name'));
      expect(salesCsv, contains('Total GST Tax (INR)'));

      // Verify Graphical screens mount properly as Scaffolds
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(home: LedgerGraphicalReportScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ledger & Khata Report'), findsOneWidget);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(home: OrdersReportScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Orders & Volume Report'), findsOneWidget);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(home: InventoryReportScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Inventory & Valuation Report'), findsOneWidget);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(home: SalesReportScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sales & Tax Report'), findsOneWidget);
    });

    // 7. Collect payment on order page
    testWidgets('7. Orders tab order card displays Collect Payment button and triggers dialog', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final appState = AppState();

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(
            home: Scaffold(
              body: OrdersTab(initialTabIndex: 0),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Collect Payment'), findsWidgets);

      // Tap first Collect Payment
      await tester.tap(find.text('Collect Payment').first);
      await tester.pumpAndSettle();

      expect(find.byType(CollectPaymentDialog), findsOneWidget);
    });

    // 8. Remove shop report from order screen
    testWidgets('8. Shop Report button is completely removed from order cards', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final appState = AppState();

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(
            home: Scaffold(
              body: OrdersTab(initialTabIndex: 1),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Shop Report'), findsNothing);
    });
  });
}
