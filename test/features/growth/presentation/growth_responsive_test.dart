import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/growth/data/growth_repository_provider.dart';
import 'package:rebirth/features/growth/domain/growth_period.dart';
import 'package:rebirth/features/growth/domain/growth_repository.dart';
import 'package:rebirth/features/growth/domain/growth_snapshot.dart';
import 'package:rebirth/features/growth/presentation/growth_page.dart';

import '../growth_test_data.dart';

void main() {
  final cases = <({double width, double textScale})>[
    (width: 320, textScale: 2),
    (width: 360, textScale: 1.5),
    (width: 412, textScale: 1.3),
    (width: 720, textScale: 2),
    (width: 840, textScale: 1.5),
    (width: 1200, textScale: 1),
  ];

  for (final testCase in cases) {
    testWidgets(
      '${testCase.width}px at ${testCase.textScale}x text has no overflow',
      (tester) async {
        final snapshot = _completeSnapshot();
        await _pumpPage(
          tester,
          _FakeGrowthRepository(snapshot),
          size: Size(testCase.width, 900),
          textScale: testCase.textScale,
        );

        expect(tester.takeException(), isNull);
        await _scrollTo(tester, const ValueKey('growthDailyDetails'));
        await tester.tap(
          find.byKey(const ValueKey('growthDailyDetailsToggle')),
        );
        await tester.pumpAndSettle();
        await _scrollTo(tester, const ValueKey('growthDailyDetail_2026-07-16'));

        expect(find.text('Journal：已完成'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('refresh failure fits 320px at 2x text scale', (tester) async {
    final repository = _FakeGrowthRepository(_completeSnapshot());
    await _pumpPage(
      tester,
      repository,
      size: const Size(320, 900),
      textScale: 2,
    );

    repository.nextError = StateError('refresh failed');
    await tester.tap(find.byKey(const ValueKey('refreshGrowthButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('growthRefreshError')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

GrowthSnapshot _completeSnapshot() {
  return growthTestSnapshot(
    dataForDay: (index, date) => GrowthDayTestData(
      researchMinutes: index == 0 ? 0 : 30 + index,
      learningMinutes: 45 + index,
      exerciseMinutes: 20 + index,
      sleepMinutes: 420 + index,
      moodScore: 1 + index % 5,
      energyScore: 5 - index % 5,
      journalRecorded: true,
      journalCompleted: index.isEven,
    ),
  );
}

Future<void> _pumpPage(
  WidgetTester tester,
  GrowthRepository repository, {
  required Size size,
  required double textScale,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [growthRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const Scaffold(body: GrowthPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, Key key) async {
  await tester.scrollUntilVisible(
    find.byKey(key),
    500,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

final class _FakeGrowthRepository implements GrowthRepository {
  _FakeGrowthRepository(this.snapshot);

  final GrowthSnapshot snapshot;
  Object? nextError;

  @override
  Future<GrowthSnapshot> loadRecent(GrowthPeriod period) async {
    final error = nextError;
    nextError = null;
    if (error != null) {
      throw error;
    }
    return snapshot;
  }
}
