import 'sync_record_baseline.dart';

abstract interface class SyncRecordBaselineRepository {
  Future<SyncRecordBaseline?> read({
    required String localUserId,
    required String entityType,
    required String recordId,
  });

  Future<void> write(SyncRecordBaseline baseline);

  Future<void> delete({
    required String localUserId,
    required String entityType,
    required String recordId,
  });
}
