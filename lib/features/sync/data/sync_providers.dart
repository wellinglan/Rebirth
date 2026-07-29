import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/config/server_endpoint_provider.dart';
import 'package:rebirth/core/database/database_provider.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/account/data/account_repository_provider.dart';
import 'package:rebirth/features/journal/data/journal_sync_adapter.dart';
import 'package:rebirth/features/journal/data/journal_prompt_repository_provider.dart';
import 'package:rebirth/features/journal/data/journal_prompt_sync_adapter.dart';
import 'package:rebirth/features/health/data/health_sync_adapter.dart';
import 'package:rebirth/features/profile/data/profile_sync_adapter.dart';
import 'package:rebirth/features/plan/data/plan_sync_adapter.dart';
import 'package:rebirth/features/sync/application/sync_coordinator.dart';
import 'package:rebirth/features/sync/domain/sync_entity_adapter.dart';
import 'package:rebirth/features/today/data/today_sync_adapter.dart';

import 'sync_repository_provider.dart';
import 'sync_conflict_providers.dart';

final profileSyncAdapterProvider = Provider<ProfileSyncAdapter>((ref) {
  return ProfileSyncAdapter(ref.watch(appDatabaseProvider));
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

final syncEntityAdapterRegistryProvider = Provider<SyncEntityAdapterRegistry>((
  ref,
) {
  return SyncEntityAdapterRegistry([
    ref.watch(profileSyncAdapterProvider),
    ref.watch(todaySyncAdapterProvider),
    ref.watch(journalPromptSyncAdapterProvider),
    ref.watch(journalSyncAdapterProvider),
    ref.watch(healthSyncAdapterProvider),
    ref.watch(planSyncAdapterProvider),
  ]);
});

final syncCoordinatorProvider = Provider<SyncCoordinator>((ref) {
  final endpoint = ref.watch(effectiveServerEndpointProvider).baseUrl;
  return SyncCoordinator(
    endpoint: endpoint,
    sessionStore: ref.watch(authSessionStoreProvider),
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
