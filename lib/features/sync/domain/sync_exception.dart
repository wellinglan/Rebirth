class SyncException implements Exception {
  const SyncException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class SyncAuthenticationRequiredException extends SyncException {
  const SyncAuthenticationRequiredException() : super('请先开发登录');
}

final class SyncDeviceRegistrationRequiredException extends SyncException {
  const SyncDeviceRegistrationRequiredException() : super('请先注册当前设备');
}

final class SyncUnsupportedTableException extends SyncException {
  const SyncUnsupportedTableException(String tableName)
    : super('当前 Sprint 不支持同步表：$tableName');
}
