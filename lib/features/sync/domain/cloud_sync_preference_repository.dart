abstract interface class CloudSyncPreferenceRepository {
  Future<bool> readEnabled(String localUserId);

  Future<bool> setEnabled({required String localUserId, required bool enabled});
}
