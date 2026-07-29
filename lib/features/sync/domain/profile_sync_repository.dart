import 'profile_sync_result.dart';
import 'sync_models.dart';

abstract interface class ProfileSyncRepository {
  Future<SyncRunResult> syncProfile();

  Future<ProfileSyncResult> pushProfile();

  Future<ProfileSyncResult> pullProfile();

  Future<ProfileSyncResult> resolveConflictUsingCloud();

  Future<ProfileSyncResult> resolveConflictKeepingLocal();

  Future<bool> hasConflict();
}
