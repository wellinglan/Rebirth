import 'auth_user.dart';
import 'device_registration.dart';

enum AccountMode { localOnly, cloudReady, cloud }

enum AuthenticationStatus { signedOut, signedIn }

final class AccountStatus {
  const AccountStatus({
    required this.mode,
    required this.authentication,
    required this.backendConfigured,
    required this.backendReachable,
    this.user,
    this.deviceRegistration,
    this.lastCheckedAt,
    this.errorMessage,
  });

  const AccountStatus.localOnly({this.backendConfigured = false})
    : mode = AccountMode.localOnly,
      authentication = AuthenticationStatus.signedOut,
      backendReachable = false,
      user = null,
      deviceRegistration = null,
      lastCheckedAt = null,
      errorMessage = null;

  final AccountMode mode;
  final AuthenticationStatus authentication;
  final bool backendConfigured;
  final bool backendReachable;
  final AuthUser? user;
  final DeviceRegistration? deviceRegistration;
  final int? lastCheckedAt;
  final String? errorMessage;

  bool get isAuthenticated =>
      authentication == AuthenticationStatus.signedIn && user != null;

  bool get deviceRegistered => deviceRegistration?.isRegistered ?? false;

  String? get deviceIdShort => deviceRegistration?.deviceIdShort;

  AccountStatus copyWith({
    AccountMode? mode,
    AuthenticationStatus? authentication,
    bool? backendConfigured,
    bool? backendReachable,
    Object? user = _unset,
    Object? deviceRegistration = _unset,
    Object? lastCheckedAt = _unset,
    Object? errorMessage = _unset,
  }) {
    return AccountStatus(
      mode: mode ?? this.mode,
      authentication: authentication ?? this.authentication,
      backendConfigured: backendConfigured ?? this.backendConfigured,
      backendReachable: backendReachable ?? this.backendReachable,
      user: identical(user, _unset) ? this.user : user as AuthUser?,
      deviceRegistration: identical(deviceRegistration, _unset)
          ? this.deviceRegistration
          : deviceRegistration as DeviceRegistration?,
      lastCheckedAt: identical(lastCheckedAt, _unset)
          ? this.lastCheckedAt
          : lastCheckedAt as int?,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

const _unset = Object();
