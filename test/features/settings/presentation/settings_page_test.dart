import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/config/server_endpoint.dart';
import 'package:rebirth/core/config/server_endpoint_provider.dart';
import 'package:rebirth/core/network/api_exception.dart';
import 'package:rebirth/features/ai_coach/data/ai_coach_repository_providers.dart';
import 'package:rebirth/features/ai_coach/domain/ai_consent_repository.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_authorization.dart';
import 'package:rebirth/features/account/data/account_repository_provider.dart';
import 'package:rebirth/features/account/domain/account_exception.dart';
import 'package:rebirth/features/account/domain/account_status.dart';
import 'package:rebirth/features/account/domain/auth_repository.dart';
import 'package:rebirth/features/account/domain/auth_session.dart';
import 'package:rebirth/features/account/domain/auth_user.dart';
import 'package:rebirth/features/account/domain/backend_health.dart';
import 'package:rebirth/features/account/domain/device_registration.dart';
import 'package:rebirth/features/profile/data/profile_repository_provider.dart';
import 'package:rebirth/features/profile/data/profile_sync_repository_provider.dart';
import 'package:rebirth/features/profile/domain/device_profile_status.dart';
import 'package:rebirth/features/profile/domain/profile_repository.dart';
import 'package:rebirth/features/profile/domain/profile_save_data.dart';
import 'package:rebirth/features/profile/domain/user_profile.dart';
import 'package:rebirth/features/settings/presentation/settings_page.dart';
import 'package:rebirth/features/settings/presentation/widgets/device_status_card.dart';
import 'package:rebirth/features/sync/domain/profile_sync_direction.dart';
import 'package:rebirth/features/sync/domain/profile_sync_repository.dart';
import 'package:rebirth/features/sync/domain/profile_sync_result.dart';
import 'package:rebirth/features/sync/domain/sync_exception.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('SettingsPage shows loading state', (tester) async {
    final gate = Completer<UserProfile>();
    await _pumpSettings(
      tester,
      _FakeProfileRepository(profileGate: gate),
      _FakeAuthRepository(),
    );

    expect(find.byKey(const ValueKey('settingsLoadingState')), findsOneWidget);
  });

  testWidgets('SettingsPage shows error and retries', (tester) async {
    final profileRepository = _FakeProfileRepository(
      loadError: StateError('failed'),
    );
    await _pumpSettings(
      tester,
      profileRepository,
      _FakeAuthRepository(),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('settingsErrorState')), findsOneWidget);
    expect(find.text('设置暂时无法加载'), findsOneWidget);

    profileRepository.loadError = null;
    await tester.tap(find.byKey(const ValueKey('retrySettingsButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('settingsDataState')), findsOneWidget);
    expect(profileRepository.profileLoads, greaterThanOrEqualTo(2));
  });

  testWidgets('initial account state is local and does not call the network', (
    tester,
  ) async {
    final authRepository = _FakeAuthRepository();
    await _pumpSettings(
      tester,
      _FakeProfileRepository(),
      authRepository,
    );
    await tester.pumpAndSettle();

    expect(find.text('当前模式'), findsOneWidget);
    expect(find.text('本地模式'), findsNWidgets(2));
    expect(find.text('登录状态'), findsOneWidget);
    expect(find.text('未登录'), findsOneWidget);
    expect(find.text('后端状态'), findsOneWidget);
    expect(find.text('未连接'), findsOneWidget);
    expect(find.text('云账号'), findsOneWidget);
    expect(find.text('尚未连接'), findsOneWidget);
    expect(find.text('同步范围'), findsOneWidget);
    expect(find.text('仅 Profile 手动同步'), findsOneWidget);
    expect(find.text('设备注册'), findsOneWidget);
    expect(find.text('未注册'), findsOneWidget);
    expect(find.text('Profile 同步'), findsOneWidget);
    expect(find.text('需要先登录'), findsOneWidget);
    expect(authRepository.healthCalls, 0);
    expect(authRepository.loginCalls, 0);
    expect(authRepository.registrationCalls, 0);
  });

  testWidgets('checking backend health shows the connected state', (
    tester,
  ) async {
    final authRepository = _FakeAuthRepository();
    await _pumpSettings(
      tester,
      _FakeProfileRepository(),
      authRepository,
    );
    await tester.pumpAndSettle();

    await _tapByKey(tester, 'checkBackendButton');

    expect(authRepository.healthCalls, 1);
    expect(find.text('开发服务已连接'), findsOneWidget);
    expect(find.text('开发后端已连接'), findsOneWidget);
  });

  testWidgets('backend health failure keeps local state available', (
    tester,
  ) async {
    final authRepository = _FakeAuthRepository()
      ..healthError = const ApiException(
        message: '无法连接开发后端，请确认服务已启动且网络可达。',
        isNetworkError: true,
      );
    await _pumpSettings(
      tester,
      _FakeProfileRepository(),
      authRepository,
    );
    await tester.pumpAndSettle();

    await _tapByKey(tester, 'checkBackendButton');

    expect(find.text('未连接'), findsOneWidget);
    expect(find.text('无法连接开发后端'), findsOneWidget);
    expect(find.text('Local user'), findsOneWidget);
    expect(find.byKey(const ValueKey('accountActionError')), findsOneWidget);
  });

  testWidgets('development login opens a dev_user_key dialog', (tester) async {
    await _pumpSettings(
      tester,
      _FakeProfileRepository(),
      _FakeAuthRepository(),
    );
    await tester.pumpAndSettle();

    await _tapByKey(tester, 'devLoginButton');

    expect(find.byKey(const ValueKey('devLoginDialog')), findsOneWidget);
    expect(find.byKey(const ValueKey('devUserKeyField')), findsOneWidget);
    expect(find.text('local-test-user'), findsOneWidget);
  });

  testWidgets('successful development login updates account status', (
    tester,
  ) async {
    final authRepository = _FakeAuthRepository();
    await _pumpSettings(
      tester,
      _FakeProfileRepository(),
      authRepository,
    );
    await tester.pumpAndSettle();

    await _login(tester, 'research-user');

    expect(authRepository.lastDevUserKey, 'research-user');
    expect(find.text('开发云账号'), findsNWidgets(2));
    expect(find.text('已登录，开发账号'), findsOneWidget);
    expect(find.text('开发账号已连接'), findsOneWidget);
    expect(find.text('Dev research-user'), findsOneWidget);
    expect(find.text('开发登录成功'), findsOneWidget);
    expect(find.text('仅 Profile 手动同步'), findsOneWidget);
  });

  testWidgets('registering a device while signed out asks for login', (
    tester,
  ) async {
    await _pumpSettings(
      tester,
      _FakeProfileRepository(),
      _FakeAuthRepository(),
    );
    await tester.pumpAndSettle();

    await _tapByKey(tester, 'registerDeviceButton');

    expect(find.text('请先开发登录'), findsWidgets);
    expect(find.text('已注册'), findsNothing);
  });

  testWidgets('signed-in user can register the current device', (tester) async {
    final authRepository = _FakeAuthRepository();
    await _pumpSettings(
      tester,
      _FakeProfileRepository(),
      authRepository,
    );
    await tester.pumpAndSettle();
    await _login(tester, 'local-test-user');

    await _tapByKey(tester, 'registerDeviceButton');

    expect(authRepository.registrationCalls, 1);
    expect(find.text('已注册'), findsOneWidget);
    expect(find.text('12345678...cdef'), findsNWidgets(2));
    expect(find.text('当前设备已注册'), findsOneWidget);
    expect(find.text(_deviceId), findsNothing);
  });

  testWidgets('signed-out Profile upload asks for development login', (
    tester,
  ) async {
    final syncRepository = _FakeProfileSyncRepository(
      pushError: const SyncAuthenticationRequiredException(),
    );
    await _pumpSettings(
      tester,
      _FakeProfileRepository(),
      _FakeAuthRepository(),
      syncRepository: syncRepository,
    );
    await tester.pumpAndSettle();

    await _tapByKey(tester, 'pushProfileButton');

    expect(syncRepository.pushCalls, 1);
    expect(find.text('请先开发登录'), findsOneWidget);
  });

  testWidgets('signed-in unregistered Profile sync asks for registration', (
    tester,
  ) async {
    final authRepository = _signedInAuthRepository();
    final syncRepository = _FakeProfileSyncRepository(
      pullError: const SyncDeviceRegistrationRequiredException(),
    );
    await _pumpSettings(
      tester,
      _FakeProfileRepository(),
      authRepository,
      syncRepository: syncRepository,
    );
    await tester.pumpAndSettle();

    expect(find.text('需要先注册设备'), findsOneWidget);
    await _tapByKey(tester, 'pullProfileButton');

    expect(find.text('请先注册当前设备'), findsOneWidget);
  });

  testWidgets('registered account exposes manual Profile sync actions', (
    tester,
  ) async {
    await _pumpSettings(
      tester,
      _FakeProfileRepository(),
      _registeredAuthRepository(),
    );
    await tester.pumpAndSettle();

    expect(find.text('可手动同步'), findsOneWidget);
    expect(find.byKey(const ValueKey('pushProfileButton')), findsOneWidget);
    expect(find.byKey(const ValueKey('pullProfileButton')), findsOneWidget);
  });

  testWidgets('successful Profile upload shows an honest result', (
    tester,
  ) async {
    final syncRepository = _FakeProfileSyncRepository();
    await _pumpSettings(
      tester,
      _FakeProfileRepository(),
      _registeredAuthRepository(),
      syncRepository: syncRepository,
    );
    await tester.pumpAndSettle();

    await _tapByKey(tester, 'pushProfileButton');

    expect(syncRepository.pushCalls, 1);
    expect(find.text('Profile 已上传'), findsOneWidget);
    expect(find.text('最近已上传'), findsOneWidget);
  });

  testWidgets('successful Profile pull shows the update result', (
    tester,
  ) async {
    final syncRepository = _FakeProfileSyncRepository();
    await _pumpSettings(
      tester,
      _FakeProfileRepository(),
      _registeredAuthRepository(),
      syncRepository: syncRepository,
    );
    await tester.pumpAndSettle();

    await _tapByKey(tester, 'pullProfileButton');

    expect(syncRepository.pullCalls, 1);
    expect(find.text('Profile 已更新'), findsOneWidget);
    expect(find.text('最近已更新'), findsOneWidget);
  });

  testWidgets('Profile pull reports when there is no newer item', (
    tester,
  ) async {
    final syncRepository = _FakeProfileSyncRepository(
      pullResult: const ProfileSyncResult(
        success: true,
        direction: ProfileSyncDirection.pull,
        message: '没有新的 Profile 更新',
        pushed: false,
        pulled: false,
        conflict: false,
        serverVersion: 2,
      ),
    );
    await _pumpSettings(
      tester,
      _FakeProfileRepository(),
      _registeredAuthRepository(),
      syncRepository: syncRepository,
    );
    await tester.pumpAndSettle();

    await _tapByKey(tester, 'pullProfileButton');

    expect(find.text('没有新的 Profile 更新'), findsOneWidget);
  });

  testWidgets('Profile conflict is shown without claiming an update', (
    tester,
  ) async {
    final syncRepository = _FakeProfileSyncRepository(
      pullResult: const ProfileSyncResult(
        success: false,
        direction: ProfileSyncDirection.pull,
        message: '检测到本地与云端都有修改，暂未自动覆盖',
        pushed: false,
        pulled: false,
        conflict: true,
        serverVersion: 3,
      ),
    );
    await _pumpSettings(
      tester,
      _FakeProfileRepository(),
      _registeredAuthRepository(),
      syncRepository: syncRepository,
    );
    await tester.pumpAndSettle();

    await _tapByKey(tester, 'pullProfileButton');

    expect(find.text('检测到本地与云端都有修改，暂未自动覆盖'), findsOneWidget);
    expect(find.text('检测到冲突'), findsOneWidget);
    expect(find.text('Profile 已更新'), findsNothing);
  });

  testWidgets('Profile network failure keeps local Profile available', (
    tester,
  ) async {
    final syncRepository = _FakeProfileSyncRepository(
      pushError: const ApiException(
        message: '无法连接开发后端',
        isNetworkError: true,
      ),
    );
    await _pumpSettings(
      tester,
      _FakeProfileRepository(),
      _registeredAuthRepository(),
      syncRepository: syncRepository,
    );
    await tester.pumpAndSettle();

    await _tapByKey(tester, 'pushProfileButton');

    expect(find.text('无法连接开发后端，本地资料未受影响'), findsOneWidget);
    expect(find.text('Local user'), findsOneWidget);
  });

  testWidgets('logout returns to local mode without touching profile data', (
    tester,
  ) async {
    final profileRepository = _FakeProfileRepository();
    final authRepository = _FakeAuthRepository();
    await _pumpSettings(tester, profileRepository, authRepository);
    await tester.pumpAndSettle();
    await _login(tester, 'local-test-user');
    await _tapByKey(tester, 'registerDeviceButton');

    await _tapByKey(tester, 'logoutButton');

    expect(authRepository.logoutCalls, 1);
    expect(find.text('未登录'), findsOneWidget);
    expect(find.text('未注册'), findsOneWidget);
    expect(find.text('Local user'), findsOneWidget);
    expect(find.text('已退出开发账号，本地数据保持不变'), findsOneWidget);
    expect(profileRepository.saveCalls, 0);
  });

  testWidgets('WeChat login remains explicitly unavailable', (tester) async {
    await _pumpSettings(
      tester,
      _FakeProfileRepository(),
      _FakeAuthRepository(),
    );
    await tester.pumpAndSettle();

    await _tapByKey(tester, 'wechatLoginButton');

    expect(find.byKey(const ValueKey('wechatLoginDialog')), findsOneWidget);
    expect(find.text('微信登录尚未启用'), findsOneWidget);
    expect(find.textContaining('微信开放平台配置'), findsOneWidget);
  });

  testWidgets('sync settings explains the Profile-only manual scope', (
    tester,
  ) async {
    await _pumpSettings(
      tester,
      _FakeProfileRepository(),
      _FakeAuthRepository(),
    );
    await tester.pumpAndSettle();

    await _tapByKey(tester, 'syncSettingsButton');

    expect(find.byKey(const ValueKey('syncSettingsDialog')), findsOneWidget);
    expect(find.text('同步范围'), findsWidgets);
    expect(find.textContaining('当前仅支持 Profile 手动同步'), findsOneWidget);
    expect(find.textContaining('同步失败不会删除本地数据'), findsOneWidget);
  });

  testWidgets('account UI never claims unavailable cloud capabilities', (
    tester,
  ) async {
    await _pumpSettings(
      tester,
      _FakeProfileRepository(),
      _FakeAuthRepository(),
    );
    await tester.pumpAndSettle();

    for (final unavailableClaim in [
      '全部数据已同步',
      'Today 已同步',
      'Journal 已同步',
      'Plan 已同步',
      'Health 已同步',
      '微信已绑定',
      '云端已同步',
    ]) {
      expect(find.text(unavailableClaim), findsNothing);
    }
  });

  testWidgets('device read failure keeps Settings usable', (tester) async {
    await _pumpSettings(
      tester,
      _FakeProfileRepository(deviceError: StateError('device failed')),
      _FakeAuthRepository(),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('settingsDataState')), findsOneWidget);
    expect(find.text('无法读取设备信息'), findsOneWidget);
    expect(find.text('Local user'), findsOneWidget);
  });

  testWidgets('server endpoint validates, tests, saves, and restores', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await _pumpSettings(
      tester,
      _FakeProfileRepository(),
      _FakeAuthRepository(),
      endpointTester: const _FakeEndpointTester(),
    );
    await tester.pumpAndSettle();
    expect(find.text('http://127.0.0.1:8000'), findsWidgets);
    expect(find.text('应用默认值'), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('settingsDataState')),
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('editServerEndpointButton')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('serverEndpointField')),
      'ftp://invalid.example.com',
    );
    await tester.tap(find.byKey(const ValueKey('testServerEndpointButton')));
    await tester.pump();
    expect(find.textContaining('HTTP 或 HTTPS'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('serverEndpointField')),
      'http://server-b:8000/',
    );
    await tester.tap(find.byKey(const ValueKey('testServerEndpointButton')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('serverEndpointTestSuccess')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('saveServerEndpointButton')));
    await tester.pumpAndSettle();

    expect(find.text('http://server-b:8000'), findsWidgets);
    expect(find.text('用户设置'), findsOneWidget);
    await _tapByKey(tester, 'restoreServerEndpointButton');
    expect(find.text('应用默认值'), findsOneWidget);
  });

  testWidgets('changing endpoint confirms logout and preserves local profile', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final auth = _signedInAuthRepository();
    await _pumpSettings(
      tester,
      _FakeProfileRepository(),
      auth,
      endpointTester: const _FakeEndpointTester(),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('settingsDataState')),
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('editServerEndpointButton')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('serverEndpointField')),
      'http://server-b:8000',
    );
    await tester.tap(find.byKey(const ValueKey('testServerEndpointButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('saveServerEndpointButton')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('confirmServerEndpointChangeDialog')),
      findsOneWidget,
    );
    expect(find.textContaining('不会删除 Profile'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('confirmServerEndpointChangeButton')),
    );
    await tester.pumpAndSettle();

    expect(auth.logoutCalls, 1);
    expect(find.text('Local user'), findsOneWidget);
    expect(find.textContaining('请在新服务器重新登录'), findsOneWidget);
  });

  test('identifier formatting exposes only a short local value', () {
    expect(formatLocalIdentifier(_installationId), '12345678...cdef');
    expect(formatLocalIdentifier('short-id'), 'short-id');
  });

  test('Settings presentation keeps data and network boundaries explicit', () {
    final directory = Directory('lib/features/settings/presentation');
    for (final file in directory.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      expect(source, isNot(contains('app_database')));
      expect(source, isNot(contains('package:drift')));
      expect(source, isNot(contains('RepositoryImpl')));
      expect(source, isNot(contains('features/account/data')));
      expect(source, isNot(contains('core/network')));
      expect(source, isNot(contains('features/profile/presentation')));
    }
  });
}

