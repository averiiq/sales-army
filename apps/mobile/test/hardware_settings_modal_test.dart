import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/features/settings/presentation/dialogs/hardware_settings_modal.dart';

void main() {
  testWidgets('HardwareSettingsModal renders Settings & Gateway matching all 5 screenshots', (tester) async {
    final appState = AppState();
    appState.tenant = appState.tenant.copyWith(
      paymentGatewayConfig: {
        'displayName': 'Sharma FMCG & Grocery Distribution',
      },
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => const HardwareSettingsModal(),
                  );
                },
                child: const Text('Open Settings'),
              ),
            ),
          ),
        ),
      ),
    );

    // Open modal
    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();

    // 1. Header checks
    expect(find.text('Settings & Gateway'), findsOneWidget);
    expect(find.text('UPI QR Code & Payment Gateway Connections'), findsOneWidget);
    expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    // 2. Sub-tabs bar checks
    expect(find.text('UPI QR'), findsOneWidget);
    expect(find.text('Gateway'), findsOneWidget);
    expect(find.text('Printer'), findsOneWidget);

    // 3. Tab 0: UPI QR Content (Screenshot 1, 3, 4)
    expect(find.text('Live On-Counter QR Preview'), findsOneWidget);
    expect(find.textContaining('READY FOR'), findsOneWidget);
    expect(find.text('SalesArmy SaaS HQ'), findsWidgets);
    expect(find.text('rahul.salesarmy@okhdfcbank'), findsWidgets);
    expect(find.text('Dynamic Invoice Amount: ₹500'), findsOneWidget);
    expect(find.text('Copy UPI'), findsOneWidget);
    expect(find.text('Share QR'), findsOneWidget);

    // Scroll down in Tab 0
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(find.text('UPI Account & Merchant VPA'), findsOneWidget);
    expect(find.text('Distributor UPI VPA ID *'), findsOneWidget);
    expect(find.text('Merchant / Business Display Name'), findsOneWidget);
    expect(find.text('Sample Dynamic Test Amount (₹)'), findsOneWidget);
    expect(find.text('QR Code Presentation Source'), findsOneWidget);
    expect(find.text('Auto Dynamic QR'), findsOneWidget);
    expect(find.text('Upload Standee'), findsOneWidget);
    expect(find.text('Sound Box Voice Confirmation'), findsOneWidget);

    // Sticky bottom buttons
    expect(find.text('Close'), findsOneWidget);
    expect(find.text('Save Settings'), findsOneWidget);

    // 4. Switch to Gateway tab (Screenshot 2 & 5)
    await tester.tap(find.text('Gateway'));
    await tester.pumpAndSettle();

    expect(find.text('Gateway Connected & Active'), findsOneWidget);
    expect(find.textContaining('Razorpay • Live Mode'), findsOneWidget);
    expect(find.text('Gateway API Credentials'), findsOneWidget);
    expect(find.text('Razorpay'), findsOneWidget);
    expect(find.text('Gateway Environment'), findsOneWidget);
    expect(find.text('Live Production'), findsOneWidget);
    expect(find.text('Sandbox / Test Mode'), findsOneWidget);
    expect(find.text('Merchant Key ID / API Key *'), findsOneWidget);
    expect(find.text('Key Secret *'), findsOneWidget);
    expect(find.text('rzp_live_8K9vLmQ19284j'), findsOneWidget);

    // Scroll down in Gateway tab
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(find.text('Webhook Secret (Optional)'), findsOneWidget);
    expect(find.text('whsec_live_99812736'), findsOneWidget);
    expect(find.text('Merchant Display Name on Checkout'), findsOneWidget);
    expect(find.text('Sharma FMCG & Grocery Distribution'), findsOneWidget);
    expect(find.text('Auto-Verify Shop Online Invoices'), findsOneWidget);
    expect(find.text('Connection Diagnostics & Test Handshake'), findsOneWidget);
    expect(find.text('Test Gateway Connection'), findsOneWidget);

    // Test Diagnostics tap
    await tester.tap(find.text('Test Gateway Connection'));
    await tester.pumpAndSettle();
    expect(find.text('Gateway Diagnostics'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Close')));
    await tester.pumpAndSettle();

    // 5. Switch to Printer tab (Screenshots 1, 3, 4, 5)
    await tester.tap(find.text('Printer'));
    await tester.pumpAndSettle();

    // Top Card (Image 5)
    expect(find.text('Printer Connected & Ready'), findsOneWidget);
    expect(find.textContaining('POS-58 Bluetooth Thermal Printer'), findsWidgets);
    expect(find.textContaining('Battery: 88%'), findsOneWidget);

    // Paired & Nearby Devices Card (Image 1, 3, 5)
    expect(find.text('Paired & Nearby Devices'), findsOneWidget);
    expect(find.text('Scan for Nearby Bluetooth Printers'), findsOneWidget);
    expect(find.text('POS-58 Bluetooth Printer'), findsOneWidget);
    expect(find.text('Selected'), findsOneWidget);
    expect(find.text('Everycom EC-58 2-Inch ESC/POS'), findsOneWidget);
    expect(find.text('Bluewoods MPT-II 80mm HighSpeed'), findsOneWidget);
    expect(find.text('TVS Electronics RP-3150 Star'), findsOneWidget);
    expect(find.text('MPT-III 80mm Bluetooth Bill POS'), findsOneWidget);
    expect(find.text('Connect'), findsWidgets);

    // Form fields in Printer Tab (Image 3)
    expect(find.text('Printer Display Name'), findsOneWidget);
    expect(find.text('Bluetooth MAC Address (e.g. 00:11:22:33:AA:BB)'), findsOneWidget);
    expect(find.text('66:32:B1:8A:4F:92'), findsWidgets);

    // Paper Size & Hardware Specifications Card (Image 3, 4)
    expect(find.text('Paper Size & Hardware Specifications'), findsOneWidget);
    expect(find.text('Thermal Paper Roll Width'), findsOneWidget);
    expect(find.text('58mm'), findsWidgets);
    expect(find.text('80mm'), findsOneWidget);
    expect(find.text('2-Inch (32 cols)'), findsOneWidget);
    expect(find.text('3-Inch (48 cols)'), findsOneWidget);

    // Scroll down in Printer Tab
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(find.text('Print Head Darkness / Density'), findsOneWidget);
    expect(find.text('Low (Saver)'), findsOneWidget);
    expect(find.text('Normal'), findsOneWidget);
    expect(find.text('High (Deep)'), findsOneWidget);
    expect(find.text('Command Protocol / Character Encoding'), findsOneWidget);
    expect(find.text('ESC/POS Standard (UTF-8)'), findsOneWidget);

    // Invoice Printing & Automation (Screenshots 1, 3)
    expect(find.text('Invoice Printing & Automation'), findsOneWidget);
    expect(find.text('Auto-Print on Order Checkout'), findsOneWidget);
    expect(find.text('Print Copies per Bill'), findsOneWidget);
    expect(find.text('1 Copy'), findsOneWidget);
    expect(find.text('2 Copy'), findsOneWidget);
    expect(find.text('Print Dynamic UPI QR on Receipt'), findsOneWidget);
    expect(find.text('Print Agency Address & FSSAI / GSTIN'), findsOneWidget);

    // Scroll further down for buzzer, footer note, and receipt simulator
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(find.text('Beep Buzzer on Print Finished'), findsOneWidget);
    expect(find.text('Receipt Footer Note / Terms'), findsOneWidget);
    expect(find.text('Thank You for Ordering! For support call distributor.'), findsWidgets);

    // Live Test Print Simulator (Screenshots 3, 4)
    expect(find.text('Live Test Print Simulator'), findsOneWidget);
    expect(find.text('Print Test Receipt'), findsOneWidget);

    // Simulated Thermal Receipt (Screenshots 2, 4)
    expect(find.textContaining('THERMAL RECEIPT PREVIEW'), findsOneWidget);
    expect(find.text('SALESARMY SAAS HQ'), findsWidgets);
    expect(find.textContaining('Plot 42, Sector 8'), findsOneWidget);
    expect(find.textContaining('GSTIN: 27ABCDE1234F1Z5'), findsOneWidget);
    expect(find.textContaining('Retailer: Laxmi Super Market'), findsOneWidget);
    expect(find.text('Britannia GoodDay'), findsOneWidget);
    expect(find.text('Tata Tea Gold 250g'), findsOneWidget);
    expect(find.text('TOTAL AMOUNT'), findsOneWidget);
    expect(find.text('₹580.00'), findsOneWidget);
    expect(find.text('[ ☷☷ DYNAMIC UPI QR ☷☷ ]'), findsOneWidget);

    // Test Print Receipt button
    await tester.ensureVisible(find.text('Print Test Receipt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Print Test Receipt'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Test receipt sent to 58mm Thermal Bluetooth POS Printer!'), findsOneWidget);

    // Wait for first snackbar to dismiss
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // 6. Test Save Settings
    await tester.tap(find.text('Save Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Settings & Hardware configurations saved!'), findsOneWidget);
    expect(find.text('Settings & Gateway'), findsNothing);
  });
}
