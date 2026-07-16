import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/config/app_config.dart';
import 'package:rebirth/core/network/api_exception.dart';
import 'package:rebirth/features/account/data/account_api_data_source.dart';
import 'package:rebirth/features/account/data/account_repository_impl.dart';
import 'package:rebirth/features/account/data/auth_session_store.dart';
import 'package:rebirth/features/account/data/device_info_service.dart';
import 'package:rebirth/features/account/domain/account_exception.dart';
import 'package:rebirth/features/account/domain/account_status.dart';
import 'package:rebirth/features/account/domain/auth_session.dart';
import 'package:rebirth/features/account/domain/auth_user.dart';
import 'package:rebirth/features/account/domain/backend_health.dart';
import 'package:rebirth/features/account/domain/device_registration.dart';

void main() {
  late _FakeRemoteDataSource remote;
  late _FakeSessionStore store;
  late AccountRepositoryImpl repository;
  var installationLoads = 0;

  setUp(() {
    remote = _FakeRemoteDataSource();
    store = _FakeSessionStore();
    installationLoads = 0;
    repository = AccountRepositoryImpl(
      remoteDataSource: remote,
      sessionStore: store,
      loadLocalInstallationId: () async {
        installationLoads += 1;
        return 'installation-1';
      },
      deviceInfoService: const DeviceInfoService(
        platform: TargetPlatform.windows,
        isWeb: false,
      ),
      config: const AppConfig.development(),
      serverBaseUrl: AppConfig.defaultApiBaseUrl,
    );
  });

  test('getAccountStatus is signed out when no session exists', () async {
    final status = await repository.getAccountStatus();

    expect(status.mode, AccountMode.localOnly);
    expect(status.authentication, AuthenticationStatus.signedOut);
    expect(status.backendConfigured, isTrue);
    expect(status.backendReachable, isFalse);
  });

  test('getAccountStatus restores a persisted user and device', () async {
    store.session = _session.copyWith(
      deviceRegistration: const DeviceRegistration(
        deviceId: _deviceId,
        serverTime: 123,
      ),
    );

    final status = await repository.getAccountStatus();

    expect(status.mode, AccountMode.cloudReady);
    expect(status.authentication, AuthenticationStatus.signedIn);
    expect(status.user?.id, 'cloud-user-1');
    expect(status.deviceRegistration?.deviceId, _deviceId);
    expect(status.backendReachable, isFalse);
  });

  test('devLogin saves the returned session', () async {
    final session = await repository.devLogin(' local-test-user ');

    expect(remote.lastDevUserKey, 'local-test-user');
    expect(store.session, same(session));
    expect(session.serverBaseUrl, AppConfig.defaultApiBaseUrl);
  });

  test('logout clears only the account session', () async {
    store.session = _session;

    await repository.logout();

    expect(store.session, isNull);
    expect(store.clearCount, 1);
  });

  test('registerCurrentDevice requires a session', () {
    expect(
      repository.registerCurrentDevice(),
      throwsA(isA<AccountAuthenticationRequiredException>()),
    );
  });

  test('registerCurrentDevice uses the Bootstrap installation id', () async {
    store.session = _session;

    await repository.registerCurrentDevice();

    expect(installationLoads, 1);
    expect(remote.lastDeviceRequest?.localInstallationId, 'installation-1');
    expect(remote.lastDeviceRequest?.platform, 'windows');
    expect(remote.lastDeviceRequest?.appVersion, '1.0.0+1');
    expect(remote.lastAccessToken, 'test-access-token');
  });

  test('registerCurrentDevice saves the returned device id', () async {
    store.session = _session;

    final registration = await repository.registerCurrentDevice();

    expect(registration.deviceId, _deviceId);
    expect(store.session?.deviceRegistration?.deviceId, _deviceId);
  });

  test('repeated registration replaces the same persisted device', () async {
    store.session = _session;

    await repository.registerCurrentDevice();
    await repository.registerCurrentDevice();

    expect(remote.registrationCalls, 2);
    expect(store.session?.deviceRegistration?.deviceId, _deviceId);
  });

  test('network failure does not clear an existing session', () async {
    store.session = _session;
    remote.error = const ApiException(
      message: '无法连接开发后端',
      isNetworkError: true,
    );

    await expectLater(
      repository.registerCurrentDevice(),
      throwsA(isA<ApiException>()),
    );

    expect(store.session, same(_session));
    expect(store.clearCount, 0);
  });
}

const _deviceId = '12345678-1234-1234-1234-12345678cdef';
const _session = AuthSession(
  accessToken: 'test-access-token',
  refreshToken: 'test-refresh-token',
  user: AuthUser(id: 'cloud-user-1', displayName: 'Dev user'),
);

final class _FakeSessionStore implements AuthSessionStore {
  AuthSession? session;
  int clearCount = 0;

  @override
  Future<void> clear() async {
    clearCount += 1;
    session = null;
  }

  @override
  Future<AuthSession?> read() async => session;

  @override
  Future<void> save(AuthSession session) async {
    this.session = session;
  }
}

final class _FakeRemoteDataSource implements AccountRemoteDataSource {
  String? lastDevUserKey;
  DeviceRegistrationRequest? lastDeviceRequest;
  String? lastAccessToken;
  int registrationCalls = 0;
  ApiException? error;

  @override
  Future<BackendHealth> getHealth() async {
    if (error case final value?) throw value;
    return const BackendHealth(status: 'ok', service: 'rebirth-api');
  }

  @override
  Future<AuthSession> devLogin(String devUserKey) async {
    if (error case final value?) throw value;
    lastDevUserKey = devUserKey;
    return _session;
  }

  @override
  Future<DeviceRegistration> registerDevice(
    DeviceRegistrationRequest request, {
    required String accessToken,
  }) async {
    if (error case final value?) throw value;
    registrationCalls += 1;
    lastDeviceRequest = request;
    lastAccessToken = accessToken;
    return const DeviceRegistration(deviceId: _deviceId, serverTime: 123);
  }
}
