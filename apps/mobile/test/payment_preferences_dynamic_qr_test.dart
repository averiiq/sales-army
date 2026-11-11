import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/core/services/printer_service.dart';
import 'package:salesarmy/features/admin/data/models/tenant_model.dart';
import 'package:salesarmy/features/billing/data/models/invoice_model.dart';
import 'package:salesarmy/features/billing/presentation/screens/gst_tax_invoice_viewer.dart';
import 'package:salesarmy/features/settings/presentation/screens/payment_preferences_screen.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  Widget createWidgetUnderTest({AppState? state}) {
    final appState = state ?? AppState();
    return ChangeNotifierProvider<AppState>.value(
      value: appState,
      child: const MaterialApp(
        home: PaymentPreferencesScreen(initialTab: 0),
      ),
    );
  }

  testWidgets('PaymentPreferencesScreen starts clean with no dummy UPI ID or dummy Merchant Name', (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final appState = AppState();
    // Ensure tenant has no upiId
    appState.updateTenant(appState.tenant.copyWith(upiId: '', firmName: ''));

    await tester.pumpWidget(createWidgetUnderTest(state: appState));
    await tester.pumpAndSettle();

    // Verify no dummy text appears
    expect(find.text('salesarmy@okhdfcbank'), findsNothing);
    expect(find.text('SalesArmy Merchant HQ'), findsNothing);
    expect(find.text('rahul.salesarmy@okhdfcbank'), findsNothing);

    // Verify information section is completely removed
    expect(find.text('Is Dynamic UPI QR 100% Legal & Safe?'), findsNothing);
    expect(find.text('Official NPCI UPI 2.0 Standard'), findsNothing);
    expect(find.text('Zero Payment Gateway MDR Fees'), findsNothing);

    // Since UPI ID is empty, Dynamic mode requires UPI ID
    expect(find.text('UPI ID Required'), findsOneWidget);
  });

  testWidgets('Entering UPI ID displays the Dynamic QR generator section without amount functionality', (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final appState = AppState();
    appState.updateTenant(appState.tenant.copyWith(upiId: 'testmerchant@okhdfcbank', firmName: 'My Wholesale Agency'));

    await tester.pumpWidget(createWidgetUnderTest(state: appState));
    await tester.pumpAndSettle();

    // Dynamic QR generator section is visible
    expect(find.text('Dynamic QR Generator'), findsOneWidget);
    expect(find.text('REAL-TIME'), findsOneWidget);
    expect(find.text('Show Counter QR'), findsOneWidget);
    expect(find.text('Simulate Scan'), findsOneWidget);

    // Amount functionality is removed
    expect(find.text('Bill Amount (₹)'), findsNothing);
    expect(find.text('Enter Custom Amount (₹)'), findsNothing);
    expect(find.text('₹100'), findsNothing);
    expect(find.text('₹500'), findsNothing);
    expect(find.text('₹1000'), findsNothing);
    expect(find.text('Invoice Note / Order Ref (tn param)'), findsNothing);

    // Deep link contains UPI ID and name, but NO amount parameter
    expect(find.textContaining('upi://pay?pa=testmerchant@okhdfcbank'), findsWidgets);
    expect(find.textContaining('&am='), findsNothing);
  });

  testWidgets('Switching to Static mode shows Static QR upload option', (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final appState = AppState();
    await tester.pumpWidget(createWidgetUnderTest(state: appState));
    await tester.pumpAndSettle();

    // Tap Static radio tile
    await tester.tap(find.text('Static'));
    await tester.pumpAndSettle();

    // Static upload container appears
    expect(find.text('Static QR Code'), findsOneWidget);
    expect(find.text('Upload Static QR Code Image'), findsOneWidget);
    expect(find.text('Tap to choose image from photo gallery'), findsOneWidget);
    expect(find.text('Dynamic QR Generator'), findsNothing);
  });

  testWidgets('Saving preferences persists UPI ID, QR mode, and syncs PrinterService', (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final appState = AppState();
    await tester.pumpWidget(createWidgetUnderTest(state: appState));
    await tester.pumpAndSettle();

    // Enter UPI ID
    final upiField = find.widgetWithText(TextField, 'Merchant VPA / UPI ID *');
    await tester.enterText(upiField, 'agency.biz@icici');

    // Tap Save button
    await tester.tap(find.text('Save Payment Preferences'));
    await tester.pumpAndSettle();

    // Verify tenant updated
    expect(appState.tenant.upiId, 'agency.biz@icici');
    // Verify PrinterService settings synced
    expect(PrinterService.instance.settings.upiVpa, 'agency.biz@icici');

    // Verify SharedPreferences persisted values
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('salesarmy_pref_upi_id_v2'), 'agency.biz@icici');
    expect(prefs.getString('salesarmy_pref_qr_source_v2'), 'dynamic');
  });

  test('Static QR and UPI ID persist across app restarts and cloud tenant updates', () async {
    const testUpi = 'myfirm@okhdfcbank';
    const testStaticQrDataUri = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

    // 1. User configures payment preferences and saves
    final appState = AppState();
    await appState.updateTenant(appState.tenant.copyWith(
      upiId: testUpi,
      paymentGatewayConfig: {
        'qrSource': 'static',
        'staticQrImage': testStaticQrDataUri,
        'merchantName': 'My Distribution Firm',
      },
    ));

    // Verify written to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('salesarmy_pref_upi_id_v2'), testUpi);
    expect(prefs.getString('salesarmy_pref_static_qr_image_v2'), testStaticQrDataUri);
    expect(prefs.getString('salesarmy_pref_qr_source_v2'), 'static');

    // 2. Simulate complete app restart: new AppState instance created
    final restartedAppState = AppState();
    // Allow constructor async _loadSavedTenant to complete
    await Future.delayed(const Duration(milliseconds: 100));

    expect(restartedAppState.tenant.upiId, testUpi);
    expect(restartedAppState.tenant.paymentGatewayConfig?['staticQrImage'], testStaticQrDataUri);
    expect(restartedAppState.tenant.paymentGatewayConfig?['qrSource'], 'static');

    // 3. Simulate cloud update (e.g. from backend where public.tenants table doesn't have upi_id or payment_gateway_config)
    final backendTenantUpdate = TenantModel.fromMap({
      'business_name': 'Updated Firm Name from Cloud',
      'contact_person': 'Updated Owner',
    }, restartedAppState.tenant.tenantId);

    // Call updateTenant
    await restartedAppState.updateTenant(backendTenantUpdate);

    // Verify defensive merge prevented wipeout
    expect(restartedAppState.tenant.firmName, 'Updated Firm Name from Cloud');
    expect(restartedAppState.tenant.upiId, testUpi);
    expect(restartedAppState.tenant.paymentGatewayConfig?['staticQrImage'], testStaticQrDataUri);
    expect(restartedAppState.tenant.paymentGatewayConfig?['qrSource'], 'static');

    // Verify SharedPreferences still retains the values
    expect(prefs.getString('salesarmy_pref_upi_id_v2'), testUpi);
    expect(prefs.getString('salesarmy_pref_static_qr_image_v2'), testStaticQrDataUri);
  });

  testWidgets('GST Tax Invoice displays dynamic QR with exact bill amount when configured', (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final appState = AppState();
    appState.updateTenant(appState.tenant.copyWith(
      upiId: 'superstore@okaxis',
      paymentGatewayConfig: {'qrSource': 'dynamic'},
    ));

    final invoice = InvoiceModel(
      invoiceId: 'INV-TEST-001',
      invoiceNumber: 'SA-2026-001',
      invoiceDate: DateTime.now(),
      orderId: 'ORD-001',
      shopId: 'SHOP-001',
      invoiceType: 'B2B Tax Invoice',
      placeOfSupply: '27 (Maharashtra)',
      seller: {'firmName': 'Apex FMCG Distributors', 'gstin': '27AAACS1429B1ZB'},
      buyer: {'shopName': 'Krishna General Store', 'gstin': '27AABCU9603R1ZM'},
      items: const [],
      taxableSubtotal: 500.0,
      cgst: 0.0,
      sgst: 0.0,
      igst: 0.0,
      grandTotal: 500.0,
      paidAmount: 0.0,
      dueAmount: 500.0,
      paymentStatus: 'unpaid',
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(
          home: GstTaxInvoiceViewer(invoice: invoice),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify dynamic bill QR with amount 500.00 is rendered
    expect(find.text('Scan to Pay: ₹500.00'), findsOneWidget);
    expect(find.text('UPI ID: superstore@okaxis'), findsOneWidget);
  });
}
