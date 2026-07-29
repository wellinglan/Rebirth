import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/features/personal_data/data/providers/health_personal_data_provider.dart';
import 'package:rebirth/features/personal_data/data/providers/journal_personal_data_provider.dart';
import 'package:rebirth/features/personal_data/data/providers/plan_personal_data_provider.dart';
import 'package:rebirth/features/personal_data/data/providers/profile_personal_data_provider.dart';
import 'package:rebirth/features/personal_data/data/providers/today_personal_data_provider.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_fact.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_privacy.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_quality.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_query.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_value.dart';

void main() {
  late AppDatabase database;
  late String userA;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    userA = (await database.bootstrapDao.bootstrap(
      createUnboundProfile: true,
    )).activeUserId;
  });

  tearDown(() => database.close());

  group('ProfilePersonalDataProvider', () {
    test('returns privacy-safe current-account context only', () async {
      await (database.update(
        database.userProfiles,
      )..where((row) => row.id.equals(userA))).write(
        const UserProfilesCompanion(
          displayName: Value('Private Name'),
          growthFocus: Value('Private Focus'),
          syncStatus: Value('conflict'),
        ),
      );
      await _insertSecondUser(database);

      final contribution = await ProfilePersonalDataProvider(
        database: database,
        localUserId: userA,
      ).collect(_query());

      expect(contribution.items, hasLength(1));
      expect(contribution.quality.status, PersonalDataQualityStatus.conflicted);
      final output = _visibleText(contribution.items.single.facts);
      expect(output, isNot(contains('Private Name')));
      expect(output, isNot(contains('Private Focus')));
      expect(output, isNot(contains(userA)));
      expect(contribution.items.single.id.value, isNot(contains(userA)));
    });
  });

  group('PlanPersonalDataProvider', () {
    test(
      'uses bounded date overlap, excludes tombstones, and marks conflict',
      () async {
        await database.batch((batch) {
          batch.insertAll(database.goals, [
            _goal(
              id: _id(11),
              userId: userA,
              title: 'Active goal',
              startDate: '2026-07-01',
              targetDate: '2026-07-31',
              syncStatus: 'conflict',
            ),
            _goal(
              id: _id(12),
              userId: userA,
              title: 'Archived goal',
              archivedAt: _now,
            ),
            _goal(
              id: _id(13),
              userId: userA,
              title: 'Deleted goal',
              deletedAt: _now,
            ),
            _goal(
              id: _id(14),
              userId: userA,
              title: 'Future goal',
              startDate: '2026-08-01',
              targetDate: '2026-08-31',
            ),
          ]);
        });

        final contribution = await PlanPersonalDataProvider(
          database: database,
          localUserId: userA,
        ).collect(_query());

        expect(
          contribution.items.map((item) => item.title),
          unorderedEquals(['Active goal', 'Archived goal']),
        );
        expect(
          contribution.quality.status,
          PersonalDataQualityStatus.conflicted,
        );
        expect(
          contribution.items.every((item) => !item.id.value.contains(_id(11))),
          isTrue,
        );
      },
    );

    test(
      'applies the query result limit as structured partial quality',
      () async {
        await database.batch((batch) {
          batch.insertAll(database.goals, [
            _goal(id: _id(21), userId: userA, title: 'One'),
            _goal(id: _id(22), userId: userA, title: 'Two'),
          ]);
        });
        final contribution = await PlanPersonalDataProvider(
          database: database,
          localUserId: userA,
        ).collect(_query(maxItems: 1));

        expect(contribution.items, hasLength(1));
        expect(contribution.quality.status, PersonalDataQualityStatus.partial);
        expect(contribution.quality.reasonCode, 'result_limit_applied');
      },
    );
  });

  group('TodayPersonalDataProvider', () {
    test(
      'distinguishes zero from null and never exposes Health or notes',
      () async {
        await database
            .into(database.todayRecords)
            .insert(
              TodayRecordsCompanion.insert(
                id: Value(_id(31)),
                userId: userA,
                recordDate: '2026-07-29',
                timezoneOffsetMinutes: 480,
                researchMinutes: const Value(0),
                learningMinutes: const Value(null),
                dailyNote: const Value('private daily note'),
                createdAt: const Value(_now),
                updatedAt: const Value(_now),
              ),
            );
        await database
            .into(database.healthRecords)
            .insert(
              HealthRecordsCompanion.insert(
                id: Value(_id(32)),
                userId: userA,
                recordDate: '2026-07-29',
                timezoneOffsetMinutes: 480,
                note: const Value('private health note'),
                createdAt: const Value(_now),
                updatedAt: const Value(_now),
              ),
            );

        final contribution = await TodayPersonalDataProvider(
          database: database,
          localUserId: userA,
        ).collect(_query());
        final facts = contribution.items.single.facts;

        expect(
          _fact(facts, 'today.research_duration').value,
          isA<PersonalDataDurationValue>(),
        );
        expect(
          (_fact(facts, 'today.research_duration').value
                  as PersonalDataDurationValue)
              .minutes,
          0,
        );
        expect(
          facts.any((fact) => fact.key.value == 'today.learning_duration'),
          isFalse,
        );
        expect(_visibleText(facts), isNot(contains('private')));
        expect(
          facts.any((fact) => fact.key.value.startsWith('health.')),
          isFalse,
        );
      },
    );

    test(
      'missing Today remains empty and does not create a placeholder',
      () async {
        final before = await database.select(database.todayRecords).get();

        final contribution = await TodayPersonalDataProvider(
          database: database,
          localUserId: userA,
        ).collect(_query(localDate: '2026-07-28'));
        final after = await database.select(database.todayRecords).get();

        expect(contribution.items, isEmpty);
        expect(after.length, before.length);
      },
    );
  });

  group('JournalPersonalDataProvider', () {
    test(
      'returns metadata without reading body into the contribution',
      () async {
        const secret = 'journal body that must never enter the overview';
        await database
            .into(database.journalEntries)
            .insert(
              JournalEntriesCompanion.insert(
                id: Value(_id(41)),
                userId: userA,
                entryDate: '2026-07-29',
                timezoneOffsetMinutes: 480,
                mostImportantAccomplishment: const Value(secret),
                mostDrainingEvent: const Value(secret),
                createdAt: const Value(_now),
                updatedAt: const Value(_now),
              ),
            );

        final contribution = await JournalPersonalDataProvider(
          database: database,
          localUserId: userA,
        ).collect(_query());

        expect(contribution.items, hasLength(1));
        expect(contribution.sensitivity, PersonalDataSensitivity.sensitive);
        expect(
          _visibleText(contribution.items.single.facts),
          isNot(contains(secret)),
        );
        expect(contribution.items.single.title, isNot(contains(secret)));
      },
    );
  });

  group('HealthPersonalDataProvider', () {
    test(
      'works without Today and preserves null versus zero privately',
      () async {
        await database
            .into(database.healthRecords)
            .insert(
              HealthRecordsCompanion.insert(
                id: Value(_id(51)),
                userId: userA,
                recordDate: '2026-07-29',
                timezoneOffsetMinutes: 480,
                sleepDurationMinutes: const Value(null),
                exerciseDurationMinutes: const Value(0),
                note: const Value('private health note'),
                createdAt: const Value(_now),
                updatedAt: const Value(_now),
              ),
            );

        final contribution = await HealthPersonalDataProvider(
          database: database,
          localUserId: userA,
        ).collect(_query());
        final facts = contribution.items.single.facts;

        expect(
          contribution.sensitivity,
          PersonalDataSensitivity.highlySensitive,
        );
        expect(
          facts.any((fact) => fact.key.value == 'health.sleep_duration'),
          isFalse,
        );
        expect(
          (_fact(facts, 'health.exercise_duration').value
                  as PersonalDataDurationValue)
              .minutes,
          0,
        );
        expect(_visibleText(facts), isNot(contains('private health note')));
        expect(
          facts.any((fact) => fact.key.value.contains('today_record')),
          isFalse,
        );
      },
    );
  });

  test('account-scoped providers never include another local user', () async {
    final userB = await _insertSecondUser(database);
    await database.batch((batch) {
      batch.insertAll(database.todayRecords, [
        TodayRecordsCompanion.insert(
          id: Value(_id(61)),
          userId: userA,
          recordDate: '2026-07-29',
          timezoneOffsetMinutes: 480,
          createdAt: const Value(_now),
          updatedAt: const Value(_now),
        ),
        TodayRecordsCompanion.insert(
          id: Value(_id(62)),
          userId: userB,
          recordDate: '2026-07-29',
          timezoneOffsetMinutes: 480,
          createdAt: const Value(_now),
          updatedAt: const Value(_now),
        ),
      ]);
    });

    final accountA = await TodayPersonalDataProvider(
      database: database,
      localUserId: userA,
    ).collect(_query());
    final accountB = await TodayPersonalDataProvider(
      database: database,
      localUserId: userB,
    ).collect(_query());

    expect(accountA.items, hasLength(1));
    expect(accountB.items, hasLength(1));
    expect(accountA.items.single.id, isNot(accountB.items.single.id));
  });
}

