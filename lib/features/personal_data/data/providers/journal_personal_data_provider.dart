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

final class JournalPersonalDataProvider implements PersonalDataProvider {
  const JournalPersonalDataProvider({
    required this.database,
    required this.localUserId,
  });

  static final providerId = PersonalDataProviderId('rebirth.journal');

  static final _descriptor = PersonalDataProviderDescriptor(
    providerId: providerId,
    displayName: '复盘',
    description: '所选日期范围的 Journal 元数据，不包含正文',
    providerSchemaVersion: 1,
    capabilities: {
      PersonalDataCapability.timeline,
      PersonalDataCapability.reflection,
    },
    defaultSensitivity: PersonalDataSensitivity.sensitive,
    displayOrder: 40,
  );

  final AppDatabase database;
  final String localUserId;

  @override
  PersonalDataProviderDescriptor get descriptor => _descriptor;

  @override
  Future<PersonalDataContribution> collect(PersonalDataQuery query) async {
    final table = database.journalEntries;
    final statement = database.selectOnly(table)
      ..addColumns([
        table.id,
        table.entryDate,
        table.entryStatus,
        table.updatedAt,
        table.syncStatus,
      ])
      ..where(
        table.userId.equals(localUserId) &
            table.deletedAt.isNull() &
            table.entryDate.isBiggerOrEqualValue(
              query.timeRange.startLocalDate,
            ) &
            table.entryDate.isSmallerOrEqualValue(
              query.timeRange.endLocalDateInclusive,
            ),
      )
      ..orderBy([OrderingTerm.asc(table.entryDate), OrderingTerm.asc(table.id)])
      ..limit(query.maxItemsPerProvider + 1);
    final loaded = await statement.get();
    final wasLimited = loaded.length > query.maxItemsPerProvider;
    final records = loaded
        .take(query.maxItemsPerProvider)
        .map(
          (row) => _JournalMetadata(
            id: row.read(table.id)!,
            entryDate: row.read(table.entryDate)!,
            entryStatus: row.read(table.entryStatus)!,
            updatedAt: row.read(table.updatedAt)!,
            syncStatus: row.read(table.syncStatus)!,
          ),
        )
        .toList(growable: false);
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
            kind: PersonalDataItemKind('journal.entry_metadata'),
            title: '${record.entryDate} 复盘记录',
            localDate: record.entryDate,
            occurredAtUtc: utcDateTimeFromMilliseconds(record.updatedAt),
            facts: [
              fact(
                key: 'journal.entry_status',
                label: '记录状态',
                value: PersonalDataCategoricalValue(record.entryStatus),
                sensitivity: sensitivity,
                priority: 10,
              ),
            ],
            sensitivity: sensitivity,
            quality: qualityForSyncStatus(record.syncStatus),
          ),
      ],
      summaryFacts: [
        fact(
          key: 'journal.entry_count',
          label: '复盘记录',
          value: PersonalDataCountValue(records.length),
          sensitivity: sensitivity,
          unit: '条',
          priority: 0,
        ),
      ],
      generatedAtUtc: query.requestedAtUtc,
    );
  }
}

final class _JournalMetadata {
  const _JournalMetadata({
    required this.id,
    required this.entryDate,
    required this.entryStatus,
    required this.updatedAt,
    required this.syncStatus,
  });

  final String id;
  final String entryDate;
  final String entryStatus;
  final int updatedAt;
  final String syncStatus;
}
