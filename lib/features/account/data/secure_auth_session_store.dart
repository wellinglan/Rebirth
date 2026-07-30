import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:rebirth/core/config/server_endpoint_validator.dart';
import 'package:rebirth/features/account/domain/auth_session.dart';
import 'package:rebirth/features/account/domain/auth_user.dart';
import 'package:rebirth/features/account/domain/device_registration.dart';
import 'package:rebirth/features/account/domain/persisted_auth_session_envelope.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_session_store.dart';

abstract interface class SecureValueStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

final class FlutterSecureValueStore implements SecureValueStore {
  const FlutterSecureValueStore([this.storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage storage;

  @override
  Future<String?> read(String key) => storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => storage.delete(key: key);
}

final class AuthSessionStorageException implements Exception {
  const AuthSessionStorageException(this.message);

  final String message;
}

final class SecureAuthSessionStore implements AuthSessionStore {
  SecureAuthSessionStore({
    SecureValueStore? secureStore,
    Future<SharedPreferences> Function()? loadPreferences,
    this.expectedServerBaseUrl,
    this.endpointValidator = const ServerEndpointValidator(),
  }) : _secureStore = secureStore ?? const FlutterSecureValueStore(),
       _loadPreferences = loadPreferences ?? SharedPreferences.getInstance;

  static const secureSessionKey = 'rebirth.auth.secure_session.v1';
  static const legacySessionKey = 'rebirth.dev.auth_session.v1';

  final SecureValueStore _secureStore;
  final Future<SharedPreferences> Function() _loadPreferences;
  final String? expectedServerBaseUrl;
  final ServerEndpointValidator endpointValidator;

  AuthSession? _runtimeSession;

  @override
  Future<AuthSession?> read() async {
    final runtime = _runtimeSession;
    if (runtime != null) {
      if (_endpointMatches(runtime.serverBaseUrl)) return runtime;
      await clear();
      return null;
    }
    try {
      final secureEncoded = await _secureStore.read(secureSessionKey);
      if (secureEncoded != null) {
        final envelope = _decodeEnvelope(secureEncoded);
        if (!_endpointMatches(envelope.serverBaseUrl)) {
          await clear();
          return null;
        }
        return _fromEnvelope(envelope);
      }
      return _migrateLegacySession();
    } on AuthSessionStorageException {
      rethrow;
    } catch (_) {
      await _secureStore.delete(secureSessionKey);
      throw const AuthSessionStorageException(
        '安全会话不可用，本地数据仍然保留。',
      );
    }
  }

  @override
  Future<void> save(AuthSession session) async {
    if (session.refreshToken.isEmpty ||
        session.user.id.isEmpty ||
        session.serverBaseUrl.isEmpty) {
      throw const AuthSessionStorageException('安全会话数据不完整。');
    }
    final encoded = _encodeEnvelope(_toEnvelope(session));
    try {
      await _secureStore.write(secureSessionKey, encoded);
      final verified = await _secureStore.read(secureSessionKey);
      if (verified != encoded) {
        await _secureStore.delete(secureSessionKey);
        throw const AuthSessionStorageException('安全会话写入验证失败。');
      }
      _runtimeSession = session;
    } on AuthSessionStorageException {
      rethrow;
    } catch (_) {
      await _secureStore.delete(secureSessionKey);
      throw const AuthSessionStorageException('安全会话无法保存。');
    }
  }

  @override
  Future<void> clear() async {
    _runtimeSession = null;
    try {
      await _secureStore.delete(secureSessionKey);
    } finally {
      final preferences = await _loadPreferences();
      await preferences.remove(legacySessionKey);
    }
  }

  Future<AuthSession?> _migrateLegacySession() async {
    final preferences = await _loadPreferences();
    final encoded = preferences.getString(legacySessionKey);
    if (encoded == null) return null;
    AuthSession legacy;
    try {
      legacy = _decodeLegacySession(encoded);
      if (!_endpointMatches(legacy.serverBaseUrl) ||
          legacy.refreshToken.isEmpty) {
        await preferences.remove(legacySessionKey);
        return null;
      }
      final secureEncoded = _encodeEnvelope(_toEnvelope(legacy));
      await _secureStore.write(secureSessionKey, secureEncoded);
      final verified = await _secureStore.read(secureSessionKey);
      if (verified != secureEncoded) {
        throw const AuthSessionStorageException('旧会话安全迁移验证失败。');
      }
      await preferences.remove(legacySessionKey);
      _runtimeSession = legacy;
      return legacy;
    } catch (error) {
      await preferences.remove(legacySessionKey);
      if (error is AuthSessionStorageException) rethrow;
      throw const AuthSessionStorageException(
        '旧会话无法安全迁移，本地数据仍然保留。',
      );
    }
  }

  bool _endpointMatches(String actual) {
    final expected = expectedServerBaseUrl;
    if (expected == null) return true;
    if (actual.isEmpty) return false;
    return endpointValidator.normalize(actual) ==
        endpointValidator.normalize(expected);
  }

  PersistedAuthSessionEnvelope _toEnvelope(AuthSession session) {
    return PersistedAuthSessionEnvelope(
      refreshToken: session.refreshToken,
      sessionId: session.sessionId,
      cloudUserId: session.user.id,
      identityProvider: session.identityProvider,
      serverBaseUrl: session.serverBaseUrl,
      refreshExpiresAt: session.refreshExpiresAt,
      sessionAbsoluteExpiresAt: session.sessionAbsoluteExpiresAt,
      lastVerifiedAt: session.lastVerifiedAt,
      displayName: session.user.displayName,
      deviceRegistration: session.deviceRegistration,
    );
  }

  AuthSession _fromEnvelope(PersistedAuthSessionEnvelope envelope) {
    return AuthSession(
      accessToken: '',
      refreshToken: envelope.refreshToken,
      user: envelope.user,
      serverBaseUrl: envelope.serverBaseUrl,
      refreshExpiresAt: envelope.refreshExpiresAt,
      sessionAbsoluteExpiresAt: envelope.sessionAbsoluteExpiresAt,
      sessionId: envelope.sessionId,
      identityProvider: envelope.identityProvider,
      lastVerifiedAt: envelope.lastVerifiedAt,
      deviceRegistration: envelope.deviceRegistration,
    );
  }

  String _encodeEnvelope(PersistedAuthSessionEnvelope envelope) {
    final device = envelope.deviceRegistration;
    return jsonEncode({
      'version': 1,
      'refresh_token': envelope.refreshToken,
      'session_id': envelope.sessionId,
      'cloud_user_id': envelope.cloudUserId,
      'identity_provider': envelope.identityProvider,
      'server_base_url': envelope.serverBaseUrl,
      'refresh_expires_at': envelope.refreshExpiresAt,
      'session_absolute_expires_at': envelope.sessionAbsoluteExpiresAt,
      'last_verified_at': envelope.lastVerifiedAt,
      'display_name': envelope.displayName,
      'device': device == null
          ? null
          : {'device_id': device.deviceId, 'server_time': device.serverTime},
    });
  }

  PersistedAuthSessionEnvelope _decodeEnvelope(String encoded) {
    final raw = jsonDecode(encoded);
    if (raw is! Map) throw const FormatException();
    final json = Map<String, Object?>.from(raw);
    if (json['version'] != 1) throw const FormatException();
    return PersistedAuthSessionEnvelope(
      refreshToken: json['refresh_token'] as String,
      sessionId: json['session_id'] as String,
      cloudUserId: json['cloud_user_id'] as String,
      identityProvider: json['identity_provider'] as String,
      serverBaseUrl: json['server_base_url'] as String,
      refreshExpiresAt: json['refresh_expires_at'] as int,
      sessionAbsoluteExpiresAt: json['session_absolute_expires_at'] as int,
      lastVerifiedAt: json['last_verified_at'] as int,
      displayName: json['display_name'] as String?,
      deviceRegistration: _decodeDevice(json['device']),
    );
  }

  AuthSession _decodeLegacySession(String encoded) {
    final raw = jsonDecode(encoded);
    if (raw is! Map) throw const FormatException();
    final json = Map<String, Object?>.from(raw);
    final rawUser = json['user'];
    if (rawUser is! Map) throw const FormatException();
    final user = Map<String, Object?>.from(rawUser);
    return AuthSession(
      accessToken: json['access_token'] as String? ?? '',
      refreshToken: json['refresh_token'] as String? ?? '',
      tokenType: json['token_type'] as String? ?? 'bearer',
      serverBaseUrl: json['server_base_url'] as String? ?? '',
      user: AuthUser(
        id: user['id'] as String,
        displayName: user['display_name'] as String?,
      ),
      deviceRegistration: _decodeDevice(json['device']),
    );
  }

  DeviceRegistration? _decodeDevice(Object? raw) {
    if (raw == null) return null;
    if (raw is! Map) throw const FormatException();
    final json = Map<String, Object?>.from(raw);
    return DeviceRegistration(
      deviceId: json['device_id'] as String,
      serverTime: json['server_time'] as int,
    );
  }
}
