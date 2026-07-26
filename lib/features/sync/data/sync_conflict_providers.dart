import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/config/server_endpoint_provider.dart';
import 'package:rebirth/core/database/database_provider.dart';
import 'package:rebirth/features/account/data/account_repository_provider.dart';
import 'package:rebirth/features/account/domain/account_boundary.dart';
import 'package:rebirth/features/plan/data/plan_conflict_resolution_service_impl.dart';
import 'package:rebirth/features/plan/data/plan_sync_payload_codec.dart';
import 'package:rebirth/features/plan/domain/plan_conflict_resolution_service.dart';
import 'package:rebirth/features/plan/domain/plan_goal.dart';
import 'package:rebirth/features/plan/domain/plan_sync_payload.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_record.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_repository.dart';

import 'sync_conflict_repository_impl.dart';

final syncConflictRepositoryProvider = Provider<SyncConflictRepository>((ref) {
  return SyncConflictRepositoryImpl(
    ref.watch(appDatabaseProvider),
    payloadCodecs: const [PlanSyncPayloadCodec()],
  );
});

final syncConflictScopeProvider = FutureProvider<SyncConflictScope?>((
  ref,
) async {
  final endpoint = ref.watch(effectiveServerEndpointProvider).baseUrl;
  final normalized = ref
      .watch(serverEndpointValidatorProvider)
      .normalize(endpoint);
  final session = await ref.watch(authSessionStoreProvider).read();
  if (session == null ||
      session.user.id.trim().isEmpty ||
      session.serverBaseUrl.trim().isEmpty) {
    return null;
  }
  final sessionEndpoint = ref
      .read(serverEndpointValidatorProvider)
      .normalize(session.serverBaseUrl);
  if (sessionEndpoint != normalized) return null;
  final String localUserId;
  try {
    localUserId = await ref
        .watch(accountBoundaryRepositoryProvider)
        .requireActiveScope(endpoint: normalized, cloudUserId: session.user.id);
  } on AccountScopeMismatchException {
    return null;
  }
  return SyncConflictScope(
    localUserId: localUserId,
    endpointKey: normalized,
    cloudUserId: session.user.id,
  );
});

final activeSyncConflictCountProvider = StreamProvider<int>((ref) async* {
  final scope = await ref.watch(syncConflictScopeProvider.future);
  if (scope == null) {
    yield 0;
    return;
  }
  yield* ref
      .watch(syncConflictRepositoryProvider)
      .watchActiveConflictCount(scope);
});

final activeSyncConflictListProvider = FutureProvider<List<SyncConflictRecord>>(
  (ref) async {
    final scope = await ref.watch(syncConflictScopeProvider.future);
    if (scope == null) return const [];
    return ref.watch(syncConflictRepositoryProvider).listActiveConflicts(scope);
  },
);

final syncConflictDetailsProvider =
    FutureProvider.family<SyncConflictDetails, String>((ref, id) async {
      final scope = await ref.watch(syncConflictScopeProvider.future);
      if (scope == null) throw const SyncConflictNotFoundException();
      final record = await ref
          .watch(syncConflictRepositoryProvider)
          .getConflict(scope, id);
      final database = ref.watch(appDatabaseProvider);
      final goal =
          await (database.select(database.goals)..where(
                (row) =>
                    row.userId.equals(scope.localUserId) &
                    row.id.equals(record.recordId),
              ))
              .getSingleOrNull();
      final current = goal == null
          ? null
          : SyncConflictSnapshot(
              payload: goal.deletedAt == null
                  ? PlanSyncPayload(
                      parentGoalId: goal.parentGoalId,
                      title: goal.title,
                      description: goal.description,
                      goalLevel: planGoalLevelFromDatabase(goal.goalLevel),
                      status: planGoalStatusFromDatabase(goal.status),
                      startDate: goal.startDate,
                      targetDate: goal.targetDate,
                      completedAt: goal.completedAt,
                      archivedAt: goal.archivedAt,
                      sortOrder: goal.sortOrder,
                      createdAt: goal.createdAt,
                    )
                  : null,
              updatedAt: goal.updatedAt,
              deletedAt: goal.deletedAt,
              serverVersion: goal.serverVersion,
              originDeviceId: goal.originDeviceId,
            );
      return SyncConflictDetails(
        record: record,
        currentLocalSnapshot: current,
        localSnapshotChanged:
            current == null ||
            current.updatedAt != record.localSnapshot.updatedAt ||
            !_samePlanPayload(current.payload, record.localSnapshot.payload),
      );
    });

final planConflictResolutionServiceProvider =
    Provider<PlanConflictResolutionService>((ref) {
      return PlanConflictResolutionServiceImpl(
        ref.watch(appDatabaseProvider),
        ref.watch(syncConflictRepositoryProvider),
      );
    });

bool _samePlanPayload(Object? left, Object? right) {
  if (left is! PlanSyncPayload || right is! PlanSyncPayload) {
    return left == null && right == null;
  }
  return left.parentGoalId == right.parentGoalId &&
      left.title == right.title &&
      left.description == right.description &&
      left.goalLevel == right.goalLevel &&
      left.status == right.status &&
      left.startDate == right.startDate &&
      left.targetDate == right.targetDate &&
      left.completedAt == right.completedAt &&
      left.archivedAt == right.archivedAt &&
      left.sortOrder == right.sortOrder &&
      left.createdAt == right.createdAt;
}
