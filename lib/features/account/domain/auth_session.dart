import 'auth_user.dart';
import 'device_registration.dart';

final class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
    this.tokenType = 'bearer',
    this.serverBaseUrl = '',
    this.accessExpiresAt = 0,
    this.refreshExpiresAt = 0,
    this.sessionAbsoluteExpiresAt = 0,
    this.sessionId = '',
    this.identityProvider = 'dev',
    this.lastVerifiedAt = 0,
    this.deviceRegistration,
  });

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final AuthUser user;
  final String serverBaseUrl;
  final int accessExpiresAt;
  final int refreshExpiresAt;
  final int sessionAbsoluteExpiresAt;
  final String sessionId;
  final String identityProvider;
  final int lastVerifiedAt;
  final DeviceRegistration? deviceRegistration;

  AuthSession copyWith({
    String? serverBaseUrl,
    String? accessToken,
    String? refreshToken,
    int? accessExpiresAt,
    int? refreshExpiresAt,
    int? sessionAbsoluteExpiresAt,
    String? sessionId,
    String? identityProvider,
    int? lastVerifiedAt,
    DeviceRegistration? deviceRegistration,
  }) {
    return AuthSession(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      tokenType: tokenType,
      user: user,
      serverBaseUrl: serverBaseUrl ?? this.serverBaseUrl,
      accessExpiresAt: accessExpiresAt ?? this.accessExpiresAt,
      refreshExpiresAt: refreshExpiresAt ?? this.refreshExpiresAt,
      sessionAbsoluteExpiresAt:
          sessionAbsoluteExpiresAt ?? this.sessionAbsoluteExpiresAt,
      sessionId: sessionId ?? this.sessionId,
      identityProvider: identityProvider ?? this.identityProvider,
      lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
      deviceRegistration: deviceRegistration ?? this.deviceRegistration,
    );
  }
}
