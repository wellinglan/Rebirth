import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/config/app_config_provider.dart';
import 'package:rebirth/core/config/server_endpoint_provider.dart';
import 'package:rebirth/core/database/database_provider.dart';
import 'package:rebirth/core/network/api_client_provider.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/account/domain/account_boundary_repository.dart';
import 'package:rebirth/features/account/domain/auth_repository.dart';

import 'account_boundary_repository_impl.dart';
import 'account_api_data_source.dart';
import 'account_repository_impl.dart';
import 'auth_session_store.dart';
import 'device_info_service.dart';
import 'local_auth_session_store.dart';

final authSessionStoreProvider = Provider<AuthSessionStore>(
  (ref) => LocalAuthSessionStore(
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

final accountRepositoryProvider = Provider<AuthRepository>((ref) {
  return AccountRepositoryImpl(
    remoteDataSource: ref.watch(accountRemoteDataSourceProvider),
    sessionStore: ref.watch(authSessionStoreProvider),
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
