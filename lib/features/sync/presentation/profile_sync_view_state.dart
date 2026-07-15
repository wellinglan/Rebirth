import 'package:rebirth/features/sync/domain/profile_sync_result.dart';

enum ProfileSyncAction { idle, pushing, pulling }

final class ProfileSyncViewState {
  const ProfileSyncViewState({
    this.action = ProfileSyncAction.idle,
    this.lastResult,
  });

  final ProfileSyncAction action;
  final ProfileSyncResult? lastResult;

  bool get isBusy => action != ProfileSyncAction.idle;
  bool get isPushing => action == ProfileSyncAction.pushing;
  bool get isPulling => action == ProfileSyncAction.pulling;

  ProfileSyncViewState copyWith({
    ProfileSyncAction? action,
    ProfileSyncResult? lastResult,
  }) {
    return ProfileSyncViewState(
      action: action ?? this.action,
      lastResult: lastResult ?? this.lastResult,
    );
  }
}
