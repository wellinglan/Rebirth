import 'sync_conflict.dart';

final class SyncedRecord {
  const SyncedRecord({
    required this.tableName,
    required this.recordId,
    required this.serverVersion,
  });

  final String tableName;
  final String recordId;
  final int serverVersion;
}

final class SyncResult {
  SyncResult({
    required List<SyncedRecord> accepted,
    required List<SyncConflict> conflicts,
    required this.serverVersion,
  }) : accepted = List.unmodifiable(accepted),
       conflicts = List.unmodifiable(conflicts);

  final List<SyncedRecord> accepted;
  final List<SyncConflict> conflicts;
  final int serverVersion;

  bool get hasConflicts => conflicts.isNotEmpty;
}
