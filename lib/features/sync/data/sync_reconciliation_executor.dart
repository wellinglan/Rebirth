import 'package:drift/drift.dart';
import 'package:rebirth/core/database/app_database.dart' as db;
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/health/domain/health_sync_payload.dart';
import 'package:rebirth/features/journal/domain/journal_prompt_sync_payload.dart';
import 'package:rebirth/features/journal/domain/journal_sync_payload.dart';
import 'package:rebirth/features/plan/domain/plan_sync_payload.dart';
import 'package:rebirth/features/plan/domain/plan_goal.dart';
import 'package:rebirth/features/profile/domain/profile_sync_payload.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_record.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_repository.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';
import 'package:rebirth/features/today/domain/today_sync_payload.dart';

import 'sync_conflict_providers.dart';

final class SyncReconciliationExecutor {
  const SyncReconciliationExecutor({
    required this.database,
    required this.conflicts,
    required this.clock,
  });

  final db.AppDatabase database;
  final SyncConflictRepository conflicts;
  final DateTimeService clock;

  Future<void> prepareLocalRetry({
    required SyncConflictScope scope,
    required String conflictId,
    required SyncConflictSnapshot expectedLocal,
    SyncEntityPayload? mergedPayload,
  }) {
    return database.transaction(() async {
      final bootstrap = await database.bootstrapDao.bootstrap();
      if (bootstrap.activeUserId != scope.localUserId) {
        throw const SyncConflictResolutionException('同步账号已变化，自动协调已停止。');
      }
      final conflict = await conflicts.getConflict(scope, conflictId);
      if (!conflict.isActive ||
          !conflict.remoteSnapshotReady ||
          conflict.remoteSnapshot.serverVersion == null) {
        throw const SyncConflictChangedException();
      }
      if (conflict.entityType != SyncEntityType.profile &&
          conflict.remoteRecordId != null &&
          conflict.remoteRecordId != conflict.recordId) {
        throw const SyncConflictResolutionException('本地与云端记录身份不同，需要人工确认。');
      }
      final current = await loadCurrentSyncSnapshot(
        database,
        conflict.entityType,
        scope.localUserId,
        conflict.recordId,
      );
      if (!_sameSnapshot(current, expectedLocal)) {
        throw const SyncConflictChangedException();
      }

      final timestamp = clock.currentSnapshot().utcMilliseconds;
      if (mergedPayload != null) {
        await _applyMergedPayload(
          localUserId: scope.localUserId,
          recordId: conflict.recordId,
          entityType: conflict.entityType,
          payload: mergedPayload,
        );
      }
      await _markPending(
        localUserId: scope.localUserId,
        recordId: conflict.recordId,
        entityType: conflict.entityType,
        serverVersion: conflict.remoteSnapshot.serverVersion!,
        updatedAt: timestamp,
        originDeviceId: bootstrap.localInstallationId,
      );
      await conflicts.markKeepLocalRequested(scope, conflict.id);
    });
  }

  bool _sameSnapshot(
    SyncConflictSnapshot? current,
    SyncConflictSnapshot expected,
  ) {
    return current != null &&
        current.updatedAt == expected.updatedAt &&
        current.deletedAt == expected.deletedAt &&
        current.serverVersion == expected.serverVersion &&
        sameSyncPayload(current.payload, expected.payload);
  }

