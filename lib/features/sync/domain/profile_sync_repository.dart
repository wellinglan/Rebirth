import 'profile_sync_result.dart';

abstract interface class ProfileSyncRepository {
  Future<ProfileSyncResult> pushProfile();

  Future<ProfileSyncResult> pullProfile();
}
