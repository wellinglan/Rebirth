import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/config/app_config_provider.dart';
import 'package:rebirth/core/config/server_endpoint_provider.dart';
import 'package:rebirth/core/database/database_provider.dart';
import 'package:rebirth/core/network/api_client_provider.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/account/domain/account_boundary_repository.dart';
import 'package:rebirth/features/account/domain/auth_repository.dart';
import 'package:rebirth/features/account/domain/identity_repository.dart';
import 'package:rebirth/features/account/domain/legacy_ownership_verification_repository.dart';

import 'account_boundary_repository_impl.dart';
import 'account_api_data_source.dart';
import 'account_repository_impl.dart';
import 'auth_session_manager.dart';
import 'auth_session_store.dart';
import 'device_info_service.dart';
import 'identity_api_data_source.dart';
import 'identity_repository_impl.dart';
import 'secure_auth_session_store.dart';
import 'legacy_ownership_verification_api_data_source.dart';
import 'legacy_ownership_verification_repository_impl.dart';
import 'password_auth_service.dart';
import 'password_auth_remote_data_source.dart';

final authSessionStoreProvider = Provider<AuthSessionStore>(
  (ref) => SecureAuthSessionStore(
    expectedServerBaseUrl: ref.watch(effectiveServerEndpointProvider).baseUrl,
  ),
);

final deviceInfoServiceProvider = Provider<DeviceInfoService>(
  (ref) => const DeviceInfoService(),
);

final accountBoundaryRepositoryProvider = Provider<AccountBoundaryRepository>((
  ref,
) {
  final deviceInfo = ref.watch(deviceInfoServiceProvider).current();
  return AccountBoundaryRepositoryImpl(
    database: ref.watch(appDatabaseProvider),
    dateTimeService: ref.watch(dateTimeServiceProvider),
    platform: deviceInfo.platform,
    endpointValidator: ref.watch(serverEndpointValidatorProvider),
  );
});

final accountRemoteDataSourceProvider = Provider<AccountRemoteDataSource>(
  (ref) => AccountApiDataSource(ref.watch(apiClientProvider)),
);

final identityRemoteDataSourceProvider = Provider<IdentityRemoteDataSource>(
  (ref) => IdentityApiDataSource(ref.watch(apiClientProvider)),
);

final authSessionManagerProvider = Provider<AuthSessionManager>((ref) {
  final dateTimeService = ref.watch(dateTimeServiceProvider);
  final sessionStore = ref.watch(authSessionStoreProvider);
  if (sessionStore is! SecureAuthSessionStore) {
    return AuthSessionManager.forTesting(
      sessionStore: sessionStore,
      nowMilliseconds: dateTimeService.currentUtcMillisecondsSinceEpoch,
    );
  }
  return AuthSessionManager(
    sessionStore: sessionStore,
    remoteDataSource: ref.watch(accountRemoteDataSourceProvider),
    serverBaseUrl: ref.watch(effectiveServerEndpointProvider).baseUrl,
    nowMilliseconds: dateTimeService.currentUtcMillisecondsSinceEpoch,
  );
});

final accountRepositoryProvider = Provider<AuthRepository>((ref) {
  return AccountRepositoryImpl(
    remoteDataSource: ref.watch(accountRemoteDataSourceProvider),
    sessionStore: ref.watch(authSessionStoreProvider),
    sessionManager: ref.watch(authSessionManagerProvider),
    loadLocalInstallationId: () async {
      final installation = await ref
          .read(accountBoundaryRepositoryProvider)
          .ensureInstallation();
      return installation.installationId;
    },
    deviceInfoService: ref.watch(deviceInfoServiceProvider),
    config: ref.watch(appConfigProvider),
    serverBaseUrl: ref.watch(effectiveServerEndpointProvider).baseUrl,
  );
});

final identityRepositoryProvider = Provider<IdentityRepository>((ref) {
  return IdentityRepositoryImpl(
    ref.watch(authSessionManagerProvider),
    ref.watch(identityRemoteDataSourceProvider),
  );
});

final passwordAuthServiceProvider = Provider<PasswordAuthService>((ref) {
  return PasswordAuthServiceImpl(
    remoteDataSource: ref.watch(passwordAuthRemoteDataSourceProvider),
    sessionManager: ref.watch(authSessionManagerProvider),
    serverBaseUrl: ref.watch(effectiveServerEndpointProvider).baseUrl,
    loadClientMetadata: () async {
      final installation = await ref
          .read(accountBoundaryRepositoryProvider)
          .ensureInstallation();
      final device = ref.read(deviceInfoServiceProvider).current();
      return {
        'client_installation_id': installation.installationId,
        'platform': device.platform,
        'app_version': ref.read(appConfigProvider).appVersionLabel,
      };
    },
  );
});

final passwordAuthRemoteDataSourceProvider =
    Provider<PasswordAuthRemoteDataSource>(
      (ref) => PasswordAuthApiDataSource(ref.watch(apiClientProvider)),
    );

final legacyOwnershipVerificationRemoteDataSourceProvider =
    Provider<LegacyOwnershipVerificationRemoteDataSource>(
      (ref) => LegacyOwnershipVerificationApiDataSource(
        ref.watch(apiClientProvider),
      ),
    );

final legacyOwnershipVerificationRepositoryProvider =
    Provider<LegacyOwnershipVerificationRepository>((ref) {
      return LegacyOwnershipVerificationRepositoryImpl(
        database: ref.watch(appDatabaseProvider),
        sessionManager: ref.watch(authSessionManagerProvider),
        remoteDataSource: ref.watch(
          legacyOwnershipVerificationRemoteDataSourceProvider,
        ),
        dateTimeService: ref.watch(dateTimeServiceProvider),
        endpointValidator: ref.watch(serverEndpointValidatorProvider),
      );
    });