Future<void> _pumpSettings(
  WidgetTester tester,
  ProfileRepository profileRepository,
  AuthRepository authRepository, {
  ProfileSyncRepository? syncRepository,
  ServerEndpointConnectionTester? endpointTester,
  AiConsentRepository? aiConsentRepository,
}) async {
  await tester.binding.setSurfaceSize(const Size(900, 1100));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        profileRepositoryProvider.overrideWithValue(profileRepository),
        accountRepositoryProvider.overrideWithValue(authRepository),
        aiConsentRepositoryProvider.overrideWithValue(
          aiConsentRepository ?? _FakeAiConsentRepository(),
        ),
        profileSyncRepositoryProvider.overrideWithValue(
          syncRepository ?? _FakeProfileSyncRepository(),
        ),
        if (endpointTester != null)
          serverEndpointConnectionTesterProvider.overrideWithValue(
            endpointTester,
          ),
      ],
      child: const MaterialApp(home: SettingsPage()),
    ),
  );
}

final class _FakeAiConsentRepository implements AiConsentRepository {
  AiDataAuthorization authorization = const AiDataAuthorization.disabled();

  @override
  Future<AiDataAuthorization> read() async => authorization;

  @override
  Future<AiDataAuthorization> grant() async {
    return authorization = AiDataAuthorization(enabled: true, consentAt: 1);
  }

