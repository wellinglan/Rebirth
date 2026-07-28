import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/features/profile/data/profile_sync_repository_provider.dart';
import 'package:rebirth/features/sync/domain/profile_sync_result.dart';
import 'package:rebirth/shared/state/profile_revision_provider.dart';

import 'profile_sync_view_state.dart';

final profileSyncControllerProvider =
    NotifierProvider<ProfileSyncController, ProfileSyncViewState>(
      ProfileSyncController.new,
    );

class ProfileSyncController extends Notifier<ProfileSyncViewState> {
  @override
  ProfileSyncViewState build() => const ProfileSyncViewState();

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
