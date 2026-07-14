import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/theme/app_theme.dart';
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
