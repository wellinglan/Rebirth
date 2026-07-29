import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/growth/domain/growth_coverage.dart';
import 'package:rebirth/features/growth/domain/growth_dimension_descriptor.dart';
import 'package:rebirth/features/growth/domain/growth_dimension_projection.dart';
import 'package:rebirth/features/growth/domain/growth_identifier.dart';
import 'package:rebirth/features/growth/domain/growth_period.dart';
import 'package:rebirth/features/growth/domain/growth_projection.dart';
import 'package:rebirth/features/growth/domain/growth_projection_context.dart';
import 'package:rebirth/features/growth/domain/growth_projection_failure.dart';
import 'package:rebirth/features/growth/presentation/widgets/growth_projection_overview.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_aggregation_result.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_capability.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_privacy.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_query.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_quality.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_time_range.dart';

void main() {
  testWidgets('renders an unknown future dimension without UI branching', (
    tester,
  ) async {
    final projection = _projection(
      dimensions: [
        GrowthDimensionProjection(
          descriptor: GrowthDimensionDescriptor(
            dimensionId: GrowthDimensionId('future.resilience'),
            displayName: 'Future Resilience',
            description: 'A dimension supplied by a future contributor.',
            requiredCapabilities: {
              PersonalDataCapability('future.resilience_signal'),
            },
            sensitivity: PersonalDataSensitivity.sensitive,
          ),
          metrics: const [],
          coverage: GrowthCoverage.fromObserved(
            observedCount: 1,
            expectedCount: 7,
          ),
          quality: const PersonalDataQuality.partial('limited_history'),
          sensitivity: PersonalDataSensitivity.sensitive,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: GrowthProjectionOverview(projection: projection),
          ),
        ),
      ),
    );

    expect(find.text('Future Resilience'), findsOneWidget);
    expect(find.text('覆盖 1 / 7 天 · 缺失 6 天'), findsOneWidget);
    expect(find.text('质量：部分可用'), findsOneWidget);
    expect(find.text('敏感'), findsOneWidget);
  });

  testWidgets('shows a contributor failure without hiding healthy dimensions', (
    tester,
  ) async {
    final projection = _projection(
      dimensions: [
        GrowthDimensionProjection(
          descriptor: GrowthDimensionDescriptor(
            dimensionId: GrowthDimensionId('future.healthy'),
            displayName: 'Healthy Dimension',
            description: 'Still available.',
            requiredCapabilities: {PersonalDataCapability.timeline},
            sensitivity: PersonalDataSensitivity.standardPrivate,
          ),
          metrics: const [],
          coverage: GrowthCoverage.fromObserved(
            observedCount: 0,
            expectedCount: 7,
          ),
          quality: const PersonalDataQuality.partial('no_observations'),
          sensitivity: PersonalDataSensitivity.standardPrivate,
        ),
      ],
      failures: [
        GrowthProjectionFailure(
          dimensionId: GrowthDimensionId('future.failed'),
          reasonCode: 'contributor_failure',
          message: '该维度暂时无法计算。',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: GrowthProjectionOverview(projection: projection),
          ),
        ),
      ),
    );

    expect(find.text('Healthy Dimension'), findsOneWidget);
    expect(find.text('部分成长维度暂不可用'), findsOneWidget);
    expect(find.text('该维度暂时无法计算。'), findsOneWidget);
  });
}

GrowthProjection _projection({
  required List<GrowthDimensionProjection> dimensions,
  List<GrowthProjectionFailure> failures = const [],
}) {
  final generatedAt = DateTime.utc(2026, 7, 29, 1);
  final dates = [
    '2026-07-23',
    '2026-07-24',
    '2026-07-25',
    '2026-07-26',
    '2026-07-27',
    '2026-07-28',
    '2026-07-29',
  ];
  final timeRange = PersonalDataTimeRange.forSystemLocalDateRange(
    startLocalDate: dates.first,
    endLocalDateInclusive: dates.last,
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
      period: GrowthPeriod.sevenDays,
      timeRange: timeRange,
      expectedLocalDates: dates,
      generatedAtUtc: generatedAt,
    ),
    aggregationResult: PersonalDataAggregationResult(
      query: query,
      contributions: const [],
      failures: const [],
      generatedAtUtc: generatedAt,
    ),
    dimensions: dimensions,
    failures: failures,
  );
}
