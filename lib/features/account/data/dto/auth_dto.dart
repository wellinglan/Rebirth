import 'package:rebirth/features/account/domain/auth_session.dart';
import 'package:rebirth/features/account/domain/auth_user.dart';

final class AuthSessionDto {
  const AuthSessionDto({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
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
      userId: user['id'] as String,
      displayName: user['display_name'] as String?,
    );
  }

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final String userId;
  final String? displayName;

  AuthSession toDomain() {
    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      tokenType: tokenType,
      user: AuthUser(id: userId, displayName: displayName),
    );
  }
}
