import 'package:drift/drift.dart';
import 'package:rebirth/core/database/app_database.dart' as db;
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/plan/domain/plan_conflict_resolution_service.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_record.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_repository.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';

final class PlanConflictResolutionServiceImpl
    implements PlanConflictResolutionService {
  const PlanConflictResolutionServiceImpl(
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
    return _conflictRepository.markAdoptRemoteRequested(scope, conflictId);
  }

  @override
  Future<void> requestKeepLocal({
    required SyncConflictScope scope,
    required String conflictId,
  }) {
    return _database.transaction(() async {
      final bootstrap = await _database.bootstrapDao.bootstrap();
      if (bootstrap.activeUserId != scope.localUserId) {
        throw const SyncConflictResolutionException('当前本地用户与冲突记录不匹配。');
      }
      final conflict = await _conflictRepository.getConflict(scope, conflictId);
      if (!conflict.isActive ||
          conflict.entityType != SyncEntityType.plan ||
          conflict.remoteSnapshot.serverVersion == null) {
        throw const SyncConflictNotReadyException();
      }
      final goal =
          await (_database.select(_database.goals)..where(
                (row) =>
                    row.userId.equals(scope.localUserId) &
                    row.id.equals(conflict.recordId),
              ))
              .getSingleOrNull();
      if (goal == null) throw const SyncConflictNotFoundException();
      final now = _dateTimeService.currentSnapshot().utcMilliseconds;
      final affected =
          await (_database.update(_database.goals)..where(
                (row) =>
                    row.userId.equals(scope.localUserId) &
                    row.id.equals(conflict.recordId),
              ))
              .write(
                db.GoalsCompanion(
                  serverVersion: Value(conflict.remoteSnapshot.serverVersion),
                  syncStatus: const Value('pending'),
                  updatedAt: Value(now),
                  originDeviceId: Value(bootstrap.localInstallationId),
                ),
              );
      if (affected != 1) throw const SyncConflictChangedException();
      await _conflictRepository.markKeepLocalRequested(scope, conflictId);
    });
  }
}
