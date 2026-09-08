import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/growth/presentation/growth_controller.dart';
import 'package:rebirth/features/personal_data/application/personal_data_aggregation_controller.dart';
import 'package:rebirth/features/personal_data/application/personal_data_providers.dart';
import 'package:rebirth/features/profile/data/profile_sync_repository_provider.dart';
import 'package:rebirth/features/sync/data/sync_conflict_providers.dart';
import 'package:rebirth/features/sync/data/sync_providers.dart';

import '../application/sync_all_orchestrator.dart';
import '../application/sync_module_registry.dart';
import '../application/sync_module_runner.dart';
import '../domain/sync_module.dart';
import '../domain/sync_models.dart';
import 'health_sync_controller.dart';
import 'ai_report_sync_controller.dart';
import 'journal_sync_controller.dart';
import 'plan_sync_controller.dart';
import 'profile_sync_controller.dart';
import 'today_sync_controller.dart';

final syncModuleRegistryProvider = Provider<SyncModuleRegistry>((ref) {
  return createDefaultSyncModuleRegistry();
});

final syncModuleRunnersProvider = Provider<List<SyncModuleRunner>>((ref) {
  final registry = ref.watch(syncModuleRegistryProvider);
  SyncModuleDescriptor descriptor(SyncModuleId id) =>
      registry.descriptorFor(id);
  Future<SyncRunResult> runAndRefresh(
    SyncModuleId moduleId,
    Future<SyncRunResult> Function() operation,
  ) async {
    final initial = await operation();
    final result = await ref
        .read(syncConflictReconciliationRunnerProvider)
        .reconcile(
          entityTypes: descriptor(moduleId).entityTypes,
          initialResult: initial,
        );
    ref.invalidate(personalDataAggregationControllerProvider);
    ref.invalidate(personalDataProviderRegistryProvider);
    ref.invalidate(growthControllerProvider);
    ref.invalidate(activeSyncConflictCountProvider);
    ref.invalidate(activeSyncConflictListProvider);
    return result;
  }

  return List.unmodifiable([
    CallbackSyncModuleRunner(
      descriptor: descriptor(SyncModuleId.profile),
      onRun: () => runAndRefresh(
        SyncModuleId.profile,
        ref.read(profileSyncControllerProvider.notifier).syncProfile,
      ),
      onRefresh: () async {
        ref.invalidate(profileSyncConflictProvider);
      },
    ),
    CallbackSyncModuleRunner(
      descriptor: descriptor(SyncModuleId.plan),
      onRun: () => runAndRefresh(
        SyncModuleId.plan,
        ref.read(planSyncControllerProvider.notifier).syncPlan,
      ),
      onRefresh: ref
          .read(planSyncControllerProvider.notifier)
          .reloadConflictCount,
    ),
    CallbackSyncModuleRunner(
      descriptor: descriptor(SyncModuleId.today),
      onRun: () => runAndRefresh(
        SyncModuleId.today,
        ref.read(todaySyncControllerProvider.notifier).syncToday,
      ),
      onRefresh: ref
          .read(todaySyncControllerProvider.notifier)
          .reloadConflictCount,
    ),
    CallbackSyncModuleRunner(
      descriptor: descriptor(SyncModuleId.journal),
      onRun: () => runAndRefresh(
        SyncModuleId.journal,
        ref.read(journalSyncControllerProvider.notifier).syncJournal,
      ),
      onRefresh: ref
          .read(journalSyncControllerProvider.notifier)
          .reloadConflictCount,
    ),
    CallbackSyncModuleRunner(
      descriptor: descriptor(SyncModuleId.health),
      onRun: () => runAndRefresh(
        SyncModuleId.health,
        ref.read(healthSyncControllerProvider.notifier).syncHealth,
      ),
      onRefresh: ref
          .read(healthSyncControllerProvider.notifier)
          .reloadConflictCount,
    ),
    CallbackSyncModuleRunner(
      descriptor: descriptor(SyncModuleId.aiReport),
      onRun: () => runAndRefresh(
        SyncModuleId.aiReport,
        ref.read(aiReportSyncControllerProvider.notifier).syncAiReports,
      ),
      onRefresh: ref
          .read(aiReportSyncControllerProvider.notifier)
          .reloadConflictCount,
    ),
  ]);
});

final syncAllOrchestratorProvider = Provider<SyncAllOrchestrator>((ref) {
  final clock = ref.watch(dateTimeServiceProvider);
  return SyncAllOrchestrator(
    registry: ref.watch(syncModuleRegistryProvider),
    runners: ref.watch(syncModuleRunnersProvider),
    nowMilliseconds: () => clock.currentSnapshot().utcMilliseconds,
  );
});