  @override
  Future<AiDataAuthorization> revoke() async {
    return authorization = AiDataAuthorization(
      enabled: false,
      consentAt: authorization.consentAt,
    );
  }
}

Future<void> _tapByKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _login(WidgetTester tester, String devUserKey) async {
  await _tapByKey(tester, 'devLoginButton');
  await tester.enterText(
    find.byKey(const ValueKey('devUserKeyField')),
    devUserKey,
  );
  await tester.tap(find.byKey(const ValueKey('confirmDevLoginButton')));
  await tester.pumpAndSettle();
}

const _installationId = '12345678-1234-1234-1234-12345678cdef';
const _deviceId = '12345678-abcd-abcd-abcd-12345678cdef';

_FakeAuthRepository _signedInAuthRepository() {
  return _FakeAuthRepository()
    ..status = const AccountStatus(
      mode: AccountMode.cloudReady,
      authentication: AuthenticationStatus.signedIn,
      backendConfigured: true,
      backendReachable: true,
      user: AuthUser(id: 'cloud-user', displayName: 'Dev user'),
    );
}

_FakeAuthRepository _registeredAuthRepository() {
  return _FakeAuthRepository()
    ..status = const AccountStatus(
      mode: AccountMode.cloudReady,
      authentication: AuthenticationStatus.signedIn,
      backendConfigured: true,
      backendReachable: true,
      user: AuthUser(id: 'cloud-user', displayName: 'Dev user'),
      deviceRegistration: DeviceRegistration(
        deviceId: _deviceId,
        serverTime: 1,
      ),
    );
}

