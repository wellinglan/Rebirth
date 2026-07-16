import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/network/api_client_provider.dart';
import 'package:rebirth/core/config/server_endpoint_provider.dart';
import 'package:rebirth/features/sync/domain/sync_cursor_store.dart';

import 'sync_api_data_source.dart';
import 'sync_cursor_store_impl.dart';

final syncCursorStoreProvider = Provider<SyncCursorStore>(
  (ref) => LocalSyncCursorStore(
    validator: ref.watch(serverEndpointValidatorProvider),
  ),
);

final syncRemoteDataSourceProvider = Provider<SyncRemoteDataSource>(
  (ref) => SyncApiDataSource(ref.watch(apiClientProvider)),
);
