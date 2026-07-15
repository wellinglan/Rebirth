import 'auth_user.dart';
import 'device_registration.dart';

final class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
    this.tokenType = 'bearer',
    this.deviceRegistration,
  });

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final AuthUser user;
  final DeviceRegistration? deviceRegistration;

  AuthSession copyWith({DeviceRegistration? deviceRegistration}) {
    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      tokenType: tokenType,
      user: user,
      deviceRegistration: deviceRegistration ?? this.deviceRegistration,
    );
  }
}
