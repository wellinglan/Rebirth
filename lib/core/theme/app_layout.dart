import 'package:flutter/widgets.dart';

abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
}

abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 10;
  static const double lg = 14;
  static const double xl = 18;
}

abstract final class AppLayout {
  static const double compactBreakpoint = 600;
  static const double navigationRailBreakpoint = 840;
  static const double expandedNavigationBreakpoint = 1200;
  static const double maxContentWidth = 720;
  static const double wideContentWidth = 840;
  static const double minimumTouchTarget = 48;
  static const EdgeInsets pagePadding = EdgeInsets.fromLTRB(20, 16, 20, 24);
  static const double sectionGap = AppSpacing.xl;
  static const double cardGap = AppSpacing.sm;
  static const double fieldGap = AppSpacing.md;

  static EdgeInsets pagePaddingFor(double width) {
    if (width < compactBreakpoint) {
      return const EdgeInsets.fromLTRB(16, 12, 16, 24);
    }
    if (width < expandedNavigationBreakpoint) {
      return pagePadding;
    }
    return const EdgeInsets.fromLTRB(32, 20, 32, 32);
  }

  static bool usesNavigationRail(double width) =>
      width >= navigationRailBreakpoint;

  static bool usesExpandedNavigation(double width, double textScale) =>
      width >= expandedNavigationBreakpoint && textScale < 2;
}
