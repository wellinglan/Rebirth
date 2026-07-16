import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/account/data/auth_session_store.dart';
import 'package:rebirth/features/account/data/local_auth_session_store.dart';
import 'package:rebirth/features/account/domain/auth_session.dart';
import 'package:rebirth/features/account/domain/auth_user.dart';
import 'package:rebirth/features/account/domain/device_registration.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('initial read is empty', () async {
    final store = LocalAuthSessionStore();

    expect(await store.read(), isNull);
  });

  test('save can be read by a new store instance', () async {
    final firstStore = LocalAuthSessionStore();
    await firstStore.save(_session);

    final restored = await LocalAuthSessionStore().read();

    expect(restored?.user.id, 'cloud-user-1');
    expect(restored?.tokenType, 'bearer');
    expect(restored?.deviceRegistration?.deviceId, _deviceId);
  });

  test('clear removes the persisted session', () async {
    final store = LocalAuthSessionStore();
    await store.save(_session);

    await store.clear();

    expect(await store.read(), isNull);
  });

  test('session is restored only for the server that issued it', () async {
    final store = LocalAuthSessionStore();
    await store.save(
      _session.copyWith(serverBaseUrl: 'http://server-a:8000'),
    );

    final restored = await LocalAuthSessionStore(
      expectedServerBaseUrl: 'http://server-a:8000/',
    ).read();

    expect(restored?.user.id, _session.user.id);
    expect(restored?.serverBaseUrl, 'http://server-a:8000');
  });

  test('different endpoint rejects and clears old session and device', () async {
    final store = LocalAuthSessionStore();
    await store.save(
      _session.copyWith(serverBaseUrl: 'http://server-a:8000'),
    );

    final restored = await LocalAuthSessionStore(
      expectedServerBaseUrl: 'http://server-b:8000',
    ).read();

    expect(restored, isNull);
    expect(await store.read(), isNull);
  });

  test('AuthSession toString does not expose tokens', () {
    expect(_session.toString(), isNot(contains('test-access-token')));
    expect(_session.toString(), isNot(contains('test-refresh-token')));
  });

  test('fake store supports widget-test session replacement', () async {
    final store = _FakeAuthSessionStore();

    await store.save(_session);
    expect((await store.read())?.user.id, 'cloud-user-1');

    await store.clear();
    expect(await store.read(), isNull);
  });
}

const _deviceId = '12345678-1234-1234-1234-12345678cdef';
const _session = AuthSession(
  accessToken: 'test-access-token',
  refreshToken: 'test-refresh-token',
  user: AuthUser(id: 'cloud-user-1', displayName: 'Dev user'),
  deviceRegistration: DeviceRegistration(deviceId: _deviceId, serverTime: 1),
);

final class _FakeAuthSessionStore implements AuthSessionStore {
  AuthSession? session;

  @override
  Future<AuthSession?> read() async => session;

  @override
  Future<void> save(AuthSession session) async {
    this.session = session;
  }

  @override
  Future<void> clear() async {
    session = null;
  }
}