final class _FakeProfileSyncRepository implements ProfileSyncRepository {
  _FakeProfileSyncRepository({
    this.pushError,
    this.pullError,
    this.pullResult = const ProfileSyncResult(
      success: true,
      direction: ProfileSyncDirection.pull,
      message: 'Profile 已更新',
      pushed: false,
      pulled: true,
      conflict: false,
      serverVersion: 2,
    ),
  });

  final Object? pushError;
  final Object? pullError;
  final ProfileSyncResult pullResult;
  int pushCalls = 0;
  int pullCalls = 0;

  @override
  Future<ProfileSyncResult> pushProfile() async {
    pushCalls += 1;
    if (pushError case final error?) throw error;
    return const ProfileSyncResult(
      success: true,
      direction: ProfileSyncDirection.push,
      message: 'Profile 已上传',
      pushed: true,
      pulled: false,
      conflict: false,
      serverVersion: 1,
    );
  }

  @override
  Future<ProfileSyncResult> pullProfile() async {
    pullCalls += 1;
    if (pullError case final error?) throw error;
    return pullResult;
  }
}

final class _FakeAuthRepository implements AuthRepository {
  AccountStatus status = const AccountStatus.localOnly(
    backendConfigured: true,
  );
  Object? healthError;
  int healthCalls = 0;
  int loginCalls = 0;
  int registrationCalls = 0;
  int logoutCalls = 0;
  String? lastDevUserKey;