const _now = 1785294000000;

PersonalDataQuery _query({String localDate = '2026-07-29', int maxItems = 50}) {
  return PersonalDataQuery.daily(
    localDate: localDate,
    requestedAtUtc: DateTime.utc(2026, 7, 29, 3),
    maxItemsPerProvider: maxItems,
  );
}

GoalsCompanion _goal({
  required String id,
  required String userId,
  required String title,
  String? startDate,
  String? targetDate,
  int? archivedAt,
  int? deletedAt,
  String syncStatus = 'local_only',
}) {
  return GoalsCompanion.insert(
    id: Value(id),
    userId: userId,
    title: title,
    goalLevel: 'month',
    startDate: Value(startDate),
    targetDate: Value(targetDate),
    archivedAt: Value(archivedAt),
    deletedAt: Value(deletedAt),
    syncStatus: Value(syncStatus),
    createdAt: const Value(_now),
    updatedAt: const Value(_now),
  );
}

Future<String> _insertSecondUser(AppDatabase database) async {
  final id = _id(2);
  await database
      .into(database.userProfiles)
      .insertOnConflictUpdate(
        UserProfilesCompanion.insert(
          id: Value(id),
          timezoneId: 'Etc/UTC',
          isActive: const Value(false),
          createdAt: const Value(_now),
          updatedAt: const Value(_now),
        ),
      );
  return id;
}

String _id(int value) =>
    '00000000-0000-4000-8000-${value.toString().padLeft(12, '0')}';

PersonalDataFact _fact(List<PersonalDataFact> facts, String key) {
  return facts.singleWhere((fact) => fact.key.value == key);
}

String _visibleText(List<PersonalDataFact> facts) {
  return facts
      .map((fact) {
        final value = fact.value;
        return switch (value) {
          PersonalDataTextValue(:final value) => value,
          PersonalDataCategoricalValue(:final value) => value,
          _ => '',
        };
      })
      .join(' ');
}
