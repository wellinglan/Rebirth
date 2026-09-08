import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/config/server_endpoint_provider.dart';
import 'package:rebirth/core/database/database_provider.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/account/data/account_repository_provider.dart';
import 'package:rebirth/features/ai_coach/data/ai_report_sync_adapter.dart';
import 'package:rebirth/features/journal/data/journal_sync_adapter.dart';
import 'package:rebirth/features/journal/data/journal_prompt_repository_provider.dart';
import 'package:rebirth/features/journal/data/journal_prompt_sync_adapter.dart';
import 'package:rebirth/features/health/data/health_sync_adapter.dart';
import 'package:rebirth/features/profile/data/profile_sync_adapter.dart';
import 'package:rebirth/features/plan/data/plan_sync_adapter.dart';
import 'package:rebirth/features/sync/application/sync_coordinator.dart';
import 'package:rebirth/features/sync/application/sync_conflict_reconciliation_runner.dart';
import 'package:rebirth/features/sync/domain/sync_entity_adapter.dart';
import 'package:rebirth/features/sync/domain/sync_merge_policy.dart';
import 'package:rebirth/features/sync/domain/sync_record_baseline_repository.dart';
import 'package:rebirth/features/today/data/today_sync_adapter.dart';

import 'sync_repository_provider.dart';
import 'sync_conflict_providers.dart';
import 'default_sync_merge_policies.dart';
import 'sync_baseline_tracking_adapter.dart';
import 'sync_record_baseline_repository_impl.dart';
import 'sync_reconciliation_executor.dart';

final syncRecordBaselineRepositoryProvider =
    Provider<SyncRecordBaselineRepository>((ref) {
      return SyncRecordBaselineRepositoryImpl(ref.watch(appDatabaseProvider));
    });

final syncMergePolicyRegistryProvider = Provider<SyncMergePolicyRegistry>((
  ref,
) {
  return createDefaultSyncMergePolicyRegistry();
});

final profileSyncAdapterProvider = Provider<ProfileSyncAdapter>((ref) {
  return ProfileSyncAdapter(
    ref.watch(appDatabaseProvider),
    ref.watch(syncConflictRepositoryProvider),
    () => ref.read(syncConflictScopeProvider.future),
  );
});

final planSyncAdapterProvider = Provider<PlanSyncAdapter>((ref) {
  return PlanSyncAdapter(
    ref.watch(appDatabaseProvider),
    ref.watch(syncConflictRepositoryProvider),
    () => ref.read(syncConflictScopeProvider.future),
    ref.watch(dateTimeServiceProvider),
  );
});

final todaySyncAdapterProvider = Provider<TodaySyncAdapter>((ref) {
  return TodaySyncAdapter(
    ref.watch(appDatabaseProvider),
    ref.watch(syncConflictRepositoryProvider),
    () => ref.read(syncConflictScopeProvider.future),
  );
});

final journalSyncAdapterProvider = Provider<JournalSyncAdapter>((ref) {
  return JournalSyncAdapter(
    ref.watch(appDatabaseProvider),
    ref.watch(syncConflictRepositoryProvider),
    () => ref.read(syncConflictScopeProvider.future),
  );
});

final journalPromptSyncAdapterProvider = Provider<JournalPromptSyncAdapter>((
  ref,
) {
  return JournalPromptSyncAdapter(
    ref.watch(appDatabaseProvider),
    ref.watch(journalPromptRepositoryProvider),
    ref.watch(syncConflictRepositoryProvider),
    () => ref.read(syncConflictScopeProvider.future),
  );
});

final healthSyncAdapterProvider = Provider<HealthSyncAdapter>((ref) {
  return HealthSyncAdapter(
    ref.watch(appDatabaseProvider),
    ref.watch(syncConflictRepositoryProvider),
    () => ref.read(syncConflictScopeProvider.future),
  );
});

final aiReportSyncAdapterProvider = Provider<AiReportSyncAdapter>((ref) {
  return AiReportSyncAdapter(
    ref.watch(appDatabaseProvider),
    ref.watch(syncConflictRepositoryProvider),
    () => ref.read(syncConflictScopeProvider.future),
  );
});

