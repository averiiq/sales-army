import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class AppTheme {
  // Brand Colors - Client Reference UI Palette (Royal Blue & Clean White)
  static const Color primary = Color(0xFF1E56E2); // Royal Blue
  static const Color primaryDark = Color(0xFF1E3A8A); // Deep Navy
  static const Color primaryLight = Color(0xFF3B82F6); // Lighter Blue
  static const Color accent = Color(0xFFFFCC00); // Signature Brand Yellow
  static const Color accentLight = Color(0xFFFEF08A); // Warm Pastel Yellow
  static const Color accentDark = Color(0xFFF59E0B); // Amber Yellow / Gold
  
  // Reference Color Tokens (Screenshots 1-5)
  static const Color royalBlue = Color(0xFF1E56E2);
  static const Color royalBlueDark = Color(0xFF195CE7);
  static const Color navyDark = Color(0xFF1E3A8A);
  static const Color surfaceLightBlue = Color(0xFFF1F5FD); // Soft Lavender/Blue Quick Action BG
  static const Color surfaceTintBlue = Color(0xFFEFF6FF); // Light Blue Icon & Card BG
  static const Color surfaceMint = Color(0xFFEFFBF4); // Soft Mint Collect Dues BG
  static const Color surfaceAmber = Color(0xFFFFF8E7); // Milestone Banner BG
  static const Color borderAmber = Color(0xFFFDE68A); // Milestone Banner Border
  static const Color surfaceRose = Color(0xFFFEE2E2); // Due Badge BG
  static const Color badgeRed = Color(0xFFDC2626); // Due Badge Text
  static const Color badgeGreen = Color(0xFF16A34A); // Positive / Sales Green Text

  // Brand Palette: Signature Yellow & Royal Blue
  static const Color brandBlue = Color(0xFF1E56E2);
  static const Color brandYellow = Color(0xFFFFCC00);
  static const Color brandYellowDark = Color(0xFFF59E0B);
  static const Color brandYellowLight = Color(0xFFFEF08A);

  // Backward compatibility palette
  static const Color yellowPrimary = Color(0xFFFFCC00); // Signature Brand Yellow
  static const Color yellowGold = Color(0xFFF59E0B);
  static const Color yellowLight = Color(0xFFFEF3C7);
  static const Color yellowWarm = Color(0xFFFFFBEB);
  static const Color yellowSoft = Color(0xFFFEFCE8);
  static const Color yellowSurface = Color(0xFFFFFDF5);
  static const Color yellowBorder = Color(0xFFFDE68A);
  static const Color yellowDark = Color(0xFFD97706);
  static const Color midnight = Color(0xFF0F172A);
  static const Color charcoal = Color(0xFF1E293B);
  static const Color cobalt = Color(0xFF2563EB);
  
  // Status Colors
  static const Color success = Color(0xFF10B981); // Emerald Mint
  static const Color successDark = Color(0xFF059669); // Deep Emerald
  static const Color warning = Color(0xFFF59E0B); // Amber Sun
  static const Color warningDark = Color(0xFFD97706); // Warm Amber
  static const Color error = Color(0xFFF43F5E); // Coral Crimson
  static const Color errorDark = Color(0xFFE11D48); // Deep Ruby
  static const Color purple = Color(0xFF8B5CF6); // Indigo / Violet
  static const Color cyan = Color(0xFF06B6D4); // Neon Cyan
  
  // Neutral Tones
  static const Color background = Colors.white; // Pure White Canvas
  static const Color surface = Colors.white;
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0); // Subtle Slate Border
  static const Color borderLight = Color(0xFFF1F5F9);
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF64748B); // Slate 500
  static const Color textMuted = Color(0xFF94A3B8); // Slate 400
  
  // Clean Ambient Canvas Gradients (Pure White Canvas)
  // 1. Dashboard: Radial gradient with center on executive header and radius 1.35
  static const RadialGradient dashboardAmbientGradient = RadialGradient(
    center: Alignment(-0.55, -0.75),
    radius: 1.35,
    colors: [
      Colors.white,
      Colors.white,
      Colors.white,
    ],
    stops: [0.0, 0.45, 1.0],
  );

  // Dark Ambient Gradients (Deep slate #0F172A to #1E293B with subtle royal navy glow)
  static const RadialGradient dashboardDarkAmbientGradient = RadialGradient(
    center: Alignment(-0.55, -0.75),
    radius: 1.35,
    colors: [
      Color(0xFF1E293B), // Charcoal Slate
      Color(0xFF111827), // Deep Slate
      Color(0xFF0F172A), // Midnight Slate Canvas
    ],
    stops: [0.0, 0.45, 1.0],
  );

  static const LinearGradient darkAmbientGradient = LinearGradient(
    colors: [
      Color(0xFF1E293B),
      Color(0xFF0F172A),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient darkNavbarGradient = LinearGradient(
    colors: [
      Color(0xFF1E293B),
      Color(0xFF0F172A),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Adaptive Ambient Gradient Getters
  static Gradient getDashboardGradient(bool isDark) => isDark ? dashboardDarkAmbientGradient : dashboardAmbientGradient;
  static Gradient getOrdersGradient(bool isDark) => isDark ? darkAmbientGradient : ordersAmbientGradient;
  static Gradient getShopsGradient(bool isDark) => isDark ? darkAmbientGradient : shopsAmbientGradient;
  static Gradient getCollectionsGradient(bool isDark) => isDark ? darkAmbientGradient : collectionsAmbientGradient;
  static Gradient getProfileGradient(bool isDark) => isDark ? darkAmbientGradient : profileAmbientGradient;
  static Gradient getVisitsGradient(bool isDark) => isDark ? darkAmbientGradient : visitsAmbientGradient;
  static Gradient getInventoryGradient(bool isDark) => isDark ? darkAmbientGradient : inventoryAmbientGradient;
  static Gradient getNavbarGradient(bool isDark) => isDark ? darkNavbarGradient : cleanWarmNavbarGradient;

  // 2. Orders Tab: Pure White Canvas
  static const LinearGradient ordersAmbientGradient = LinearGradient(
    colors: [
      Colors.white,
      Colors.white,
      Colors.white,
    ],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    stops: [0.0, 0.25, 1.0],
  );

  // 3. Inventory Tab: Pure White Canvas
  static const LinearGradient inventoryAmbientGradient = LinearGradient(
    colors: [
      Colors.white,
      Colors.white,
      Colors.white,
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.25, 1.0],
  );

  // 4. Shops Tab: Pure White Canvas
  static const LinearGradient shopsAmbientGradient = LinearGradient(
    colors: [
      Colors.white,
      Colors.white,
    ],
  );

  // 5. Visits Tab: Pure White Canvas
  static const LinearGradient visitsAmbientGradient = LinearGradient(
    colors: [
      Colors.white,
      Colors.white,
      Colors.white,
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.35, 1.0],
  );

  // 6. Collections Tab: Pure White Canvas
  static const LinearGradient collectionsAmbientGradient = LinearGradient(
    colors: [
      Colors.white,
      Colors.white,
      Colors.white,
    ],
    begin: Alignment(-0.8, -0.8),
    end: Alignment(0.6, 0.4),
    stops: [0.0, 0.30, 1.0],
  );

  // 7. Profile & Settings Ambient Canvas: Pure White Canvas
  static const LinearGradient profileAmbientGradient = LinearGradient(
    colors: [
      Colors.white,
      Colors.white,
      Colors.white,
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.20, 1.0],
  );

  static const LinearGradient profileHeaderGradient = profileAmbientGradient;

  // 8. Accounts Screen: Pure White Canvas
  static const LinearGradient accountsAmbientGradient = LinearGradient(
    colors: [
      Colors.white,
      Colors.white,
      Colors.white,
    ],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    stops: [0.0, 0.25, 1.0],
  );

  // Clean Navbar Header Gradient (Signature Brand Yellow)
  static const LinearGradient cleanWarmNavbarGradient = LinearGradient(
    colors: [
      Color(0xFFFFD500),
      Color(0xFFFFCC00),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Aliases for compatibility
  static const LinearGradient warmYellowBgGradient = inventoryAmbientGradient;
  static const LinearGradient warmYellowHeaderGradient = cleanWarmNavbarGradient;
  static const RadialGradient softWarmRadialGradient = dashboardAmbientGradient;
  static const LinearGradient softWarmAngledGradient = inventoryAmbientGradient;
  static const LinearGradient softWarmTopRightGradient = ordersAmbientGradient;

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient yellowGradient = LinearGradient(
    colors: [Color(0xFFFFCC00), Color(0xFFFFD500)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cobaltGradient = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient emeraldGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient amberGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient coralGradient = LinearGradient(
    colors: [Color(0xFFF43F5E), Color(0xFFE11D48)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient midnightGradient = LinearGradient(
    colors: [Color(0xFF0B132B), Color(0xFF0F172A), Color(0xFF1E293B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient neonAzureGradient = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient emeraldMintGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static List<BoxShadow> softShadow({
    Color tint = const Color(0xFF0F172A),
    double opacity = 0.06,
    double blur = 16,
    Offset offset = const Offset(0, 4),
    double? dy,
  }) {
    return [
      BoxShadow(
        color: tint.withValues(alpha: opacity),
        blurRadius: blur,
        offset: dy != null ? Offset(offset.dx, dy) : offset,
      ),
    ];
  }

  static List<BoxShadow> floatingShadow({
    Color tint = const Color(0xFF0F172A),
    double opacity = 0.12,
    double blur = 24,
    Offset offset = const Offset(0, 8),
  }) {
    return [
      BoxShadow(
        color: tint.withValues(alpha: opacity),
        blurRadius: blur,
        offset: offset,
      ),
    ];
  }

  static List<BoxShadow> coloredShadow({
    required Color color,
    double opacity = 0.25,
    double blur = 14,
    Offset offset = const Offset(0, 4),
  }) {
    return [
      BoxShadow(
        color: color.withValues(alpha: opacity),
        blurRadius: blur,
        offset: offset,
      ),
    ];
  }

  // Material 3 ThemeData with field-tested tactile dimensions
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: accent,
        surface: surface,
        error: error,
      ),
      scaffoldBackgroundColor: background,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.2,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(88, 48), // Tactile minimum height for field reps
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(88, 48),
          side: const BorderSide(color: border, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: error, width: 1.2),
        ),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 14),
        hintStyle: const TextStyle(color: textMuted, fontSize: 13.5),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF1F5F9),
        selectedColor: primary,
        secondarySelectedColor: primary,
        labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.transparent),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation: 10,
        titleTextStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textPrimary, letterSpacing: -0.2),
        contentTextStyle: const TextStyle(fontSize: 13.5, color: textSecondary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: border, width: 1)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        elevation: 16,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primary,
        inactiveTrackColor: const Color(0xFFE2E8F0),
        thumbColor: primary,
        overlayColor: primary.withValues(alpha: 0.16),
        trackHeight: 6.0,
        trackShape: const RoundedRectSliderTrackShape(),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10.0, elevation: 3),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 22.0),
        tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 3.5),
        activeTickMarkColor: Colors.white.withValues(alpha: 0.7),
        inactiveTickMarkColor: const Color(0xFFCBD5E1),
        valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
        valueIndicatorColor: primary,
        valueIndicatorTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
      ),
      splashFactory: InkRipple.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(),
        },
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F172A),
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 6,
      ),
    );
  }

  // Material 3 Dark ThemeData with modern slate surfaces
  static ThemeData get darkTheme {
    const darkScaffold = Color(0xFF0F172A);
    const darkSurface = Color(0xFF1E293B);
    const darkBorder = Color(0xFF334155);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: darkSurface,
        error: error,
      ),
      scaffoldBackgroundColor: darkScaffold,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: darkScaffold,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: -0.2,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(88, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF60A5FA),
          minimumSize: const Size(88, 48),
          side: const BorderSide(color: darkBorder, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF60A5FA), width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: error, width: 1.2),
        ),
        labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
        hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13.5),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkSurface,
        selectedColor: primary,
        secondarySelectedColor: primary,
        labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: darkBorder),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      dividerTheme: const DividerThemeData(
        color: darkBorder,
        thickness: 1,
        space: 1,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkScaffold,
        selectedItemColor: Color(0xFF60A5FA),
        unselectedItemColor: Color(0xFF94A3B8),
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        elevation: 10,
        titleTextStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.2),
        contentTextStyle: const TextStyle(fontSize: 13.5, color: Color(0xFFCBD5E1)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFF334155), width: 1)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkSurface,
        modalBackgroundColor: darkSurface,
        elevation: 16,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: const Color(0xFF3B82F6),
        inactiveTrackColor: const Color(0xFF334155),
        thumbColor: const Color(0xFF60A5FA),
        overlayColor: const Color(0xFF3B82F6).withValues(alpha: 0.20),
        trackHeight: 6.0,
        trackShape: const RoundedRectSliderTrackShape(),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10.0, elevation: 3),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 22.0),
        tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 3.5),
        activeTickMarkColor: Colors.white.withValues(alpha: 0.8),
        inactiveTickMarkColor: const Color(0xFF475569),
        valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
        valueIndicatorColor: const Color(0xFF1E293B),
        valueIndicatorTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF3B82F6);
          }
          return const Color(0xFF94A3B8);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF1E3A8A);
          }
          return const Color(0xFF334155);
        }),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: Color(0xFF94A3B8),
        indicatorColor: primary,
      ),
      splashFactory: InkRipple.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(),
        },
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: Color(0xFFE2E8F0)),
        bodySmall: TextStyle(color: Color(0xFF94A3B8)),
        titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        titleMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        titleSmall: TextStyle(color: Color(0xFFE2E8F0), fontWeight: FontWeight.w600),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E293B),
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 6,
      ),
    );
  }

  // Component Styling Helpers
  static BoxDecoration cleanCardDecoration({
    Color? bgColor,
    Color? borderColor,
    double borderRadius = 16,
    double shadowOpacity = 0.04,
  }) {
    return BoxDecoration(
      color: bgColor ?? surface,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: borderColor ?? borderLight, width: 1),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: shadowOpacity),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  static BoxDecoration cardDecoration({
    Color? bgColor,
    Color? borderColor,
    double borderRadius = 16,
  }) {
    return BoxDecoration(
      color: bgColor ?? surface,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: borderColor ?? border, width: 1),
      boxShadow: [
        BoxShadow(
          color: const Color(0x0A000000),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  static BoxDecoration gradientCardDecoration(
    LinearGradient gradient, {
    double borderRadius = 18,
  }) {
    return BoxDecoration(
      gradient: gradient,
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: [
        BoxShadow(
          color: gradient.colors.first.withValues(alpha: 0.28),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  static BoxDecoration statusBadgeDecoration({
    required bool isPositive,
    double borderRadius = 8,
  }) {
    final bg = isPositive ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2);
    final border = isPositive ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA);
    return BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: border, width: 1),
    );
  }

  static BoxDecoration capsuleDecoration({
    required Color bgColor,
    required Color borderColor,
    double borderRadius = 20,
    List<BoxShadow>? shadows,
  }) {
    return BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: borderColor, width: 1.0),
      boxShadow: shadows,
    );
  }

  static ButtonStyle yellowButtonStyle({double height = 48, double radius = 12}) {
    return ElevatedButton.styleFrom(
      backgroundColor: brandYellow,
      foregroundColor: const Color(0xFF0F172A),
      elevation: 0,
      minimumSize: Size(88, height),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: Color(0xFF0F172A)),
    );
  }

  static ButtonStyle blueButtonStyle({double height = 48, double radius = 12}) {
    return ElevatedButton.styleFrom(
      backgroundColor: royalBlue,
      foregroundColor: Colors.white,
      elevation: 0,
      minimumSize: Size(88, height),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: Colors.white),
    );
  }
}
