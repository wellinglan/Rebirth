import 'package:drift/drift.dart';
import 'package:rebirth/core/config/server_endpoint_validator.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/account/domain/account_boundary.dart';
import 'package:rebirth/features/account/domain/account_boundary_repository.dart';
import 'package:rebirth/features/account/domain/auth_session.dart';
import 'package:uuid/uuid.dart';

final class AccountBoundaryRepositoryImpl implements AccountBoundaryRepository {
  const AccountBoundaryRepositoryImpl({
    required AppDatabase database,
    required DateTimeService dateTimeService,
    required String platform,
    ServerEndpointValidator endpointValidator = const ServerEndpointValidator(),
    Uuid uuid = const Uuid(),
  }) : this._(database, dateTimeService, platform, endpointValidator, uuid);

  const AccountBoundaryRepositoryImpl._(
    this._database,
    this._dateTimeService,
    this._platform,
    this._endpointValidator,
    this._uuid,
  );

  final AppDatabase _database;
  final DateTimeService _dateTimeService;
  final String _platform;
  final ServerEndpointValidator _endpointValidator;
  final Uuid _uuid;

  @override
  Future<InstallationInfoRow> ensureInstallation() {
    return _database.transaction(_ensureInstallationInTransaction);
  }

  @override
  Future<AccountBindingResolution> resolveAndActivate(AuthSession session) {
    final scope = _scopeForSession(session);

    return _database.transaction(() async {
      final now = _dateTimeService.currentSnapshot().utcMilliseconds;
      final installation = await _ensureInstallationInTransaction();
      final existingBinding = await _bindingForScope(scope);

      if (existingBinding != null) {
        return _activateExistingBinding(
          existingBinding,
          scope: scope,
          installationId: installation.installationId,
          now: now,
        );
      }

      final profiles = await (_database.select(
        _database.userProfiles,
      )..where((row) => row.deletedAt.isNull())).get();
      final bindings = await _database
          .select(_database.cloudAccountBindings)
          .get();
      final boundProfileIds = bindings
          .map((binding) => binding.localUserId)
          .toSet();
      final unboundProfiles = profiles
          .where((profile) => !boundProfileIds.contains(profile.id))
          .toList(growable: false);
      if (unboundProfiles.isNotEmpty) {
        await _deactivateAllProfilesInTransaction();
        return AccountBindingResolution.bindingRequired(
          unboundProfileCount: unboundProfiles.length,
          accountScope: scope,
        );
      }

      return _createBoundProfile(
        scope: scope,
        installationId: installation.installationId,
        now: now,
        origin: AccountBindingOrigin.cleanFirstLogin,
      );
    });
  }

  @override
  Future<List<LegacyLocalDataSpaceCandidate>> listLegacyDataSpaces() async {
    final profiles =
        await (_database.select(_database.userProfiles)
              ..where((row) => row.deletedAt.isNull())
              ..orderBy([
                (row) => OrderingTerm.asc(row.createdAt),
                (row) => OrderingTerm.asc(row.id),
              ]))
            .get();
    final boundIds =
        (await _database.select(_database.cloudAccountBindings).get())
            .map((row) => row.localUserId)
            .toSet();
    final unbound = profiles
        .where((profile) => !boundIds.contains(profile.id))
        .toList(growable: false);
    final result = <LegacyLocalDataSpaceCandidate>[];
    for (var index = 0; index < unbound.length; index += 1) {
      final profile = unbound[index];
      final aggregate = await _legacyAggregate(profile.id);
      result.add(
        LegacyLocalDataSpaceCandidate(
          localUserId: profile.id,
          summary: LegacyLocalDataSpaceSummary(
            selectionKey: 'local-space-${index + 1}',
            displayIndex: index + 1,
            profileCreatedDate: _dateTimeService.formatLocalDate(
              DateTime.fromMillisecondsSinceEpoch(profile.createdAt),
            ),
            latestBusinessUpdatedAt: aggregate.latestBusinessUpdatedAt,
            todayCount: aggregate.todayCount,
            journalCount: aggregate.journalCount,
            goalCount: aggregate.goalCount,
            healthCount: aggregate.healthCount,
            aiReportCount: aggregate.aiReportCount,
            tombstoneCount: aggregate.tombstoneCount,
            hasSyncHistory: aggregate.hasSyncHistory,
            hasConflictHistory: aggregate.hasConflictHistory,
            hasAiPending: aggregate.hasAiPending,
            isAlreadyBound: false,
          ),
        ),
      );
    }
    return List.unmodifiable(result);
  }

