import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/account/data/secure_auth_session_store.dart';
import 'package:rebirth/features/account/domain/auth_session.dart';
import 'package:rebirth/features/account/domain/auth_user.dart';
import 'package:rebirth/features/account/domain/device_registration.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late _FakeSecureValueStore secureValues;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    secureValues = _FakeSecureValueStore();
  });

  test('initial read is empty', () async {
    final store = SecureAuthSessionStore(secureStore: secureValues);

    expect(await store.read(), isNull);
  });

  test('only refresh envelope survives a new store instance', () async {
    final firstStore = SecureAuthSessionStore(secureStore: secureValues);
    await firstStore.save(_session);

    final restored = await SecureAuthSessionStore(
      secureStore: secureValues,
    ).read();
    final encoded = secureValues.values[SecureAuthSessionStore.secureSessionKey];

    expect(restored?.user.id, 'cloud-user-1');
    expect(restored?.accessToken, isEmpty);
    expect(restored?.refreshToken, 'test-refresh-token');
    expect(restored?.deviceRegistration?.deviceId, _deviceId);
    expect(encoded, isNot(contains('test-access-token')));
    expect(encoded, contains('test-refresh-token'));
  });

  test('clear removes secure and legacy sessions', () async {
    final store = SecureAuthSessionStore(secureStore: secureValues);
    await store.save(_session);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      SecureAuthSessionStore.legacySessionKey,
      'legacy',
    );

    await store.clear();

    expect(await store.read(), isNull);
    expect(
      preferences.getString(SecureAuthSessionStore.legacySessionKey),
      isNull,
    );
  });

  test('session is restored only for the issuing endpoint', () async {
    final store = SecureAuthSessionStore(secureStore: secureValues);
    await store.save(_session);

    final restored = await SecureAuthSessionStore(
      secureStore: secureValues,
      expectedServerBaseUrl: 'http://server-a:8000/',
    ).read();

    expect(restored?.user.id, _session.user.id);
    expect(restored?.serverBaseUrl, 'http://server-a:8000');
  });

  test('different endpoint clears the secure session', () async {
    final store = SecureAuthSessionStore(secureStore: secureValues);
    await store.save(_session);

    final restored = await SecureAuthSessionStore(
      secureStore: secureValues,
      expectedServerBaseUrl: 'http://server-b:8000',
    ).read();

    expect(restored, isNull);
    expect(secureValues.values, isEmpty);
  });

  test('legacy SharedPreferences session migrates once then is cleared', () async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      SecureAuthSessionStore.legacySessionKey,
      jsonEncode({
        'access_token': 'legacy-access',
        'refresh_token': 'legacy-refresh',
        'token_type': 'bearer',
        'server_base_url': 'http://server-a:8000',
        'user': {'id': 'cloud-user-1', 'display_name': 'Alpha User'},
        'device': null,
      }),
    );
    final store = SecureAuthSessionStore(
      secureStore: secureValues,
      expectedServerBaseUrl: 'http://server-a:8000',
    );

    final migrated = await store.read();

    expect(migrated?.accessToken, 'legacy-access');
    expect(migrated?.refreshToken, 'legacy-refresh');
    expect(
      preferences.getString(SecureAuthSessionStore.legacySessionKey),
      isNull,
    );
    expect(
      secureValues.values[SecureAuthSessionStore.secureSessionKey],
      contains('legacy-refresh'),
    );
  });

  test('secure write failure clears legacy plaintext and fails closed', () async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      SecureAuthSessionStore.legacySessionKey,
      jsonEncode({
        'access_token': 'legacy-access',
        'refresh_token': 'legacy-refresh',
        'token_type': 'bearer',
        'server_base_url': 'http://server-a:8000',
        'user': {'id': 'cloud-user-1', 'display_name': null},
      }),
    );
    secureValues.failWrites = true;
    final store = SecureAuthSessionStore(
      secureStore: secureValues,
      expectedServerBaseUrl: 'http://server-a:8000',
    );

    await expectLater(store.read(), throwsA(isA<AuthSessionStorageException>()));
    expect(
      preferences.getString(SecureAuthSessionStore.legacySessionKey),
      isNull,
    );
  });

  test('AuthSession toString does not expose tokens', () {
    expect(_session.toString(), isNot(contains('test-access-token')));
    expect(_session.toString(), isNot(contains('test-refresh-token')));
  });
}

const _deviceId = '12345678-1234-1234-1234-12345678cdef';
const _session = AuthSession(
  accessToken: 'test-access-token',
  refreshToken: 'test-refresh-token',
  user: AuthUser(id: 'cloud-user-1', displayName: 'Alpha User'),
  serverBaseUrl: 'http://server-a:8000',
  accessExpiresAt: 2000,
  refreshExpiresAt: 3000,
  sessionAbsoluteExpiresAt: 4000,
  sessionId: 'session-1',
  identityProvider: 'dev',
  lastVerifiedAt: 1000,
  deviceRegistration: DeviceRegistration(deviceId: _deviceId, serverTime: 1),
);

final class _FakeSecureValueStore implements SecureValueStore {
  final Map<String, String> values = {};
  bool failWrites = false;

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw StateError('write failed');
    values[key] = value;
  }
}
