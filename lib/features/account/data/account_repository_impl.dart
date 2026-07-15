import 'package:rebirth/core/config/app_config.dart';
import 'package:rebirth/features/account/domain/account_exception.dart';
import 'package:rebirth/features/account/domain/account_status.dart';
import 'package:rebirth/features/account/domain/auth_repository.dart';
import 'package:rebirth/features/account/domain/auth_session.dart';
import 'package:rebirth/features/account/domain/backend_health.dart';
import 'package:rebirth/features/account/domain/device_registration.dart';

import 'account_api_data_source.dart';
import 'auth_session_store.dart';
import 'device_info_service.dart';

final class AccountRepositoryImpl implements AuthRepository {
  const AccountRepositoryImpl({
    required this.remoteDataSource,
    required this.sessionStore,
    required this.loadLocalInstallationId,
    required this.deviceInfoService,
    required this.config,
  });

  final AccountRemoteDataSource remoteDataSource;
  final AuthSessionStore sessionStore;
  final Future<String> Function() loadLocalInstallationId;
  final DeviceInfoService deviceInfoService;
  final AppConfig config;

  @override
  Future<AccountStatus> getAccountStatus() async {
    final session = await sessionStore.read();
    final backendConfigured = config.apiBaseUrl.trim().isNotEmpty;
    if (session == null) {
      return AccountStatus.localOnly(backendConfigured: backendConfigured);
    }
    return AccountStatus(
      mode: AccountMode.cloudReady,
      authentication: AuthenticationStatus.signedIn,
      backendConfigured: backendConfigured,
      backendReachable: false,
      user: session.user,
      deviceRegistration: session.deviceRegistration,
    );
  }

  @override
  Future<BackendHealth> checkBackendHealth() {
    return remoteDataSource.getHealth();
  }

  @override
  Future<AuthSession> devLogin(String devUserKey) async {
    if (!config.enableDevLogin) {
      throw UnsupportedError('Development login is disabled.');
    }
    final key = devUserKey.trim();
    if (key.isEmpty) {
      throw ArgumentError.value(devUserKey, 'devUserKey', 'Must not be empty.');
    }
    final session = await remoteDataSource.devLogin(key);
    await sessionStore.save(session);
    return session;
  }

  @override
  Future<DeviceRegistration> registerCurrentDevice() async {
    final session = await sessionStore.read();
    if (session == null) {
      throw const AccountAuthenticationRequiredException();
    }
    final installationId = await loadLocalInstallationId();
    final deviceInfo = deviceInfoService.current();
    final registration = await remoteDataSource.registerDevice(
      DeviceRegistrationRequest(
        localInstallationId: installationId,
        platform: deviceInfo.platform,
        deviceName: deviceInfo.deviceName,
        appVersion: config.appVersionLabel,
      ),
      accessToken: session.accessToken,
    );
    await sessionStore.save(
      session.copyWith(deviceRegistration: registration),
    );
    return registration;
  }

  @override
  Future<void> logout() {
    return sessionStore.clear();
  }

  @override
  Future<void> refreshSession() {
    throw UnsupportedError('Session refresh is not available in Sprint 6C.');
  }
}
