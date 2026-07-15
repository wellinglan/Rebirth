import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/network/api_client_provider.dart';

import 'sync_api_data_source.dart';

final syncRemoteDataSourceProvider = Provider<SyncRemoteDataSource>(
  (ref) => SyncApiDataSource(ref.watch(apiClientProvider)),
);
