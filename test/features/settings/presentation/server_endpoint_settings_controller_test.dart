import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/config/app_config.dart';
import 'package:rebirth/core/config/app_config_provider.dart';
import 'package:rebirth/core/config/server_endpoint.dart';
import 'package:rebirth/core/config/server_endpoint_provider.dart';
import 'package:rebirth/features/settings/presentation/server_endpoint_settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('failed health check cannot save or replace current endpoint', () async {
    final tester = _FakeConnectionTester(error: StateError('offline'));
    final container = _container(tester);
    addTearDown(container.dispose);
    await container.read(serverEndpointControllerProvider.future);
    final controller = container.read(
      serverEndpointSettingsControllerProvider.notifier,
    );

    expect(await controller.testConnection('http://server-b:8000'), isFalse);
    expect(controller.canSave('http://server-b:8000'), isFalse);
    expect(
      () => controller.save('http://server-b:8000'),
      throwsStateError,
    );
    expect(
      container.read(effectiveServerEndpointProvider).baseUrl,
      'http://server-a:8000',
    );
  });

  test('compatible health check enables normalized save', () async {
    final container = _container(_FakeConnectionTester());
    addTearDown(container.dispose);
    await container.read(serverEndpointControllerProvider.future);
    final controller = container.read(
      serverEndpointSettingsControllerProvider.notifier,
    );

    expect(
      await controller.testConnection(' http://server-b:8000/ '),
      isTrue,
    );
    await controller.save('http://server-b:8000/');

    expect(
      container.read(effectiveServerEndpointProvider).baseUrl,
      'http://server-b:8000',
    );
  });
}

ProviderContainer _container(ServerEndpointConnectionTester tester) {
  return ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(
        const AppConfig(
          apiBaseUrl: 'http://server-a:8000',
          enableDevLogin: true,
          appVersionLabel: 'test',
        ),
      ),
      serverEndpointConnectionTesterProvider.overrideWithValue(tester),
    ],
  );
}

final class _FakeConnectionTester implements ServerEndpointConnectionTester {
  const _FakeConnectionTester({this.error});

  final Object? error;

  @override
  Future<ServerEndpointHealth> test(String baseUrl) async {
    if (error case final value?) throw value;
    return const ServerEndpointHealth(
      status: 'ok',
      service: 'rebirth-api',
      apiVersion: 1,
      syncProtocolVersion: 2,
      environment: 'development',
    );
  }
}
