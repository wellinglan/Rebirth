import 'package:shared_preferences/shared_preferences.dart';

import 'server_endpoint.dart';
import 'server_endpoint_store.dart';
import 'server_endpoint_validator.dart';

final class LocalServerEndpointStore implements ServerEndpointStore {
  LocalServerEndpointStore({
    Future<SharedPreferences> Function()? loadPreferences,
    this.validator = const ServerEndpointValidator(),
  }) : _loadPreferences = loadPreferences ?? SharedPreferences.getInstance;

  static const _endpointKey = 'rebirth.server_endpoint.v1';

  final Future<SharedPreferences> Function() _loadPreferences;
  final ServerEndpointValidator validator;

  @override
  Future<ServerEndpoint> read({required ServerEndpoint fallback}) async {
    final preferences = await _loadPreferences();
    final saved = preferences.getString(_endpointKey);
    if (saved == null) return fallback;
    try {
      return ServerEndpoint(
        baseUrl: validator.normalize(saved),
        source: ServerEndpointSource.saved,
      );
    } on FormatException {
      await preferences.remove(_endpointKey);
      return fallback;
    }
  }

  @override
  Future<void> save(String baseUrl) async {
    final normalized = validator.normalize(baseUrl);
    final preferences = await _loadPreferences();
    final saved = await preferences.setString(_endpointKey, normalized);
    if (!saved) throw StateError('Server endpoint could not be saved.');
  }

  @override
  Future<void> clear() async {
    final preferences = await _loadPreferences();
    await preferences.remove(_endpointKey);
  }
}

