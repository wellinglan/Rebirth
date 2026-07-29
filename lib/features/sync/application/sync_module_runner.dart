import '../domain/sync_module.dart';
import '../domain/sync_models.dart';

abstract interface class SyncModuleRunner {
  SyncModuleDescriptor get descriptor;

  Future<SyncRunResult> runManualSync();

  Future<void> refreshStatus();
}

final class CallbackSyncModuleRunner implements SyncModuleRunner {
  const CallbackSyncModuleRunner({
    required this.descriptor,
    required this.onRun,
    required this.onRefresh,
  });

  @override
  final SyncModuleDescriptor descriptor;

  final Future<SyncRunResult> Function() onRun;
  final Future<void> Function() onRefresh;

  @override
  Future<SyncRunResult> runManualSync() => onRun();

  @override
  Future<void> refreshStatus() => onRefresh();
}
