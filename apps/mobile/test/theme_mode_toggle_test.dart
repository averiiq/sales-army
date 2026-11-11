import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/core/theme/app_theme.dart';
import 'package:salesarmy/core/navigation/main_shell.dart';
import 'package:salesarmy/features/profile/presentation/screens/profile_and_settings_screen.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('Light & Dark Theme Functionality Tests', () {
    test('AppState initial theme is light and toggles to dark and back', () {
      final appState = AppState();
      expect(appState.themeMode, ThemeMode.light);
      expect(appState.isDarkMode, false);

      appState.toggleTheme();
      expect(appState.themeMode, ThemeMode.dark);
      expect(appState.isDarkMode, true);

      appState.toggleTheme();
      expect(appState.themeMode, ThemeMode.light);
      expect(appState.isDarkMode, false);
    });

    test('AppState setThemeMode explicitly sets dark and light mode', () {
      final appState = AppState();
      appState.setThemeMode(ThemeMode.dark);
      expect(appState.themeMode, ThemeMode.dark);
      expect(appState.isDarkMode, true);

      appState.setThemeMode(ThemeMode.light);
      expect(appState.themeMode, ThemeMode.light);
      expect(appState.isDarkMode, false);
    });

    test('AppState loads theme from SharedPreferences on initialization', () async {
      SharedPreferences.setMockInitialValues({'app_theme_mode': 'dark'});
      final appState = AppState();
      // Allow async SharedPreferences load to complete
      await Future.delayed(const Duration(milliseconds: 50));
      expect(appState.themeMode, ThemeMode.dark);
      expect(appState.isDarkMode, true);
    });

    test('AppTheme adaptive gradients return dark ambient gradient when isDark is true', () {
      final darkDash = AppTheme.getDashboardGradient(true);
      final lightDash = AppTheme.getDashboardGradient(false);
      expect(darkDash, AppTheme.dashboardDarkAmbientGradient);
      expect(lightDash, AppTheme.dashboardAmbientGradient);

      final darkOrders = AppTheme.getOrdersGradient(true);
      final lightOrders = AppTheme.getOrdersGradient(false);
      expect(darkOrders, AppTheme.darkAmbientGradient);
      expect(lightOrders, AppTheme.ordersAmbientGradient);

      final darkShops = AppTheme.getShopsGradient(true);
      final lightShops = AppTheme.getShopsGradient(false);
      expect(darkShops, AppTheme.darkAmbientGradient);
      expect(lightShops, AppTheme.shopsAmbientGradient);

      final darkNav = AppTheme.getNavbarGradient(true);
      final lightNav = AppTheme.getNavbarGradient(false);
      expect(darkNav, AppTheme.darkNavbarGradient);
      expect(lightNav, AppTheme.cleanWarmNavbarGradient);
    });

    testWidgets('ProfileAndSettingsScreen displays Dark Mode toggle and switches state', (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final appState = AppState();
      expect(appState.isDarkMode, false);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: appState.themeMode,
            home: const ProfileAndSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find Dark Theme Mode tile
      expect(find.text('Dark Theme Mode'), findsOneWidget);

      // Find switch widget
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsWidgets);

      // Ensure switch is scrolled into view and tap it
      await tester.ensureVisible(find.widgetWithText(SwitchListTile, 'Dark Theme Mode'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(SwitchListTile, 'Dark Theme Mode'));
      await tester.pumpAndSettle();

      // AppState must now be in dark mode
      expect(appState.isDarkMode, true);
      expect(appState.themeMode, ThemeMode.dark);
    });

    testWidgets('MainShell adapts navigation and shell styling in dark mode', (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final appState = AppState();
      appState.setThemeMode(ThemeMode.dark);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: appState.themeMode,
            home: MainShell(onSignOut: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify MainShell renders tabs
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Parties'), findsOneWidget);
      expect(find.text('Bill'), findsOneWidget);
      expect(find.text('Orders'), findsOneWidget);
      expect(find.text('Collection'), findsOneWidget);
    });
  });
}
