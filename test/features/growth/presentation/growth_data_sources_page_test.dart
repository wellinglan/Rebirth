import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rebirth/core/router/route_names.dart';
import 'package:rebirth/features/growth/data/growth_repository_provider.dart';
import 'package:rebirth/features/growth/domain/growth_period.dart';
import 'package:rebirth/features/growth/domain/growth_projection.dart';
import 'package:rebirth/features/growth/domain/growth_projection_context.dart';
import 'package:rebirth/features/growth/domain/growth_repository.dart';
import 'package:rebirth/features/growth/domain/growth_snapshot.dart';
import 'package:rebirth/features/growth/presentation/growth_data_sources_page.dart';
import 'package:rebirth/features/growth/presentation/growth_page.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_aggregation_result.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_query.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_time_range.dart';

import '../growth_test_data.dart';

void main() {
  testWidgets('data sources route reuses projection and preserves period', (
    tester,
  ) async {
    final repository = _FakeGrowthRepository();
    final router = GoRouter(
      initialLocation: RoutePaths.growth,
      routes: [
        GoRoute(
          path: RoutePaths.growth,
          builder: (context, state) => const Scaffold(body: GrowthPage()),
          routes: [
            GoRoute(
              path: 'data-sources',
              builder: (context, state) =>
                  const Scaffold(body: GrowthDataSourcesPage()),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [growthRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('growthPeriodThirtyDays')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('growthDataSourcesEntry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('growthDataSourcesPage')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('growthProjectionOverview')),
      findsOneWidget,
    );
    expect(find.text('数据覆盖与来源'), findsOneWidget);
    expect(find.text('近 30 天 · 6月17日 — 7月16日'), findsOneWidget);
    expect(repository.calls, [GrowthPeriod.sevenDays, GrowthPeriod.thirtyDays]);

    await tester.tap(find.byKey(const ValueKey('growthDataSourcesBackButton')));
    await tester.pumpAndSettle();

    final selector = tester.widget<SegmentedButton<GrowthPeriod>>(
      find.byKey(const ValueKey('growthPeriodSelector')),
    );
    expect(selector.selected, {GrowthPeriod.thirtyDays});
  });

  testWidgets('data sources page fits 320px at 2x text scale', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          growthRepositoryProvider.overrideWithValue(_FakeGrowthRepository()),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const Scaffold(body: GrowthDataSourcesPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('数据说明'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('growthProjectionOverview')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

final class _FakeGrowthRepository implements GrowthRepository {
  final List<GrowthPeriod> calls = [];

  @override
  Future<GrowthSnapshot> loadRecent(GrowthPeriod period) async {
    calls.add(period);
    return growthTestSnapshot(
      period: period,
      projection: _projection(period),
      dataForDay: (index, date) => GrowthDayTestData(
        moodScore: 1 + index % 10,
        energyScore: 10 - index % 10,
      ),
    );
  }
}

GrowthProjection _projection(GrowthPeriod period) {
  final generatedAt = DateTime.utc(2026, 7, 16, 1);
  final startDate = period == GrowthPeriod.sevenDays
      ? '2026-07-10'
      : '2026-06-17';
  final expectedDates = List<String>.generate(period.days, (index) {
    final start = DateTime.parse(startDate);
    final date = DateTime(start.year, start.month, start.day + index);
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  });
  final timeRange = PersonalDataTimeRange.forSystemLocalDateRange(
    startLocalDate: expectedDates.first,
    endLocalDateInclusive: expectedDates.last,
  );
  final query = PersonalDataQuery(
    timeRange: timeRange,
    localTimeContext: const PersonalDataLocalTimeContext(
      timezoneOffsetMinutes: 480,
    ),
    requestedAtUtc: generatedAt,
  );
  return GrowthProjection(
    context: GrowthProjectionContext(
      period: period,
      timeRange: timeRange,
      expectedLocalDates: expectedDates,
      generatedAtUtc: generatedAt,
    ),
    aggregationResult: PersonalDataAggregationResult(
      query: query,
      contributions: const [],
      failures: const [],
      generatedAtUtc: generatedAt,
    ),
    dimensions: const [],
    failures: const [],
  );
}
