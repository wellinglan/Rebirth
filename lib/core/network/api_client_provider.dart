import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/config/app_config_provider.dart';

import 'api_client.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  return DioApiClient(baseUrl: config.apiBaseUrl);
});
