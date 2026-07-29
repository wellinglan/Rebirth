import 'package:rebirth/features/sync/domain/profile_sync_result.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';

enum ProfileSyncAction {
  idle,
  syncing,
  hydratingConflict,
  adoptingRemote,
  keepingLocal,
  pushing,
  pulling,
  resolvingWithCloud,
  resolvingWithLocal,
}

final class ProfileSyncViewState {
  const ProfileSyncViewState({
    this.action = ProfileSyncAction.idle,
    this.lastResult,
    this.lastRunResult,
    this.resolvingConflictId,
  });

  final ProfileSyncAction action;
  final ProfileSyncResult? lastResult;
  final SyncRunResult? lastRunResult;
  final String? resolvingConflictId;

  bool get isBusy => action != ProfileSyncAction.idle;
  bool get isSyncing => action == ProfileSyncAction.syncing;
  bool get isPushing => action == ProfileSyncAction.pushing;
  bool get isPulling => action == ProfileSyncAction.pulling;
  bool get isResolvingWithCloud =>
      action == ProfileSyncAction.resolvingWithCloud;
  bool get isResolvingWithLocal =>
      action == ProfileSyncAction.resolvingWithLocal;

  ProfileSyncViewState copyWith({
    ProfileSyncAction? action,
    ProfileSyncResult? lastResult,
    SyncRunResult? lastRunResult,
    String? resolvingConflictId,
    bool clearResolvingConflictId = false,
  }) {
    return ProfileSyncViewState(
      action: action ?? this.action,
      lastResult: lastResult ?? this.lastResult,
      lastRunResult: lastRunResult ?? this.lastRunResult,
      resolvingConflictId: clearResolvingConflictId
          ? null
          : resolvingConflictId ?? this.resolvingConflictId,
    );
  }
}
