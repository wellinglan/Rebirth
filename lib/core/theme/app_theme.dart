import 'package:flutter/material.dart';

import 'app_typography.dart';

abstract final class AppTheme {
  static final ColorScheme _lightColorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF41695D),
    brightness: Brightness.light,
  );

  static final TextTheme _lightTextTheme = AppTypography.textTheme(
    _lightColorScheme,
  );

  static final ThemeData light = ThemeData(
    useMaterial3: true,
    colorScheme: _lightColorScheme,
    fontFamilyFallback: AppTypography.fontFamilyFallback,
    textTheme: _lightTextTheme,
    scaffoldBackgroundColor: _lightColorScheme.surface,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: _lightColorScheme.surface,
      foregroundColor: _lightColorScheme.onSurface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: _lightTextTheme.headlineSmall,
    ),
    inputDecorationTheme: InputDecorationTheme(
      labelStyle: _lightTextTheme.bodyMedium,
      floatingLabelStyle: _lightTextTheme.labelMedium?.copyWith(
        color: _lightColorScheme.primary,
      ),
      hintStyle: _lightTextTheme.bodyMedium?.copyWith(
        color: _lightColorScheme.onSurfaceVariant,
      ),
      helperStyle: _lightTextTheme.bodySmall,
      errorStyle: _lightTextTheme.bodySmall?.copyWith(
        color: _lightColorScheme.error,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      backgroundColor: _lightColorScheme.surfaceContainer,
      indicatorColor: _lightColorScheme.secondaryContainer,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStatePropertyAll(_lightTextTheme.labelMedium),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(textStyle: _lightTextTheme.labelLarge),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(textStyle: _lightTextTheme.labelLarge),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(textStyle: _lightTextTheme.labelLarge),
    ),
  );
}
