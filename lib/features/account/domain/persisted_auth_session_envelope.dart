import 'auth_user.dart';
import 'device_registration.dart';

final class PersistedAuthSessionEnvelope {
  const PersistedAuthSessionEnvelope({
    required this.refreshToken,
    required this.sessionId,
    required this.cloudUserId,
    required this.identityProvider,
    required this.serverBaseUrl,
    required this.refreshExpiresAt,
    required this.sessionAbsoluteExpiresAt,
    required this.lastVerifiedAt,
    this.displayName,
    this.deviceRegistration,
  });

  final String refreshToken;
  final String sessionId;
  final String cloudUserId;
  final String identityProvider;
  final String serverBaseUrl;
  final int refreshExpiresAt;
  final int sessionAbsoluteExpiresAt;
  final int lastVerifiedAt;
  final String? displayName;
  final DeviceRegistration? deviceRegistration;

  AuthUser get user => AuthUser(id: cloudUserId, displayName: displayName);
}