  @override
  Future<AccountBindingResolution> claimLegacyDataSpace({
    required AuthSession session,
    required CloudAccountScope expectedScope,
    required String localUserId,
  }) {
    final scope = _scopeForSession(session);
    if (!scope.matches(expectedScope)) {
      throw const AccountSessionRejectedException('确认期间登录账号或服务器已变化，请重新操作。');
    }
    return _database.transaction(() async {
      final now = _dateTimeService.currentSnapshot().utcMilliseconds;
      final installation = await _ensureInstallationInTransaction();
      final existingBinding = await _bindingForScope(scope);
      if (existingBinding != null) {
        return _activateExistingBinding(
          existingBinding,
          scope: scope,
          installationId: installation.installationId,
          now: now,
        );
      }
      final profile =
          await (_database.select(_database.userProfiles)..where(
                (row) => row.id.equals(localUserId) & row.deletedAt.isNull(),
              ))
              .getSingleOrNull();
      if (profile == null) {
        throw const AccountScopeMismatchException('所选本地数据空间已不可用，请刷新后重试。');
      }
      final occupied = await (_database.select(
        _database.cloudAccountBindings,
      )..where((row) => row.localUserId.equals(localUserId))).getSingleOrNull();
      if (occupied != null) {
        throw const AccountScopeMismatchException('所选本地数据空间已归属其他账号。');
      }
      await _activateProfile(localUserId);
      await _ensureSettings(localUserId, installation.installationId);
      await _insertBinding(
        localUserId: localUserId,
        scope: scope,
        now: now,
        origin: AccountBindingOrigin.legacyClaim,
        eligibility: AccountSyncEligibility.legacyReviewRequired,
      );
      return AccountBindingResolution.activated(
        localUserId: localUserId,
        accountScope: scope,
        syncEligibility: AccountSyncEligibility.legacyReviewRequired,
      );
    });
  }

  @override
  Future<AccountBindingResolution> createFreshDataSpace({
    required AuthSession session,
    required CloudAccountScope expectedScope,
  }) {
    final scope = _scopeForSession(session);
    if (!scope.matches(expectedScope)) {
      throw const AccountSessionRejectedException('确认期间登录账号或服务器已变化，请重新操作。');
    }
    return _database.transaction(() async {
      final now = _dateTimeService.currentSnapshot().utcMilliseconds;
      final installation = await _ensureInstallationInTransaction();
      final existingBinding = await _bindingForScope(scope);
      if (existingBinding != null) {
        return _activateExistingBinding(
          existingBinding,
          scope: scope,
          installationId: installation.installationId,
          now: now,
        );
      }
      return _createBoundProfile(
        scope: scope,
        installationId: installation.installationId,
        now: now,
        origin: AccountBindingOrigin.freshSpace,
      );
    });
  }

  @override
  Future<void> deactivateAllProfiles() {
    return _database.transaction(_deactivateAllProfilesInTransaction);
  }

  @override
  Future<String> requireActiveScope({
    required String endpoint,
    required String cloudUserId,
  }) async {
    final normalizedEndpoint = _endpointValidator.normalize(endpoint);
    final normalizedCloudUserId = cloudUserId.trim();
    if (normalizedCloudUserId.isEmpty) {
      throw const AccountScopeMismatchException();
    }
    final activeProfiles =
        await (_database.select(_database.userProfiles)..where(
              (row) => row.isActive.equals(true) & row.deletedAt.isNull(),
            ))
            .get();
    if (activeProfiles.length != 1) {
      throw const AccountScopeMismatchException();
    }
    final activeUserId = activeProfiles.single.id;
    final binding =
        await (_database.select(_database.cloudAccountBindings)..where(
              (row) =>
                  row.localUserId.equals(activeUserId) &
                  row.endpointKey.equals(normalizedEndpoint) &
                  row.cloudUserId.equals(normalizedCloudUserId) &
                  row.status.equals('active'),
            ))
            .getSingleOrNull();
    if (binding == null) throw const AccountScopeMismatchException();
    final eligibility = AccountSyncEligibility.fromWire(
      binding.syncEligibilityStatus,
    );
    if (eligibility == AccountSyncEligibility.legacyReviewRequired) {
      throw const AccountSyncReviewRequiredException();
    }
    return activeUserId;
  }

