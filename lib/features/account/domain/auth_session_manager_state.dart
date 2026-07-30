import 'auth_session.dart';

enum AuthSessionManagerStatus {
  uninitialized,
  signedOut,
  authenticated,
  refreshing,
  authenticatedOffline,
  refreshOutcomeUnknown,
  sessionRejected,
}

final class AuthSessionManagerState {
  const AuthSessionManagerState({
    required this.status,
    this.session,
  });

  const AuthSessionManagerState.uninitialized()
    : this(status: AuthSessionManagerStatus.uninitialized);

  final AuthSessionManagerStatus status;
  final AuthSession? session;
}
