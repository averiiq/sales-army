import 'package:flutter/material.dart';

/// Extension on [BuildContext] to provide intuitive responsive helpers across all screen sizes:
/// - Compact phones (< 360dp, e.g. iPhone SE, small Androids)
/// - Standard phones (360dp - 599dp)
/// - Tablets & Foldables (600dp - 1023dp)
/// - Large screens / Desktop / Web (>= 1024dp)
extension ResponsiveContext on BuildContext {
  MediaQueryData get mediaQuery => MediaQuery.of(this);
  Size get screenSize => mediaQuery.size;
  double get screenWidth => screenSize.width;
  double get screenHeight => screenSize.height;

  /// Extra small phones (e.g. 320px width)
  bool get isCompact => screenWidth < 360;

  /// Standard phone or compact
  bool get isMobile => screenWidth < 600;

  /// Tablet or unfolded foldable
  bool get isTablet => screenWidth >= 600 && screenWidth < 1024;

  /// Large tablet, desktop, or web
  bool get isDesktop => screenWidth >= 1024;

  /// Choose a value dynamically based on screen size
  T responsive<T>({
    required T mobile,
    T? compact,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop && desktop != null) return desktop;
    if (isTablet && tablet != null) return tablet;
    if (isCompact && compact != null) return compact;
    return mobile;
  }

  /// Responsive grid columns for card collections (e.g. inventory, shop list)
  int get gridColumns {
    if (screenWidth >= 1200) return 4;
    if (screenWidth >= 800) return 3;
    if (screenWidth >= 600) return 3;
    return 2;
  }

  /// Dynamic horizontal padding that prevents edge crowding on small screens
  /// and excessive stretching on wide screens
  double get horizontalPadding {
    if (screenWidth >= 1024) return 32.0;
    if (screenWidth >= 600) return 24.0;
    if (isCompact) return 10.0;
    return 16.0;
  }

  /// Dynamic dialog width constraint
  double get maxDialogWidth {
    if (screenWidth >= 900) return 600.0;
    if (screenWidth >= 600) return 500.0;
    return screenWidth * 0.92;
  }
}

/// A wrapper widget that constrains content to a sensible maximum width on tablets/desktops
/// while centering it cleanly.
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = 1200,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Padding(
        padding: padding ?? EdgeInsets.zero,
        child: child,
      ),
    );

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }

    return Center(child: content);
  }
}
