import 'package:rebirth/features/account/domain/backend_health.dart';

final class BackendHealthDto {
  const BackendHealthDto({
    required this.status,
    required this.service,
    required this.apiVersion,
    required this.syncProtocolVersion,
    required this.environment,
  });

  factory BackendHealthDto.fromJson(Map<String, Object?> json) {
    return BackendHealthDto(
      status: json['status'] as String,
      service: json['service'] as String,
      apiVersion: json['api_version'] as int,
      syncProtocolVersion: json['sync_protocol_version'] as int,
      environment: json['environment'] as String,
    );
  }

  final String status;
  final String service;
  final int apiVersion;
  final int syncProtocolVersion;
  final String environment;

  BackendHealth toDomain() {
    return BackendHealth(
      status: status,
      service: service,
      apiVersion: apiVersion,
      syncProtocolVersion: syncProtocolVersion,
      environment: environment,
    );
  }
}
