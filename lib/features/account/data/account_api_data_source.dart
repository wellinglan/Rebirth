import 'package:rebirth/core/network/api_client.dart';
import 'package:rebirth/core/network/api_exception.dart';
import 'package:rebirth/features/account/domain/auth_session.dart';
import 'package:rebirth/features/account/domain/backend_health.dart';
import 'package:rebirth/features/account/domain/device_registration.dart';

import 'dto/auth_dto.dart';
import 'dto/device_dto.dart';
import 'dto/health_dto.dart';

abstract interface class AccountRemoteDataSource {
  Future<BackendHealth> getHealth();

  Future<AuthSession> devLogin(String devUserKey);

  Future<DeviceRegistration> registerDevice(
    DeviceRegistrationRequest request, {
    required String accessToken,
  });
}

final class AccountApiDataSource implements AccountRemoteDataSource {
  const AccountApiDataSource(this.apiClient);

  final ApiClient apiClient;

  @override
  Future<BackendHealth> getHealth() async {
    final json = await apiClient.getJson(
      '/health',
      timeout: const Duration(seconds: 3),
    );
    return _parse(() => BackendHealthDto.fromJson(json).toDomain());
  }

  @override
  Future<AuthSession> devLogin(String devUserKey) async {
    final json = await apiClient.postJson(
      '/auth/dev-login',
      body: {'dev_user_key': devUserKey},
      timeout: const Duration(seconds: 5),
    );
    return _parse(() => AuthSessionDto.fromJson(json).toDomain());
  }

  @override
  Future<DeviceRegistration> registerDevice(
    DeviceRegistrationRequest request, {
    required String accessToken,
  }) async {
    final json = await apiClient.postJson(
      '/devices/register',
      accessToken: accessToken,
      timeout: const Duration(seconds: 5),
      body: {
        'local_installation_id': request.localInstallationId,
        'platform': request.platform,
        'device_name': request.deviceName,
        'app_version': request.appVersion,
      },
    );
    return _parse(() => DeviceRegistrationDto.fromJson(json).toDomain());
  }

  T _parse<T>(T Function() parser) {
    try {
      return parser();
    } on FormatException catch (error) {
      throw ApiException(message: '后端返回了无法识别的数据。', cause: error);
    } on TypeError catch (error) {
      throw ApiException(message: '后端返回了无法识别的数据。', cause: error);
    }
  }
}