  @override
  Future<AccountStatus> getAccountStatus() async => status;

  @override
  Future<BackendHealth> checkBackendHealth() async {
    healthCalls += 1;
    if (healthError case final error?) throw error;
    return const BackendHealth(status: 'ok', service: 'rebirth-api');
  }

  @override
  Future<AuthSession> devLogin(String devUserKey) async {
    loginCalls += 1;
    lastDevUserKey = devUserKey;
    final user = AuthUser(
      id: 'user-$devUserKey',
      displayName: 'Dev $devUserKey',
    );
    status = AccountStatus(
      mode: AccountMode.cloudReady,
      authentication: AuthenticationStatus.signedIn,
      backendConfigured: true,
      backendReachable: false,
      user: user,
    );
    return AuthSession(
      accessToken: 'test-access-value',
      refreshToken: 'test-refresh-value',
      user: user,
    );
  }

  @override
  Future<DeviceRegistration> registerCurrentDevice() async {
    registrationCalls += 1;
    if (!status.isAuthenticated) {
      throw const AccountAuthenticationRequiredException();
    }
    const registration = DeviceRegistration(
      deviceId: _deviceId,
      serverTime: 1784073600000,
    );
    status = status.copyWith(deviceRegistration: registration);
    return registration;
  }

  @override
  Future<void> logout() async {
    logoutCalls += 1;
    status = const AccountStatus.localOnly(backendConfigured: true);
  }

