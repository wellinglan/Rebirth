import 'dart:convert';

import 'package:rebirth/core/config/server_endpoint_validator.dart';
import 'package:rebirth/features/sync/domain/sync_cursor_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class LocalSyncCursorStore implements SyncCursorStore {
  LocalSyncCursorStore({
    Future<SharedPreferences> Function()? loadPreferences,
    this.validator = const ServerEndpointValidator(),
  }) : _loadPreferences = loadPreferences ?? SharedPreferences.getInstance;

  static const _prefix = 'rebirth.sync_cursor.v1';

  final Future<SharedPreferences> Function() _loadPreferences;
  final ServerEndpointValidator validator;

  @override
  Future<int> read({
    required String endpoint,
    required String cloudUserId,
    required String scope,
  }) async {
    final preferences = await _loadPreferences();
    return preferences.getInt(_key(endpoint, cloudUserId, scope)) ?? 0;
  }

  @override
  Future<void> write({
    required String endpoint,
    required String cloudUserId,
    required String scope,
    required int serverVersion,
  }) async {
    if (serverVersion < 0) {
      throw ArgumentError.value(serverVersion, 'serverVersion');
    }
    final preferences = await _loadPreferences();
    final saved = await preferences.setInt(
      _key(endpoint, cloudUserId, scope),
      serverVersion,
    );
    if (!saved) throw StateError('Sync cursor could not be saved.');
  }

  @override
  Future<void> clear({
    required String endpoint,
    required String cloudUserId,
    String? scope,
  }) async {
    final preferences = await _loadPreferences();
    if (scope != null) {
      await preferences.remove(_key(endpoint, cloudUserId, scope));
      return;
    }
    final prefix = _keyPrefix(endpoint, cloudUserId);
    for (final key in preferences.getKeys().where((key) => key.startsWith(prefix))) {
      await preferences.remove(key);
    }
  }

  String _key(String endpoint, String cloudUserId, String scope) {
    return '${_keyPrefix(endpoint, cloudUserId)}.${_encode(scope)}';
  }

  String _keyPrefix(String endpoint, String cloudUserId) {
    final normalized = validator.normalize(endpoint);
    return '$_prefix.${_encode(normalized)}.${_encode(cloudUserId)}';
  }

  String _encode(String value) => base64Url.encode(utf8.encode(value));
}

