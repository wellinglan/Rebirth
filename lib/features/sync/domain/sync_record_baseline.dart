final class SyncRecordBaseline {
  SyncRecordBaseline({
    required this.localUserId,
    required this.entityType,
    required this.recordId,
    required this.baseExists,
    required this.baseServerVersion,
    required this.baseTombstone,
    required Map<String, String> groupHashes,
    required this.capturedAt,
  }) : groupHashes = Map.unmodifiable(groupHashes) {
    if (localUserId.trim().isEmpty ||
        entityType.trim().isEmpty ||
        recordId.trim().isEmpty ||
        baseServerVersion < 0 ||
        capturedAt < 0 ||
        (!baseExists && baseTombstone) ||
        groupHashes.entries.any(
          (entry) =>
              entry.key.trim().isEmpty || !_sha256Pattern.hasMatch(entry.value),
        )) {
      throw ArgumentError('Invalid sync record baseline.');
    }
  }

  static final _sha256Pattern = RegExp(r'^[0-9a-f]{64}$');

  final String localUserId;
  final String entityType;
  final String recordId;
  final bool baseExists;
  final int baseServerVersion;
  final bool baseTombstone;
  final Map<String, String> groupHashes;
  final int capturedAt;
}

abstract final class SyncRecordBaselineEntity {
  static const aiReportFeedback = 'ai_report_feedback';
}
