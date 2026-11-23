import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/navigation/main_shell.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/core/theme/app_theme.dart';
import 'package:salesarmy/features/dashboard/presentation/screens/distributor_dashboard.dart';
import 'package:salesarmy/features/shops/presentation/screens/shops_tab.dart';
import 'package:salesarmy/features/orders/presentation/screens/orders_tab.dart';
import 'package:salesarmy/features/orders/presentation/screens/order_taker_flow.dart';
import 'package:salesarmy/features/collections/presentation/screens/collections_tab.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Navbar Yellow Status Bar & Slide Animation Tests', () {
    testWidgets('1. Home page has top yellow navbar extending to status bar, other pages have NO top navbar', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final appState = AppState(loadMockData: true);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp(
            home: MainShell(onSignOut: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Home Page: Top AppBar is present
      expect(find.byType(DistributorDashboard), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);

      // Verify the AppBar flexibleSpace uses cleanWarmNavbarGradient
      final appBarWidget = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBarWidget.flexibleSpace, isA<Container>());
      final container = appBarWidget.flexibleSpace as Container;
      final boxDecoration = container.decoration as BoxDecoration;
      expect(boxDecoration.gradient, equals(AppTheme.cleanWarmNavbarGradient));

      // Verify systemOverlayStyle on the Home AppBar enforces transparent status bar with contrast enforcement false
      final overlayStyle = appBarWidget.systemOverlayStyle;
      expect(overlayStyle, isNotNull);
      expect(overlayStyle!.statusBarColor, equals(Colors.transparent));
      expect(overlayStyle.systemStatusBarContrastEnforced, isFalse);
      expect(overlayStyle.statusBarIconBrightness, equals(Brightness.dark));

      // Bottom navbar is fully visible on Home
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Parties'), findsOneWidget);
      expect(find.text('Bill'), findsOneWidget);
      expect(find.text('Orders'), findsOneWidget);
      expect(find.text('Collection'), findsOneWidget);

      // Verify geometry: AppBar is at top, bottom nav is at bottom, body is visible in between
      final appBarTop = tester.getTopLeft(find.byType(AppBar)).dy;
      expect(appBarTop, equals(0.0));

      final dashboardHeight = tester.getSize(find.byType(DistributorDashboard)).height;
      expect(dashboardHeight, greaterThan(800.0)); // Body is fully visible and NOT squashed to 0!

      // Navigate to Parties (tab 1)
      await tester.tap(find.text('Parties'));
      await tester.pumpAndSettle();

      // Parties page: NO top yellow navbar (AppBar is null)
      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(ShopsTab), findsOneWidget);

      // Bottom navbar is still present on Parties
      expect(find.text('Parties'), findsWidgets);
      expect(find.text('Home'), findsOneWidget);

      // Return to Home using the back arrow button
      final backButtonFinder = find.byIcon(Icons.arrow_back_rounded);
      expect(backButtonFinder, findsWidgets);
      await tester.tap(backButtonFinder.first);
      await tester.pumpAndSettle();

      // Home: Top AppBar restored
      expect(find.byType(AppBar), findsOneWidget);

      // Navigate to Bill (tab 2)
      await tester.tap(find.text('Bill'));
      await tester.pumpAndSettle();

      // Bill page: NO top yellow navbar
      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(OrderTakerFlow), findsOneWidget);

      // Bottom navbar is still present on Bill page
      expect(find.text('Bill'), findsWidgets);
      expect(find.text('Home'), findsOneWidget);

      // Return to Home via back arrow button
      expect(backButtonFinder, findsWidgets);
      await tester.tap(backButtonFinder.first);
      await tester.pumpAndSettle();

      // Home restored
      expect(find.byType(AppBar), findsOneWidget);

      // Navigate to Orders (tab 3)
      await tester.tap(find.text('Orders'));
      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(OrdersTab), findsOneWidget);
      expect(find.text('Orders'), findsWidgets);
      expect(find.text('Home'), findsOneWidget);

      // Return to Home via back arrow button
      expect(backButtonFinder, findsWidgets);
      await tester.tap(backButtonFinder.first);
      await tester.pumpAndSettle();

      // Home restored
      expect(find.byType(AppBar), findsOneWidget);

      // Navigate to Collection (tab 4)
      await tester.tap(find.text('Collection'));
      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(CollectionsTab), findsOneWidget);
      expect(find.text('Collection'), findsWidgets);
      expect(find.text('Home'), findsOneWidget);

      // Return to Home via back arrow button
      expect(backButtonFinder, findsWidgets);
      await tester.tap(backButtonFinder.first);
      await tester.pumpAndSettle();

      // Home restored with yellow navbar
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('2. Bill page shows floating cart bar at bottom without squashing body', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final appState = AppState(loadMockData: true);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp(
            home: MainShell(onSignOut: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to Bill tab
      await tester.tap(find.text('Bill'));
      await tester.pumpAndSettle();

      expect(find.byType(OrderTakerFlow), findsOneWidget);

      // Back button is arrow-only (no 'Back to Dashboard' text taking space)
      expect(find.byIcon(Icons.arrow_back_rounded), findsWidgets);
      expect(find.text('Orders & Billing'), findsOneWidget);

      // Tap a product card to open variant and quantity modal
      final productCard = find.text('Aashirvaad Shudh Chakki Atta');
      expect(productCard, findsOneWidget);
      await tester.tap(productCard);
      await tester.pumpAndSettle();

      // Confirm and add to order
      final confirmBtn = find.text('Confirm & Add to Order');
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Floating cart action bar appears
      expect(find.text('Review & Bill'), findsOneWidget);
      expect(find.text('Book Order'), findsOneWidget);

      // Crucial: The floating cart bar must be at the BOTTOM (not top of screen)
      final reviewBtnY = tester.getTopLeft(find.text('Review & Bill')).dy;
      expect(reviewBtnY, greaterThan(900.0)); // Near screen bottom, above persistent navbar!

      // Persistent bottom navbar is still visible at bottom
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Parties'), findsOneWidget);
      expect(find.text('Bill'), findsWidgets);

      // The body / product list is visible and NOT squashed to 0 height
      final flowSize = tester.getSize(find.byType(OrderTakerFlow));
      expect(flowSize.height, greaterThan(800.0));
      expect(find.text('Orders & Billing'), findsOneWidget);
    });

    testWidgets('3. Dark mode uses dark navbar gradient on Home and transparent status bar', (tester) async {
      final appState = AppState(loadMockData: true);
      appState.setThemeMode(ThemeMode.dark);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp(
            home: MainShell(onSignOut: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsOneWidget);
      final appBarWidget = tester.widget<AppBar>(find.byType(AppBar));
      final container = appBarWidget.flexibleSpace as Container;
      final boxDecoration = container.decoration as BoxDecoration;
      expect(boxDecoration.gradient, equals(AppTheme.darkNavbarGradient));

      final overlayStyle = appBarWidget.systemOverlayStyle;
      expect(overlayStyle, isNotNull);
      expect(overlayStyle!.statusBarIconBrightness, equals(Brightness.light));
      expect(overlayStyle.systemStatusBarContrastEnforced, isFalse);
    });
  });
}

