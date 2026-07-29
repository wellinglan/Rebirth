import 'package:drift/drift.dart';
import 'package:rebirth/core/database/app_database.dart';

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

final class TodayPersonalDataProvider implements PersonalDataProvider {
  const TodayPersonalDataProvider({
    required this.database,
    required this.localUserId,
  });

  static final providerId = PersonalDataProviderId('rebirth.today');

  static final _descriptor = PersonalDataProviderDescriptor(
    providerId: providerId,
    displayName: '今日',
    description: '所选日期的 Today 本地状态摘要',
    providerSchemaVersion: 1,
    capabilities: {
      PersonalDataCapability.dailySummary,
      PersonalDataCapability.dailyState,
    },
    defaultSensitivity: PersonalDataSensitivity.standardPrivate,
    displayOrder: 30,
  );

  final AppDatabase database;
  final String localUserId;

  @override
  PersonalDataProviderDescriptor get descriptor => _descriptor;

  @override
  Future<PersonalDataContribution> collect(PersonalDataQuery query) async {
    final statement = database.select(database.todayRecords)
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
            kind: PersonalDataItemKind('today.daily_record'),
            title: '${record.recordDate} Today',
            localDate: record.recordDate,
            occurredAtUtc: utcDateTimeFromMilliseconds(record.updatedAt),
            facts: _factsFor(record, sensitivity),
            sensitivity: sensitivity,
            quality: qualityForSyncStatus(record.syncStatus),
          ),
      ],
      summaryFacts: [
        fact(
          key: 'today.record_count',
          label: '记录数',
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
    TodayRecord record,
    PersonalDataSensitivity sensitivity,
  ) {
    final priorities = [
      (record.priority1, record.priority1Completed),
      (record.priority2, record.priority2Completed),
      (record.priority3, record.priority3Completed),
    ];
    final populated = priorities
        .where((entry) => entry.$1?.trim().isNotEmpty ?? false)
        .toList(growable: false);
    return [
      fact(
        key: 'today.priority_count',
        label: '已填写重点',
        value: PersonalDataCountValue(populated.length),
        sensitivity: sensitivity,
        unit: '项',
        priority: 10,
      ),
      fact(
        key: 'today.priority_completed_count',
        label: '已完成重点',
        value: PersonalDataCountValue(
          populated.where((entry) => entry.$2).length,
        ),
        sensitivity: sensitivity,
        unit: '项',
        priority: 20,
      ),
      if (record.moodScore != null)
        fact(
          key: 'today.mood_score',
          label: '心情',
          value: PersonalDataScoreValue(
            value: record.moodScore!.toDouble(),
            minimum: 1,
            maximum: 5,
          ),
          sensitivity: sensitivity,
          priority: 30,
        ),
      if (record.energyScore != null)
        fact(
          key: 'today.energy_score',
          label: '精力',
          value: PersonalDataScoreValue(
            value: record.energyScore!.toDouble(),
            minimum: 1,
            maximum: 5,
          ),
          sensitivity: sensitivity,
          priority: 40,
        ),
      if (record.researchMinutes != null)
        fact(
          key: 'today.research_duration',
          label: '科研时间',
          value: PersonalDataDurationValue(minutes: record.researchMinutes!),
          sensitivity: sensitivity,
          priority: 50,
        ),
      if (record.learningMinutes != null)
        fact(
          key: 'today.learning_duration',
          label: '学习时间',
          value: PersonalDataDurationValue(minutes: record.learningMinutes!),
          sensitivity: sensitivity,
          priority: 60,
        ),
      fact(
        key: 'today.record_status',
        label: '记录状态',
        value: PersonalDataCategoricalValue(
          record.recordStatus == 'completed' ? '已完成' : '草稿',
        ),
        sensitivity: sensitivity,
        priority: 70,
      ),
    ];
  }
}
