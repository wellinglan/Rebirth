enum ServerEndpointSource { saved, buildConfig, defaultValue }

final class ServerEndpoint {
  const ServerEndpoint({required this.baseUrl, required this.source});

  final String baseUrl;
  final ServerEndpointSource source;

  String get sourceLabel => switch (source) {
    ServerEndpointSource.saved => '用户设置',
    ServerEndpointSource.buildConfig => '构建配置',
    ServerEndpointSource.defaultValue => '应用默认值',
  };
}

final class ServerEndpointHealth {
  const ServerEndpointHealth({
    required this.status,
    required this.service,
    required this.apiVersion,
    required this.syncProtocolVersion,
    required this.environment,
  });

  final String status;
  final String service;
  final int apiVersion;
  final int syncProtocolVersion;
  final String environment;

  bool get isCompatible =>
      status == 'ok' &&
      service == 'rebirth-api' &&
      apiVersion == 1 &&
      syncProtocolVersion == 2;
}
