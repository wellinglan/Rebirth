import 'sync_entity_type.dart';
import 'sync_models.dart';

enum SyncConflictOperation {
  upsert('upsert'),
  delete('delete'),
  unknownPendingPull('unknown_pending_pull');

  const SyncConflictOperation(this.wireValue);

  final String wireValue;

  static SyncConflictOperation parse(String value) {
    return values.firstWhere(
      (item) => item.wireValue == value,
      orElse: () =>
          throw FormatException('Unknown sync conflict operation: $value'),
    );
  }
}

enum SyncConflictResolutionStatus {
  unresolved('unresolved'),
  awaitingRemoteSnapshot('awaiting_remote_snapshot'),
  adoptRemoteRequested('adopt_remote_requested'),
  keepLocalRequested('keep_local_requested'),
  resolvedAdoptRemote('resolved_adopt_remote'),
  resolvedKeepLocal('resolved_keep_local'),
  superseded('superseded');

  const SyncConflictResolutionStatus(this.wireValue);

  final String wireValue;

  bool get isResolved =>
      this == resolvedAdoptRemote ||
      this == resolvedKeepLocal ||
      this == superseded;

  static SyncConflictResolutionStatus parse(String value) {
    return values.firstWhere(
      (item) => item.wireValue == value,
      orElse: () => throw FormatException(
        'Unknown sync conflict resolution status: $value',
      ),
    );
  }
}

enum SyncConflictResolutionAction { adoptRemote, keepLocal }

final class SyncConflictScope {
  const SyncConflictScope({
    required this.localUserId,
    required this.endpointKey,
    required this.cloudUserId,
  });

  final String localUserId;
  final String endpointKey;
  final String cloudUserId;
}

final class SyncConflictSnapshot {
  const SyncConflictSnapshot({
    required this.payload,
    required this.updatedAt,
    required this.deletedAt,
    required this.serverVersion,
    required this.originDeviceId,
  });

  final SyncEntityPayload? payload;
  final int? updatedAt;
  final int? deletedAt;
  final int? serverVersion;
  final String? originDeviceId;
}

final class SyncConflictRecord {
  const SyncConflictRecord({
    required this.id,
    required this.scope,
    required this.entityType,
    required this.recordId,
    required this.localSnapshot,
    required this.remoteSnapshot,
    required this.remoteOperation,
    required this.detectedAt,
    required this.lastSeenAt,
    required this.resolutionStatus,
    required this.resolvedAt,
  });

  final String id;
  final SyncConflictScope scope;
  final SyncEntityType entityType;
  final String recordId;
  final SyncConflictSnapshot localSnapshot;
  final SyncConflictSnapshot remoteSnapshot;
  final SyncConflictOperation remoteOperation;
  final int detectedAt;
  final int lastSeenAt;
  final SyncConflictResolutionStatus resolutionStatus;
  final int? resolvedAt;

  bool get isActive => resolvedAt == null && !resolutionStatus.isResolved;
  bool get remoteSnapshotReady =>
      remoteOperation != SyncConflictOperation.unknownPendingPull &&
      remoteSnapshot.serverVersion != null &&
      (remoteOperation == SyncConflictOperation.delete ||
          remoteSnapshot.payload != null);
}

final class SyncConflictDetails {
  const SyncConflictDetails({
    required this.record,
    required this.currentLocalSnapshot,
    required this.localSnapshotChanged,
  });

  final SyncConflictRecord record;
  final SyncConflictSnapshot? currentLocalSnapshot;
  final bool localSnapshotChanged;
}

final class SyncConflictNotFoundException implements Exception {
  const SyncConflictNotFoundException();
}

final class SyncConflictNotReadyException implements Exception {
  const SyncConflictNotReadyException([this.message = '冲突尚未取得完整云端版本。']);

  final String message;
}

final class SyncConflictChangedException implements Exception {
  const SyncConflictChangedException([this.message = '冲突的云端版本已经变化，请重新查看。']);

  final String message;
}

final class SyncConflictResolutionException implements Exception {
  const SyncConflictResolutionException(this.message);

  final String message;
}
