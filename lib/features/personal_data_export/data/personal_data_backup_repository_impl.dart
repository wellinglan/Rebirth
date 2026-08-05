import 'package:drift/drift.dart';
import 'package:rebirth/core/database/app_database.dart' as db;

import '../domain/personal_data_backup.dart';
import '../domain/personal_data_backup_repository.dart';

final class PersonalDataBackupRepositoryImpl
    implements PersonalDataBackupRepository {
  const PersonalDataBackupRepositoryImpl(this.database);

  final db.AppDatabase database;

  @override
  Future<ProfileBackupRecord> readProfile(String localUserId) async {
    final row =
        await (database.select(database.userProfiles)..where(
              (item) =>
                  item.id.equals(localUserId) &
                  item.isActive.equals(true) &
                  item.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (row == null) throw const PersonalDataBackupSourceException();
    return ProfileBackupRecord(
      displayName: row.displayName,
      growthFocus: row.growthFocus,
      timezoneId: row.timezoneId,
      createdAt: _utcIso(row.createdAt),
      updatedAt: _utcIso(row.updatedAt),
    );
  }

  @override
  Future<List<PlanGoalBackupRecord>> readPlan(String localUserId) async {
    final rows = await (database.select(
      database.goals,
    )..where((item) => item.userId.equals(localUserId))).get();
    rows.sort((left, right) => left.id.compareTo(right.id));
    final ids = rows.map((row) => row.id).toSet();
    for (final row in rows) {
      if (row.parentGoalId case final parent? when !ids.contains(parent)) {
        throw const PersonalDataBackupSourceException();
      }
    }
    return List.unmodifiable(
      rows.map(
        (row) => PlanGoalBackupRecord(
          id: row.id,
          parentGoalId: row.parentGoalId,
          title: row.title,
          description: row.description,
          goalLevel: row.goalLevel,
          status: row.status,
          startDate: row.startDate,
          targetDate: row.targetDate,
          completedAt: _nullableUtcIso(row.completedAt),
          archivedAt: _nullableUtcIso(row.archivedAt),
          sortOrder: row.sortOrder,
          createdAt: _utcIso(row.createdAt),
          updatedAt: _utcIso(row.updatedAt),
          deletedAt: _nullableUtcIso(row.deletedAt),
        ),
      ),
    );
  }

  @override
  Future<List<TodayBackupRecord>> readToday(String localUserId) async {
    final rows = await (database.select(
      database.todayRecords,
    )..where((item) => item.userId.equals(localUserId))).get();
    rows.sort(_compareTodayRows);
    final goalIds = await _goalIds(localUserId);
    final records = <TodayBackupRecord>[];
    for (final row in rows) {
      final priorities = [
        TodayPriorityBackupRecord(
          slot: 1,
          text: row.priority1,
          completed: row.priority1Completed,
          goalId: row.priority1GoalId,
        ),
        TodayPriorityBackupRecord(
          slot: 2,
          text: row.priority2,
          completed: row.priority2Completed,
          goalId: row.priority2GoalId,
        ),
        TodayPriorityBackupRecord(
          slot: 3,
          text: row.priority3,
          completed: row.priority3Completed,
          goalId: row.priority3GoalId,
        ),
      ];
      if (priorities.any(
        (item) => item.goalId != null && !goalIds.contains(item.goalId),
      )) {
        throw const PersonalDataBackupSourceException();
      }
      records.add(
        TodayBackupRecord(
          id: row.id,
          recordDate: row.recordDate,
          timezoneOffsetMinutes: row.timezoneOffsetMinutes,
          priorities: priorities,
          moodScore: row.moodScore,
          energyScore: row.energyScore,
          researchMinutes: row.researchMinutes,
          learningMinutes: row.learningMinutes,
          dailyNote: row.dailyNote,
          status: row.recordStatus,
          createdAt: _utcIso(row.createdAt),
          updatedAt: _utcIso(row.updatedAt),
          deletedAt: _nullableUtcIso(row.deletedAt),
        ),
      );
    }
    return List.unmodifiable(records);
  }

  @override
  Future<List<JournalBackupRecord>> readJournal(String localUserId) async {
    final entries = await (database.select(
      database.journalEntries,
    )..where((item) => item.userId.equals(localUserId))).get();
    entries.sort(_compareJournalRows);
    if (entries.isEmpty) return const [];

    final entryIds = entries.map((entry) => entry.id).toList(growable: false);
    final items =
        await (database.select(database.journalEntryPromptItems)
              ..where((item) => item.journalEntryId.isIn(entryIds))
              ..orderBy([
                (item) => OrderingTerm.asc(item.journalEntryId),
                (item) => OrderingTerm.asc(item.displayOrder),
                (item) => OrderingTerm.asc(item.id),
              ]))
            .get();
    final todayIds = await _todayIds(localUserId);
    final definitionIds = await _journalPromptDefinitionIds(localUserId);
    final itemsByEntry = <String, List<db.JournalEntryPromptItemRow>>{};
    for (final item in items) {
      final sourceId = item.sourcePromptId;
      if (sourceId != null && !definitionIds.contains(sourceId)) {
        throw const PersonalDataBackupSourceException();
      }
      itemsByEntry.putIfAbsent(item.journalEntryId, () => []).add(item);
    }

    final records = <JournalBackupRecord>[];
    for (final entry in entries) {
      if (entry.todayRecordId case final todayId?
          when !todayIds.contains(todayId)) {
        throw const PersonalDataBackupSourceException();
      }
      records.add(
        JournalBackupRecord(
          id: entry.id,
          todayRecordId: entry.todayRecordId,
          entryDate: entry.entryDate,
          timezoneOffsetMinutes: entry.timezoneOffsetMinutes,
          status: entry.entryStatus,
          promptItems: [
            for (final item in itemsByEntry[entry.id] ?? const [])
              JournalPromptItemBackupRecord(
                id: item.id,
                sourcePromptId: item.sourcePromptId,
                sourcePromptStableKey: item.sourcePromptStableKey,
                sourcePromptVersion: item.sourcePromptVersion,
                promptSource: item.promptSource,
                questionTextSnapshot: item.questionTextSnapshot,
                helperTextSnapshot: item.helperTextSnapshot,
                responseKind: item.responseKind,
                displayOrder: item.displayOrder,
                answerText: item.answerText,
                createdAt: _utcIso(item.createdAt),
                updatedAt: _utcIso(item.updatedAt),
              ),
          ],
          legacyCompatibility: {
            'most_important_accomplishment': entry.mostImportantAccomplishment,
            'most_draining_event': entry.mostDrainingEvent,
            'emotion_source': entry.emotionSource,
            'learning': entry.learning,
            'tomorrow_adjustment': entry.tomorrowAdjustment,
          },
          createdAt: _utcIso(entry.createdAt),
          updatedAt: _utcIso(entry.updatedAt),
          deletedAt: _nullableUtcIso(entry.deletedAt),
        ),
      );
    }
    return List.unmodifiable(records);
  }

  @override
  Future<List<JournalPromptConfigurationBackupRecord>> readJournalPrompts(
    String localUserId,
  ) async {
    final configurations =
        await (database.select(database.journalPromptConfigurations)
              ..where((item) => item.userId.equals(localUserId))
              ..orderBy([(item) => OrderingTerm.asc(item.id)]))
            .get();
    if (configurations.isEmpty) return const [];
    final configurationIds = configurations
        .map((item) => item.id)
        .toList(growable: false);
    final definitions =
        await (database.select(database.journalPromptDefinitions)
              ..where((item) => item.configurationId.isIn(configurationIds))
              ..orderBy([
                (item) => OrderingTerm.asc(item.configurationId),
                (item) => OrderingTerm.asc(item.displayOrder),
                (item) => OrderingTerm.asc(item.id),
              ]))
            .get();
    final definitionsByConfiguration =
        <String, List<db.JournalPromptDefinitionRow>>{};
    for (final definition in definitions) {
      definitionsByConfiguration
          .putIfAbsent(definition.configurationId, () => [])
          .add(definition);
    }
    return List.unmodifiable(
      configurations.map(
        (configuration) => JournalPromptConfigurationBackupRecord(
          id: configuration.id,
          logicalKey: configuration.logicalKey,
          configurationVersion: configuration.configurationVersion,
          definitions: [
            for (final definition
                in definitionsByConfiguration[configuration.id] ?? const [])
              JournalPromptDefinitionBackupRecord(
                id: definition.id,
                stableKey: definition.stableKey,
                source: definition.promptSource,
                questionText: definition.questionText,
                helperText: definition.helperText,
                responseKind: definition.responseKind,
                displayOrder: definition.displayOrder,
                isEnabled: definition.isEnabled,
                promptVersion: definition.promptVersion,
                createdAt: _utcIso(definition.createdAt),
                updatedAt: _utcIso(definition.updatedAt),
                deletedAt: _nullableUtcIso(definition.deletedAt),
              ),
          ],
          createdAt: _utcIso(configuration.createdAt),
          updatedAt: _utcIso(configuration.updatedAt),
          deletedAt: _nullableUtcIso(configuration.deletedAt),
        ),
      ),
    );
  }

  @override
  Future<List<HealthBackupRecord>> readHealth(String localUserId) async {
    final rows = await (database.select(
      database.healthRecords,
    )..where((item) => item.userId.equals(localUserId))).get();
    rows.sort(_compareHealthRows);
    final todayIds = await _todayIds(localUserId);
    final records = <HealthBackupRecord>[];
    for (final row in rows) {
      if (row.todayRecordId case final todayId?
          when !todayIds.contains(todayId)) {
        throw const PersonalDataBackupSourceException();
      }
      records.add(
        HealthBackupRecord(
          id: row.id,
          todayRecordId: row.todayRecordId,
          recordDate: row.recordDate,
          timezoneOffsetMinutes: row.timezoneOffsetMinutes,
          sleepDurationMinutes: row.sleepDurationMinutes,
          weightKg: row.weightKg,
          waterIntakeMl: row.waterIntakeMl,
          exerciseType: row.exerciseType,
          exerciseDurationMinutes: row.exerciseDurationMinutes,
          physicalStateScore: row.physicalStateScore,
          note: row.note,
          dataSource: row.dataSource,
          createdAt: _utcIso(row.createdAt),
          updatedAt: _utcIso(row.updatedAt),
          deletedAt: _nullableUtcIso(row.deletedAt),
        ),
      );
    }
    return List.unmodifiable(records);
  }

  @override
  Future<List<AiReportBackupRecord>> readAiReports(String localUserId) async {
    final reports = await (database.select(
      database.aiReports,
    )..where((item) => item.userId.equals(localUserId))).get();
    reports.sort(_compareAiReportRows);
    if (reports.isEmpty) return const [];
    final reportIds = reports
        .map((report) => report.id)
        .toList(growable: false);
    final versions =
        await (database.select(database.aiReportVersions)
              ..where((item) => item.reportId.isIn(reportIds))
              ..orderBy([
                (item) => OrderingTerm.asc(item.reportId),
                (item) => OrderingTerm.asc(item.version),
              ]))
            .get();
    final versionsByReport = <String, List<db.AiReportVersionRow>>{};
    for (final version in versions) {
      versionsByReport.putIfAbsent(version.reportId, () => []).add(version);
    }
    return List.unmodifiable(
      reports.map((report) {
        final reportVersions = versionsByReport[report.id] ?? const [];
        final currentVersionIsValid = report.currentVersion == 0
            ? reportVersions.isEmpty
            : reportVersions.isNotEmpty &&
                  reportVersions.last.version == report.currentVersion;
        if (!currentVersionIsValid) {
          throw const PersonalDataBackupSourceException();
        }
        return AiReportBackupRecord(
          id: report.id,
          title: report.title,
          reportType: report.reportType,
          periodStartDate: report.periodStartDate,
          periodEndDate: report.periodEndDate,
          lifecycleStatus: report.reportStatus,
          currentVersion: report.currentVersion,
          currentContent: report.reportContent,
          sensitivity: report.sensitivity,
          quality: report.quality,
          requestedAt: _utcIso(report.requestedAt),
          completedAt: _nullableUtcIso(report.generatedAt),
          createdAt: _utcIso(report.createdAt),
          updatedAt: _utcIso(report.updatedAt),
          deletedAt: _nullableUtcIso(report.deletedAt),
          versions: [
            for (final version in reportVersions)
              AiReportVersionBackupRecord(
                version: version.version,
                status: version.status,
                content: version.content,
                sensitivity: version.sensitivity,
                quality: version.quality,
                createdAt: _utcIso(version.createdAt),
                completedAt: _nullableUtcIso(version.completedAt),
              ),
          ],
        );
      }),
    );
  }

  Future<Set<String>> _goalIds(String localUserId) async {
    final rows =
        await (database.selectOnly(database.goals)
              ..addColumns([database.goals.id])
              ..where(database.goals.userId.equals(localUserId)))
            .get();
    return rows.map((row) => row.read(database.goals.id)!).toSet();
  }

  Future<Set<String>> _todayIds(String localUserId) async {
    final rows =
        await (database.selectOnly(database.todayRecords)
              ..addColumns([database.todayRecords.id])
              ..where(database.todayRecords.userId.equals(localUserId)))
            .get();
    return rows.map((row) => row.read(database.todayRecords.id)!).toSet();
  }

  Future<Set<String>> _journalPromptDefinitionIds(String localUserId) async {
    final query =
        database.selectOnly(database.journalPromptDefinitions).join([
            innerJoin(
              database.journalPromptConfigurations,
              database.journalPromptConfigurations.id.equalsExp(
                database.journalPromptDefinitions.configurationId,
              ),
            ),
          ])
          ..addColumns([database.journalPromptDefinitions.id])
          ..where(
            database.journalPromptConfigurations.userId.equals(localUserId),
          );
    final rows = await query.get();
    return rows
        .map((row) => row.read(database.journalPromptDefinitions.id)!)
        .toSet();
  }

  String _utcIso(int milliseconds) => DateTime.fromMillisecondsSinceEpoch(
    milliseconds,
    isUtc: true,
  ).toIso8601String();

  String? _nullableUtcIso(int? milliseconds) =>
      milliseconds == null ? null : _utcIso(milliseconds);

  int _compareTodayRows(db.TodayRecord left, db.TodayRecord right) {
    final date = left.recordDate.compareTo(right.recordDate);
    return date != 0 ? date : left.id.compareTo(right.id);
  }

  int _compareJournalRows(db.JournalEntry left, db.JournalEntry right) {
    final date = left.entryDate.compareTo(right.entryDate);
    return date != 0 ? date : left.id.compareTo(right.id);
  }

  int _compareHealthRows(db.HealthRecord left, db.HealthRecord right) {
    final date = left.recordDate.compareTo(right.recordDate);
    return date != 0 ? date : left.id.compareTo(right.id);
  }

  int _compareAiReportRows(db.AiReport left, db.AiReport right) {
    final start = left.periodStartDate.compareTo(right.periodStartDate);
    if (start != 0) return start;
    final end = left.periodEndDate.compareTo(right.periodEndDate);
    return end != 0 ? end : left.id.compareTo(right.id);
  }
}
