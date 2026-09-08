import 'package:drift/drift.dart';
import 'package:rebirth/core/database/app_database.dart' as db;
import 'package:rebirth/features/sync/domain/conflict_reconciliation_service.dart';
import 'package:rebirth/features/sync/domain/sync_conflict.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_record.dart';
import 'package:rebirth/features/sync/domain/sync_entity_adapter.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_merge_policy.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';
import 'package:rebirth/features/sync/domain/sync_record_baseline.dart';
import 'package:rebirth/features/sync/domain/sync_record_baseline_repository.dart';

typedef SyncCurrentSnapshotLoader =
    Future<SyncConflictSnapshot?> Function({
      required SyncEntityType entityType,
      required String localUserId,
      required String recordId,
    });

/// Adds durable baseline bookkeeping around an existing module adapter.
/// The outer Drift transaction keeps business metadata and its baseline in one
/// commit, including when the wrapped adapter opens a nested transaction.
final class SyncBaselineTrackingAdapter implements SyncEntityAdapter {
  const SyncBaselineTrackingAdapter({
    required this.database,
    required this.delegate,
    required this.baselines,
    required this.policy,
    required this.scopeLoader,
    required this.snapshotLoader,
    this.reconciliationService = const ConflictReconciliationService(),
  });

  final db.AppDatabase database;
  final SyncEntityAdapter delegate;
  final SyncRecordBaselineRepository baselines;
  final SyncMergePolicy policy;
  final Future<SyncConflictScope?> Function() scopeLoader;
  final SyncCurrentSnapshotLoader snapshotLoader;
  final ConflictReconciliationService reconciliationService;

  @override
  SyncEntityType get entityType => delegate.entityType;

  @override
  Future<List<SyncPushItem>> collectPending() => delegate.collectPending();

  @override
  Map<String, Object?> encodePayload(SyncEntityPayload payload) =>
      delegate.encodePayload(payload);

  @override
  SyncChange decodeRemoteChange({
    required String recordId,
    required Map<String, Object?> payload,
    required int updatedAt,
    required int? deletedAt,
    required String originDeviceId,
    required int serverVersion,
  }) => delegate.decodeRemoteChange(
    recordId: recordId,
    payload: payload,
    updatedAt: updatedAt,
    deletedAt: deletedAt,
    originDeviceId: originDeviceId,
    serverVersion: serverVersion,
  );

  @override
  Future<SyncEntityResult> acknowledgePush({
    required List<SyncPushItem> submitted,
    required List<SyncAcknowledgement> accepted,
    required List<SyncConflict> conflicts,
    required int syncedAt,
  }) {
    return database.transaction(() async {
      final result = await delegate.acknowledgePush(
        submitted: submitted,
        accepted: accepted,
        conflicts: conflicts,
        syncedAt: syncedAt,
      );
      final scope = accepted.isEmpty ? null : await scopeLoader();
      if (scope == null) return result;
      final submittedById = {for (final item in submitted) item.recordId: item};
      for (final acknowledgement in accepted) {
        final submittedItem = submittedById[acknowledgement.recordId];
        if (submittedItem == null) continue;
        final localRecordId = _localRecordId(scope, submittedItem.recordId);
        await _capture(
          scope: scope,
          recordId: localRecordId,
          payload: submittedItem.payload,
          tombstone: submittedItem.operation == SyncOperation.delete,
          serverVersion: acknowledgement.serverVersion,
          capturedAt: syncedAt,
        );

        final current = await snapshotLoader(
          entityType: entityType,
          localUserId: scope.localUserId,
          recordId: localRecordId,
        );
        if (!_matchesSubmitted(current, submittedItem)) {
          await _restorePendingAfterStaleAcknowledgement(
            localUserId: scope.localUserId,
            recordId: localRecordId,
          );
        }
      }
      return result;
    });
  }

  @override
  Future<SyncEntityResult> applyRemoteChanges({
    required List<SyncChange> changes,
    required int syncedAt,
    SyncPullMode pullMode = SyncPullMode.incremental,
  }) {
    return database.transaction(() async {
      final result = await delegate.applyRemoteChanges(
        changes: changes,
        syncedAt: syncedAt,
        pullMode: pullMode,
      );
      final scope = changes.isEmpty ? null : await scopeLoader();
      if (scope == null) return result;
      for (final change in changes) {
        final localRecordId = _localRecordId(scope, change.recordId);
        final current = await snapshotLoader(
          entityType: entityType,
          localUserId: scope.localUserId,
          recordId: localRecordId,
        );
        if (!_matchesRemote(current, change)) continue;
        await _capture(
          scope: scope,
          recordId: localRecordId,
          payload: change.payload,
          tombstone: change.operation == SyncOperation.delete,
          serverVersion: change.serverVersion,
          capturedAt: syncedAt,
        );
      }
      return result;
    });
  }

