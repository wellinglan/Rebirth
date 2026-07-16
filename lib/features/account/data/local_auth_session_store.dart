import 'dart:convert';

import 'package:rebirth/features/account/domain/auth_session.dart';
import 'package:rebirth/features/account/domain/auth_user.dart';
import 'package:rebirth/features/account/domain/device_registration.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rebirth/core/config/server_endpoint_validator.dart';

import 'auth_session_store.dart';

final class LocalAuthSessionStore implements AuthSessionStore {
  LocalAuthSessionStore({
    Future<SharedPreferences> Function()? loadPreferences,
    this.expectedServerBaseUrl,
    this.endpointValidator = const ServerEndpointValidator(),
  }) : _loadPreferences = loadPreferences ?? SharedPreferences.getInstance;

  static const _sessionKey = 'rebirth.dev.auth_session.v1';

  final Future<SharedPreferences> Function() _loadPreferences;
  final String? expectedServerBaseUrl;
  final ServerEndpointValidator endpointValidator;

  @override
  Future<AuthSession?> read() async {
    final preferences = await _loadPreferences();
    final encoded = preferences.getString(_sessionKey);
    if (encoded == null) return null;

    try {
      final json = jsonDecode(encoded);
      if (json is! Map) throw const FormatException('Invalid session data.');
      final session = _decodeSession(Map<String, Object?>.from(json));
      final expected = expectedServerBaseUrl;
      if (expected != null &&
          (session.serverBaseUrl.isEmpty ||
              endpointValidator.normalize(session.serverBaseUrl) !=
                  endpointValidator.normalize(expected))) {
        await preferences.remove(_sessionKey);
        return null;
      }
      return session;
    } on FormatException {
      await preferences.remove(_sessionKey);
      return null;
    } on TypeError {
      await preferences.remove(_sessionKey);
      return null;
    }
  }

  @override
  Future<void> save(AuthSession session) async {
    final preferences = await _loadPreferences();
    final device = session.deviceRegistration;
    final encoded = jsonEncode({
      'access_token': session.accessToken,
      'refresh_token': session.refreshToken,
      'token_type': session.tokenType,
      'server_base_url': session.serverBaseUrl,
      'user': {'id': session.user.id, 'display_name': session.user.displayName},
      'device': device == null
          ? null
          : {'device_id': device.deviceId, 'server_time': device.serverTime},
    });
    final saved = await preferences.setString(_sessionKey, encoded);
    if (!saved) {
      throw StateError('Development session could not be saved.');
    }
  }

  @override
  Future<void> clear() async {
    final preferences = await _loadPreferences();
    await preferences.remove(_sessionKey);
  }

  AuthSession _decodeSession(Map<String, Object?> json) {
    final rawUser = json['user'];
    if (rawUser is! Map) throw const FormatException('Invalid session user.');
    final user = Map<String, Object?>.from(rawUser);
    final rawDevice = json['device'];
    final device = rawDevice == null
        ? null
        : _decodeDevice(Map<String, Object?>.from(rawDevice as Map));

    return AuthSession(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      tokenType: json['token_type'] as String,
      serverBaseUrl: json['server_base_url'] as String? ?? '',
      user: AuthUser(
        id: user['id'] as String,
        displayName: user['display_name'] as String?,
      ),
      deviceRegistration: device,
    );
  }

  DeviceRegistration _decodeDevice(Map<String, Object?> json) {
    return DeviceRegistration(
      deviceId: json['device_id'] as String,
      serverTime: json['server_time'] as int,
    );
  }
}
