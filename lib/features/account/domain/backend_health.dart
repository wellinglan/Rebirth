final class BackendHealth {
  const BackendHealth({required this.status, required this.service});

  final String status;
  final String service;

  bool get isHealthy => status == 'ok' && service == 'rebirth-api';
}
