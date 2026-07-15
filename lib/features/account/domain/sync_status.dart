enum AccountSyncAvailability { disabled, available }

final class AccountSyncStatus {
  const AccountSyncStatus({
    required this.availability,
    required this.deviceRegistered,
    required this.backendReachable,
  });

  const AccountSyncStatus.disabled()
    : availability = AccountSyncAvailability.disabled,
      deviceRegistered = false,
      backendReachable = false;

  final AccountSyncAvailability availability;
  final bool deviceRegistered;
  final bool backendReachable;

  bool get canSync =>
      availability == AccountSyncAvailability.available &&
      deviceRegistered &&
      backendReachable;
}
