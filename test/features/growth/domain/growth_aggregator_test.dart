import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/growth/application/growth_dimension_contributor_registry.dart';
import 'package:rebirth/features/growth/application/growth_projection_engine.dart';
import 'package:rebirth/features/growth/domain/growth_aggregator.dart';
import 'package:rebirth/features/growth/domain/growth_coverage.dart';
import 'package:rebirth/features/growth/domain/growth_dimension_contributor.dart';
import 'package:rebirth/features/growth/domain/growth_dimension_descriptor.dart';
import 'package:rebirth/features/growth/domain/growth_dimension_projection.dart';
import 'package:rebirth/features/growth/domain/growth_identifier.dart';
import 'package:rebirth/features/growth/domain/growth_period.dart';
import 'package:rebirth/features/growth/domain/growth_projection_context.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_aggregation_result.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_capability.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_privacy.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_query.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_quality.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_time_range.dart';

void main() {
  test('registry rejects duplicate dimension IDs', () {
    expect(
      () => GrowthDimensionContributorRegistry([
        _Contributor('future.one'),
        _Contributor('future.one'),
      ]),
      throwsArgumentError,
    );
  });

  test('registry is stable and supports future capabilities', () {
    final custom = PersonalDataCapability('future.growth_progress');
    final second = _Contributor('future.second', capability: custom, order: 20);
    final first = _Contributor('future.first', capability: custom, order: 10);
    final registry = GrowthDimensionContributorRegistry([second, first]);

    expect(
      registry.contributors.map((item) => item.descriptor.dimensionId.value),
      ['future.first', 'future.second'],
    );
    expect(registry.requiring(custom), [first, second]);
  });

  test('one contributor failure does not remove healthy dimensions', () {
    final context = _context();
    final result = _aggregation(context);
    final engine = GrowthProjectionEngine(
      GrowthDimensionContributorRegistry([
        _Contributor('future.healthy'),
        _Contributor('future.failed', fail: true),
      ]),
    );

    final projection = engine.project(result, context);

    expect(projection.dimensions, hasLength(1));
    expect(projection.failures, hasLength(1));
    expect(projection.quality.isComplete, isFalse);
  });

  test('compatibility mapper creates missing Journal days safely', () {
    final context = _context();
    final projection = GrowthProjectionEngine(
      GrowthDimensionContributorRegistry([_Contributor('future.empty')]),
    ).project(_aggregation(context), context);

    final snapshot = const GrowthAggregator().aggregate(
      period: GrowthPeriod.sevenDays,
      dateRange: context.expectedLocalDates,
      projection: projection,
    );

    expect(snapshot.days, hasLength(7));
    expect(snapshot.days.every((day) => !day.journalRecorded), isTrue);
    expect(snapshot.projection, same(projection));
  });
}

final class _Contributor implements GrowthDimensionContributor {
  _Contributor(
    String id, {
    PersonalDataCapability? capability,
    int order = 10,
    this.fail = false,
  }) : descriptor = GrowthDimensionDescriptor(
         dimensionId: GrowthDimensionId(id),
         displayName: id,
         description: 'Future test contributor',
         requiredCapabilities: {
           capability ?? PersonalDataCapability.timeline,
         },
         sensitivity: PersonalDataSensitivity.standardPrivate,
         displayOrder: order,
       );

  @override
  final GrowthDimensionDescriptor descriptor;
  final bool fail;

  @override
  Set<PersonalDataCapability> get requiredCapabilities =>
      descriptor.requiredCapabilities;

  @override
  GrowthDimensionProjection project(
    PersonalDataAggregationResult result,
    GrowthProjectionContext context,
  ) {
    if (fail) throw StateError('private contributor failure');
    return GrowthDimensionProjection(
      descriptor: descriptor,
      metrics: const [],
      coverage: GrowthCoverage.fromObserved(
        observedCount: 0,
        expectedCount: context.period.days,
      ),
      quality: const PersonalDataQuality.partial('no_observations'),
      sensitivity: descriptor.sensitivity,
    );
  }
}

GrowthProjectionContext _context() {
  final dates = [
    '2026-07-10',
    '2026-07-11',
    '2026-07-12',
    '2026-07-13',
    '2026-07-14',
    '2026-07-15',
    '2026-07-16',
  ];
  final range = PersonalDataTimeRange.forSystemLocalDateRange(
    startLocalDate: dates.first,
    endLocalDateInclusive: dates.last,
  );
  return GrowthProjectionContext(
    period: GrowthPeriod.sevenDays,
    timeRange: range,
    expectedLocalDates: dates,
    generatedAtUtc: DateTime.utc(2026, 7, 16, 1),
  );
}

PersonalDataAggregationResult _aggregation(
  GrowthProjectionContext context,
) {
  return PersonalDataAggregationResult(
    query: PersonalDataQuery(
      timeRange: context.timeRange,
      localTimeContext: const PersonalDataLocalTimeContext(
        timezoneOffsetMinutes: 480,
      ),
      requestedAtUtc: context.generatedAtUtc,
    ),
    contributions: const [],
    failures: const [],
    generatedAtUtc: context.generatedAtUtc,
  );
}
