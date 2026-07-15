import 'sync_result.dart';
import 'sync_status.dart';

abstract interface class SyncRepository {
  Future<SyncStatus> getSyncStatus();

  Future<void> registerDevice();

  Future<SyncResult> pushPendingChanges();

  Future<SyncResult> pullChanges();
}
