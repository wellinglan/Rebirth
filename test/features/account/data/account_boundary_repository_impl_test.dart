import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart';
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
