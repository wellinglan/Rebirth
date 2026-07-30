import 'account_boundary.dart';

enum AppAuthStatus {
  initializing,
  signedOut,
  submittingLogin,
  submittingRegister,
  submittingDeveloperLogin,
  bindingRequired,
  authenticated,
  authenticatedOffline,
  refreshOutcomeUnknown,
  sessionRejected,
  fatalMigrationError,
}

final class AppAuthState {
  const AppAuthState({
    required this.status,
    this.localUserId,
    this.cloudUserId,
    this.accountScope,
    this.syncEligibility,
    this.verificationStatus = AccountOwnershipVerificationStatus.verified,
    this.verificationReason,
    this.unboundProfileCount = 0,
    this.message,
    this.identityProvider,
    this.displayName,
  });

  const AppAuthState.initializing() : this(status: AppAuthStatus.initializing);

  const AppAuthState.signedOut({String? message})
    : this(status: AppAuthStatus.signedOut, message: message);

  final AppAuthStatus status;
  final String? localUserId;
  final String? cloudUserId;
  final CloudAccountScope? accountScope;
  final AccountSyncEligibility? syncEligibility;
  final AccountOwnershipVerificationStatus? verificationStatus;
  final String? verificationReason;
  final int unboundProfileCount;
  final String? message;
  final String? identityProvider;
  final String? displayName;

  bool get canAccessBusiness =>
      status == AppAuthStatus.authenticated ||
      status == AppAuthStatus.authenticatedOffline;

  bool get isSubmitting =>
      status == AppAuthStatus.submittingLogin ||
      status == AppAuthStatus.submittingRegister ||
      status == AppAuthStatus.submittingDeveloperLogin;

  bool get isOffline => status == AppAuthStatus.authenticatedOffline;

  bool get canUseCloudSync =>
      canAccessBusiness &&
      syncEligibility == AccountSyncEligibility.ready &&
      verificationStatus == AccountOwnershipVerificationStatus.verified;
}
