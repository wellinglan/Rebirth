import 'package:flutter/material.dart';

import 'app_layout.dart';
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
    cardTheme: CardThemeData(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: _lightColorScheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: _lightColorScheme.outlineVariant,
      space: 1,
      thickness: 1,
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xxs,
      ),
      titleTextStyle: _lightTextTheme.titleMedium,
      subtitleTextStyle: _lightTextTheme.bodyMedium,
      iconColor: _lightColorScheme.onSurfaceVariant,
    ),
    chipTheme: ChipThemeData(
      labelStyle: _lightTextTheme.labelMedium,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      side: BorderSide(color: _lightColorScheme.outlineVariant),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: _lightColorScheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: _lightTextTheme.titleLarge,
      contentTextStyle: _lightTextTheme.bodyMedium,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
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
