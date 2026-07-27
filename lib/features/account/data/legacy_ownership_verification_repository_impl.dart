import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:rebirth/core/config/server_endpoint_validator.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/account/data/auth_session_store.dart';
import 'package:rebirth/features/account/domain/account_boundary.dart';
import 'package:rebirth/features/account/domain/auth_session.dart';
import 'package:rebirth/features/account/domain/legacy_ownership_verification.dart';
import 'package:rebirth/features/account/domain/legacy_ownership_verification_repository.dart';
import 'package:rebirth/features/sync/domain/sync_record_keys.dart';

import 'legacy_ownership_verification_api_data_source.dart';

final class LegacyOwnershipVerificationRepositoryImpl
    implements LegacyOwnershipVerificationRepository {
  const LegacyOwnershipVerificationRepositoryImpl({
    required AppDatabase database,
    required AuthSessionStore sessionStore,
    required LegacyOwnershipVerificationRemoteDataSource remoteDataSource,
    required DateTimeService dateTimeService,
    ServerEndpointValidator endpointValidator = const ServerEndpointValidator(),
  }) : this._(
         database,
         sessionStore,
         remoteDataSource,
         dateTimeService,
         endpointValidator,
       );

  const LegacyOwnershipVerificationRepositoryImpl._(
    this._database,
    this._sessionStore,
    this._remoteDataSource,
    this._dateTimeService,
    this._endpointValidator,
  );

  static const maxEvidenceItems = 500;

  final AppDatabase _database;
  final AuthSessionStore _sessionStore;
  final LegacyOwnershipVerificationRemoteDataSource _remoteDataSource;
  final DateTimeService _dateTimeService;
  final ServerEndpointValidator _endpointValidator;

  @override
  Future<LegacyOwnershipVerificationResult> verifyCurrentDataSpace() async {
    final session = await _requireSession();
    final context = await _loadContext(session);
    if (context.binding.syncEligibilityStatus == 'ready' &&
        context.binding.verificationStatus == 'verified') {
      return const LegacyOwnershipVerificationResult(
        outcome: LegacyOwnershipVerificationOutcome.verified,
        verifiedCount: 0,
        rejectedCount: 0,
        unknownCount: 0,
        reason: LegacyOwnershipVerificationReason.allEvidenceMatchesCurrentUser,
      );
    }
    if (context.binding.bindingOrigin != 'legacy_claim') {
      throw const AccountSyncReviewRequiredException('当前数据空间不需要旧数据归属验证。');
    }

    final evidence = await _collectEvidence(context);
    if (evidence.length > maxEvidenceItems) {
      throw const AccountSyncReviewRequiredException(
        '旧同步记录超过单次安全验证上限，同步继续保持关闭。',
      );
    }
    final result = await _remoteDataSource.verify(
      evidence: evidence,
      accessToken: session.accessToken,
    );

    final currentSession = await _requireSession();
    if (!_sameSessionScope(session, currentSession)) {
      throw const AccountSessionRejectedException('验证期间登录账号或服务器已变化，请重新操作。');
    }
    await _persistResult(context, result);
    return result;
  }

  Future<_VerificationContext> _loadContext(AuthSession session) async {
    final endpointKey = _normalizeEndpoint(session.serverBaseUrl);
    final cloudUserId = session.user.id.trim();
    if (cloudUserId.isEmpty) {
      throw const AccountSessionRejectedException();
    }
    final profiles =
        await (_database.select(_database.userProfiles)..where(
              (row) => row.isActive.equals(true) & row.deletedAt.isNull(),
            ))
            .get();
    if (profiles.length != 1) {
      throw const AccountScopeMismatchException();
    }
    final profile = profiles.single;
    final binding =
        await (_database.select(_database.cloudAccountBindings)..where(
              (row) =>
                  row.localUserId.equals(profile.id) &
                  row.endpointKey.equals(endpointKey) &
                  row.cloudUserId.equals(cloudUserId) &
                  row.status.equals('active'),
            ))
            .getSingleOrNull();
    if (binding == null) throw const AccountScopeMismatchException();
    return _VerificationContext(
      session: session,
      endpointKey: endpointKey,
      profile: profile,
      binding: binding,
    );
  }

  Future<List<LegacyOwnershipEvidence>> _collectEvidence(
    _VerificationContext context,
  ) async {
    final installation = await _database
        .select(_database.installationInfo)
        .getSingle();
    final result = <LegacyOwnershipEvidence>[];
    final profileVersion = context.profile.serverVersion;
    if (profileVersion != null && profileVersion > 0) {
      result.add(
        _evidence(
          tableName: 'user_profiles',
          recordId: SyncRecordKeys.profile,
          serverVersion: profileVersion,
          updatedAt: context.profile.updatedAt,
          deletedAt: context.profile.deletedAt,
          originDeviceId:
              context.profile.originDeviceId ?? installation.installationId,
        ),
      );
    }
    final goals =
        await (_database.select(_database.goals)
              ..where((row) => row.userId.equals(context.profile.id))
              ..orderBy([(row) => OrderingTerm.asc(row.id)]))
            .get();
    for (final goal in goals) {
      final version = goal.serverVersion;
      if (version == null || version <= 0) continue;
      result.add(
        _evidence(
          tableName: 'goals',
          recordId: goal.id,
          serverVersion: version,
          updatedAt: goal.updatedAt,
          deletedAt: goal.deletedAt,
          originDeviceId: goal.originDeviceId ?? installation.installationId,
        ),
      );
    }
    return result;
  }

  LegacyOwnershipEvidence _evidence({
    required String tableName,
    required String recordId,
    required int serverVersion,
    required int updatedAt,
    required int? deletedAt,
    required String originDeviceId,
  }) {
    final canonical = jsonEncode(<String, Object?>{
      'deleted_at': deletedAt,
      'origin_device_id': originDeviceId,
      'record_id': recordId,
      'server_version': serverVersion,
      'table': tableName,
      'updated_at': updatedAt,
    });
    return LegacyOwnershipEvidence(
      tableName: tableName,
      recordId: recordId,
      serverVersion: serverVersion,
      metadataFingerprint: sha256.convert(utf8.encode(canonical)).toString(),
    );
  }

  Future<void> _persistResult(
    _VerificationContext expected,
    LegacyOwnershipVerificationResult result,
  ) {
    return _database.transaction(() async {
      final activeProfile =
          await (_database.select(_database.userProfiles)..where(
                (row) =>
                    row.id.equals(expected.profile.id) &
                    row.isActive.equals(true) &
                    row.deletedAt.isNull(),
              ))
              .getSingleOrNull();
      final binding =
          await (_database.select(_database.cloudAccountBindings)..where(
                (row) =>
                    row.id.equals(expected.binding.id) &
                    row.localUserId.equals(expected.profile.id) &
                    row.endpointKey.equals(expected.endpointKey) &
                    row.cloudUserId.equals(expected.session.user.id) &
                    row.status.equals('active'),
              ))
              .getSingleOrNull();
      if (activeProfile == null || binding == null) {
        throw const AccountScopeMismatchException('验证完成前账号数据空间已变化，结果未保存。');
      }
      final now = _dateTimeService.currentSnapshot().utcMilliseconds;
      final verified = result.isVerified;
      final status = switch (result.outcome) {
        LegacyOwnershipVerificationOutcome.verified => 'verified',
        LegacyOwnershipVerificationOutcome.unknown => 'not_verified',
        LegacyOwnershipVerificationOutcome.rejected => 'failed',
      };
      await (_database.update(
        _database.cloudAccountBindings,
      )..where((row) => row.id.equals(binding.id))).write(
        CloudAccountBindingsCompanion(
          syncEligibilityStatus: Value(
            verified ? 'ready' : 'legacy_review_required',
          ),
          verificationStatus: Value(status),
          verificationTime: Value(now),
          verificationMethod: const Value('server_sync_metadata_v1'),
          verificationReason: Value(result.reason.wireValue),
        ),
      );
    });
  }

  Future<AuthSession> _requireSession() async {
    final session = await _sessionStore.read();
    if (session == null || session.accessToken.trim().isEmpty) {
      throw const AccountSessionRejectedException('登录会话已失效，请重新登录。');
    }
    return session;
  }

  bool _sameSessionScope(AuthSession left, AuthSession right) {
    return left.accessToken == right.accessToken &&
        left.user.id == right.user.id &&
        _normalizeEndpoint(left.serverBaseUrl) ==
            _normalizeEndpoint(right.serverBaseUrl);
  }

  String _normalizeEndpoint(String endpoint) {
    try {
      return _endpointValidator.normalize(endpoint);
    } on FormatException {
      throw const AccountSessionRejectedException();
    }
  }
}

final class _VerificationContext {
  const _VerificationContext({
    required this.session,
    required this.endpointKey,
    required this.profile,
    required this.binding,
  });

  final AuthSession session;
  final String endpointKey;
  final UserProfile profile;
  final CloudAccountBindingRow binding;
}
