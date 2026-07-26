import 'sync_entity_type.dart';

enum SyncOperation { upsert, delete }

abstract interface class SyncEntityPayload {}

final class SyncPushItem {
  const SyncPushItem({
    required this.entityType,
    required this.operation,
    required this.recordId,
    required this.payload,
    required this.updatedAt,
    required this.deletedAt,
    required this.originDeviceId,
    required this.clientVersion,
  });

  final SyncEntityType entityType;
  final SyncOperation operation;
  final String recordId;
  final SyncEntityPayload? payload;
  final int updatedAt;
  final int? deletedAt;
  final String originDeviceId;
  final int clientVersion;
}

final class SyncChange {
  const SyncChange({
    required this.entityType,
    required this.operation,
    required this.recordId,
    required this.payload,
    required this.updatedAt,
    required this.deletedAt,
    required this.originDeviceId,
    required this.serverVersion,
  });

  final SyncEntityType entityType;
  final SyncOperation operation;
  final String recordId;
  final SyncEntityPayload? payload;
  final int updatedAt;
  final int? deletedAt;
  final String originDeviceId;
  final int serverVersion;
}

final class SyncPullPage {
  SyncPullPage({
    required this.entityType,
    required this.serverVersion,
    required List<SyncChange> changes,
  }) : changes = List.unmodifiable(changes);

  final SyncEntityType entityType;
  final int serverVersion;
  final List<SyncChange> changes;
}

final class SyncCursor {
  const SyncCursor({
    required this.endpoint,
    required this.cloudUserId,
    required this.scope,
    required this.serverVersion,
  });

  final String endpoint;
  final String cloudUserId;
  final SyncEntityType scope;
  final int serverVersion;
}

final class SyncAcknowledgement {
  const SyncAcknowledgement({
    required this.entityType,
    required this.recordId,
    required this.serverVersion,
  });

  final SyncEntityType entityType;
  final String recordId;
  final int serverVersion;
}

enum SyncRunDirection { push, pull, twoWay }

enum SyncRunPhase {
  endpointCheck,
  sessionCheck,
  accountScopeCheck,
  deviceCheck,
  cursorRead,
  collectPending,
  push,
  acknowledgePush,
  pull,
  apply,
  cursorAdvance,
  completed,
  failed,
}

enum SyncEntityStatus { noChanges, succeeded, conflict, failed }

final class SyncEntityResult {
  const SyncEntityResult({
    required this.entityType,
    required this.status,
    required this.message,
    this.pushedCount = 0,
    this.pulledCount = 0,
    this.deletedCount = 0,
    this.ignoredCount = 0,
    this.conflictCount = 0,
    this.serverVersion,
  });

  final SyncEntityType entityType;
  final SyncEntityStatus status;
  final String message;
  final int pushedCount;
  final int pulledCount;
  final int deletedCount;
  final int ignoredCount;
  final int conflictCount;
  final int? serverVersion;

  bool get isSuccessful =>
      status == SyncEntityStatus.succeeded ||
      status == SyncEntityStatus.noChanges;

  SyncEntityResult merge(SyncEntityResult other) {
    if (entityType != other.entityType) {
      throw ArgumentError('Cannot merge results for different entity types.');
    }
    final mergedStatus = switch ((status, other.status)) {
      (SyncEntityStatus.failed, _) ||
      (_, SyncEntityStatus.failed) => SyncEntityStatus.failed,
      (SyncEntityStatus.conflict, _) ||
      (_, SyncEntityStatus.conflict) => SyncEntityStatus.conflict,
      (SyncEntityStatus.succeeded, _) ||
      (_, SyncEntityStatus.succeeded) => SyncEntityStatus.succeeded,
      _ => SyncEntityStatus.noChanges,
    };
    return SyncEntityResult(
      entityType: entityType,
      status: mergedStatus,
      message: other.message,
      pushedCount: pushedCount + other.pushedCount,
      pulledCount: pulledCount + other.pulledCount,
      deletedCount: deletedCount + other.deletedCount,
      ignoredCount: ignoredCount + other.ignoredCount,
      conflictCount: conflictCount + other.conflictCount,
      serverVersion: other.serverVersion ?? serverVersion,
    );
  }
}

enum SyncFailureReason {
  endpointUnavailable,
  authenticationRequired,
  cloudUserUnavailable,
  accountScopeMismatch,
  deviceRegistrationRequired,
  syncInProgress,
  unsupportedEntity,
  pushFailed,
  pullFailed,
  payloadInvalid,
  applyFailed,
  conflict,
  cursorFailed,
  unexpected,
}

final class SyncFailure {
  const SyncFailure({
    required this.reason,
    required this.phase,
    required this.message,
    this.entityType,
  });

  final SyncFailureReason reason;
  final SyncRunPhase phase;
  final String message;
  final SyncEntityType? entityType;
}

final class SyncRunResult {
  SyncRunResult({
    required this.direction,
    required List<SyncRunPhase> phases,
    required List<SyncEntityResult> entityResults,
    required this.startedAt,
    required this.completedAt,
    this.failure,
  }) : phases = List.unmodifiable(phases),
       entityResults = List.unmodifiable(entityResults);

  final SyncRunDirection direction;
  final List<SyncRunPhase> phases;
  final List<SyncEntityResult> entityResults;
  final int startedAt;
  final int completedAt;
  final SyncFailure? failure;

  bool get isSuccessful =>
      failure == null && entityResults.every((result) => result.isSuccessful);

  bool get isPartialSuccess =>
      !isSuccessful &&
      entityResults.any(
        (result) =>
            result.isSuccessful ||
            result.pushedCount > 0 ||
            result.pulledCount > 0,
      );

  SyncEntityResult? resultFor(SyncEntityType entityType) {
    for (final result in entityResults) {
      if (result.entityType == entityType) return result;
    }
    return null;
  }
}
