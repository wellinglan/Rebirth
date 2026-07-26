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
    final endpointKey = _normalizeSessionEndpoint(session);
    final cloudUserId = session.user.id.trim();
    if (cloudUserId.isEmpty) {
      throw const AccountSessionRejectedException('当前登录会话缺少云账号身份，请重新登录。');
    }

    return _database.transaction(() async {
      final now = _dateTimeService.currentSnapshot().utcMilliseconds;
      final installation = await _ensureInstallationInTransaction();
      final existingBinding =
          await (_database.select(_database.cloudAccountBindings)..where(
                (row) =>
                    row.endpointKey.equals(endpointKey) &
                    row.cloudUserId.equals(cloudUserId) &
                    row.status.equals('active'),
              ))
              .getSingleOrNull();

      if (existingBinding != null) {
        final profile =
            await (_database.select(_database.userProfiles)..where(
                  (row) =>
                      row.id.equals(existingBinding.localUserId) &
                      row.deletedAt.isNull(),
                ))
                .getSingleOrNull();
        if (profile == null) {
          throw const AccountScopeMismatchException('账号绑定的本地数据空间不可用，已停止登录。');
        }
        await _activateProfile(profile.id);
        await _ensureSettings(profile.id, installation.installationId);
        await (_database.update(_database.cloudAccountBindings)
              ..where((row) => row.id.equals(existingBinding.id)))
            .write(CloudAccountBindingsCompanion(lastUsedAt: Value(now)));
        return AccountBindingResolution.activated(profile.id);
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
        return AccountBindingResolution.bindingRequired(unboundProfiles.length);
      }

      final profileId = _uuid.v4();
      await _deactivateAllProfilesInTransaction();
      await _database
          .into(_database.userProfiles)
          .insert(
            UserProfilesCompanion.insert(
              id: Value(profileId),
              timezoneId: 'Etc/UTC',
              isActive: const Value(true),
              createdAt: Value(now),
              updatedAt: Value(now),
              originDeviceId: Value(installation.installationId),
            ),
          );
      await _ensureSettings(profileId, installation.installationId);
      await _database
          .into(_database.cloudAccountBindings)
          .insert(
            CloudAccountBindingsCompanion.insert(
              id: Value(_uuid.v4()),
              localUserId: profileId,
              endpointKey: endpointKey,
              cloudUserId: cloudUserId,
              createdAt: now,
              lastUsedAt: now,
            ),
          );
      return AccountBindingResolution.activated(profileId);
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
    return activeUserId;
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
}