  CloudAccountScope _scopeForSession(AuthSession session) {
    final cloudUserId = session.user.id.trim();
    if (cloudUserId.isEmpty) {
      throw const AccountSessionRejectedException('当前登录会话缺少云账号身份，请重新登录。');
    }
    return CloudAccountScope(
      endpointKey: _normalizeSessionEndpoint(session),
      cloudUserId: cloudUserId,
    );
  }

  String _normalizeSessionEndpoint(AuthSession session) {
    final endpoint = session.serverBaseUrl.trim();
    if (endpoint.isEmpty) throw const AccountSessionRejectedException();
    try {
      return _endpointValidator.normalize(endpoint);
    } on FormatException {
      throw const AccountSessionRejectedException();
    }
  }

  Future<InstallationInfoRow> _ensureInstallationInTransaction() async {
    final existing = await _database
        .select(_database.installationInfo)
        .getSingleOrNull();
    if (existing != null) return existing;

    final settings =
        await (_database.select(_database.appSettings)
              ..orderBy([(row) => OrderingTerm.asc(row.createdAt)])
              ..limit(1))
            .getSingleOrNull();
    final now = _dateTimeService.currentSnapshot().utcMilliseconds;
    final installationId = settings?.localInstallationId ?? _uuid.v4();
    await _database
        .into(_database.installationInfo)
        .insert(
          InstallationInfoCompanion.insert(
            installationId: installationId,
            createdAt: settings?.createdAt ?? now,
            platform: Value(_platform.trim().isEmpty ? null : _platform),
          ),
        );
    return _database.select(_database.installationInfo).getSingle();
  }

  Future<void> _activateProfile(String profileId) async {
    await _deactivateAllProfilesInTransaction();
    final affected =
        await (_database.update(_database.userProfiles)..where(
              (row) => row.id.equals(profileId) & row.deletedAt.isNull(),
            ))
            .write(const UserProfilesCompanion(isActive: Value(true)));
    if (affected != 1) {
      throw const AccountScopeMismatchException('无法激活账号对应的本地数据空间。');
    }
  }

  Future<CloudAccountBindingRow?> _bindingForScope(
    CloudAccountScope scope,
  ) async {
    final binding =
        await (_database.select(_database.cloudAccountBindings)..where(
              (row) =>
                  row.endpointKey.equals(scope.endpointKey) &
                  row.cloudUserId.equals(scope.cloudUserId),
            ))
            .getSingleOrNull();
    if (binding != null && binding.status != 'active') {
      throw const AccountSessionRejectedException('当前账号的数据空间绑定已停用。');
    }
    return binding;
  }

