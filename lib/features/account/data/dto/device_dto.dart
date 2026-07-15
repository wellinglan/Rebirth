import 'package:rebirth/features/account/domain/device_registration.dart';

final class DeviceRegistrationDto {
  const DeviceRegistrationDto({
    required this.deviceId,
    required this.serverTime,
  });

  factory DeviceRegistrationDto.fromJson(Map<String, Object?> json) {
    return DeviceRegistrationDto(
      deviceId: json['device_id'] as String,
      serverTime: json['server_time'] as int,
    );
  }

  final String deviceId;
  final int serverTime;

  DeviceRegistration toDomain() {
    return DeviceRegistration(deviceId: deviceId, serverTime: serverTime);
  }
}
