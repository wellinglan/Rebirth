import 'package:flutter/material.dart';

import 'app_layout.dart';
import 'app_semantic_colors.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static final ColorScheme _lightColorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF356859),
    brightness: Brightness.light,
  ).copyWith(
    primary: const Color(0xFF356859),
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFD6ECE3),
    onPrimaryContainer: const Color(0xFF102F27),
    secondary: const Color(0xFF6D6249),
    onSecondary: Colors.white,
    secondaryContainer: const Color(0xFFECE4CF),
    onSecondaryContainer: const Color(0xFF302B1D),
    tertiary: const Color(0xFF87574D),
    onTertiary: Colors.white,
    tertiaryContainer: const Color(0xFFFFDAD3),
    onTertiaryContainer: const Color(0xFF3A1610),
    surface: const Color(0xFFF8FAF8),
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: const Color(0xFFF1F5F2),
    surfaceContainer: const Color(0xFFEBF0EC),
    surfaceContainerHigh: const Color(0xFFE5EBE7),
    surfaceContainerHighest: const Color(0xFFDDE5E0),
    onSurface: const Color(0xFF1A211E),
    onSurfaceVariant: const Color(0xFF4A5550),
    outline: const Color(0xFF77827D),
    outlineVariant: const Color(0xFFC5CEC9),
    error: const Color(0xFFB3261E),
    onError: Colors.white,
    errorContainer: const Color(0xFFF9DEDC),
    onErrorContainer: const Color(0xFF410E0B),
  );

  static final TextTheme _lightTextTheme = AppTypography.textTheme(
    _lightColorScheme,
  );

  static final ThemeData light = ThemeData(
    useMaterial3: true,
    colorScheme: _lightColorScheme,
    extensions: const <ThemeExtension<dynamic>>[AppSemanticColors.light],
    fontFamilyFallback: AppTypography.fontFamilyFallback,
    textTheme: _lightTextTheme,
    scaffoldBackgroundColor: _lightColorScheme.surface,
    visualDensity: VisualDensity.standard,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: _lightColorScheme.surface,
      foregroundColor: _lightColorScheme.onSurface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: _lightTextTheme.headlineSmall,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _lightColorScheme.surfaceContainerLowest,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: _lightColorScheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: _lightColorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: _lightColorScheme.primary, width: 2),
      ),
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
        borderRadius: BorderRadius.circular(AppRadius.sm),
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
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      backgroundColor: _lightColorScheme.surfaceContainerLow,
      indicatorColor: _lightColorScheme.secondaryContainer,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStatePropertyAll(_lightTextTheme.labelMedium),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: _lightColorScheme.surfaceContainerLow,
      indicatorColor: _lightColorScheme.secondaryContainer,
      selectedIconTheme: IconThemeData(color: _lightColorScheme.primary),
      unselectedIconTheme: IconThemeData(
        color: _lightColorScheme.onSurfaceVariant,
      ),
      selectedLabelTextStyle: _lightTextTheme.labelMedium?.copyWith(
        color: _lightColorScheme.primary,
      ),
      unselectedLabelTextStyle: _lightTextTheme.labelMedium?.copyWith(
        color: _lightColorScheme.onSurfaceVariant,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, AppLayout.minimumTouchTarget),
        textStyle: _lightTextTheme.labelLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, AppLayout.minimumTouchTarget),
        textStyle: _lightTextTheme.labelLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, AppLayout.minimumTouchTarget),
        textStyle: _lightTextTheme.labelLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size.square(AppLayout.minimumTouchTarget),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(
          Size(48, AppLayout.minimumTouchTarget),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(
          _lightColorScheme.surfaceContainerLowest,
        ),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: _lightColorScheme.inverseSurface,
      contentTextStyle: _lightTextTheme.bodyMedium?.copyWith(
        color: _lightColorScheme.onInverseSurface,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 500),
      textStyle: _lightTextTheme.bodySmall?.copyWith(
        color: _lightColorScheme.onInverseSurface,
      ),
    ),
  );
}
