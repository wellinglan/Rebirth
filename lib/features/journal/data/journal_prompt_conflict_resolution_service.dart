import 'package:drift/drift.dart';
import 'package:rebirth/core/database/app_database.dart' as db;
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_record.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_repository.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';

final class JournalPromptConflictResolutionService {
  const JournalPromptConflictResolutionService(
    this._database,
    this._conflictRepository, [
    this._dateTimeService = const DateTimeService(),
  ]);

  final db.AppDatabase _database;
  final SyncConflictRepository _conflictRepository;
  final DateTimeService _dateTimeService;

  Future<void> requestAdoptRemote({
    required SyncConflictScope scope,
    required String conflictId,
  }) {
    return _database.transaction(() async {
      await _requireConflict(scope, conflictId);
      await _conflictRepository.markAdoptRemoteRequested(scope, conflictId);
    });
  }

  Future<void> requestKeepLocal({
    required SyncConflictScope scope,
    required String conflictId,
  }) {
    return _database.transaction(() async {
      final bootstrap = await _database.bootstrapDao.bootstrap();
      final conflict = await _requireConflict(scope, conflictId);
      final remoteVersion = conflict.remoteSnapshot.serverVersion;
      if (remoteVersion == null) {
        throw const SyncConflictNotReadyException();
      }
      final local =
          await (_database.select(_database.journalPromptConfigurations)..where(
                (row) =>
                    row.userId.equals(scope.localUserId) &
                    row.id.equals(conflict.recordId),
              ))
              .getSingleOrNull();
      if (local == null) throw const SyncConflictNotFoundException();
      final now = _dateTimeService.currentSnapshot().utcMilliseconds;
      final remoteId = conflict.remoteRecordId ?? conflict.recordId;
      if (remoteId == local.id) {
        await (_database.update(_database.journalPromptConfigurations)..where(
              (row) =>
                  row.userId.equals(scope.localUserId) &
                  row.id.equals(local.id),
            ))
            .write(
              db.JournalPromptConfigurationsCompanion(
                serverVersion: Value(remoteVersion),
                syncStatus: const Value('pending'),
                updatedAt: Value(now),
                originDeviceId: Value(bootstrap.localInstallationId),
              ),
            );
      } else {
        await _rekey(
          local: local,
          remoteId: remoteId,
          remoteVersion: remoteVersion,
          timestamp: now,
          deviceId: bootstrap.localInstallationId,
        );
      }
      await _conflictRepository.markKeepLocalRequested(scope, conflictId);
    });
  }

  Future<SyncConflictRecord> _requireConflict(
    SyncConflictScope scope,
    String conflictId,
  ) async {
    final bootstrap = await _database.bootstrapDao.bootstrap();
    if (bootstrap.activeUserId != scope.localUserId) {
      throw const SyncConflictResolutionException('当前本地用户与冲突记录不匹配。');
    }
    final conflict = await _conflictRepository.getConflict(scope, conflictId);
    if (!conflict.isActive ||
        conflict.entityType != SyncEntityType.journalPromptConfiguration ||
        conflict.remoteSnapshot.serverVersion == null) {
      throw const SyncConflictNotReadyException();
    }
    return conflict;
  }

  Future<void> _rekey({
    required db.JournalPromptConfigurationRow local,
    required String remoteId,
    required int remoteVersion,
    required int timestamp,
    required String deviceId,
  }) async {
    final definitions = await (_database.select(
      _database.journalPromptDefinitions,
    )..where((row) => row.configurationId.equals(local.id))).get();
    final global = await (_database.select(
      _database.journalPromptConfigurations,
    )..where((row) => row.id.equals(remoteId))).getSingleOrNull();
    if (global != null && global.userId != local.userId) {
      throw const SyncConflictResolutionException(
        '云端 Journal 问题配置身份与其他本地账号冲突。',
      );
    }
    if (global != null) {
      await (_database.delete(
        _database.journalPromptDefinitions,
      )..where((row) => row.configurationId.equals(remoteId))).go();
      await (_database.delete(
        _database.journalPromptConfigurations,
      )..where((row) => row.id.equals(remoteId))).go();
    }
    await (_database.delete(
      _database.journalPromptDefinitions,
    )..where((row) => row.configurationId.equals(local.id))).go();
    await (_database.delete(_database.journalPromptConfigurations)..where(
          (row) => row.userId.equals(local.userId) & row.id.equals(local.id),
        ))
        .go();
    await _database
        .into(_database.journalPromptConfigurations)
        .insert(
          db.JournalPromptConfigurationsCompanion.insert(
            id: Value(remoteId),
            userId: local.userId,
            logicalKey: Value(local.logicalKey),
            configurationVersion: Value(local.configurationVersion),
            createdAt: Value(local.createdAt),
            updatedAt: Value(timestamp),
            syncStatus: const Value('pending'),
            serverVersion: Value(remoteVersion),
            lastSyncedAt: Value(local.lastSyncedAt),
            originDeviceId: Value(deviceId),
          ),
        );
    for (final definition in definitions) {
      await _database
          .into(_database.journalPromptDefinitions)
          .insert(definition.copyWith(configurationId: remoteId));
    }
  }
}
