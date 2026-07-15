import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/network/api_client.dart';
import 'package:rebirth/core/network/api_exception.dart';
import 'package:rebirth/features/sync/data/dto/sync_dto.dart';
import 'package:rebirth/features/sync/data/sync_api_data_source.dart';
import 'package:rebirth/features/sync/domain/sync_exception.dart';
import 'package:rebirth/features/sync/domain/sync_item.dart';

void main() {
  test('push hits /sync/push with the Profile item payload', () async {
    final client = _FakeApiClient(
      response: const {
        'accepted': [
          {'table': 'user_profiles', 'id': 'profile-1', 'server_version': 4},
        ],
        'conflicts': <Object?>[],
      },
    );
    final dataSource = SyncApiDataSource(client);

    final response = await dataSource.push(
      SyncPushRequestDto(deviceId: 'device-1', items: [_profileItem]),
      accessToken: 'test-access-token',
    );

    expect(client.lastPath, '/sync/push');
    expect(client.lastBody?['device_id'], 'device-1');
    expect(
      ((client.lastBody?['items'] as List).single as Map)['table'],
      'user_profiles',
    );
    expect(response.accepted.single.serverVersion, 4);
  });

  test('pull hits /sync/pull and converts returned DTO', () async {
    final client = _FakeApiClient(
      response: const {
        'server_version': 8,
        'items': [
          {
            'table': 'user_profiles',
            'id': 'remote-profile',
            'payload': {
              'display_name': 'Cloud user',
              'growth_focus': 'Research',
              'timezone_id': 'Asia/Shanghai',
              'updated_at': 90,
            },
            'updated_at': 90,
            'deleted_at': null,
            'origin_device_id': 'installation-2',
            'server_version': 8,
          },
        ],
      },
    );
    final dataSource = SyncApiDataSource(client);

    final response = await dataSource.pull(
      SyncPullRequestDto(
        deviceId: 'device-1',
        sinceServerVersion: 3,
        tables: const ['user_profiles'],
      ),
      accessToken: 'test-access-token',
    );

    expect(client.lastPath, '/sync/pull');
    expect(client.lastBody?['since_server_version'], 3);
    expect(client.lastBody?['tables'], ['user_profiles']);
    expect(response.serverVersion, 8);
    expect(response.items.single.payload['display_name'], 'Cloud user');
  });

  test('Bearer token is passed without entering the request body', () async {
    final client = _FakeApiClient(
      response: const {'accepted': <Object?>[], 'conflicts': <Object?>[]},
    );

    await SyncApiDataSource(client).push(
      SyncPushRequestDto(deviceId: 'device-1', items: [_profileItem]),
      accessToken: 'test-access-token',
    );

    expect(client.lastAccessToken, 'test-access-token');
    expect(client.lastBody.toString(), isNot(contains('test-access-token')));
  });

  test('backend errors remain sanitized and do not expose the token', () async {
    const error = ApiException(message: '后端返回错误（500）。', statusCode: 500);
    final dataSource = SyncApiDataSource(_FakeApiClient(error: error));

    final thrown = await _capture(
      dataSource.push(
        SyncPushRequestDto(deviceId: 'device-1', items: [_profileItem]),
        accessToken: 'test-access-token',
      ),
    );

    expect(thrown, same(error));
    expect(thrown.toString(), isNot(contains('test-access-token')));
  });

  test('empty access token is rejected before a request', () {
    final dataSource = SyncApiDataSource(_FakeApiClient());

    expect(
      dataSource.push(
        SyncPushRequestDto(deviceId: 'device-1', items: [_profileItem]),
        accessToken: '',
      ),
      throwsA(isA<SyncAuthenticationRequiredException>()),
    );
  });

  test('empty device id is rejected before a request', () {
    final dataSource = SyncApiDataSource(_FakeApiClient());

    expect(
      dataSource.pull(
        SyncPullRequestDto(
          deviceId: '',
          sinceServerVersion: 0,
          tables: const ['user_profiles'],
        ),
        accessToken: 'test-access-token',
      ),
      throwsA(isA<SyncDeviceRegistrationRequiredException>()),
    );
  });

  test('Sprint 6D rejects every table except user_profiles', () {
    final dataSource = SyncApiDataSource(_FakeApiClient());
    final todayItem = SyncItem(
      tableName: 'today_records',
      recordId: 'today-1',
      payload: const {},
      updatedAt: 1,
      deletedAt: null,
      originDeviceId: 'installation-1',
      clientVersion: 0,
    );

    expect(
      dataSource.push(
        SyncPushRequestDto(deviceId: 'device-1', items: [todayItem]),
        accessToken: 'test-access-token',
      ),
      throwsA(isA<SyncUnsupportedTableException>()),
    );
  });

  test('push conflict DTO is converted with its server version', () async {
    final dataSource = SyncApiDataSource(
      _FakeApiClient(
        response: const {
          'accepted': <Object?>[],
          'conflicts': [
            {
              'table': 'user_profiles',
              'id': 'profile-1',
              'server_version': 7,
              'reason': 'stale_client',
            },
          ],
        },
      ),
    );

    final response = await dataSource.push(
      SyncPushRequestDto(deviceId: 'device-1', items: [_profileItem]),
      accessToken: 'test-access-token',
    );

    expect(response.conflicts.single.serverVersion, 7);
    expect(response.conflicts.single.reason, 'stale_client');
  });
}

final _profileItem = SyncItem(
  tableName: 'user_profiles',
  recordId: 'profile-1',
  payload: const {
    'display_name': 'Local user',
    'growth_focus': 'Research',
    'timezone_id': 'Asia/Shanghai',
    'updated_at': 20,
  },
  updatedAt: 20,
  deletedAt: null,
  originDeviceId: 'installation-1',
  clientVersion: 3,
);

Future<ApiException> _capture(Future<Object?> future) async {
  try {
    await future;
  } on ApiException catch (error) {
    return error;
  }
  throw TestFailure('Expected ApiException.');
}

final class _FakeApiClient implements ApiClient {
  _FakeApiClient({this.response = const {}, this.error});

  final Map<String, Object?> response;
  final ApiException? error;
  String? lastPath;
  String? lastAccessToken;
  Map<String, Object?>? lastBody;

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    String? accessToken,
    Duration? timeout,
  }) {
    throw UnimplementedError();
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
    return response;
  }
}
