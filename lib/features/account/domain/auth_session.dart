import 'auth_user.dart';
import 'device_registration.dart';

final class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
    this.tokenType = 'bearer',
    this.serverBaseUrl = '',
    this.deviceRegistration,
  });

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final AuthUser user;
  final String serverBaseUrl;
  final DeviceRegistration? deviceRegistration;

  AuthSession copyWith({
    String? serverBaseUrl,
    DeviceRegistration? deviceRegistration,
  }) {
    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      tokenType: tokenType,
      user: user,
      serverBaseUrl: serverBaseUrl ?? this.serverBaseUrl,
      deviceRegistration: deviceRegistration ?? this.deviceRegistration,
    );
  }
}
