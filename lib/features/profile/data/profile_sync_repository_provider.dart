import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/database/database_provider.dart';
import 'package:rebirth/core/config/server_endpoint_provider.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/account/data/account_repository_provider.dart';
import 'package:rebirth/features/sync/data/sync_repository_provider.dart';
import 'package:rebirth/features/sync/domain/profile_sync_repository.dart';

import 'profile_sync_repository_impl.dart';

final profileSyncRepositoryProvider = Provider<ProfileSyncRepository>((ref) {
  return ProfileSyncRepositoryImpl(
    database: ref.watch(appDatabaseProvider),
    sessionStore: ref.watch(authSessionStoreProvider),
    remoteDataSource: ref.watch(syncRemoteDataSourceProvider),
    dateTimeService: ref.watch(dateTimeServiceProvider),
    cursorStore: ref.watch(syncCursorStoreProvider),
    endpoint: ref.watch(effectiveServerEndpointProvider).baseUrl,
  );
});