  Future<void> _applyMergedPayload({
    required String localUserId,
    required String recordId,
    required SyncEntityType entityType,
    required SyncEntityPayload payload,
  }) async {
    switch (entityType) {
      case SyncEntityType.profile:
        final value = payload as ProfileSyncPayload;
        final changed =
            await (database.update(database.userProfiles)..where(
                  (row) =>
                      row.id.equals(localUserId) & row.isActive.equals(true),
                ))
                .write(
                  db.UserProfilesCompanion(
                    displayName: Value(value.displayName),
                    growthFocus: Value(value.growthFocus),
                    timezoneId: Value(value.timezoneId),
                  ),
                );
        _requireOne(changed);
      case SyncEntityType.plan:
        final value = payload as PlanSyncPayload;
        final changed =
            await (database.update(database.goals)..where(
                  (row) =>
                      row.userId.equals(localUserId) & row.id.equals(recordId),
                ))
                .write(
                  db.GoalsCompanion(
                    parentGoalId: Value(value.parentGoalId),
                    title: Value(value.title),
                    description: Value(value.description),
                    goalLevel: Value(value.goalLevel.databaseValue),
                    status: Value(value.status.databaseValue),
                    startDate: Value(value.startDate),
                    targetDate: Value(value.targetDate),
                    completedAt: Value(value.completedAt),
                    archivedAt: Value(value.archivedAt),
                    sortOrder: Value(value.sortOrder),
                    createdAt: Value(value.createdAt),
                  ),
                );
        _requireOne(changed);
      case SyncEntityType.today:
        final value = payload as TodaySyncPayload;
        final changed =
            await (database.update(database.todayRecords)..where(
                  (row) =>
                      row.userId.equals(localUserId) & row.id.equals(recordId),
                ))
                .write(
                  db.TodayRecordsCompanion(
                    recordDate: Value(value.recordDate),
                    timezoneOffsetMinutes: Value(value.timezoneOffsetMinutes),
                    priority1: Value(value.priority1),
                    priority1Completed: Value(value.priority1Completed),
                    priority1GoalId: Value(value.priority1GoalId),
                    priority2: Value(value.priority2),
                    priority2Completed: Value(value.priority2Completed),
                    priority2GoalId: Value(value.priority2GoalId),
                    priority3: Value(value.priority3),
                    priority3Completed: Value(value.priority3Completed),
                    priority3GoalId: Value(value.priority3GoalId),
                    moodScore: Value(value.moodScore),
                    wellbeingScoreScale: Value(value.wellbeingScoreScale),
                    moodDescription: Value(value.moodDescription),
                    energyScore: Value(value.energyScore),
                    energyDescription: Value(value.energyDescription),
                    researchMinutes: Value(value.researchMinutes),
                    researchDescription: Value(value.researchDescription),
                    learningMinutes: Value(value.learningMinutes),
                    learningDescription: Value(value.learningDescription),
                    dailyNote: Value(value.dailyNote),
                    recordStatus: Value(value.status.name),
                    createdAt: Value(value.createdAt),
                  ),
                );
        _requireOne(changed);
      case SyncEntityType.health:
        final value = payload as HealthSyncPayload;
        final changed =
            await (database.update(database.healthRecords)..where(
                  (row) =>
                      row.userId.equals(localUserId) & row.id.equals(recordId),
                ))
                .write(
                  db.HealthRecordsCompanion(
                    recordDate: Value(value.recordDate),
                    timezoneOffsetMinutes: Value(value.timezoneOffsetMinutes),
                    sleepDurationMinutes: Value(value.sleepDurationMinutes),
                    sleepDescription: Value(value.sleepDescription),
                    weightKg: Value(value.weightKg),
                    weightDescription: Value(value.weightDescription),
                    waterIntakeMl: Value(value.waterIntakeMl),
                    waterDescription: Value(value.waterDescription),
                    exerciseType: Value(value.exerciseType),
                    exerciseDurationMinutes: Value(
                      value.exerciseDurationMinutes,
                    ),
                    exerciseDescription: Value(value.exerciseDescription),
                    physicalStateScore: Value(value.physicalStateScore),
                    physicalStateScoreScale: Value(
                      value.physicalStateScoreScale,
                    ),
                    physicalStateDescription: Value(
                      value.physicalStateDescription,
                    ),
                    note: Value(value.note),
                    dataSource: Value(value.dataSource),
                    sourceRecordId: Value(value.sourceRecordId),
                    createdAt: Value(value.createdAt),
                  ),
                );
        _requireOne(changed);
      case SyncEntityType.journal:
        await _applyMergedJournal(
          localUserId: localUserId,
          recordId: recordId,
          payload: payload as JournalSyncPayload,
        );
      case SyncEntityType.journalPromptConfiguration:
        if (payload is! JournalPromptConfigurationSyncPayload) {
          throw const SyncConflictResolutionException('Journal 配置协调数据无效。');
        }
        throw const SyncConflictResolutionException('Journal 问题配置不允许字段级自动合并。');
      case SyncEntityType.aiReport:
        throw const SyncConflictResolutionException('AI 报告正文与版本不允许字段级自动合并。');
    }
  }

