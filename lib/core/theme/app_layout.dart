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
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
}

abstract final class AppLayout {
  static const double maxContentWidth = 720;
  static const double wideContentWidth = 840;
  static const EdgeInsets pagePadding = EdgeInsets.fromLTRB(20, 16, 20, 24);
  static const double sectionGap = AppSpacing.xl;
  static const double cardGap = AppSpacing.sm;
  static const double fieldGap = AppSpacing.md;
}
