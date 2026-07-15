import 'auth_user.dart';

enum AccountMode { localOnly, cloud }

enum AuthenticationStatus { signedOut, signedIn }

final class AccountStatus {
  const AccountStatus({
    required this.mode,
    required this.authentication,
    required this.backendConfigured,
    this.user,
  });

  const AccountStatus.localOnly()
    : mode = AccountMode.localOnly,
      authentication = AuthenticationStatus.signedOut,
      backendConfigured = false,
      user = null;

  final AccountMode mode;
  final AuthenticationStatus authentication;
  final bool backendConfigured;
  final AuthUser? user;

  bool get isAuthenticated =>
      authentication == AuthenticationStatus.signedIn && user != null;
}