  Future<void> _applyMergedJournal({
    required String localUserId,
    required String recordId,
    required JournalSyncPayload payload,
  }) async {
    final changed =
        await (database.update(database.journalEntries)..where(
              (row) => row.userId.equals(localUserId) & row.id.equals(recordId),
            ))
            .write(
              db.JournalEntriesCompanion(
                entryDate: Value(payload.entryDate),
                timezoneOffsetMinutes: Value(payload.timezoneOffsetMinutes),
                mostImportantAccomplishment: Value(
                  payload.mostImportantAccomplishment,
                ),
                mostDrainingEvent: Value(payload.mostDrainingEvent),
                emotionSource: Value(payload.emotionSource),
                learning: Value(payload.learning),
                tomorrowAdjustment: Value(payload.tomorrowAdjustment),
                entryStatus: Value(payload.status.name),
                createdAt: Value(payload.createdAt),
              ),
            );
    _requireOne(changed);
    await (database.delete(
      database.journalEntryPromptItems,
    )..where((row) => row.journalEntryId.equals(recordId))).go();
    for (final item in payload.promptItems) {
      await database
          .into(database.journalEntryPromptItems)
          .insert(
            db.JournalEntryPromptItemsCompanion.insert(
              id: Value(item.id),
              journalEntryId: recordId,
              sourcePromptId: Value(item.sourcePromptId),
              sourcePromptStableKey: Value(item.sourcePromptStableKey),
              sourcePromptVersion: item.sourcePromptVersion,
              promptSource: item.promptSource.wireName,
              questionTextSnapshot: item.questionTextSnapshot,
              helperTextSnapshot: Value(item.helperTextSnapshot),
              responseKind: Value(item.responseKind.wireName),
              displayOrder: item.displayOrder,
              answerText: Value(item.answerText),
              createdAt: Value(item.createdAt),
              updatedAt: Value(item.updatedAt),
            ),
          );
    }
  }

  Future<void> _markPending({
    required String localUserId,
    required String recordId,
    required SyncEntityType entityType,
    required int serverVersion,
    required int updatedAt,
    required String originDeviceId,
  }) async {
    final changed = switch (entityType) {
      SyncEntityType.profile =>
        await (database.update(database.userProfiles)..where(
              (row) => row.id.equals(localUserId) & row.isActive.equals(true),
            ))
            .write(
              db.UserProfilesCompanion(
                syncStatus: const Value('pending'),
                serverVersion: Value(serverVersion),
                updatedAt: Value(updatedAt),
                originDeviceId: Value(originDeviceId),
              ),
            ),
      SyncEntityType.plan =>
        await (database.update(database.goals)..where(
              (row) => row.userId.equals(localUserId) & row.id.equals(recordId),
            ))
            .write(
              db.GoalsCompanion(
                syncStatus: const Value('pending'),
                serverVersion: Value(serverVersion),
                updatedAt: Value(updatedAt),
                originDeviceId: Value(originDeviceId),
              ),
            ),
      SyncEntityType.today =>
        await (database.update(database.todayRecords)..where(
              (row) => row.userId.equals(localUserId) & row.id.equals(recordId),
            ))
            .write(
              db.TodayRecordsCompanion(
                syncStatus: const Value('pending'),
                serverVersion: Value(serverVersion),
                updatedAt: Value(updatedAt),
                originDeviceId: Value(originDeviceId),
              ),
            ),
      SyncEntityType.journalPromptConfiguration =>
        await (database.update(database.journalPromptConfigurations)..where(
              (row) => row.userId.equals(localUserId) & row.id.equals(recordId),
            ))
            .write(
              db.JournalPromptConfigurationsCompanion(
                syncStatus: const Value('pending'),
                serverVersion: Value(serverVersion),
                updatedAt: Value(updatedAt),
                originDeviceId: Value(originDeviceId),
              ),
            ),
      SyncEntityType.journal =>
        await (database.update(database.journalEntries)..where(
              (row) => row.userId.equals(localUserId) & row.id.equals(recordId),
            ))
            .write(
              db.JournalEntriesCompanion(
                syncStatus: const Value('pending'),
                serverVersion: Value(serverVersion),
                updatedAt: Value(updatedAt),
                originDeviceId: Value(originDeviceId),
              ),
            ),
      SyncEntityType.health =>
        await (database.update(database.healthRecords)..where(
              (row) => row.userId.equals(localUserId) & row.id.equals(recordId),
            ))
            .write(
              db.HealthRecordsCompanion(
                syncStatus: const Value('pending'),
                serverVersion: Value(serverVersion),
                updatedAt: Value(updatedAt),
                originDeviceId: Value(originDeviceId),
              ),
            ),
      SyncEntityType.aiReport =>
        await (database.update(database.aiReports)..where(
              (row) => row.userId.equals(localUserId) & row.id.equals(recordId),
            ))
            .write(
              db.AiReportsCompanion(
                syncStatus: const Value('pending'),
                serverVersion: Value(serverVersion),
                updatedAt: Value(updatedAt),
                originDeviceId: Value(originDeviceId),
              ),
            ),
    };
    _requireOne(changed);
  }

  void _requireOne(int changed) {
    if (changed != 1) throw const SyncConflictChangedException();
  }
}
