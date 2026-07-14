import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/theme/app_theme.dart';
import 'package:rebirth/core/theme/app_layout.dart';
import 'package:rebirth/core/theme/app_typography.dart';

void main() {
  test('light theme uses Material 3 and the Rebirth text hierarchy', () {
    final theme = AppTheme.light;

    expect(theme.useMaterial3, isTrue);
    expect(theme.textTheme.bodyMedium, isNotNull);
    expect(theme.textTheme.headlineSmall, isNotNull);
    expect(theme.colorScheme.brightness, Brightness.light);
    expect(
      theme.textTheme.bodyMedium?.fontFamilyFallback,
      AppTypography.fontFamilyFallback,
    );
  });

  test('navigation, inputs, and buttons use theme text roles', () {
    final theme = AppTheme.light;
    final navigationStyle = theme.navigationBarTheme.labelTextStyle?.resolve(
      const <WidgetState>{},
    );
    final filledButtonStyle = theme.filledButtonTheme.style?.textStyle?.resolve(
      const <WidgetState>{},
    );

    expect(navigationStyle?.fontWeight, FontWeight.w500);
    expect(
      navigationStyle?.fontFamilyFallback,
      AppTypography.fontFamilyFallback,
    );
    expect(filledButtonStyle?.fontWeight, FontWeight.w500);
    expect(theme.inputDecorationTheme.errorStyle?.fontSize, 12);
    expect(theme.inputDecorationTheme.helperStyle?.fontSize, 12);
  });

  test(
    'cards, dialogs, dividers, list tiles, and chips share visual basics',
    () {
      final theme = AppTheme.light;

      expect(theme.cardTheme.shape, isNotNull);
      expect(theme.dialogTheme.shape, isNotNull);
      expect(theme.dividerTheme.thickness, 1);
      expect(theme.dividerTheme.color, isNotNull);
      expect(theme.listTileTheme.contentPadding, isNotNull);
      expect(theme.chipTheme.shape, isNotNull);
    },
  );

  test('layout constants provide an increasing spacing scale', () {
    expect([
      AppSpacing.xxs,
      AppSpacing.xs,
      AppSpacing.sm,
      AppSpacing.md,
      AppSpacing.lg,
      AppSpacing.xl,
      AppSpacing.xxl,
    ], orderedEquals([4, 8, 12, 16, 20, 24, 32]));
    expect(AppRadius.sm, lessThan(AppRadius.md));
    expect(AppRadius.md, lessThan(AppRadius.lg));
    expect(AppRadius.lg, lessThan(AppRadius.xl));
    expect(AppLayout.maxContentWidth, 720);
    expect(AppLayout.wideContentWidth, 840);
  });

  test('typography polish adds no bundled or network font dependency', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, isNot(contains('google_fonts')));

    final fontExtensions = <String>{'.ttf', '.otf', '.woff', '.woff2'};
    final fontFiles = Directory.current
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) {
          final relative = file.path
              .substring(Directory.current.path.length + 1)
              .replaceAll('\\', '/');
          if (relative.startsWith('build/') ||
              relative.startsWith('.dart_tool/') ||
              relative.startsWith('.git/') ||
              relative.contains('/ephemeral/')) {
            return false;
          }
          final lower = relative.toLowerCase();
          return fontExtensions.any(lower.endsWith);
        })
        .toList(growable: false);

    expect(fontFiles, isEmpty);
  });

  test('database schema remains version 3', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    expect(database.schemaVersion, 3);
  });
}
