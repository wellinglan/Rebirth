import 'package:drift/drift.dart';
import 'package:rebirth/core/database/app_database.dart';

import '../../domain/personal_data_capability.dart';
import '../../domain/personal_data_contribution.dart';
import '../../domain/personal_data_identifier.dart';
import '../../domain/personal_data_item.dart';
import '../../domain/personal_data_privacy.dart';
import '../../domain/personal_data_provider.dart';
import '../../domain/personal_data_provider_descriptor.dart';
import '../../domain/personal_data_query.dart';
import '../../domain/personal_data_value.dart';
import 'personal_data_provider_support.dart';

final class PlanPersonalDataProvider implements PersonalDataProvider {
  const PlanPersonalDataProvider({
    required this.database,
    required this.localUserId,
  });

  static final providerId = PersonalDataProviderId('rebirth.plan');

  static final _descriptor = PersonalDataProviderDescriptor(
    providerId: providerId,
    displayName: '计划',
    description: '所选日期范围内相关目标的本地摘要',
    providerSchemaVersion: 1,
    capabilities: {
      PersonalDataCapability.timeline,
      PersonalDataCapability.goalTracking,
    },
    defaultSensitivity: PersonalDataSensitivity.standardPrivate,
    displayOrder: 20,
  );

  final AppDatabase database;
  final String localUserId;

  @override
  PersonalDataProviderDescriptor get descriptor => _descriptor;

  @override
  Future<PersonalDataContribution> collect(PersonalDataQuery query) async {
    final range = query.timeRange;
    final statement = database.select(database.goals)
      ..where(
        (row) =>
            row.userId.equals(localUserId) &
            row.deletedAt.isNull() &
            (row.startDate.isNull() |
                row.startDate.isSmallerOrEqualValue(
                  range.endLocalDateInclusive,
                )) &
            (row.targetDate.isNull() |
                row.targetDate.isBiggerOrEqualValue(range.startLocalDate)),
      )
      ..orderBy([
        (row) => OrderingTerm.asc(row.sortOrder),
        (row) => OrderingTerm.asc(row.targetDate.isNull()),
        (row) => OrderingTerm.asc(row.targetDate),
        (row) => OrderingTerm.asc(row.id),
      ])
      ..limit(query.maxItemsPerProvider + 1);
    final loaded = await statement.get();
    final wasLimited = loaded.length > query.maxItemsPerProvider;
    final goals = loaded.take(query.maxItemsPerProvider).toList();
    final sensitivity = descriptor.defaultSensitivity;
    final hasConflict = goals.any((goal) => goal.syncStatus == 'conflict');

    return PersonalDataContribution(
      providerId: providerId,
      providerSchemaVersion: descriptor.providerSchemaVersion,
      coveredTimeRange: range,
      capabilities: descriptor.capabilities,
      sensitivity: sensitivity,
      quality: contributionQuality(
        hasConflict: hasConflict,
        wasLimited: wasLimited,
      ),
      items: [
        for (final goal in goals)
          PersonalDataItem(
            id: protectedItemId(providerId, goal.id),
            kind: PersonalDataItemKind('plan.goal'),
            title: boundedTitle(goal.title, fallback: '未命名目标'),
            localDate: goal.targetDate ?? goal.startDate,
            occurredAtUtc: utcDateTimeFromMilliseconds(goal.updatedAt),
            displayOrder: goal.sortOrder,
            facts: [
              fact(
                key: 'plan.goal_level',
                label: '层级',
                value: PersonalDataCategoricalValue(
                  _goalLevelLabel(goal.goalLevel),
                ),
                sensitivity: sensitivity,
                priority: 10,
              ),
              fact(
                key: 'plan.status',
                label: '状态',
                value: PersonalDataCategoricalValue(
                  _goalStatusLabel(goal.status),
                ),
                sensitivity: sensitivity,
                priority: 20,
              ),
              fact(
                key: 'plan.has_parent',
                label: '有上级目标',
                value: PersonalDataPresenceValue(goal.parentGoalId != null),
                sensitivity: sensitivity,
                priority: 30,
              ),
              fact(
                key: 'plan.archived',
                label: '已归档',
                value: PersonalDataBooleanValue(goal.archivedAt != null),
                sensitivity: sensitivity,
                priority: 40,
              ),
              if (goal.startDate != null)
                fact(
                  key: 'plan.start_date',
                  label: '开始日期',
                  value: PersonalDataDateValue(goal.startDate!),
                  sensitivity: sensitivity,
                  priority: 50,
                ),
              if (goal.targetDate != null)
                fact(
                  key: 'plan.target_date',
                  label: '目标日期',
                  value: PersonalDataDateValue(goal.targetDate!),
                  sensitivity: sensitivity,
                  priority: 60,
                ),
            ],
            sensitivity: sensitivity,
            quality: qualityForSyncStatus(goal.syncStatus),
          ),
      ],
      summaryFacts: [
        fact(
          key: 'plan.goal_count',
          label: '相关目标',
          value: PersonalDataCountValue(goals.length),
          sensitivity: sensitivity,
          unit: '项',
          priority: 0,
        ),
        fact(
          key: 'plan.completed_count',
          label: '已完成',
          value: PersonalDataCountValue(
            goals.where((goal) => goal.status == 'completed').length,
          ),
          sensitivity: sensitivity,
          unit: '项',
          priority: 10,
        ),
        fact(
          key: 'plan.archived_count',
          label: '已归档',
          value: PersonalDataCountValue(
            goals.where((goal) => goal.archivedAt != null).length,
          ),
          sensitivity: sensitivity,
          unit: '项',
          priority: 20,
        ),
      ],
      generatedAtUtc: query.requestedAtUtc,
    );
  }
}

String _goalLevelLabel(String value) => switch (value) {
  'life' => '人生',
  'year' => '年度',
  'quarter' => '季度',
  'month' => '月度',
  'week' => '周度',
  'day' => '每日',
  'custom' => '自定义',
  _ => '未知层级',
};

String _goalStatusLabel(String value) => switch (value) {
  'not_started' => '未开始',
  'in_progress' => '进行中',
  'completed' => '已完成',
  'paused' => '已暂停',
  'cancelled' => '已取消',
  _ => '未知状态',
};
