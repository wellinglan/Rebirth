import 'package:drift/drift.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/wellbeing/wellbeing_score.dart';

import '../../domain/personal_data_capability.dart';
import '../../domain/personal_data_contribution.dart';
import '../../domain/personal_data_fact.dart';
import '../../domain/personal_data_identifier.dart';
import '../../domain/personal_data_item.dart';
import '../../domain/personal_data_privacy.dart';
import '../../domain/personal_data_provider.dart';
import '../../domain/personal_data_provider_descriptor.dart';
import '../../domain/personal_data_query.dart';
import '../../domain/personal_data_value.dart';
import 'personal_data_provider_support.dart';

final class HealthPersonalDataProvider implements PersonalDataProvider {
  const HealthPersonalDataProvider({
    required this.database,
    required this.localUserId,
  });

  static final providerId = PersonalDataProviderId('rebirth.health');

  static final _descriptor = PersonalDataProviderDescriptor(
    providerId: providerId,
    displayName: '健康',
    description: '所选日期的本地健康指标，默认折叠展示',
    providerSchemaVersion: 1,
    capabilities: {
      PersonalDataCapability.timeline,
      PersonalDataCapability.wellbeingMetrics,
    },
    defaultSensitivity: PersonalDataSensitivity.highlySensitive,
    displayOrder: 50,
  );

  final AppDatabase database;
  final String localUserId;

  @override
  PersonalDataProviderDescriptor get descriptor => _descriptor;

  @override
  Future<PersonalDataContribution> collect(PersonalDataQuery query) async {
    final statement = database.select(database.healthRecords)
      ..where(
        (row) =>
            row.userId.equals(localUserId) &
            row.deletedAt.isNull() &
            row.recordDate.isBiggerOrEqualValue(
              query.timeRange.startLocalDate,
            ) &
            row.recordDate.isSmallerOrEqualValue(
              query.timeRange.endLocalDateInclusive,
            ),
      )
      ..orderBy([
        (row) => OrderingTerm.asc(row.recordDate),
        (row) => OrderingTerm.asc(row.id),
      ])
      ..limit(query.maxItemsPerProvider + 1);
    final loaded = await statement.get();
    final wasLimited = loaded.length > query.maxItemsPerProvider;
    final records = loaded.take(query.maxItemsPerProvider).toList();
    final sensitivity = descriptor.defaultSensitivity;
    final hasConflict = records.any(
      (record) => record.syncStatus == 'conflict',
    );

    return PersonalDataContribution(
      providerId: providerId,
      providerSchemaVersion: descriptor.providerSchemaVersion,
      coveredTimeRange: query.timeRange,
      capabilities: descriptor.capabilities,
      sensitivity: sensitivity,
      quality: contributionQuality(
        hasConflict: hasConflict,
        wasLimited: wasLimited,
      ),
      items: [
        for (final record in records)
          PersonalDataItem(
            id: protectedItemId(providerId, record.id),
            kind: PersonalDataItemKind('health.daily_metrics'),
            title: '${record.recordDate} 健康记录',
            localDate: record.recordDate,
            occurredAtUtc: utcDateTimeFromMilliseconds(record.updatedAt),
            facts: _factsFor(record, sensitivity),
            sensitivity: sensitivity,
            quality: qualityForSyncStatus(record.syncStatus),
          ),
      ],
      summaryFacts: [
        fact(
          key: 'health.record_count',
          label: '健康记录',
          value: PersonalDataCountValue(records.length),
          sensitivity: sensitivity,
          unit: '条',
          priority: 0,
        ),
      ],
      generatedAtUtc: query.requestedAtUtc,
    );
  }

  List<PersonalDataFact> _factsFor(
    HealthRecord record,
    PersonalDataSensitivity sensitivity,
  ) {
    final physicalStateScore = normalizeWellbeingScore(
      record.physicalStateScore,
      record.physicalStateScoreScale,
    );
    return [
      fact(
        key: 'health.data_source',
        label: '数据来源',
        value: PersonalDataCategoricalValue(
          _dataSourceLabel(record.dataSource),
        ),
        sensitivity: sensitivity,
        priority: 10,
      ),
      if (record.sleepDurationMinutes != null)
        fact(
          key: 'health.sleep_duration',
          label: '睡眠时长',
          value: PersonalDataDurationValue(
            minutes: record.sleepDurationMinutes!,
          ),
          sensitivity: sensitivity,
          priority: 20,
        ),
      if (record.weightKg != null)
        fact(
          key: 'health.weight',
          label: '体重',
          value: PersonalDataDecimalValue(record.weightKg!),
          sensitivity: sensitivity,
          unit: 'kg',
          priority: 30,
        ),
      if (record.waterIntakeMl != null)
        fact(
          key: 'health.water_intake',
          label: '饮水量',
          value: PersonalDataIntegerValue(record.waterIntakeMl!),
          sensitivity: sensitivity,
          unit: 'ml',
          priority: 40,
        ),
      if (record.exerciseDurationMinutes != null)
        fact(
          key: 'health.exercise_duration',
          label: '运动时长',
          value: PersonalDataDurationValue(
            minutes: record.exerciseDurationMinutes!,
          ),
          sensitivity: sensitivity,
          priority: 50,
        ),
      if (record.exerciseType?.trim().isNotEmpty ?? false)
        fact(
          key: 'health.exercise_type',
          label: '运动类型',
          value: PersonalDataCategoricalValue(record.exerciseType!),
          sensitivity: sensitivity,
          priority: 60,
        ),
      if (physicalStateScore != null)
        fact(
          key: 'health.physical_state_score',
          label: '身体状态',
          value: PersonalDataScoreValue(
            value: physicalStateScore.toDouble(),
            minimum: 1,
            maximum: 10,
          ),
          sensitivity: sensitivity,
          priority: 70,
        ),
      fact(
        key: 'health.note_included',
        label: '备注已展示',
        value: const PersonalDataBooleanValue(false),
        sensitivity: sensitivity,
        priority: 80,
      ),
    ];
  }
}

String _dataSourceLabel(String value) => switch (value) {
  'manual' => '手动记录',
  'health_connect' => 'Health Connect',
  'apple_health' => 'Apple Health',
  _ => '其他来源',
};
