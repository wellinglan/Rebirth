final class SyncItem {
  SyncItem({
    required this.tableName,
    required this.recordId,
    required Map<String, Object?> payload,
    required this.updatedAt,
    required this.deletedAt,
    required this.originDeviceId,
    required this.clientVersion,
  }) : payload = Map.unmodifiable(payload);

  final String tableName;
  final String recordId;
  final Map<String, Object?> payload;
  final int updatedAt;
  final int? deletedAt;
  final String originDeviceId;
  final int clientVersion;

  bool get isTombstone => deletedAt != null;
}
