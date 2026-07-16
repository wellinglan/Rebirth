import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/network/api_client.dart';

import 'app_config.dart';
import 'app_config_provider.dart';
import 'server_endpoint.dart';
import 'server_endpoint_store.dart';
import 'server_endpoint_store_impl.dart';
import 'server_endpoint_validator.dart';

final serverEndpointValidatorProvider = Provider<ServerEndpointValidator>(
  (ref) => const ServerEndpointValidator(),
);

final serverEndpointStoreProvider = Provider<ServerEndpointStore>(
  (ref) => LocalServerEndpointStore(
    validator: ref.watch(serverEndpointValidatorProvider),
  ),
);

final fallbackServerEndpointProvider = Provider<ServerEndpoint>((ref) {
  final config = ref.watch(appConfigProvider);
  final normalized = ref
      .watch(serverEndpointValidatorProvider)
      .normalize(config.apiBaseUrl);
  return ServerEndpoint(
    baseUrl: normalized,
    source: config.apiBaseUrl == AppConfig.defaultApiBaseUrl
        ? ServerEndpointSource.defaultValue
        : ServerEndpointSource.buildConfig,
  );
});

final serverEndpointControllerProvider =
    AsyncNotifierProvider<ServerEndpointController, ServerEndpoint>(
      ServerEndpointController.new,
    );

final effectiveServerEndpointProvider = Provider<ServerEndpoint>((ref) {
  return ref.watch(serverEndpointControllerProvider).value ??
      ref.watch(fallbackServerEndpointProvider);
});

final serverEndpointConnectionTesterProvider =
    Provider<ServerEndpointConnectionTester>(
      (ref) => const DioServerEndpointConnectionTester(),
    );

class ServerEndpointController extends AsyncNotifier<ServerEndpoint> {
  @override
  Future<ServerEndpoint> build() {
    return ref
        .watch(serverEndpointStoreProvider)
        .read(fallback: ref.watch(fallbackServerEndpointProvider));
  }

  Future<void> save(String baseUrl) async {
    final normalized = ref.read(serverEndpointValidatorProvider).normalize(baseUrl);
    await ref.read(serverEndpointStoreProvider).save(normalized);
    state = AsyncData(
      ServerEndpoint(
        baseUrl: normalized,
        source: ServerEndpointSource.saved,
      ),
    );
  }

  Future<void> restoreDefault() async {
    await ref.read(serverEndpointStoreProvider).clear();
    state = AsyncData(ref.read(fallbackServerEndpointProvider));
  }
}

abstract interface class ServerEndpointConnectionTester {
  Future<ServerEndpointHealth> test(String baseUrl);
}

final class DioServerEndpointConnectionTester
    implements ServerEndpointConnectionTester {
  const DioServerEndpointConnectionTester();

  @override
  Future<ServerEndpointHealth> test(String baseUrl) async {
    final json = await DioApiClient(baseUrl: baseUrl).getJson(
      '/health',
      timeout: const Duration(seconds: 3),
    );
    final health = ServerEndpointHealth(
      status: json['status'] as String,
      service: json['service'] as String,
      apiVersion: json['api_version'] as int,
      syncProtocolVersion: json['sync_protocol_version'] as int,
      environment: json['environment'] as String,
    );
    if (!health.isCompatible) {
      throw const FormatException('服务器 API 或同步协议版本不兼容。');
    }
    return health;
  }
}
