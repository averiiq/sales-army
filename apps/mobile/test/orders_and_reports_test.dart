import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/features/orders/presentation/screens/orders_tab.dart';
import 'package:salesarmy/features/collections/presentation/dialogs/ledger_report_modal.dart';
import 'package:salesarmy/features/billing/presentation/screens/gst_tax_invoice_viewer.dart';
import 'package:salesarmy/features/collections/presentation/screens/collections_tab.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/core/utils/formatters.dart';

void main() {
  testWidgets('OrdersTab UI renders Orders tab at index 0 without Order Taker subtab', (tester) async {
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

    // Verify sub-tabs: Order Taker removed from OrdersTab
    expect(find.text('Order Taker'), findsNothing);
    expect(find.text('Orders'), findsOneWidget);
    expect(find.text('Bill'), findsOneWidget);

    // Verify Total Orders & Sales Report banner is removed
    expect(find.text('Total Orders & Sales Report'), findsNothing);

    // Verify Search bar
    expect(find.text('Search by Shop, Order # or Note...'), findsOneWidget);

    // Verify Filter chips
    expect(find.text('All (2)'), findsOneWidget);
    expect(find.text('Pending (0)'), findsOneWidget);
    expect(find.text('Delivered (2)'), findsOneWidget);

    // Verify Order cards
    expect(find.text('ORD-2026-001'), findsWidgets);
    expect(find.text('Shree Ganesh Kirana & General Store'), findsWidgets);
    expect(find.textContaining('Order Placed:'), findsWidgets);
    expect(find.text('Delivered'), findsWidgets);
    expect(find.text('Collect Payment'), findsWidgets);
    expect(find.text('View Bill'), findsWidgets);
  });

  testWidgets('LedgerReportModal renders Download Orders Report matching Images 4 and 5', (tester) async {
    final appState = AppState();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: const MaterialApp(
          home: Scaffold(
            body: LedgerReportModal(
              initialIsKhata: false,
              initialShopId: 'shop_001',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Modal Title & Subtitle
    expect(find.text('Download Orders Report'), findsOneWidget);
    expect(find.text('One-Click Half Year / Annual Sales Export'), findsOneWidget);

    // Verify Section 1: Time Period Matrix
    expect(find.text('1. Select Report Time Period'), findsOneWidget);
    expect(find.text('Half Year'), findsOneWidget);
    expect(find.text('Popular'), findsOneWidget);
    expect(find.text('Annual Sale'), findsOneWidget);
    expect(find.text('Full FY'), findsOneWidget);
    expect(find.text('This Month'), findsOneWidget);
    expect(find.text('All Time'), findsOneWidget);

    // Verify Section 2: Shop / Territory scope
    expect(find.text('2. Filter by Shop / Territory'), findsOneWidget);
    expect(find.text('Target Retail Shop Scope'), findsOneWidget);
    expect(find.text('Shree Ganesh Kirana & General Store'), findsOneWidget);

    // Verify Section 3: Summary Metrics Card
    expect(find.text('Report Summary Metrics'), findsOneWidget);
    expect(find.text('2 Orders Found'), findsOneWidget);
    expect(find.text('Gross Sales Revenue'), findsOneWidget);
    expect(find.text('₹ 4,900'), findsOneWidget);
    expect(find.text('GST Tax Amount'), findsOneWidget);
    expect(find.text('₹ 245'), findsOneWidget);
    expect(find.text('Delivered: 2 | Pending: 0'), findsOneWidget);
    expect(find.text('Balance Due: ₹2400'), findsOneWidget);

    // Verify Accordion & Buttons
    expect(find.text('Show Orders & Delivery Details Preview (2)'), findsOneWidget);
    expect(find.text('Download CSV / Excel Report'), findsOneWidget);
    expect(find.text('Share via WA'), findsOneWidget);
    expect(find.text('Copy Report'), findsOneWidget);
  });

  testWidgets('OrdersTab renders GST Bills tab at index 1 with top buttons removed', (tester) async {
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

    // Verify Action buttons are removed per requirement
    expect(find.text('Create GST Bill'), findsNothing);
    expect(find.text('Export All GST'), findsNothing);

    // Verify Search Bar
    expect(find.text('Search by Invoice #, Shop, or GSTIN...'), findsOneWidget);

    // Verify Filter Chips
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Paid'), findsOneWidget);
    expect(find.text('Partial'), findsWidgets);
    expect(find.text('Unpaid'), findsOneWidget);
    expect(find.text('GST Only'), findsOneWidget);

    // Verify Invoices list
    expect(find.text('INV-2026-0001'), findsWidgets);
    expect(find.text('GST Tax Invoice'), findsWidgets);
    expect(find.text('Shree Ganesh Kirana & General Store'), findsWidgets);
    expect(find.text(AppFormatters.currency(2572.50)), findsWidgets);
    expect(find.text('Bill'), findsWidgets);
  });

  testWidgets('GstTaxInvoiceViewer renders full dialog matching Screenshots 1, 2 and 3', (tester) async {
    final appState = AppState();
    final invoice = appState.invoices.first;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GstTaxInvoiceViewer(invoice: invoice),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Header
    expect(find.text('GST Tax Invoice'), findsOneWidget);
    expect(find.text('TAX INVOICE'), findsOneWidget);
    expect(find.text('(Under Section 31 of CGST Act, 2017)'), findsOneWidget);

    // Seller & Buyer
    expect(find.text('SalesArmy SaaS HQ'), findsWidgets);
    expect(find.text('Invoice Details:'), findsOneWidget);
    expect(find.text('Bill To (Buyer):'), findsOneWidget);
    expect(find.text('Shree Ganesh Kirana & General Store'), findsOneWidget);

    // Items table header & totals
    expect(find.text('GRAND TOTAL (₹):'), findsOneWidget);
    expect(find.text('₹2572.50'), findsOneWidget);
    expect(find.text('Paid: ₹1372'), findsOneWidget);
    expect(find.text('Due Balance: ₹1200'), findsOneWidget);

    // Bottom action buttons
    expect(find.textContaining('WhatsApp'), findsOneWidget);
    expect(find.textContaining('Thermal'), findsOneWidget);
  });

  testWidgets('CollectionsTab renders Territory Balance and Shop Dues matching Screenshot 5', (tester) async {
    final appState = AppState();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: const MaterialApp(
          home: Scaffold(
            body: CollectionsTab(initialTabIndex: 0),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Territory Summary Card
    expect(find.text('Parties Outstanding'), findsOneWidget);
    expect(find.text('Territory Credit Outstanding'), findsNothing);
    expect(find.text(AppFormatters.currency(16400)), findsOneWidget);
    expect(find.text('Khata Ledger'), findsOneWidget);
    expect(find.text('Cash: ₹2745'), findsOneWidget);
    expect(find.text('PG: ₹0'), findsOneWidget);
    // "N Shops Due" pill was removed from the outstanding card.
    expect(find.textContaining('Shops Due'), findsNothing);

    // Gateway Strip
    expect(find.text('Razorpay Gateway Connected & Ready'), findsOneWidget);
    expect(find.text('LIVE'), findsOneWidget);

    // Sub Tabs
    expect(find.byWidgetPredicate((w) => w is Text && (w.data == 'Outstanding Dues' || w.data == 'Retailer Dues')), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is Text && (w.data == 'Payment Ledger' || w.data == 'Ledger')), findsOneWidget);

    // Download Ledger Banner
    expect(find.text('Download Territory Dues Ledger'), findsOneWidget);
    expect(find.text('Export'), findsOneWidget);

    // Shop Due Cards
    expect(find.text('Balaji Provisions & Wholesale'), findsWidgets);
    expect(find.text('Due: '), findsWidgets);
    expect(find.text(AppFormatters.currency(4500)), findsWidgets);
    expect(find.text('Khata'), findsWidgets);
    expect(find.byWidgetPredicate((w) => w is Text && (w.data == 'Collect' || w.data == 'Record Cash' || w.data == 'Record Payment')), findsWidgets);
  });

  testWidgets('LedgerReportModal renders All Shops Ledger matching Screenshots 1 and 2', (tester) async {
    final appState = AppState();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: const MaterialApp(
          home: Scaffold(
            body: LedgerReportModal(initialIsKhata: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Header
    expect(find.text('Download Ledger & Khata'), findsOneWidget);
    expect(find.text('All Shops & Individual Khata Statement'), findsOneWidget);

    // 2. Subtabs
    expect(find.text('All Shops Ledger'), findsOneWidget);
    expect(find.text('(8)'), findsOneWidget);
    expect(find.text('Individual Shop'), findsOneWidget);
    expect(find.text('Khata'), findsOneWidget);

    // 3. Statement Time Range
    expect(find.text('Statement Time Range'), findsOneWidget);
    expect(find.text('Half Year'), findsOneWidget);
    expect(find.text('6 Mo'), findsOneWidget);
    expect(find.text('Annual Sale'), findsOneWidget);
    expect(find.text('1 Year'), findsOneWidget);
    expect(find.text('This Month'), findsOneWidget);
    expect(find.text('All Time'), findsOneWidget);

    // 4. Territory Consolidated Ledger Card
    expect(find.text('Territory Consolidated Ledger'), findsOneWidget);
    expect(find.text('Total Territory Billed'), findsOneWidget);
    expect(find.text('₹ 5,145'), findsOneWidget);
    expect(find.text('Total Collections'), findsOneWidget);
    expect(find.text('₹ 2,745'), findsOneWidget);
    expect(find.text('6 of 8 Shops have pending dues'), findsOneWidget);
    expect(find.text('Net Due:'), findsOneWidget);
    expect(find.text('₹16400'), findsOneWidget);

    // 5. Accordion
    expect(find.text('Show Outlet Breakdown (8 Shops)'), findsOneWidget);

    // 6. Action buttons
    expect(find.text('Download All Shops Ledger (CSV / Excel)'), findsOneWidget);
    expect(find.text('Share Summary'), findsOneWidget);
    expect(find.text('Copy Statement'), findsOneWidget);
  });

  testWidgets('LedgerReportModal renders Individual Shop Khata matching Screenshot 3', (tester) async {
    final appState = AppState();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: const MaterialApp(
          home: Scaffold(
            body: LedgerReportModal(
              initialIsKhata: true,
              initialShopId: 'shop_002',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Header
    expect(find.text('Download Ledger & Khata'), findsOneWidget);

    // 2. Subtabs
    expect(find.text('Individual Shop'), findsOneWidget);

    // 3. Statement Time Range
    expect(find.text('Statement Time Range'), findsOneWidget);
    expect(find.text('Half Year'), findsOneWidget);

    // 4. Select Retail Shop Dropdown
    expect(find.text('Select Retail Shop'), findsOneWidget);
    expect(find.text('Customer / Retailer Account'), findsOneWidget);
    expect(find.text('Balaji Provisions & Wholesale'), findsWidgets);

    // 5. Action buttons
    expect(find.text('Download Shop Khata Book (CSV / Excel)'), findsOneWidget);
    expect(find.text('Send to Shop WA'), findsOneWidget);
    expect(find.text('Copy Statement'), findsOneWidget);
  });

  testWidgets('Collect Outstanding Payment modal renders matching Screenshot 4', (tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final appState = AppState();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: const MaterialApp(
          home: Scaffold(
            body: CollectionsTab(initialTabIndex: 0),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap Collect / Record Cash button on Balaji Provisions
    final collectButtons = find.byWidgetPredicate((w) => w is Text && (w.data == 'Collect' || w.data == 'Record Cash' || w.data == 'Record Payment'));
    expect(collectButtons, findsWidgets);
    await tester.ensureVisible(collectButtons.first);
    await tester.tap(collectButtons.first);
    await tester.pumpAndSettle();

    // Verify Modal
    expect(find.text('Collect Payment'), findsWidgets);
    expect(find.text('Balaji Provisions & Wholesale'), findsWidgets);
    expect(find.text(AppFormatters.currency(4500)), findsWidgets);
    expect(find.text('Amount Received (₹) *'), findsOneWidget);
    expect(find.text('4500'), findsOneWidget);

    // Verify Payment Modes
    expect(find.text('Payment Mode'), findsOneWidget);
    expect(find.textContaining('Cash'), findsWidgets);
    expect(find.textContaining('UPI'), findsWidgets);
    expect(find.textContaining('Razorpay'), findsWidgets);

    // Verify Actions
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Record Collection'), findsOneWidget);
  });
}

