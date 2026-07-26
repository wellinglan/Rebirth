import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/database/daos/bootstrap_dao.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/account/data/account_boundary_repository_impl.dart';
import 'package:rebirth/features/account/domain/account_boundary.dart';
import 'package:rebirth/features/account/domain/auth_session.dart';
import 'package:rebirth/features/account/domain/auth_user.dart';

void main() {
  late AppDatabase database;
  late AccountBoundaryRepositoryImpl repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = AccountBoundaryRepositoryImpl(
      database: database,
      dateTimeService: DateTimeService(
        now: () => DateTime.utc(2030, 1, 2, 3, 4, 5),
      ),
      platform: 'windows',
    );
  });

  tearDown(() => database.close());

  test('fresh account creates and activates its bound local profile', () async {
    final result = await repository.resolveAndActivate(_session('account-a'));

    expect(result.isActivated, isTrue);
    final profiles = await database.select(database.userProfiles).get();
    final bindings = await database.select(database.cloudAccountBindings).get();
    final installation = await database
        .select(database.installationInfo)
        .getSingle();
    expect(profiles, hasLength(1));
    expect(profiles.single.id, result.localUserId);
    expect(profiles.single.isActive, isTrue);
    expect(bindings, hasLength(1));
    expect(bindings.single.localUserId, profiles.single.id);
    expect(bindings.single.cloudUserId, 'account-a');
    expect(bindings.single.endpointKey, _endpoint);
    expect(bindings.single.bindingOrigin, 'clean_first_login');
    expect(bindings.single.syncEligibilityStatus, 'ready');
    expect(bindings.single.ownershipConfirmedAt, isNotNull);
    expect(installation.platform, 'windows');
  });

  test(
    'account A and B use different profiles and switch back safely',
    () async {
      final accountA = await repository.resolveAndActivate(
        _session('account-a'),
      );
      final installationA = await database
          .select(database.installationInfo)
          .getSingle();
      await database
          .into(database.goals)
          .insert(
            GoalsCompanion.insert(
              userId: accountA.localUserId!,
              title: 'Account A goal',
              goalLevel: 'month',
              originDeviceId: Value(installationA.installationId),
            ),
          );

      await repository.deactivateAllProfiles();
      final accountB = await repository.resolveAndActivate(
        _session('account-b'),
      );

      expect(accountB.localUserId, isNot(accountA.localUserId));
      expect(
        await repository.requireActiveScope(
          endpoint: _endpoint,
          cloudUserId: 'account-b',
        ),
        accountB.localUserId,
      );
      final visibleToB = await (database.select(
        database.goals,
      )..where((row) => row.userId.equals(accountB.localUserId!))).get();
      expect(visibleToB, isEmpty);
      await expectLater(
        repository.requireActiveScope(
          endpoint: _endpoint,
          cloudUserId: 'account-a',
        ),
        throwsA(isA<AccountScopeMismatchException>()),
      );

      await repository.deactivateAllProfiles();
      final restoredA = await repository.resolveAndActivate(
        _session('account-a'),
      );
      expect(restoredA.localUserId, accountA.localUserId);
      final restoredGoals = await (database.select(
        database.goals,
      )..where((row) => row.userId.equals(restoredA.localUserId!))).get();
      expect(restoredGoals.single.title, 'Account A goal');

      final settings = await database.select(database.appSettings).get();
      expect(settings.map((row) => row.localInstallationId).toSet(), {
        installationA.installationId,
      });
    },
  );

  test('legacy unbound profile requires explicit migration', () async {
    final legacy = await database.bootstrapDao.bootstrap(
      createUnboundProfile: true,
    );

    final result = await repository.resolveAndActivate(_session('account-a'));

    expect(result.status, AccountBindingResolutionStatus.bindingRequired);
    expect(result.unboundProfileCount, 1);
    expect(await database.select(database.cloudAccountBindings).get(), isEmpty);
    final stored = await database.select(database.userProfiles).getSingle();
    expect(stored.id, legacy.activeUserId);
    expect(stored.isActive, isFalse);
  });

  test('cloud scope and local profile bindings are unique', () async {
    final accountA = await repository.resolveAndActivate(_session('account-a'));
    final now = DateTime.utc(2030, 1, 2, 3, 4, 5).millisecondsSinceEpoch;

    await expectLater(
      database
          .into(database.cloudAccountBindings)
          .insert(
            CloudAccountBindingsCompanion.insert(
              localUserId: accountA.localUserId!,
              endpointKey: _endpoint,
              cloudUserId: 'account-other',
              createdAt: now,
              lastUsedAt: now,
            ),
          ),
      throwsA(isA<Exception>()),
    );
  });

  test('endpoint mismatch is rejected before sync work', () async {
    await repository.resolveAndActivate(_session('account-a'));

    await expectLater(
      repository.requireActiveScope(
        endpoint: 'https://other.example.test',
        cloudUserId: 'account-a',
      ),
      throwsA(isA<AccountScopeMismatchException>()),
    );
  });

  test(
    'legacy summary exposes counts and flags without private content',
    () async {
      final legacy = await _seedLegacySpace(database);

      final candidates = await repository.listLegacyDataSpaces();

      expect(candidates, hasLength(1));
      final summary = candidates.single.summary;
      expect(summary.displayLabel, '本地数据空间 1');
      expect(summary.todayCount, 1);
      expect(summary.journalCount, 1);
      expect(summary.goalCount, 1);
      expect(summary.healthCount, 1);
      expect(summary.aiReportCount, 1);
      expect(summary.tombstoneCount, 1);
      expect(summary.hasSyncHistory, isTrue);
      expect(summary.hasConflictHistory, isTrue);
      expect(summary.hasAiPending, isTrue);
      expect(summary.selectionKey, isNot(legacy.activeUserId));
      expect(summary.toString(), isNot(contains('private journal body')));
      expect(summary.toString(), isNot(contains('private goal title')));
    },
  );

  test(
    'claiming legacy space persists ownership and quarantines cloud sync',
    () async {
      final legacy = await _seedLegacySpace(database);
      final beforeGoal = await database.select(database.goals).getSingle();
      final beforeConflict = await database
          .select(database.syncConflicts)
          .getSingle();
      final beforeAi = await database.select(database.aiReports).getSingle();
      final pending = await repository.resolveAndActivate(
        _session('account-a'),
      );

      final claimed = await repository.claimLegacyDataSpace(
        session: _session('account-a'),
        expectedScope: pending.accountScope!,
        localUserId: legacy.activeUserId,
      );

      expect(claimed.localUserId, legacy.activeUserId);
      expect(
        claimed.syncEligibility,
        AccountSyncEligibility.legacyReviewRequired,
      );
      final binding = await database
          .select(database.cloudAccountBindings)
          .getSingle();
      expect(binding.bindingOrigin, 'legacy_claim');
      expect(binding.syncEligibilityStatus, 'legacy_review_required');
      expect(binding.ownershipConfirmedAt, isNotNull);
      expect(
        repository.requireActiveScope(
          endpoint: _endpoint,
          cloudUserId: 'account-a',
        ),
        throwsA(isA<AccountSyncReviewRequiredException>()),
      );
      final afterGoal = await database.select(database.goals).getSingle();
      final afterConflict = await database
          .select(database.syncConflicts)
          .getSingle();
      final afterAi = await database.select(database.aiReports).getSingle();
      expect(afterGoal.serverVersion, beforeGoal.serverVersion);
      expect(afterGoal.lastSyncedAt, beforeGoal.lastSyncedAt);
      expect(afterGoal.syncStatus, beforeGoal.syncStatus);
      expect(afterGoal.deletedAt, beforeGoal.deletedAt);
      expect(afterConflict, beforeConflict);
      expect(afterAi, beforeAi);
      expect(await repository.listLegacyDataSpaces(), isEmpty);

      final repeated = await repository.claimLegacyDataSpace(
        session: _session('account-a'),
        expectedScope: pending.accountScope!,
        localUserId: legacy.activeUserId,
      );
      expect(repeated.localUserId, legacy.activeUserId);
      expect(
        await database.select(database.cloudAccountBindings).get(),
        hasLength(1),
      );
      expect(await database.select(database.userProfiles).get(), hasLength(1));
    },
  );

  test('fresh space preserves legacy data and is idempotent', () async {
    final legacy = await _seedLegacySpace(database);
    final pending = await repository.resolveAndActivate(_session('account-b'));

    final fresh = await repository.createFreshDataSpace(
      session: _session('account-b'),
      expectedScope: pending.accountScope!,
    );

    expect(fresh.localUserId, isNot(legacy.activeUserId));
    expect(fresh.syncEligibility, AccountSyncEligibility.ready);
    final profiles = await database.select(database.userProfiles).get();
    expect(profiles, hasLength(2));
    expect(
      profiles.singleWhere((row) => row.id == legacy.activeUserId).isActive,
      isFalse,
    );
    expect(
      profiles.singleWhere((row) => row.id == fresh.localUserId).isActive,
      isTrue,
    );
    final binding = await database
        .select(database.cloudAccountBindings)
        .getSingle();
    expect(binding.bindingOrigin, 'fresh_space');
    expect(binding.syncEligibilityStatus, 'ready');
    expect(
      await (database.select(
        database.goals,
      )..where((row) => row.userId.equals(fresh.localUserId!))).get(),
      isEmpty,
    );
    expect(
      await (database.select(
        database.goals,
      )..where((row) => row.userId.equals(legacy.activeUserId))).get(),
      hasLength(1),
    );

    final repeated = await repository.createFreshDataSpace(
      session: _session('account-b'),
      expectedScope: pending.accountScope!,
    );
    expect(repeated.localUserId, fresh.localUserId);
    expect(await database.select(database.userProfiles).get(), hasLength(2));
    expect(
      await database.select(database.cloudAccountBindings).get(),
      hasLength(1),
    );
  });

  test('ownership confirmation rejects a changed account scope', () async {
    final legacy = await database.bootstrapDao.bootstrap(
      createUnboundProfile: true,
    );
    final pending = await repository.resolveAndActivate(_session('account-a'));

    expect(
      () => repository.claimLegacyDataSpace(
        session: _session('account-b'),
        expectedScope: pending.accountScope!,
        localUserId: legacy.activeUserId,
      ),
      throwsA(isA<AccountSessionRejectedException>()),
    );
    expect(await database.select(database.cloudAccountBindings).get(), isEmpty);
  });
}

