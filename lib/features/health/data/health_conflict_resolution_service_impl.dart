import 'package:drift/drift.dart';
import 'package:rebirth/core/database/app_database.dart' as db;
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/health/domain/health_conflict_resolution_service.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_record.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_repository.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';

final class HealthConflictResolutionServiceImpl
    implements HealthConflictResolutionService {
  const HealthConflictResolutionServiceImpl(
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
      await _requireCurrentHealthConflict(scope, conflictId);
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
      final conflict = await _requireCurrentHealthConflict(scope, conflictId);
      final remoteVersion = conflict.remoteSnapshot.serverVersion;
      if (remoteVersion == null) {
        throw const SyncConflictNotReadyException();
      }
      final local =
          await (_database.select(_database.healthRecords)..where(
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
            await (_database.update(_database.healthRecords)..where(
                  (row) =>
                      row.userId.equals(scope.localUserId) &
                      row.id.equals(conflict.recordId),
                ))
                .write(
                  db.HealthRecordsCompanion(
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

  Future<SyncConflictRecord> _requireCurrentHealthConflict(
    SyncConflictScope scope,
    String conflictId,
  ) async {
    final bootstrap = await _database.bootstrapDao.bootstrap();
    if (bootstrap.activeUserId != scope.localUserId) {
      throw const SyncConflictResolutionException('当前本地用户与冲突记录不匹配。');
    }
    final conflict = await _conflictRepository.getConflict(scope, conflictId);
    if (!conflict.isActive ||
        conflict.entityType != SyncEntityType.health ||
        conflict.remoteSnapshot.serverVersion == null) {
      throw const SyncConflictNotReadyException();
    }
    return conflict;
  }

  Future<void> _rekeyLocalVersion({
    required db.HealthRecord local,
    required String remoteId,
    required int remoteVersion,
    required int timestamp,
    required String originDeviceId,
  }) async {
    final global = await (_database.select(
      _database.healthRecords,
    )..where((row) => row.id.equals(remoteId))).getSingleOrNull();
    if (global != null && global.userId != local.userId) {
      throw const SyncConflictResolutionException('云端 Health 身份与其他本地账号冲突。');
    }

    await (_database.update(_database.healthRecords)..where(
          (row) => row.userId.equals(local.userId) & row.id.equals(local.id),
        ))
        .write(
          db.HealthRecordsCompanion(
            todayRecordId: const Value(null),
            deletedAt: Value(local.deletedAt ?? timestamp),
            syncStatus: const Value('synced'),
          ),
        );

    final todayRecordId = await _findTodayRecordId(
      userId: local.userId,
      recordDate: local.recordDate,
    );
    final changes = db.HealthRecordsCompanion(
      todayRecordId: Value(todayRecordId),
      recordDate: Value(local.recordDate),
      timezoneOffsetMinutes: Value(local.timezoneOffsetMinutes),
      sleepDurationMinutes: Value(local.sleepDurationMinutes),
      weightKg: Value(local.weightKg),
      waterIntakeMl: Value(local.waterIntakeMl),
      exerciseType: Value(local.exerciseType),
      exerciseDurationMinutes: Value(local.exerciseDurationMinutes),
      physicalStateScore: Value(local.physicalStateScore),
      physicalStateScoreScale: Value(local.physicalStateScoreScale),
      physicalStateDescription: Value(local.physicalStateDescription),
      note: Value(local.note),
      dataSource: Value(local.dataSource),
      sourceRecordId: Value(local.sourceRecordId),
      createdAt: Value(local.createdAt),
      updatedAt: Value(timestamp),
      deletedAt: Value(local.deletedAt),
      syncStatus: const Value('pending'),
      serverVersion: Value(remoteVersion),
      lastSyncedAt: Value(local.lastSyncedAt),
      originDeviceId: Value(originDeviceId),
    );
    if (global == null) {
      await _database
          .into(_database.healthRecords)
          .insert(
            db.HealthRecordsCompanion.insert(
              id: Value(remoteId),
              userId: local.userId,
              todayRecordId: Value(todayRecordId),
              recordDate: local.recordDate,
              timezoneOffsetMinutes: local.timezoneOffsetMinutes,
              sleepDurationMinutes: Value(local.sleepDurationMinutes),
              weightKg: Value(local.weightKg),
              waterIntakeMl: Value(local.waterIntakeMl),
              exerciseType: Value(local.exerciseType),
              exerciseDurationMinutes: Value(local.exerciseDurationMinutes),
              physicalStateScore: Value(local.physicalStateScore),
              physicalStateScoreScale: Value(local.physicalStateScoreScale),
              physicalStateDescription: Value(local.physicalStateDescription),
              note: Value(local.note),
              dataSource: Value(local.dataSource),
              sourceRecordId: Value(local.sourceRecordId),
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
      await (_database.update(_database.healthRecords)..where(
            (row) => row.userId.equals(local.userId) & row.id.equals(remoteId),
          ))
          .write(changes);
    }
  }

  Future<String?> _findTodayRecordId({
    required String userId,
    required String recordDate,
  }) async {
    final today =
        await (_database.select(_database.todayRecords)..where(
              (row) =>
                  row.userId.equals(userId) &
                  row.recordDate.equals(recordDate) &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    return today?.id;
  }
}
