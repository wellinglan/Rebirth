enum SyncPhase { disabled, idle, syncing, failed }

final class SyncStatus {
  const SyncStatus({
    required this.phase,
    required this.deviceRegistered,
    required this.pendingChangeCount,
    this.lastSyncedAt,
    this.errorMessage,
  });

  const SyncStatus.disabled()
    : phase = SyncPhase.disabled,
      deviceRegistered = false,
      pendingChangeCount = 0,
      lastSyncedAt = null,
      errorMessage = null;

  final SyncPhase phase;
  final bool deviceRegistered;
  final int pendingChangeCount;
  final int? lastSyncedAt;
  final String? errorMessage;

  bool get isEnabled => phase != SyncPhase.disabled;
}
