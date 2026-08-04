import 'package:drift/drift.dart';
import 'package:rebirth/core/database/app_database.dart' as db;
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_conflict_resolution_service.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_record.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_repository.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';

final class AiReportConflictResolutionServiceImpl
    implements AiReportConflictResolutionService {
  const AiReportConflictResolutionServiceImpl(
    this._database,
    this._conflicts, [
    this._clock = const DateTimeService(),
  ]);

  final db.AppDatabase _database;
  final SyncConflictRepository _conflicts;
  final DateTimeService _clock;

  @override
  Future<void> requestAdoptRemote({
    required SyncConflictScope scope,
    required String conflictId,
  }) => _database.transaction(() async {
    await _require(scope, conflictId);
    await _conflicts.markAdoptRemoteRequested(scope, conflictId);
  });

  @override
  Future<void> requestKeepLocal({
    required SyncConflictScope scope,
    required String conflictId,
  }) => _database.transaction(() async {
    final bootstrap = await _database.bootstrapDao.bootstrap();
    if (bootstrap.activeUserId != scope.localUserId) {
      throw const SyncConflictResolutionException('Active account changed.');
    }
    final conflict = await _require(scope, conflictId);
    final remoteVersion = conflict.remoteSnapshot.serverVersion;
    if (remoteVersion == null) throw const SyncConflictNotReadyException();
    final report =
        await (_database.select(_database.aiReports)..where(
              (row) =>
                  row.userId.equals(scope.localUserId) &
                  row.id.equals(conflict.recordId),
            ))
            .getSingleOrNull();
    if (report == null ||
        (report.deletedAt == null &&
            !const {
              'completed',
              'failed',
              'archived',
            }.contains(report.reportStatus))) {
      throw const SyncConflictChangedException();
    }
    final now = _clock.currentSnapshot().utcMilliseconds;
    final updated =
        await (_database.update(_database.aiReports)..where(
              (row) =>
                  row.userId.equals(scope.localUserId) &
                  row.id.equals(conflict.recordId),
            ))
            .write(
              db.AiReportsCompanion(
                serverVersion: Value(remoteVersion),
                syncStatus: const Value('pending'),
                updatedAt: Value(now),
                originDeviceId: Value(bootstrap.localInstallationId),
              ),
            );
    if (updated != 1) throw const SyncConflictChangedException();
    await _conflicts.markKeepLocalRequested(scope, conflictId);
  });

  Future<SyncConflictRecord> _require(
    SyncConflictScope scope,
    String conflictId,
  ) async {
    final conflict = await _conflicts.getConflict(scope, conflictId);
    if (!conflict.isActive ||
        conflict.entityType != SyncEntityType.aiReport ||
        conflict.remoteSnapshot.serverVersion == null) {
      throw const SyncConflictNotReadyException();
    }
    return conflict;
  }
}
