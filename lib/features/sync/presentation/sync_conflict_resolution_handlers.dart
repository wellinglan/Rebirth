import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';

import 'plan_sync_controller.dart';
import 'journal_sync_controller.dart';
import 'today_sync_controller.dart';
import 'health_sync_controller.dart';

abstract interface class SyncConflictResolutionHandler {
  SyncEntityType get entityType;

  bool get isBusy;

  String? get resolvingConflictId;

  Future<SyncRunResult> retryHydration(String conflictId);

  Future<SyncRunResult> adoptRemote(String conflictId);

  Future<SyncRunResult> keepLocal(String conflictId);

  Future<SyncRunResult> retryRequestedResolution(String conflictId);
}

final class SyncConflictResolutionHandlerRegistry {
  SyncConflictResolutionHandlerRegistry(
    Iterable<SyncConflictResolutionHandler> handlers,
  ) : _handlers = {for (final handler in handlers) handler.entityType: handler};

  final Map<SyncEntityType, SyncConflictResolutionHandler> _handlers;

  SyncConflictResolutionHandler? handlerFor(SyncEntityType entityType) {
    return _handlers[entityType];
  }
}

final syncConflictResolutionHandlerRegistryProvider =
    Provider<SyncConflictResolutionHandlerRegistry>((ref) {
      final planState = ref.watch(planSyncControllerProvider);
      final todayState = ref.watch(todaySyncControllerProvider);
      final journalState = ref.watch(journalSyncControllerProvider);
      final healthState = ref.watch(healthSyncControllerProvider);
      return SyncConflictResolutionHandlerRegistry([
        _CallbackConflictResolutionHandler(
          entityType: SyncEntityType.plan,
          isBusy: planState.isBusy,
          resolvingConflictId: planState.resolvingConflictId,
          retryHydration: ref
              .read(planSyncControllerProvider.notifier)
              .retryConflictHydration,
          adoptRemote: ref
              .read(planSyncControllerProvider.notifier)
              .adoptRemote,
          keepLocal: ref.read(planSyncControllerProvider.notifier).keepLocal,
          retryRequestedResolution: ref
              .read(planSyncControllerProvider.notifier)
              .retryRequestedResolution,
        ),
        _CallbackConflictResolutionHandler(
          entityType: SyncEntityType.today,
          isBusy: todayState.isBusy,
          resolvingConflictId: todayState.resolvingConflictId,
          retryHydration: ref
              .read(todaySyncControllerProvider.notifier)
              .retryConflictHydration,
          adoptRemote: ref
              .read(todaySyncControllerProvider.notifier)
              .adoptRemote,
          keepLocal: ref.read(todaySyncControllerProvider.notifier).keepLocal,
          retryRequestedResolution: ref
              .read(todaySyncControllerProvider.notifier)
              .retryRequestedResolution,
        ),
        _CallbackConflictResolutionHandler(
          entityType: SyncEntityType.journal,
          isBusy: journalState.isBusy,
          resolvingConflictId: journalState.resolvingConflictId,
          retryHydration: ref
              .read(journalSyncControllerProvider.notifier)
              .retryConflictHydration,
          adoptRemote: ref
              .read(journalSyncControllerProvider.notifier)
              .adoptRemote,
          keepLocal: ref.read(journalSyncControllerProvider.notifier).keepLocal,
          retryRequestedResolution: ref
              .read(journalSyncControllerProvider.notifier)
              .retryRequestedResolution,
        ),
        _CallbackConflictResolutionHandler(
          entityType: SyncEntityType.health,
          isBusy: healthState.isBusy,
          resolvingConflictId: healthState.resolvingConflictId,
          retryHydration: ref
              .read(healthSyncControllerProvider.notifier)
              .retryConflictHydration,
          adoptRemote: ref
              .read(healthSyncControllerProvider.notifier)
              .adoptRemote,
          keepLocal: ref.read(healthSyncControllerProvider.notifier).keepLocal,
          retryRequestedResolution: ref
              .read(healthSyncControllerProvider.notifier)
              .retryRequestedResolution,
        ),
      ]);
    });

final class _CallbackConflictResolutionHandler
    implements SyncConflictResolutionHandler {
  const _CallbackConflictResolutionHandler({
    required this.entityType,
    required this.isBusy,
    required this.resolvingConflictId,
    required this._retryHydration,
    required this._adoptRemote,
    required this._keepLocal,
    required this._retryRequestedResolution,
  });

  @override
  final SyncEntityType entityType;

  @override
  final bool isBusy;

  @override
  final String? resolvingConflictId;

  final Future<SyncRunResult> Function(String) _retryHydration;
  final Future<SyncRunResult> Function(String) _adoptRemote;
  final Future<SyncRunResult> Function(String) _keepLocal;
  final Future<SyncRunResult> Function(String) _retryRequestedResolution;

  @override
  Future<SyncRunResult> retryHydration(String conflictId) {
    return _retryHydration(conflictId);
  }

  @override
  Future<SyncRunResult> adoptRemote(String conflictId) {
    return _adoptRemote(conflictId);
  }

  @override
  Future<SyncRunResult> keepLocal(String conflictId) {
    return _keepLocal(conflictId);
  }

  @override
  Future<SyncRunResult> retryRequestedResolution(String conflictId) {
    return _retryRequestedResolution(conflictId);
  }
}
