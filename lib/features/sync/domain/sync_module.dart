import 'sync_entity_type.dart';
import 'sync_models.dart';

enum SyncModuleId {
  profile('module.profile'),
  plan('module.plan'),
  today('module.today'),
  journal('module.journal'),
  health('module.health'),
  aiReport('module.ai_report');

  const SyncModuleId(this.stableId);

  final String stableId;
}

enum SyncModuleSensitivity { standard, sensitive }

final class SyncModuleDescriptor {
  SyncModuleDescriptor({
    required this.moduleId,
    required this.displayName,
    required this.description,
    required this.displayOrder,
    required Iterable<SyncEntityType> entityTypes,
    required this.sensitivity,
    this.supportsIndependentSync = true,
  }) : entityTypes = List.unmodifiable(entityTypes),
       conflictEntityTypes = Set.unmodifiable(entityTypes);

  final SyncModuleId moduleId;
  final String displayName;
  final String description;
  final int displayOrder;
  final List<SyncEntityType> entityTypes;
  final Set<SyncEntityType> conflictEntityTypes;
  final SyncModuleSensitivity sensitivity;
  final bool supportsIndependentSync;
}

enum SyncModuleExecutionStatus {
  idle,
  queued,
  running,
  noChanges,
  succeeded,
  conflict,
  partial,
  failed,
  skipped,
}

final class SyncModuleExecutionResult {
  SyncModuleExecutionResult({
    required this.moduleId,
    required this.status,
    required this.startedAt,
    required this.completedAt,
    required Iterable<SyncEntityResult> entityResults,
    required this.userFacingMessage,
    this.failureReason,
  }) : entityResults = List.unmodifiable(entityResults);

  factory SyncModuleExecutionResult.fromRun({
    required SyncModuleDescriptor descriptor,
    required SyncRunResult run,
  }) {
    final results = run.entityResults
        .where((result) => descriptor.entityTypes.contains(result.entityType))
        .toList(growable: false);
    final failedEntities = results
        .where((result) => result.status == SyncEntityStatus.failed)
        .length;
    final conflicts = results.fold(
      0,
      (total, result) => total + result.conflictCount,
    );
    final hasProgress = results.any(
      (result) =>
          result.isSuccessful ||
          result.pushedCount > 0 ||
          result.pulledCount > 0 ||
          result.deletedCount > 0,
    );
    final SyncModuleExecutionStatus status;
    if (conflicts > 0) {
      status = hasProgress || failedEntities > 0
          ? SyncModuleExecutionStatus.partial
          : SyncModuleExecutionStatus.conflict;
    } else if (failedEntities > 0) {
      status = hasProgress
          ? SyncModuleExecutionStatus.partial
          : SyncModuleExecutionStatus.failed;
    } else if (run.failure?.reason == SyncFailureReason.conflict) {
      status = SyncModuleExecutionStatus.conflict;
    } else if (run.failure != null) {
      status = hasProgress
          ? SyncModuleExecutionStatus.partial
          : SyncModuleExecutionStatus.failed;
    } else if (results.every(
      (result) =>
          result.status == SyncEntityStatus.noChanges &&
          result.pushedCount == 0 &&
          result.pulledCount == 0 &&
          result.deletedCount == 0,
    )) {
      status = SyncModuleExecutionStatus.noChanges;
    } else {
      status = SyncModuleExecutionStatus.succeeded;
    }
    return SyncModuleExecutionResult(
      moduleId: descriptor.moduleId,
      status: status,
      startedAt: run.startedAt,
      completedAt: run.completedAt,
      entityResults: results,
      userFacingMessage: _messageFor(status, run.failure),
      failureReason: run.failure?.reason,
    );
  }

  factory SyncModuleExecutionResult.skipped({
    required SyncModuleId moduleId,
    required int timestamp,
    required String message,
  }) {
    return SyncModuleExecutionResult(
      moduleId: moduleId,
      status: SyncModuleExecutionStatus.skipped,
      startedAt: timestamp,
      completedAt: timestamp,
      entityResults: const [],
      userFacingMessage: message,
    );
  }

  final SyncModuleId moduleId;
  final SyncModuleExecutionStatus status;
  final int startedAt;
  final int completedAt;
  final List<SyncEntityResult> entityResults;
  final String userFacingMessage;
  final SyncFailureReason? failureReason;

  int get pushedCount =>
      entityResults.fold(0, (total, item) => total + item.pushedCount);
  int get pulledCount =>
      entityResults.fold(0, (total, item) => total + item.pulledCount);
  int get deletedCount =>
      entityResults.fold(0, (total, item) => total + item.deletedCount);
  int get ignoredCount =>
      entityResults.fold(0, (total, item) => total + item.ignoredCount);
  int get conflictCount =>
      entityResults.fold(0, (total, item) => total + item.conflictCount);
  int get failedEntityCount => entityResults
      .where((item) => item.status == SyncEntityStatus.failed)
      .length;

  bool get isPartialSuccess => status == SyncModuleExecutionStatus.partial;
  bool get hasConflict =>
      status == SyncModuleExecutionStatus.conflict || conflictCount > 0;

  bool get isGlobalFailure => switch (failureReason) {
    SyncFailureReason.endpointUnavailable ||
    SyncFailureReason.authenticationRequired ||
    SyncFailureReason.cloudUserUnavailable ||
    SyncFailureReason.accountScopeMismatch ||
    SyncFailureReason.accountSyncReviewRequired ||
    SyncFailureReason.deviceRegistrationRequired => true,
    _ => false,
  };

  static String _messageFor(
    SyncModuleExecutionStatus status,
    SyncFailure? failure,
  ) {
    return switch (status) {
      SyncModuleExecutionStatus.noChanges => '没有新变化',
      SyncModuleExecutionStatus.succeeded => '同步完成',
      SyncModuleExecutionStatus.conflict => '部分数据需要处理',
      SyncModuleExecutionStatus.partial => '部分完成，请查看结果',
      SyncModuleExecutionStatus.failed => failure?.message ?? '同步失败，本地数据未受影响',
      SyncModuleExecutionStatus.skipped => '未执行',
      SyncModuleExecutionStatus.idle => '等待同步',
      SyncModuleExecutionStatus.queued => '等待执行',
      SyncModuleExecutionStatus.running => '正在同步',
    };
  }
}

final class SyncAllExecutionResult {
  SyncAllExecutionResult({
    required Iterable<SyncModuleExecutionResult> moduleResults,
    required this.startedAt,
    required this.completedAt,
  }) : moduleResults = List.unmodifiable(moduleResults);

  final List<SyncModuleExecutionResult> moduleResults;
  final int startedAt;
  final int completedAt;

  int get pushedCount =>
      moduleResults.fold(0, (total, item) => total + item.pushedCount);
  int get pulledCount =>
      moduleResults.fold(0, (total, item) => total + item.pulledCount);
  int get deletedCount =>
      moduleResults.fold(0, (total, item) => total + item.deletedCount);
  int get conflictCount =>
      moduleResults.fold(0, (total, item) => total + item.conflictCount);
  int get failedEntityCount =>
      moduleResults.fold(0, (total, item) => total + item.failedEntityCount);

  bool get hasFailure => moduleResults.any(
    (item) =>
        item.status == SyncModuleExecutionStatus.failed ||
        item.status == SyncModuleExecutionStatus.partial,
  );
  bool get hasConflict => moduleResults.any((item) => item.hasConflict);
  bool get isPartialSuccess => hasFailure || hasConflict;
}