  Future<void> _capture({
    required SyncConflictScope scope,
    required String recordId,
    required SyncEntityPayload? payload,
    required bool tombstone,
    required int serverVersion,
    required int capturedAt,
  }) {
    final hashes = payload == null
        ? const <String, String>{}
        : reconciliationService.hashGroups(policy, encodePayload(payload));
    return baselines.write(
      SyncRecordBaseline(
        localUserId: scope.localUserId,
        entityType: entityType.wireName,
        recordId: recordId,
        baseExists: true,
        baseServerVersion: serverVersion,
        baseTombstone: tombstone,
        groupHashes: hashes,
        capturedAt: capturedAt,
      ),
    );
  }

  String _localRecordId(SyncConflictScope scope, String wireRecordId) =>
      entityType == SyncEntityType.profile ? scope.localUserId : wireRecordId;

  bool _matchesSubmitted(
    SyncConflictSnapshot? current,
    SyncPushItem submitted,
  ) {
    if (current == null || current.updatedAt != submitted.updatedAt) {
      return false;
    }
    if (submitted.operation == SyncOperation.delete) {
      return current.deletedAt == submitted.deletedAt;
    }
    if (current.deletedAt != null || current.payload == null) return false;
    return _samePayload(current.payload!, submitted.payload!);
  }

  bool _matchesRemote(SyncConflictSnapshot? current, SyncChange remote) {
    if (current == null || current.serverVersion != remote.serverVersion) {
      return false;
    }
    if (remote.operation == SyncOperation.delete) {
      return current.deletedAt != null && current.payload == null;
    }
    if (current.deletedAt != null || current.payload == null) return false;
    return _samePayload(current.payload!, remote.payload!);
  }

  bool _samePayload(SyncEntityPayload left, SyncEntityPayload right) {
    final leftHashes = reconciliationService.hashGroups(
      policy,
      encodePayload(left),
    );
    final rightHashes = reconciliationService.hashGroups(
      policy,
      encodePayload(right),
    );
    return policy.fieldGroups.every(
      (group) => leftHashes[group.id] == rightHashes[group.id],
    );
  }

  Future<void> _restorePendingAfterStaleAcknowledgement({
    required String localUserId,
    required String recordId,
  }) async {
    switch (entityType) {
      case SyncEntityType.profile:
        await (database.update(database.userProfiles)..where(
              (row) => row.id.equals(localUserId) & row.isActive.equals(true),
            ))
            .write(
              const db.UserProfilesCompanion(syncStatus: Value('pending')),
            );
      case SyncEntityType.plan:
        await (database.update(database.goals)..where(
              (row) => row.userId.equals(localUserId) & row.id.equals(recordId),
            ))
            .write(const db.GoalsCompanion(syncStatus: Value('pending')));
      case SyncEntityType.today:
        await (database.update(database.todayRecords)..where(
              (row) => row.userId.equals(localUserId) & row.id.equals(recordId),
            ))
            .write(
              const db.TodayRecordsCompanion(syncStatus: Value('pending')),
            );
      case SyncEntityType.journalPromptConfiguration:
        await (database.update(database.journalPromptConfigurations)..where(
              (row) => row.userId.equals(localUserId) & row.id.equals(recordId),
            ))
            .write(
              const db.JournalPromptConfigurationsCompanion(
                syncStatus: Value('pending'),
              ),
            );
      case SyncEntityType.journal:
        await (database.update(database.journalEntries)..where(
              (row) => row.userId.equals(localUserId) & row.id.equals(recordId),
            ))
            .write(
              const db.JournalEntriesCompanion(syncStatus: Value('pending')),
            );
      case SyncEntityType.health:
        await (database.update(database.healthRecords)..where(
              (row) => row.userId.equals(localUserId) & row.id.equals(recordId),
            ))
            .write(
              const db.HealthRecordsCompanion(syncStatus: Value('pending')),
            );
      case SyncEntityType.aiReport:
        await (database.update(database.aiReports)..where(
              (row) => row.userId.equals(localUserId) & row.id.equals(recordId),
            ))
            .write(const db.AiReportsCompanion(syncStatus: Value('pending')));
    }
  }
}
