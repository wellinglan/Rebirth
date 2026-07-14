import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart' hide FontFeature;

abstract final class AppTypography {
  static const fontFamilyFallback = <String>[
    'MiSans',
    'HarmonyOS Sans SC',
    'PingFang SC',
    'Microsoft YaHei UI',
    'Microsoft YaHei',
    'Noto Sans CJK SC',
    'Noto Sans SC',
    'Segoe UI',
    'Roboto',
    'Arial',
  ];

  static TextTheme textTheme(ColorScheme colors) {
    return TextTheme(
      displaySmall: _style(
        size: 28,
        lineHeight: 36,
        weight: FontWeight.w600,
        color: colors.onSurface,
      ),
      headlineMedium: _style(
        size: 28,
        lineHeight: 36,
        weight: FontWeight.w600,
        color: colors.onSurface,
      ),
      headlineSmall: _style(
        size: 24,
        lineHeight: 32,
        weight: FontWeight.w600,
        color: colors.onSurface,
      ),
      titleLarge: _style(
        size: 20,
        lineHeight: 28,
        weight: FontWeight.w600,
        color: colors.onSurface,
      ),
      titleMedium: _style(
        size: 16,
        lineHeight: 24,
        weight: FontWeight.w600,
        color: colors.onSurface,
      ),
      titleSmall: _style(
        size: 14,
        lineHeight: 20,
        weight: FontWeight.w500,
        color: colors.onSurface,
      ),
      bodyLarge: _style(
        size: 16,
        lineHeight: 26,
        weight: FontWeight.w400,
        color: colors.onSurface,
      ),
      bodyMedium: _style(
        size: 14,
        lineHeight: 22,
        weight: FontWeight.w400,
        color: colors.onSurface,
      ),
      bodySmall: _style(
        size: 12,
        lineHeight: 18,
        weight: FontWeight.w400,
        color: colors.onSurfaceVariant,
      ),
      labelLarge: _style(
        size: 14,
        lineHeight: 20,
        weight: FontWeight.w500,
        color: colors.onSurface,
      ),
      labelMedium: _style(
        size: 13,
        lineHeight: 18,
        weight: FontWeight.w500,
        color: colors.onSurface,
      ),
      labelSmall: _style(
        size: 12,
        lineHeight: 16,
        weight: FontWeight.w500,
        color: colors.onSurface,
      ),
    );
  }

  static TextStyle numericStyle(TextStyle base) {
    return base.copyWith(
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
  }

  static TextStyle _style({
    required double size,
    required double lineHeight,
    required FontWeight weight,
    required Color color,
  }) {
    return TextStyle(
      color: color,
      fontSize: size,
      height: lineHeight / size,
      fontWeight: weight,
      fontFamilyFallback: fontFamilyFallback,
      letterSpacing: 0,
    );
  }
}
