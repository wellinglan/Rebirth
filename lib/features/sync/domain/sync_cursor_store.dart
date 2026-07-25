abstract interface class SyncCursorStore {
  Future<int> read({
    required String endpoint,
    required String cloudUserId,
    required String scope,
  });

  Future<void> write({
    required String endpoint,
    required String cloudUserId,
    required String scope,
    required int serverVersion,
  });

  Future<void> clear({
    required String endpoint,
    required String cloudUserId,
    String? scope,
  });
}

final class InvalidSyncCursorException implements Exception {
  const InvalidSyncCursorException();

  @override
  String toString() => 'The local sync cursor is invalid.';
}
