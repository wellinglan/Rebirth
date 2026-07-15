import 'package:rebirth/features/account/domain/backend_health.dart';

final class BackendHealthDto {
  const BackendHealthDto({required this.status, required this.service});

  factory BackendHealthDto.fromJson(Map<String, Object?> json) {
    return BackendHealthDto(
      status: json['status'] as String,
      service: json['service'] as String,
    );
  }

  final String status;
  final String service;

  BackendHealth toDomain() {
    return BackendHealth(status: status, service: service);
  }
}
