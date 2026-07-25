import 'sync_conflict_record.dart';
import 'sync_entity_type.dart';

final class SyncConflictDetection {
  const SyncConflictDetection({
    required this.scope,
    required this.entityType,
    required this.recordId,
    required this.localSnapshot,
    required this.remoteSnapshot,
    required this.remoteOperation,
    required this.resolutionStatus,
    required this.detectedAt,
  });

  final SyncConflictScope scope;
  final SyncEntityType entityType;
  final String recordId;
  final SyncConflictSnapshot localSnapshot;
  final SyncConflictSnapshot remoteSnapshot;
  final SyncConflictOperation remoteOperation;
  final SyncConflictResolutionStatus resolutionStatus;
  final int detectedAt;
}

abstract interface class SyncConflictRepository {
  Future<List<SyncConflictRecord>> listActiveConflicts(SyncConflictScope scope);

  Stream<int> watchActiveConflictCount(SyncConflictScope scope);

  Future<SyncConflictRecord> getConflict(SyncConflictScope scope, String id);

  Future<SyncConflictRecord?> findActiveConflict({
    required SyncConflictScope scope,
    required SyncEntityType entityType,
    required String recordId,
  });

  Future<SyncConflictRecord> upsertDetectedConflict(
    SyncConflictDetection detection,
  );

  Future<SyncConflictRecord> hydrateRemoteSnapshot({
    required SyncConflictScope scope,
    required SyncEntityType entityType,
    required String recordId,
    required SyncConflictOperation operation,
    required SyncConflictSnapshot remoteSnapshot,
    required int seenAt,
  });

  Future<void> markAdoptRemoteRequested(SyncConflictScope scope, String id);

  Future<void> markKeepLocalRequested(SyncConflictScope scope, String id);

  Future<void> markResolvedAdoptRemote(
    SyncConflictScope scope,
    String id, {
    required int resolvedAt,
  });

  Future<void> markResolvedKeepLocal(
    SyncConflictScope scope,
    String id, {
    required int resolvedAt,
  });

  Future<void> markSuperseded(
    SyncConflictScope scope,
    String id, {
    required int resolvedAt,
  });
}
