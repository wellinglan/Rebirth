import 'package:drift/drift.dart';
import 'package:rebirth/core/database/app_database.dart' as db;
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/journal/domain/journal_conflict_resolution_service.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_record.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_repository.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';

final class JournalConflictResolutionServiceImpl
    implements JournalConflictResolutionService {
  const JournalConflictResolutionServiceImpl(
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
      await _requireCurrentJournalConflict(scope, conflictId);
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
      final conflict = await _requireCurrentJournalConflict(scope, conflictId);
      final remoteVersion = conflict.remoteSnapshot.serverVersion;
      if (remoteVersion == null) {
        throw const SyncConflictNotReadyException();
      }
      final local =
          await (_database.select(_database.journalEntries)..where(
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
            await (_database.update(_database.journalEntries)..where(
                  (row) =>
                      row.userId.equals(scope.localUserId) &
                      row.id.equals(conflict.recordId),
                ))
                .write(
                  db.JournalEntriesCompanion(
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

  Future<SyncConflictRecord> _requireCurrentJournalConflict(
    SyncConflictScope scope,
    String conflictId,
  ) async {
    final bootstrap = await _database.bootstrapDao.bootstrap();
    if (bootstrap.activeUserId != scope.localUserId) {
      throw const SyncConflictResolutionException('当前本地用户与冲突记录不匹配。');
    }
    final conflict = await _conflictRepository.getConflict(scope, conflictId);
    if (!conflict.isActive ||
        conflict.entityType != SyncEntityType.journal ||
        conflict.remoteSnapshot.serverVersion == null) {
      throw const SyncConflictNotReadyException();
    }
    return conflict;
  }

  Future<void> _rekeyLocalVersion({
    required db.JournalEntry local,
    required String remoteId,
    required int remoteVersion,
    required int timestamp,
    required String originDeviceId,
  }) async {
    final global = await (_database.select(
      _database.journalEntries,
    )..where((row) => row.id.equals(remoteId))).getSingleOrNull();
    if (global != null && global.userId != local.userId) {
      throw const SyncConflictResolutionException('云端 Journal 身份与其他本地账号冲突。');
    }

    await (_database.update(_database.journalEntries)..where(
          (row) => row.userId.equals(local.userId) & row.id.equals(local.id),
        ))
        .write(
          db.JournalEntriesCompanion(
            deletedAt: Value(local.deletedAt ?? timestamp),
            syncStatus: const Value('synced'),
          ),
        );

    final changes = db.JournalEntriesCompanion(
      todayRecordId: Value(local.todayRecordId),
      entryDate: Value(local.entryDate),
      timezoneOffsetMinutes: Value(local.timezoneOffsetMinutes),
      mostImportantAccomplishment: Value(local.mostImportantAccomplishment),
      mostDrainingEvent: Value(local.mostDrainingEvent),
      emotionSource: Value(local.emotionSource),
      learning: Value(local.learning),
      tomorrowAdjustment: Value(local.tomorrowAdjustment),
      entryStatus: Value(local.entryStatus),
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
          .into(_database.journalEntries)
          .insert(
            db.JournalEntriesCompanion.insert(
              id: Value(remoteId),
              userId: local.userId,
              todayRecordId: Value(local.todayRecordId),
              entryDate: local.entryDate,
              timezoneOffsetMinutes: local.timezoneOffsetMinutes,
              mostImportantAccomplishment: Value(
                local.mostImportantAccomplishment,
              ),
              mostDrainingEvent: Value(local.mostDrainingEvent),
              emotionSource: Value(local.emotionSource),
              learning: Value(local.learning),
              tomorrowAdjustment: Value(local.tomorrowAdjustment),
              entryStatus: Value(local.entryStatus),
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
      await (_database.update(_database.journalEntries)..where(
            (row) => row.userId.equals(local.userId) & row.id.equals(remoteId),
          ))
          .write(changes);
    }
  }
}
