import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/theme/app_typography.dart';

void main() {
  final colors = ColorScheme.fromSeed(seedColor: const Color(0xFF41695D));
  final textTheme = AppTypography.textTheme(colors);

  test('font fallback covers common Chinese desktop platforms', () {
    expect(AppTypography.fontFamilyFallback, isNotEmpty);
    expect(
      AppTypography.fontFamilyFallback,
      containsAll(<String>[
        'Microsoft YaHei UI',
        'PingFang SC',
        'Noto Sans SC',
      ]),
    );
  });

  test('core text roles use the intended hierarchy', () {
    expect(textTheme.bodyMedium, isNotNull);
    expect(textTheme.titleMedium, isNotNull);
    expect(textTheme.headlineSmall, isNotNull);

    expect(textTheme.headlineSmall!.fontSize, 24);
    expect(textTheme.headlineSmall!.height, closeTo(32 / 24, 0.001));
    expect(
      textTheme.headlineSmall!.fontWeight!.value,
      lessThanOrEqualTo(FontWeight.w600.value),
    );
    expect(textTheme.titleMedium!.fontWeight, FontWeight.w600);
    expect(textTheme.bodyMedium!.fontWeight, FontWeight.w400);
    expect(textTheme.bodySmall!.fontSize, greaterThanOrEqualTo(12));
    expect(textTheme.labelLarge!.fontWeight, FontWeight.w500);
  });

  test('titles never use excessively heavy defaults', () {
    final titleStyles = <TextStyle?>[
      textTheme.displaySmall,
      textTheme.headlineMedium,
      textTheme.headlineSmall,
      textTheme.titleLarge,
      textTheme.titleMedium,
      textTheme.titleSmall,
    ];

    for (final style in titleStyles) {
      expect(style, isNotNull);
      expect(
        style!.fontWeight!.value,
        lessThanOrEqualTo(FontWeight.w600.value),
      );
      expect(style.fontWeight, isNot(FontWeight.w300));
    }
  });

  test('all configured roles inherit the same fallback list', () {
    for (final style in <TextStyle?>[
      textTheme.headlineSmall,
      textTheme.titleLarge,
      textTheme.titleMedium,
      textTheme.bodyLarge,
      textTheme.bodyMedium,
      textTheme.bodySmall,
      textTheme.labelLarge,
      textTheme.labelMedium,
      textTheme.labelSmall,
    ]) {
      expect(style?.fontFamilyFallback, AppTypography.fontFamilyFallback);
    }
  });

  test('numericStyle enables tabular figures without changing hierarchy', () {
    final base = textTheme.titleMedium!;
    final numeric = AppTypography.numericStyle(base);

    expect(numeric.fontSize, base.fontSize);
    expect(numeric.fontWeight, base.fontWeight);
    expect(
      numeric.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
  });
}
