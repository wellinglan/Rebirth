import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/config/server_endpoint_provider.dart';

import 'api_client.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final endpoint = ref.watch(effectiveServerEndpointProvider);
  return DioApiClient(baseUrl: endpoint.baseUrl);
});
