import 'package:rebirth/core/network/api_client.dart';
import 'package:rebirth/core/network/api_exception.dart';
import 'package:rebirth/features/sync/domain/sync_exception.dart';

import 'dto/sync_dto.dart';

abstract interface class SyncRemoteDataSource {
  Future<SyncPushResponseDto> push(
    SyncPushRequestDto request, {
    required String accessToken,
  });

  Future<SyncPullResponseDto> pull(
    SyncPullRequestDto request, {
    required String accessToken,
  });
}

final class SyncApiDataSource implements SyncRemoteDataSource {
  const SyncApiDataSource(this.apiClient);

  static const _supportedTable = 'user_profiles';

  final ApiClient apiClient;

  @override
  Future<SyncPushResponseDto> push(
    SyncPushRequestDto request, {
    required String accessToken,
  }) async {
    _validateCredentials(accessToken, request.deviceId);
    for (final item in request.items) {
      _validateTable(item.tableName);
    }
    final json = await apiClient.postJson(
      '/sync/push',
      body: request.toJson(),
      accessToken: accessToken,
      timeout: const Duration(seconds: 5),
    );
    return _parse(() => SyncPushResponseDto.fromJson(json));
  }

  @override
  Future<SyncPullResponseDto> pull(
    SyncPullRequestDto request, {
    required String accessToken,
  }) async {
    _validateCredentials(accessToken, request.deviceId);
    for (final table in request.tables) {
      _validateTable(table);
    }
    final json = await apiClient.postJson(
      '/sync/pull',
      body: request.toJson(),
      accessToken: accessToken,
      timeout: const Duration(seconds: 5),
    );
    return _parse(() => SyncPullResponseDto.fromJson(json));
  }

  void _validateCredentials(String accessToken, String deviceId) {
    if (accessToken.trim().isEmpty) {
      throw const SyncAuthenticationRequiredException();
    }
    if (deviceId.trim().isEmpty) {
      throw const SyncDeviceRegistrationRequiredException();
    }
  }

  void _validateTable(String tableName) {
    if (tableName != _supportedTable) {
      throw SyncUnsupportedTableException(tableName);
    }
  }

  T _parse<T>(T Function() parser) {
    try {
      return parser();
    } on FormatException catch (error) {
      throw ApiException(message: '后端返回了无法识别的同步数据。', cause: error);
    } on TypeError catch (error) {
      throw ApiException(message: '后端返回了无法识别的同步数据。', cause: error);
    }
  }
}
