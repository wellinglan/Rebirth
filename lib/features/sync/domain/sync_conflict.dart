final class SyncConflict {
  const SyncConflict({
    required this.tableName,
    required this.recordId,
    required this.serverVersion,
    required this.reason,
    this.remoteRecordId,
  });

  final String tableName;
  final String recordId;
  final int serverVersion;
  final String reason;
  final String? remoteRecordId;
}