final syncEntityAdapterRegistryProvider = Provider<SyncEntityAdapterRegistry>((
  ref,
) {
  final database = ref.watch(appDatabaseProvider);
  final baselines = ref.watch(syncRecordBaselineRepositoryProvider);
  final policies = ref.watch(syncMergePolicyRegistryProvider);
  final delegates = <SyncEntityAdapter>[
    ref.watch(profileSyncAdapterProvider),
    ref.watch(todaySyncAdapterProvider),
    ref.watch(journalPromptSyncAdapterProvider),
    ref.watch(journalSyncAdapterProvider),
    ref.watch(healthSyncAdapterProvider),
    ref.watch(aiReportSyncAdapterProvider),
    ref.watch(planSyncAdapterProvider),
  ];
  SyncEntityAdapter track(SyncEntityAdapter delegate) {
    final SyncMergePolicy policy = policies.policyFor(delegate.entityType);
    return SyncBaselineTrackingAdapter(
      database: database,
      delegate: delegate,
      baselines: baselines,
      policy: policy,
      scopeLoader: () => ref.read(syncConflictScopeProvider.future),
      snapshotLoader:
          ({required entityType, required localUserId, required recordId}) =>
              loadCurrentSyncSnapshot(
                database,
                entityType,
                localUserId,
                recordId,
              ),
    );
  }

  return SyncEntityAdapterRegistry([
    for (final delegate in delegates) track(delegate),
  ]);
});

final syncCoordinatorProvider = Provider<SyncCoordinator>((ref) {
  final endpoint = ref.watch(effectiveServerEndpointProvider).baseUrl;
  return SyncCoordinator(
    endpoint: endpoint,
    sessionManager: ref.watch(authSessionManagerProvider),
    remoteDataSource: ref.watch(syncRemoteDataSourceProvider),
    cursorStore: ref.watch(syncCursorStoreProvider),
    adapterRegistry: ref.watch(syncEntityAdapterRegistryProvider),
    endpointProbe: (candidate) async {
      await ref.read(serverEndpointConnectionTesterProvider).test(candidate);
    },
    dateTimeService: ref.watch(dateTimeServiceProvider),
    accountScopeGuard: ({required endpoint, required cloudUserId}) {
      return ref
          .read(accountBoundaryRepositoryProvider)
          .requireActiveScope(endpoint: endpoint, cloudUserId: cloudUserId);
    },
  );
});

final syncReconciliationExecutorProvider = Provider<SyncReconciliationExecutor>(
  (ref) {
    return SyncReconciliationExecutor(
      database: ref.watch(appDatabaseProvider),
      conflicts: ref.watch(syncConflictRepositoryProvider),
      clock: ref.watch(dateTimeServiceProvider),
    );
  },
);

final syncConflictReconciliationRunnerProvider =
    Provider<SyncConflictReconciliationRunner>((ref) {
      final database = ref.watch(appDatabaseProvider);
      final coordinator = ref.watch(syncCoordinatorProvider);
      final executor = ref.watch(syncReconciliationExecutorProvider);
      return SyncConflictReconciliationRunner(
        syncRunner:
            ({required direction, required entityTypes, required pullMode}) =>
                coordinator.run(
                  direction: direction,
                  entityTypes: entityTypes,
                  pullMode: pullMode,
                ),
        conflicts: ref.watch(syncConflictRepositoryProvider),
        baselines: ref.watch(syncRecordBaselineRepositoryProvider),
        policies: ref.watch(syncMergePolicyRegistryProvider),
        adapters: ref.watch(syncEntityAdapterRegistryProvider),
        prepareLocalRetry:
            ({
              required scope,
              required conflictId,
              required expectedLocal,
              mergedPayload,
            }) => executor.prepareLocalRetry(
              scope: scope,
              conflictId: conflictId,
              expectedLocal: expectedLocal,
              mergedPayload: mergedPayload,
            ),
        scopeLoader: () => ref.read(syncConflictScopeProvider.future),
        executionGuard: (expected) async {
          final current = await ref.read(syncConflictScopeProvider.future);
          if (current == null ||
              current.localUserId != expected.localUserId ||
              current.endpointKey != expected.endpointKey ||
              current.cloudUserId != expected.cloudUserId) {
            return false;
          }
          final sessionManager = ref.read(authSessionManagerProvider);
          await sessionManager.initialize();
          final session = sessionManager.state.session;
          return session != null &&
              session.user.id == expected.cloudUserId &&
              session.deviceRegistration?.isRegistered == true;
        },
        snapshotLoader:
            ({required entityType, required localUserId, required recordId}) =>
                loadCurrentSyncSnapshot(
                  database,
                  entityType,
                  localUserId,
                  recordId,
                ),
      );
    });
