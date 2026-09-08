import '../domain/sync_module.dart';

enum ForegroundAutoSyncStatus {
  unavailable,
  loadingPreference,
  disabled,
  waitingForAccount,
  idle,
  pending,
  syncing,
  retryScheduled,
  needsAttention,
  failed,
}

enum ForegroundAutoSyncTrigger {
  enabled,
  sessionReady,
  resumed,
  localMutation,
  periodic,
  retry,
}

final class ForegroundAutoSyncTiming {
  const ForegroundAutoSyncTiming({
    this.mutationDebounce = const Duration(milliseconds: 1800),
    this.reconciliationInterval = const Duration(seconds: 60),
    this.resumeCooldown = const Duration(seconds: 20),
    this.retryDelays = const [
      Duration(seconds: 15),
      Duration(seconds: 60),
      Duration(minutes: 5),
    ],
  });

  final Duration mutationDebounce;
  final Duration reconciliationInterval;
  final Duration resumeCooldown;
  final List<Duration> retryDelays;
}

final class ForegroundAutoSyncState {
  const ForegroundAutoSyncState({
    this.status = ForegroundAutoSyncStatus.unavailable,
    this.enabled = false,
    this.isForeground = false,
    this.isSavingPreference = false,
    this.pendingModuleCount = 0,
    this.conflictCount = 0,
    this.currentModule,
    this.lastTrigger,
    this.lastAttemptAt,
    this.lastSuccessAt,
    this.retryAt,
    this.message,
  });

  final ForegroundAutoSyncStatus status;
  final bool enabled;
  final bool isForeground;
  final bool isSavingPreference;
  final int pendingModuleCount;
  final int conflictCount;
  final SyncModuleId? currentModule;
  final ForegroundAutoSyncTrigger? lastTrigger;
  final int? lastAttemptAt;
  final int? lastSuccessAt;
  final int? retryAt;
  final String? message;

  bool get isSyncing => status == ForegroundAutoSyncStatus.syncing;

  bool get hasAccountPreference =>
      status != ForegroundAutoSyncStatus.unavailable &&
      status != ForegroundAutoSyncStatus.loadingPreference;

  ForegroundAutoSyncState copyWith({
    ForegroundAutoSyncStatus? status,
    bool? enabled,
    bool? isForeground,
    bool? isSavingPreference,
    int? pendingModuleCount,
    int? conflictCount,
    SyncModuleId? currentModule,
    bool clearCurrentModule = false,
    ForegroundAutoSyncTrigger? lastTrigger,
    int? lastAttemptAt,
    int? lastSuccessAt,
    int? retryAt,
    bool clearRetryAt = false,
    String? message,
    bool clearMessage = false,
  }) {
    return ForegroundAutoSyncState(
      status: status ?? this.status,
      enabled: enabled ?? this.enabled,
      isForeground: isForeground ?? this.isForeground,
      isSavingPreference: isSavingPreference ?? this.isSavingPreference,
      pendingModuleCount: pendingModuleCount ?? this.pendingModuleCount,
      conflictCount: conflictCount ?? this.conflictCount,
      currentModule: clearCurrentModule
          ? null
          : currentModule ?? this.currentModule,
      lastTrigger: lastTrigger ?? this.lastTrigger,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
      retryAt: clearRetryAt ? null : retryAt ?? this.retryAt,
      message: clearMessage ? null : message ?? this.message,
    );
  }
}