  Future<AccountBindingResolution> _activateExistingBinding(
    CloudAccountBindingRow binding, {
    required CloudAccountScope scope,
    required String installationId,
    required int now,
  }) async {
    final profile =
        await (_database.select(_database.userProfiles)..where(
              (row) =>
                  row.id.equals(binding.localUserId) & row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (profile == null) {
      throw const AccountScopeMismatchException('账号绑定的本地数据空间不可用，已停止登录。');
    }
    await _activateProfile(profile.id);
    await _ensureSettings(profile.id, installationId);
    await (_database.update(_database.cloudAccountBindings)
          ..where((row) => row.id.equals(binding.id)))
        .write(CloudAccountBindingsCompanion(lastUsedAt: Value(now)));
    return AccountBindingResolution.activated(
      localUserId: profile.id,
      accountScope: scope,
      syncEligibility: AccountSyncEligibility.fromWire(
        binding.syncEligibilityStatus,
      ),
    );
  }

  Future<AccountBindingResolution> _createBoundProfile({
    required CloudAccountScope scope,
    required String installationId,
    required int now,
    required AccountBindingOrigin origin,
  }) async {
    final profileId = _uuid.v4();
    final snapshot = _dateTimeService.currentSnapshot();
    final timezoneId = snapshot.now.timeZoneName.trim();
    await _deactivateAllProfilesInTransaction();
    await _database
        .into(_database.userProfiles)
        .insert(
          UserProfilesCompanion.insert(
            id: Value(profileId),
            timezoneId: timezoneId.isEmpty ? 'Etc/UTC' : timezoneId,
            isActive: const Value(true),
            createdAt: Value(now),
            updatedAt: Value(now),
            originDeviceId: Value(installationId),
          ),
        );
    await _ensureSettings(profileId, installationId);
    await _insertBinding(
      localUserId: profileId,
      scope: scope,
      now: now,
      origin: origin,
      eligibility: AccountSyncEligibility.ready,
    );
    return AccountBindingResolution.activated(
      localUserId: profileId,
      accountScope: scope,
      syncEligibility: AccountSyncEligibility.ready,
    );
  }

  Future<void> _insertBinding({
    required String localUserId,
    required CloudAccountScope scope,
    required int now,
    required AccountBindingOrigin origin,
    required AccountSyncEligibility eligibility,
  }) {
    return _database
        .into(_database.cloudAccountBindings)
        .insert(
          CloudAccountBindingsCompanion.insert(
            id: Value(_uuid.v4()),
            localUserId: localUserId,
            endpointKey: scope.endpointKey,
            cloudUserId: scope.cloudUserId,
            createdAt: now,
            lastUsedAt: now,
            bindingOrigin: Value(origin.wireValue),
            syncEligibilityStatus: Value(eligibility.wireValue),
            ownershipConfirmedAt: Value(now),
          ),
        );
  }

  Future<void> _deactivateAllProfilesInTransaction() async {
    await (_database.update(_database.userProfiles)
          ..where((row) => row.isActive.equals(true)))
        .write(const UserProfilesCompanion(isActive: Value(false)));
  }

  Future<void> _ensureSettings(
    String localUserId,
    String installationId,
  ) async {
    final existing = await (_database.select(
      _database.appSettings,
    )..where((row) => row.userId.equals(localUserId))).getSingleOrNull();
    if (existing != null) {
      if (existing.localInstallationId != installationId) {
        await (_database.update(
          _database.appSettings,
        )..where((row) => row.id.equals(existing.id))).write(
          AppSettingsCompanion(localInstallationId: Value(installationId)),
        );
      }
      return;
    }
    final now = _dateTimeService.currentSnapshot().utcMilliseconds;
    await _database
        .into(_database.appSettings)
        .insert(
          AppSettingsCompanion.insert(
            id: Value(_uuid.v4()),
            userId: localUserId,
            localInstallationId: installationId,
            createdAt: Value(now),
            updatedAt: Value(now),
            originDeviceId: Value(installationId),
          ),
        );
  }

  Future<_LegacyAggregate> _legacyAggregate(String localUserId) async {
    final row = await _database
        .customSelect(
          '''
SELECT
  (SELECT COUNT(*) FROM today_records WHERE user_id = ?1 AND deleted_at IS NULL) AS today_count,
  (SELECT COUNT(*) FROM journal_entries WHERE user_id = ?1 AND deleted_at IS NULL) AS journal_count,
  (SELECT COUNT(*) FROM goals WHERE user_id = ?1 AND deleted_at IS NULL) AS goal_count,
  (SELECT COUNT(*) FROM health_records WHERE user_id = ?1 AND deleted_at IS NULL) AS health_count,
  (SELECT COUNT(*) FROM ai_reports WHERE user_id = ?1 AND deleted_at IS NULL) AS ai_report_count,
  (
    (SELECT COUNT(*) FROM today_records WHERE user_id = ?1 AND deleted_at IS NOT NULL) +
    (SELECT COUNT(*) FROM journal_entries WHERE user_id = ?1 AND deleted_at IS NOT NULL) +
    (SELECT COUNT(*) FROM goals WHERE user_id = ?1 AND deleted_at IS NOT NULL) +
    (SELECT COUNT(*) FROM health_records WHERE user_id = ?1 AND deleted_at IS NOT NULL) +
    (SELECT COUNT(*) FROM ai_reports WHERE user_id = ?1 AND deleted_at IS NOT NULL)
  ) AS tombstone_count,
  (SELECT MAX(updated_at) FROM (
    SELECT updated_at FROM today_records WHERE user_id = ?1
    UNION ALL SELECT updated_at FROM journal_entries WHERE user_id = ?1
    UNION ALL SELECT updated_at FROM goals WHERE user_id = ?1
    UNION ALL SELECT updated_at FROM health_records WHERE user_id = ?1
    UNION ALL SELECT updated_at FROM ai_reports WHERE user_id = ?1
  )) AS latest_business_updated_at,
  (
    EXISTS(SELECT 1 FROM user_profiles WHERE id = ?1 AND
      (COALESCE(server_version, 0) > 0 OR last_synced_at IS NOT NULL OR sync_status IN ('synced', 'conflict'))) OR
    EXISTS(SELECT 1 FROM today_records WHERE user_id = ?1 AND
      (COALESCE(server_version, 0) > 0 OR last_synced_at IS NOT NULL OR sync_status IN ('synced', 'conflict'))) OR
    EXISTS(SELECT 1 FROM journal_entries WHERE user_id = ?1 AND
      (COALESCE(server_version, 0) > 0 OR last_synced_at IS NOT NULL OR sync_status IN ('synced', 'conflict'))) OR
    EXISTS(SELECT 1 FROM goals WHERE user_id = ?1 AND
      (COALESCE(server_version, 0) > 0 OR last_synced_at IS NOT NULL OR sync_status IN ('synced', 'conflict'))) OR
    EXISTS(SELECT 1 FROM health_records WHERE user_id = ?1 AND
      (COALESCE(server_version, 0) > 0 OR last_synced_at IS NOT NULL OR sync_status IN ('synced', 'conflict'))) OR
    EXISTS(SELECT 1 FROM ai_reports WHERE user_id = ?1 AND
      (COALESCE(server_version, 0) > 0 OR last_synced_at IS NOT NULL OR sync_status IN ('synced', 'conflict'))) OR
    EXISTS(SELECT 1 FROM sync_conflicts WHERE local_user_id = ?1)
  ) AS has_sync_history,
  EXISTS(SELECT 1 FROM sync_conflicts WHERE local_user_id = ?1) AS has_conflict_history,
  EXISTS(SELECT 1 FROM ai_reports WHERE user_id = ?1 AND deleted_at IS NULL
    AND report_status = 'pending') AS has_ai_pending
''',
          variables: [Variable.withString(localUserId)],
          readsFrom: {
            _database.userProfiles,
            _database.todayRecords,
            _database.journalEntries,
            _database.goals,
            _database.healthRecords,
            _database.aiReports,
            _database.syncConflicts,
          },
        )
        .getSingle();
    return _LegacyAggregate(
      todayCount: row.read<int>('today_count'),
      journalCount: row.read<int>('journal_count'),
      goalCount: row.read<int>('goal_count'),
      healthCount: row.read<int>('health_count'),
      aiReportCount: row.read<int>('ai_report_count'),
      tombstoneCount: row.read<int>('tombstone_count'),
      latestBusinessUpdatedAt: row.readNullable<int>(
        'latest_business_updated_at',
      ),
      hasSyncHistory: row.read<int>('has_sync_history') == 1,
      hasConflictHistory: row.read<int>('has_conflict_history') == 1,
      hasAiPending: row.read<int>('has_ai_pending') == 1,
    );
  }
}

final class _LegacyAggregate {
  const _LegacyAggregate({
    required this.todayCount,
    required this.journalCount,
    required this.goalCount,
    required this.healthCount,
    required this.aiReportCount,
    required this.tombstoneCount,
    required this.latestBusinessUpdatedAt,
    required this.hasSyncHistory,
    required this.hasConflictHistory,
    required this.hasAiPending,
  });

  final int todayCount;
  final int journalCount;
  final int goalCount;
  final int healthCount;
  final int aiReportCount;
  final int tombstoneCount;
  final int? latestBusinessUpdatedAt;
  final bool hasSyncHistory;
  final bool hasConflictHistory;
  final bool hasAiPending;
}
