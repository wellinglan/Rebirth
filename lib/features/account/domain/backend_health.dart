final class BackendHealth {
  const BackendHealth({
    required this.status,
    required this.service,
    this.apiVersion = 1,
    this.syncProtocolVersion = 2,
    this.environment = 'development',
  });

  final String status;
  final String service;
  final int apiVersion;
  final int syncProtocolVersion;
  final String environment;

  bool get isHealthy => status == 'ok' && service == 'rebirth-api';

  bool get isCompatible =>
      isHealthy && apiVersion == 1 && syncProtocolVersion == 2;
}