  @override
  Future<void> refreshSession() async {
    throw UnsupportedError('Not available in this sprint.');
  }
}

final class _FakeEndpointTester implements ServerEndpointConnectionTester {
  const _FakeEndpointTester();

  @override
  Future<ServerEndpointHealth> test(String baseUrl) async {
    return const ServerEndpointHealth(
      status: 'ok',
      service: 'rebirth-api',
      apiVersion: 1,
      syncProtocolVersion: 2,
      environment: 'development',
    );
  }
}

final class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository({this.profileGate, this.loadError, this.deviceError});

  final Completer<UserProfile>? profileGate;
  Object? loadError;
  Object? deviceError;
  int profileLoads = 0;
  int saveCalls = 0;
  UserProfile profile = const UserProfile(
    id: '87654321-1234-1234-1234-12345678dcba',
    displayName: 'Local user',
    growthFocus: '持续成长',
    timezoneId: 'Asia/Shanghai',
    createdAt: 1,
    updatedAt: 1,
  );

  @override
  Future<UserProfile> getActiveProfile() async {
    profileLoads += 1;
    if (loadError != null) throw loadError!;
    return profileGate?.future ?? profile;
  }

  @override
  Future<DeviceProfileStatus> getDeviceStatus() async {
    if (loadError != null) throw loadError!;
    if (deviceError != null) throw deviceError!;
    return const DeviceProfileStatus(
      localInstallationId: _installationId,
      activeUserId: '87654321-1234-1234-1234-12345678dcba',
      isLocalMode: true,
      syncEnabled: false,
    );
  }

  @override
  Future<UserProfile> saveProfile(ProfileSaveData data) async {
    saveCalls += 1;
    return profile;
  }
}
