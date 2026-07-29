import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/growth/application/growth_dimension_contributor_registry.dart';
import 'package:rebirth/features/growth/application/growth_projection_engine.dart';
import 'package:rebirth/features/growth/data/contributors/focus_growth_contributor.dart';
import 'package:rebirth/features/growth/data/contributors/recovery_growth_contributor.dart';
import 'package:rebirth/features/growth/data/contributors/reflection_growth_contributor.dart';
import 'package:rebirth/features/growth/data/contributors/subjective_state_growth_contributor.dart';
import 'package:rebirth/features/growth/data/growth_repository_impl.dart';
import 'package:rebirth/features/growth/domain/growth_period.dart';
import 'package:rebirth/features/personal_data/application/personal_data_aggregation_engine.dart';
import 'package:rebirth/features/personal_data/application/personal_data_provider_registry.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_capability.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_contribution.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_fact.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_identifier.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_item.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_privacy.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_provider.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_provider_descriptor.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_quality.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_query.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_value.dart';

void main() {
  late _GrowthProvider today;
  late _GrowthProvider journal;
  late _GrowthProvider health;
  late GrowthRepositoryImpl repository;

  setUp(() {
    today = _GrowthProvider(
      id: 'rebirth.today',
      capabilities: {
        PersonalDataCapability.dailySummary,
        PersonalDataCapability.dailyState,
      },
      sensitivity: PersonalDataSensitivity.standardPrivate,
    );
    journal = _GrowthProvider(
      id: 'rebirth.journal',
      capabilities: {
        PersonalDataCapability.timeline,
        PersonalDataCapability.reflection,
      },
      sensitivity: PersonalDataSensitivity.sensitive,
    );
    health = _GrowthProvider(
      id: 'rebirth.health',
      capabilities: {
        PersonalDataCapability.timeline,
        PersonalDataCapability.wellbeingMetrics,
      },
      sensitivity: PersonalDataSensitivity.highlySensitive,
    );
    repository = _repository(today, journal, health);
  });

  test('7 day load queries the aggregation framework once', () async {
    final snapshot = await repository.loadRecent(GrowthPeriod.sevenDays);

    expect(snapshot.startDate, '2026-07-10');
    expect(snapshot.endDate, '2026-07-16');
    expect(snapshot.days, hasLength(7));
    expect(today.queries, hasLength(1));
    expect(journal.queries, hasLength(1));
    expect(health.queries, hasLength(1));
    expect(
      today.queries.single.requestedCapabilities,
      containsAll({
        PersonalDataCapability.dailyState,
        PersonalDataCapability.reflection,
        PersonalDataCapability.wellbeingMetrics,
      }),
    );
  });

  test('30 day range is ascending and uses a deterministic clock', () async {
    final snapshot = await repository.loadRecent(GrowthPeriod.thirtyDays);

    expect(snapshot.startDate, '2026-06-17');
    expect(snapshot.endDate, '2026-07-16');
    expect(snapshot.days, hasLength(30));
    expect(
      snapshot.projection?.context.generatedAtUtc,
      DateTime.utc(2026, 7, 16, 1),
    );
  });

  test('typed facts preserve null and zero through projection', () async {
    today.itemFactories = [
      (query) => _item(
        providerId: today.descriptor.providerId,
        id: 'today.zero',
        date: '2026-07-15',
        sensitivity: PersonalDataSensitivity.standardPrivate,
        facts: [
          _fact(
            'today.research_duration',
            PersonalDataDurationValue(minutes: 0),
          ),
          _fact(
            'today.mood_score',
            PersonalDataScoreValue(value: 4, minimum: 1, maximum: 5),
          ),
        ],
      ),
    ];
    health.itemFactories = [
      (query) => _item(
        providerId: health.descriptor.providerId,
        id: 'health.day',
        date: '2026-07-15',
        sensitivity: PersonalDataSensitivity.highlySensitive,
        facts: [
          _fact(
            'health.sleep_duration',
            PersonalDataDurationValue(minutes: 450),
            sensitivity: PersonalDataSensitivity.highlySensitive,
          ),
        ],
      ),
    ];
    journal.itemFactories = [
      (query) => _item(
        providerId: journal.descriptor.providerId,
        id: 'journal.draft',
        date: '2026-07-15',
        sensitivity: PersonalDataSensitivity.sensitive,
        facts: [
          _fact(
            'journal.entry_status',
            PersonalDataCategoricalValue('draft'),
            sensitivity: PersonalDataSensitivity.sensitive,
          ),
        ],
      ),
    ];

    final snapshot = await repository.loadRecent(GrowthPeriod.sevenDays);
    final day = snapshot.days.singleWhere(
      (candidate) => candidate.date == '2026-07-15',
    );

    expect(day.researchMinutes, 0);
    expect(day.learningMinutes, isNull);
    expect(day.moodScore, 4);
    expect(day.sleepMinutes, 450);
    expect(day.exerciseMinutes, isNull);
    expect(day.journalRecorded, isTrue);
    expect(day.journalCompleted, isFalse);
  });

  test('one provider failure preserves other dimensions as partial', () async {
    health.error = StateError('private health failure');
    today.itemFactories = [
      (query) => _item(
        providerId: today.descriptor.providerId,
        id: 'today.day',
        date: '2026-07-16',
        sensitivity: PersonalDataSensitivity.standardPrivate,
        facts: [
          _fact(
            'today.research_duration',
            PersonalDataDurationValue(minutes: 30),
          ),
        ],
      ),
    ];

    final snapshot = await repository.loadRecent(GrowthPeriod.sevenDays);

    expect(snapshot.researchSummary.total, 30);
    expect(snapshot.projection?.aggregationResult.failures, hasLength(1));
    expect(snapshot.projection?.quality.isComplete, isFalse);
    expect(
      snapshot.projection?.dimensions.singleWhere(
        (dimension) =>
            dimension.descriptor.dimensionId.value == 'growth.recovery',
      ).quality.isUnavailable,
      isTrue,
    );
  });

  test('Growth implementation has no business repository or Drift imports', () {
    final source = File(
      'lib/features/growth/data/growth_repository_impl.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('TodayRepository')));
    expect(source, isNot(contains('HealthRepository')));
    expect(source, isNot(contains('JournalRepository')));
    expect(source, isNot(contains('PlanRepository')));
    expect(source, isNot(contains('package:drift/')));
    expect(source, contains('PersonalDataAggregationEngine'));
    expect(source, contains('GrowthProjectionEngine'));
  });
}

GrowthRepositoryImpl _repository(
  _GrowthProvider today,
  _GrowthProvider journal,
  _GrowthProvider health,
) {
  return GrowthRepositoryImpl(
    aggregationEngine: PersonalDataAggregationEngine(
      PersonalDataProviderRegistry([today, journal, health]),
    ),
    projectionEngine: GrowthProjectionEngine(
      GrowthDimensionContributorRegistry([
        FocusGrowthContributor(),
        RecoveryGrowthContributor(),
        SubjectiveStateGrowthContributor(),
        ReflectionGrowthContributor(),
      ]),
    ),
    dateTimeService: DateTimeService(now: () => DateTime(2026, 7, 16, 9)),
  );
}

final class _GrowthProvider implements PersonalDataProvider {
  _GrowthProvider({
    required String id,
    required Set<PersonalDataCapability> capabilities,
    required PersonalDataSensitivity sensitivity,
  }) : descriptor = PersonalDataProviderDescriptor(
         providerId: PersonalDataProviderId(id),
         displayName: id,
         description: 'Growth test provider',
         providerSchemaVersion: 1,
         capabilities: capabilities,
         defaultSensitivity: sensitivity,
         displayOrder: 10,
       );

  @override
  final PersonalDataProviderDescriptor descriptor;
  final List<PersonalDataQuery> queries = [];
  List<PersonalDataItem Function(PersonalDataQuery)> itemFactories = [];
  Object? error;

  @override
  Future<PersonalDataContribution> collect(PersonalDataQuery query) async {
    queries.add(query);
    if (error case final error?) throw error;
    return PersonalDataContribution(
      providerId: descriptor.providerId,
      providerSchemaVersion: descriptor.providerSchemaVersion,
      coveredTimeRange: query.timeRange,
      capabilities: descriptor.capabilities,
      sensitivity: descriptor.defaultSensitivity,
      quality: const PersonalDataQuality.complete(),
      items: itemFactories.map((factory) => factory(query)).toList(),
      generatedAtUtc: query.requestedAtUtc,
    );
  }
}

PersonalDataItem _item({
  required PersonalDataProviderId providerId,
  required String id,
  required String date,
  required PersonalDataSensitivity sensitivity,
  required List<PersonalDataFact> facts,
}) {
  return PersonalDataItem(
    id: PersonalDataItemId('${providerId.value}.$id'),
    kind: PersonalDataItemKind('${providerId.value}.test_item'),
    title: date,
    localDate: date,
    sensitivity: sensitivity,
    quality: const PersonalDataQuality.complete(),
    facts: facts,
  );
}

PersonalDataFact _fact(
  String key,
  PersonalDataValue value, {
  PersonalDataSensitivity sensitivity =
      PersonalDataSensitivity.standardPrivate,
}) {
  return PersonalDataFact(
    key: PersonalDataFactKey(key),
    label: key,
    value: value,
    sensitivity: sensitivity,
  );
}
