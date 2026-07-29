import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/features/profile/data/profile_sync_repository_provider.dart';
import 'package:rebirth/features/sync/domain/profile_sync_result.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_record.dart';
import 'package:rebirth/features/sync/domain/sync_exception.dart';
import 'package:rebirth/features/sync/data/sync_conflict_providers.dart';
import 'package:rebirth/features/sync/data/sync_providers.dart';
import 'package:rebirth/shared/state/profile_revision_provider.dart';

import 'profile_sync_view_state.dart';

final profileSyncControllerProvider =
    NotifierProvider<ProfileSyncController, ProfileSyncViewState>(
      ProfileSyncController.new,
    );

class ProfileSyncController extends Notifier<ProfileSyncViewState> {
  @override
  ProfileSyncViewState build() => const ProfileSyncViewState();

  Future<SyncRunResult> syncProfile() async {
    if (state.isBusy) {
      throw StateError('A Profile sync operation is already running.');
    }
    state = state.copyWith(action: ProfileSyncAction.syncing);
    try {
      final result = await ref
          .read(profileSyncRepositoryProvider)
          .syncProfile();
      state = ProfileSyncViewState(lastRunResult: result);
      final profile = result.resultFor(SyncEntityType.profile);
      if (profile?.pulledCount case final count? when count > 0) {
        ref.read(profileRevisionProvider.notifier).bump();
      }
      ref.invalidate(profileSyncConflictProvider);
      return result;
    } catch (_) {
      state = state.copyWith(action: ProfileSyncAction.idle);
      ref.invalidate(profileSyncConflictProvider);
      rethrow;
    }
  }

  Future<SyncRunResult> retryConflictHydration(String conflictId) {
    return _runConflict(
      conflictId: conflictId,
      action: ProfileSyncAction.hydratingConflict,
      prepare: null,
      direction: SyncRunDirection.pull,
      pullMode: SyncPullMode.incremental,
    );
  }

  Future<SyncRunResult> adoptRemote(String conflictId) {
    return _runConflict(
      conflictId: conflictId,
      action: ProfileSyncAction.adoptingRemote,
      prepare: (scope) => ref
          .read(profileConflictResolutionServiceProvider)
          .requestAdoptRemote(scope: scope, conflictId: conflictId),
      direction: SyncRunDirection.pull,
      pullMode: SyncPullMode.preferRemoteConflictResolution,
    );
  }

  Future<SyncRunResult> keepLocal(String conflictId) {
    return _runConflict(
      conflictId: conflictId,
      action: ProfileSyncAction.keepingLocal,
      prepare: (scope) => ref
          .read(profileConflictResolutionServiceProvider)
          .requestKeepLocal(scope: scope, conflictId: conflictId),
      direction: SyncRunDirection.push,
    );
  }

  Future<SyncRunResult> retryRequestedResolution(String conflictId) async {
    final scope = await _requireScope();
    final conflict = await ref
        .read(syncConflictRepositoryProvider)
        .getConflict(scope, conflictId);
    return switch (conflict.resolutionStatus) {
      SyncConflictResolutionStatus.adoptRemoteRequested => adoptRemote(
        conflictId,
      ),
      SyncConflictResolutionStatus.keepLocalRequested => keepLocal(conflictId),
      _ => throw const SyncException('该冲突当前没有可重试的解决操作。'),
    };
  }

  Future<SyncRunResult> _runConflict({
    required String conflictId,
    required ProfileSyncAction action,
    required Future<void> Function(SyncConflictScope scope)? prepare,
    required SyncRunDirection direction,
    SyncPullMode pullMode = SyncPullMode.incremental,
  }) async {
    if (state.isBusy) {
      throw const SyncException('已有其他 Profile 同步操作正在进行。');
    }
    state = state.copyWith(action: action, resolvingConflictId: conflictId);
    try {
      final scope = await _requireScope();
      if (prepare != null) await prepare(scope);
      final result = await ref
          .read(syncCoordinatorProvider)
          .run(
            direction: direction,
            entityTypes: const [SyncEntityType.profile],
            pullMode: pullMode,
          );
      ref.invalidate(syncConflictDetailsProvider(conflictId));
      ref.invalidate(activeSyncConflictListProvider);
      ref.invalidate(activeSyncConflictCountProvider);
      ref.invalidate(profileSyncConflictProvider);
      if ((result.resultFor(SyncEntityType.profile)?.pulledCount ?? 0) > 0) {
        ref.read(profileRevisionProvider.notifier).bump();
      }
      state = ProfileSyncViewState(lastRunResult: result);
      return result;
    } catch (_) {
      state = state.copyWith(
        action: ProfileSyncAction.idle,
        clearResolvingConflictId: true,
      );
      rethrow;
    }
  }

  Future<SyncConflictScope> _requireScope() async {
    final scope = await ref.read(syncConflictScopeProvider.future);
    if (scope == null) {
      throw const SyncException('请先登录当前服务器的云账号。');
    }
    return scope;
  }

  Future<ProfileSyncResult> pushProfile() {
    return _run(
      ProfileSyncAction.pushing,
      () => ref.read(profileSyncRepositoryProvider).pushProfile(),
    );
  }

  Future<ProfileSyncResult> pullProfile() {
    return _run(
      ProfileSyncAction.pulling,
      () => ref.read(profileSyncRepositoryProvider).pullProfile(),
    );
  }

  Future<ProfileSyncResult> resolveConflictUsingCloud() {
    return _run(
      ProfileSyncAction.resolvingWithCloud,
      () => ref.read(profileSyncRepositoryProvider).resolveConflictUsingCloud(),
    );
  }

  Future<ProfileSyncResult> resolveConflictKeepingLocal() {
    return _run(
      ProfileSyncAction.resolvingWithLocal,
      () =>
          ref.read(profileSyncRepositoryProvider).resolveConflictKeepingLocal(),
    );
  }

  Future<ProfileSyncResult> _run(
    ProfileSyncAction action,
    Future<ProfileSyncResult> Function() operation,
  ) async {
    if (state.isBusy) {
      throw StateError('A Profile sync operation is already running.');
    }
    state = state.copyWith(action: action);
    try {
      final result = await operation();
      state = ProfileSyncViewState(lastResult: result);
      if (result.pulled) {
        ref.read(profileRevisionProvider.notifier).bump();
      }
      ref.invalidate(profileSyncConflictProvider);
      return result;
    } catch (_) {
      state = state.copyWith(action: ProfileSyncAction.idle);
      ref.invalidate(profileSyncConflictProvider);
      rethrow;
    }
  }
}
