enum AppAuthStatus {
  initializing,
  signedOut,
  bindingRequired,
  authenticated,
  authenticatedOffline,
  sessionRejected,
  fatalMigrationError,
}

final class AppAuthState {
  const AppAuthState({
    required this.status,
    this.localUserId,
    this.cloudUserId,
    this.unboundProfileCount = 0,
    this.message,
  });

  const AppAuthState.initializing() : this(status: AppAuthStatus.initializing);

  const AppAuthState.signedOut({String? message})
    : this(status: AppAuthStatus.signedOut, message: message);

  final AppAuthStatus status;
  final String? localUserId;
  final String? cloudUserId;
  final int unboundProfileCount;
  final String? message;

  bool get canAccessBusiness =>
      status == AppAuthStatus.authenticated ||
      status == AppAuthStatus.authenticatedOffline;

  bool get isOffline => status == AppAuthStatus.authenticatedOffline;
}
