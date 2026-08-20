import 'package:drift/drift.dart';
import 'package:rebirth/core/database/app_database.dart' as db;
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_record.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_repository.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/today/domain/today_conflict_resolution_service.dart';

final class TodayConflictResolutionServiceImpl
    implements TodayConflictResolutionService {
  const TodayConflictResolutionServiceImpl(
    this._database,
    this._conflictRepository, [
    this._dateTimeService = const DateTimeService(),
  ]);

  final db.AppDatabase _database;
  final SyncConflictRepository _conflictRepository;
  final DateTimeService _dateTimeService;

  @override
  Future<void> requestAdoptRemote({
    required SyncConflictScope scope,
    required String conflictId,
  }) {
    return _database.transaction(() async {
      await _requireCurrentTodayConflict(scope, conflictId);
      await _conflictRepository.markAdoptRemoteRequested(scope, conflictId);
    });
  }

  @override
  Future<void> requestKeepLocal({
    required SyncConflictScope scope,
    required String conflictId,
  }) {
    return _database.transaction(() async {
      final bootstrap = await _database.bootstrapDao.bootstrap();
      final conflict = await _requireCurrentTodayConflict(scope, conflictId);
      final remoteVersion = conflict.remoteSnapshot.serverVersion;
      if (remoteVersion == null) {
        throw const SyncConflictNotReadyException();
      }
      final local =
          await (_database.select(_database.todayRecords)..where(
                (row) =>
                    row.userId.equals(scope.localUserId) &
                    row.id.equals(conflict.recordId),
              ))
              .getSingleOrNull();
      if (local == null) throw const SyncConflictNotFoundException();
      final now = _dateTimeService.currentSnapshot().utcMilliseconds;
      final remoteId = conflict.remoteRecordId ?? conflict.recordId;

      if (remoteId == conflict.recordId) {
        final affected =
            await (_database.update(_database.todayRecords)..where(
                  (row) =>
                      row.userId.equals(scope.localUserId) &
                      row.id.equals(conflict.recordId),
                ))
                .write(
                  db.TodayRecordsCompanion(
                    serverVersion: Value(remoteVersion),
                    syncStatus: const Value('pending'),
                    updatedAt: Value(now),
                    originDeviceId: Value(bootstrap.localInstallationId),
                  ),
                );
        if (affected != 1) throw const SyncConflictChangedException();
      } else {
        await _rekeyLocalVersion(
          local: local,
          remoteId: remoteId,
          remoteVersion: remoteVersion,
          timestamp: now,
          originDeviceId: bootstrap.localInstallationId,
        );
      }
      await _conflictRepository.markKeepLocalRequested(scope, conflictId);
    });
  }

  Future<SyncConflictRecord> _requireCurrentTodayConflict(
    SyncConflictScope scope,
    String conflictId,
  ) async {
    final bootstrap = await _database.bootstrapDao.bootstrap();
    if (bootstrap.activeUserId != scope.localUserId) {
      throw const SyncConflictResolutionException('当前本地用户与冲突记录不匹配。');
    }
    final conflict = await _conflictRepository.getConflict(scope, conflictId);
    if (!conflict.isActive ||
        conflict.entityType != SyncEntityType.today ||
        conflict.remoteSnapshot.serverVersion == null) {
      throw const SyncConflictNotReadyException();
    }
    return conflict;
  }

  Future<void> _rekeyLocalVersion({
    required db.TodayRecord local,
    required String remoteId,
    required int remoteVersion,
    required int timestamp,
    required String originDeviceId,
  }) async {
    final global = await (_database.select(
      _database.todayRecords,
    )..where((row) => row.id.equals(remoteId))).getSingleOrNull();
    if (global != null && global.userId != local.userId) {
      throw const SyncConflictResolutionException('云端 Today 身份与其他本地账号冲突。');
    }

    await (_database.update(_database.todayRecords)..where(
          (row) => row.userId.equals(local.userId) & row.id.equals(local.id),
        ))
        .write(
          db.TodayRecordsCompanion(
            deletedAt: Value(local.deletedAt ?? timestamp),
            syncStatus: const Value('synced'),
          ),
        );

    if (global == null) {
      await _database
          .into(_database.todayRecords)
          .insert(
            db.TodayRecordsCompanion.insert(
              id: Value(remoteId),
              userId: local.userId,
              recordDate: local.recordDate,
              timezoneOffsetMinutes: local.timezoneOffsetMinutes,
              priority1: Value(local.priority1),
              priority1Completed: Value(local.priority1Completed),
              priority1GoalId: Value(local.priority1GoalId),
              priority2: Value(local.priority2),
              priority2Completed: Value(local.priority2Completed),
              priority2GoalId: Value(local.priority2GoalId),
              priority3: Value(local.priority3),
              priority3Completed: Value(local.priority3Completed),
              priority3GoalId: Value(local.priority3GoalId),
              moodScore: Value(local.moodScore),
              wellbeingScoreScale: Value(local.wellbeingScoreScale),
              moodDescription: Value(local.moodDescription),
              energyScore: Value(local.energyScore),
              energyDescription: Value(local.energyDescription),
              researchMinutes: Value(local.researchMinutes),
              learningMinutes: Value(local.learningMinutes),
              dailyNote: Value(local.dailyNote),
              recordStatus: Value(local.recordStatus),
              createdAt: Value(local.createdAt),
              updatedAt: Value(timestamp),
              deletedAt: Value(local.deletedAt),
              syncStatus: const Value('pending'),
              serverVersion: Value(remoteVersion),
              lastSyncedAt: Value(local.lastSyncedAt),
              originDeviceId: Value(originDeviceId),
            ),
          );
    } else {
      await (_database.update(_database.todayRecords)..where(
            (row) => row.userId.equals(local.userId) & row.id.equals(remoteId),
          ))
          .write(
            db.TodayRecordsCompanion(
              recordDate: Value(local.recordDate),
              timezoneOffsetMinutes: Value(local.timezoneOffsetMinutes),
              priority1: Value(local.priority1),
              priority1Completed: Value(local.priority1Completed),
              priority1GoalId: Value(local.priority1GoalId),
              priority2: Value(local.priority2),
              priority2Completed: Value(local.priority2Completed),
              priority2GoalId: Value(local.priority2GoalId),
              priority3: Value(local.priority3),
              priority3Completed: Value(local.priority3Completed),
              priority3GoalId: Value(local.priority3GoalId),
              moodScore: Value(local.moodScore),
              wellbeingScoreScale: Value(local.wellbeingScoreScale),
              moodDescription: Value(local.moodDescription),
              energyScore: Value(local.energyScore),
              energyDescription: Value(local.energyDescription),
              researchMinutes: Value(local.researchMinutes),
              learningMinutes: Value(local.learningMinutes),
              dailyNote: Value(local.dailyNote),
              recordStatus: Value(local.recordStatus),
              createdAt: Value(local.createdAt),
              updatedAt: Value(timestamp),
              deletedAt: Value(local.deletedAt),
              syncStatus: const Value('pending'),
              serverVersion: Value(remoteVersion),
              lastSyncedAt: Value(local.lastSyncedAt),
              originDeviceId: Value(originDeviceId),
            ),
          );
    }

    await (_database.update(_database.healthRecords)..where(
          (row) =>
              row.userId.equals(local.userId) &
              row.recordDate.equals(local.recordDate) &
              row.deletedAt.isNull(),
        ))
        .write(db.HealthRecordsCompanion(todayRecordId: Value(remoteId)));
  }
}
