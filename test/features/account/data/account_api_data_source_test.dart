import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/network/api_client.dart';
import 'package:rebirth/core/network/api_exception.dart';
import 'package:rebirth/features/account/data/account_api_data_source.dart';
import 'package:rebirth/features/account/domain/device_registration.dart';

void main() {
  test('getHealth requests /health and converts DTO', () async {
    final client = _FakeApiClient(
      getResponse: const {'status': 'ok', 'service': 'rebirth-api'},
    );
    final dataSource = AccountApiDataSource(client);

    final health = await dataSource.getHealth();

    expect(client.lastPath, '/health');
    expect(health.isHealthy, isTrue);
  });

  test('devLogin requests /auth/dev-login and converts session DTO', () async {
    final client = _FakeApiClient(
      postResponse: const {
        'access_token': 'test-access-token',
        'refresh_token': 'test-refresh-token',
        'token_type': 'bearer',
        'user': {'id': 'user-1', 'display_name': 'Dev local-test-user'},
      },
    );
    final dataSource = AccountApiDataSource(client);

    final session = await dataSource.devLogin('local-test-user');

    expect(client.lastPath, '/auth/dev-login');
    expect(client.lastBody?['dev_user_key'], 'local-test-user');
    expect(session.user.displayName, 'Dev local-test-user');
  });

  test('registerDevice requests protected endpoint and converts DTO', () async {
    final client = _FakeApiClient(
      postResponse: const {'device_id': 'device-1', 'server_time': 123},
    );
    final dataSource = AccountApiDataSource(client);

    final result = await dataSource.registerDevice(
      const DeviceRegistrationRequest(
        localInstallationId: 'installation-1',
        platform: 'windows',
        deviceName: 'Windows PC',
        appVersion: '1.0.0+1',
      ),
      accessToken: 'test-access-token',
    );

    expect(client.lastPath, '/devices/register');
    expect(client.lastAccessToken, 'test-access-token');
    expect(client.lastBody?['local_installation_id'], 'installation-1');
    expect(result.deviceId, 'device-1');
  });

  test('malformed DTO is converted to ApiException', () async {
    final dataSource = AccountApiDataSource(
      _FakeApiClient(getResponse: const {'status': 'ok'}),
    );

    expect(dataSource.getHealth(), throwsA(isA<ApiException>()));
  });

  test('backend ApiException passes through unchanged', () async {
    const expected = ApiException(message: '后端返回错误（500）。', statusCode: 500);
    final dataSource = AccountApiDataSource(_FakeApiClient(error: expected));

    expect(dataSource.getHealth(), throwsA(same(expected)));
  });
}

final class _FakeApiClient implements ApiClient {
  _FakeApiClient({this.getResponse, this.postResponse, this.error});

  final Map<String, Object?>? getResponse;
  final Map<String, Object?>? postResponse;
  final ApiException? error;
  String? lastPath;
  String? lastAccessToken;
  Map<String, Object?>? lastBody;

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    String? accessToken,
    Duration? timeout,
  }) async {
    lastPath = path;
    lastAccessToken = accessToken;
    if (error case final value?) throw value;
    return getResponse ?? const {};
  }

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    required Map<String, Object?> body,
    String? accessToken,
    Duration? timeout,
  }) async {
    lastPath = path;
    lastBody = body;
    lastAccessToken = accessToken;
    if (error case final value?) throw value;
    return postResponse ?? const {};
  }
}