AuthSession _session(String userId) {
  return AuthSession(
    accessToken: 'token-$userId',
    refreshToken: 'refresh-$userId',
    user: AuthUser(id: userId, displayName: userId),
    serverBaseUrl: _endpoint,
  );
}

const _endpoint = 'https://alpha.example.test';

Future<DatabaseBootstrapResult> _seedLegacySpace(AppDatabase database) async {
  final legacy = await database.bootstrapDao.bootstrap(
    createUnboundProfile: true,
  );
  const goalId = '10000000-0000-4000-8000-000000000001';
  await database
      .into(database.goals)
      .insert(
        GoalsCompanion.insert(
          id: const Value(goalId),
          userId: legacy.activeUserId,
          title: 'private goal title',
          goalLevel: 'month',
          syncStatus: const Value('conflict'),
          serverVersion: const Value(7),
          lastSyncedAt: const Value(700),
          createdAt: const Value(100),
          updatedAt: const Value(700),
          originDeviceId: Value(legacy.localInstallationId),
        ),
      );
  await database
      .into(database.todayRecords)
      .insert(
        TodayRecordsCompanion.insert(
          id: const Value('20000000-0000-4000-8000-000000000001'),
          userId: legacy.activeUserId,
          recordDate: '2029-12-31',
          timezoneOffsetMinutes: 0,
          createdAt: const Value(100),
          updatedAt: const Value(200),
        ),
      );
  await database
      .into(database.todayRecords)
      .insert(
        TodayRecordsCompanion.insert(
          id: const Value('20000000-0000-4000-8000-000000000002'),
          userId: legacy.activeUserId,
          recordDate: '2029-12-30',
          timezoneOffsetMinutes: 0,
          createdAt: const Value(100),
          updatedAt: const Value(300),
          deletedAt: const Value(300),
        ),
      );
  await database
      .into(database.journalEntries)
      .insert(
        JournalEntriesCompanion.insert(
          id: const Value('30000000-0000-4000-8000-000000000001'),
          userId: legacy.activeUserId,
          entryDate: '2029-12-31',
          timezoneOffsetMinutes: 0,
          learning: const Value('private journal body'),
          createdAt: const Value(100),
          updatedAt: const Value(400),
        ),
      );
  await database
      .into(database.healthRecords)
      .insert(
        HealthRecordsCompanion.insert(
          id: const Value('40000000-0000-4000-8000-000000000001'),
          userId: legacy.activeUserId,
          recordDate: '2029-12-31',
          timezoneOffsetMinutes: 0,
          createdAt: const Value(100),
          updatedAt: const Value(500),
        ),
      );
  await database
      .into(database.aiReports)
      .insert(
        AiReportsCompanion.insert(
          id: const Value('50000000-0000-4000-8000-000000000001'),
          userId: legacy.activeUserId,
          reportType: 'weekly_report',
          periodStartDate: '2029-12-25',
          periodEndDate: '2029-12-31',
          inputHash:
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          promptVersion: 'weekly-report-v1',
          reportStatus: const Value('pending'),
          requestedAt: 600,
          createdAt: const Value(100),
          updatedAt: const Value(600),
        ),
      );
  await database
      .into(database.syncConflicts)
      .insert(
        SyncConflictsCompanion.insert(
          id: const Value('60000000-0000-4000-8000-000000000001'),
          localUserId: legacy.activeUserId,
          endpointKey: _endpoint,
          cloudUserId: 'legacy-cloud-user',
          entityType: 'goals',
          recordId: goalId,
          localUpdatedAt: 700,
          localServerVersion: const Value(7),
          remoteOperation: 'upsert',
          remoteServerVersion: 8,
          detectedAt: 800,
          lastSeenAt: 800,
          resolutionStatus: 'unresolved',
        ),
      );
  return legacy;
}
