import 'package:rebirth/core/network/api_client.dart';
import 'package:rebirth/core/network/api_exception.dart';
import 'package:rebirth/features/account/domain/legacy_ownership_verification.dart';

abstract interface class LegacyOwnershipVerificationRemoteDataSource {
  Future<LegacyOwnershipVerificationResult> verify({
    required List<LegacyOwnershipEvidence> evidence,
    required String accessToken,
  });
}

final class LegacyOwnershipVerificationApiDataSource
    implements LegacyOwnershipVerificationRemoteDataSource {
  const LegacyOwnershipVerificationApiDataSource(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<LegacyOwnershipVerificationResult> verify({
    required List<LegacyOwnershipEvidence> evidence,
    required String accessToken,
  }) async {
    if (accessToken.trim().isEmpty) {
      throw const ApiException(message: '登录状态已失效，请重新登录。');
    }
    final json = await _apiClient.postJson(
      '/sync/verify-ownership',
      accessToken: accessToken,
      timeout: const Duration(seconds: 8),
      body: {
        'evidence': evidence
            .map(
              (item) => <String, Object?>{
                'table': item.tableName,
                'id': item.recordId,
                'server_version': item.serverVersion,
                'metadata_fingerprint': item.metadataFingerprint,
              },
            )
            .toList(growable: false),
      },
    );
    try {
      return LegacyOwnershipVerificationResult(
        outcome: LegacyOwnershipVerificationOutcome.fromWire(
          json['status'] as String,
        ),
        verifiedCount: _nonNegativeInt(json, 'verified_count'),
        rejectedCount: _nonNegativeInt(json, 'rejected_count'),
        unknownCount: _nonNegativeInt(json, 'unknown_count'),
        reason: LegacyOwnershipVerificationReason.fromWire(
          json['reason'] as String,
        ),
      );
    } on FormatException catch (error) {
      throw ApiException(message: '后端返回了无法识别的验证结果。', cause: error);
    } on TypeError catch (error) {
      throw ApiException(message: '后端返回了无法识别的验证结果。', cause: error);
    }
  }

  int _nonNegativeInt(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! int || value < 0) {
      throw const FormatException('Invalid ownership verification count.');
    }
    return value;
  }
}
