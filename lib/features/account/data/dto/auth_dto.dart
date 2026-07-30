import 'package:rebirth/features/account/domain/auth_session.dart';
import 'package:rebirth/features/account/domain/auth_user.dart';

final class AuthSessionDto {
  const AuthSessionDto({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.accessExpiresAt,
    required this.refreshExpiresAt,
    required this.sessionAbsoluteExpiresAt,
    required this.sessionId,
    required this.identityProvider,
    required this.userId,
    required this.displayName,
  });

  factory AuthSessionDto.fromJson(Map<String, Object?> json) {
    final rawUser = json['user'];
    if (rawUser is! Map) throw const FormatException('Invalid auth user.');
    final user = Map<String, Object?>.from(rawUser);
    return AuthSessionDto(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      tokenType: json['token_type'] as String,
      accessExpiresAt: json['access_expires_at'] as int,
      refreshExpiresAt: json['refresh_expires_at'] as int,
      sessionAbsoluteExpiresAt: json['session_absolute_expires_at'] as int,
      sessionId: json['session_id'] as String,
      identityProvider: json['identity_provider'] as String,
      userId: user['id'] as String,
      displayName: user['display_name'] as String?,
    );
  }

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int accessExpiresAt;
  final int refreshExpiresAt;
  final int sessionAbsoluteExpiresAt;
  final String sessionId;
  final String identityProvider;
  final String userId;
  final String? displayName;

  AuthSession toDomain() {
    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      tokenType: tokenType,
      accessExpiresAt: accessExpiresAt,
      refreshExpiresAt: refreshExpiresAt,
      sessionAbsoluteExpiresAt: sessionAbsoluteExpiresAt,
      sessionId: sessionId,
      identityProvider: identityProvider,
      lastVerifiedAt: 0,
      user: AuthUser(id: userId, displayName: displayName),
    );
  }
}
