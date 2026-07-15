final class DeviceRegistrationRequest {
  const DeviceRegistrationRequest({
    required this.localInstallationId,
    required this.platform,
    required this.deviceName,
    required this.appVersion,
  });

  final String localInstallationId;
  final String platform;
  final String deviceName;
  final String appVersion;
}

final class DeviceRegistration {
  const DeviceRegistration({required this.deviceId, required this.serverTime});

  final String deviceId;
  final int serverTime;

  bool get isRegistered => deviceId.isNotEmpty;

  String get deviceIdShort {
    if (deviceId.length <= 13) return deviceId;
    return '${deviceId.substring(0, 8)}...${deviceId.substring(deviceId.length - 4)}';
  }
}
