final class DeviceProfileStatus {
  const DeviceProfileStatus({
    required this.localInstallationId,
    required this.activeUserId,
    required this.isLocalMode,
    required this.syncEnabled,
  });

  final String localInstallationId;
  final String activeUserId;
  final bool isLocalMode;
  final bool syncEnabled;
}
