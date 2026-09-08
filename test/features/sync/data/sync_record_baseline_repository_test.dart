import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/features/sync/data/sync_record_baseline_repository_impl.dart';
import 'package:rebirth/features/sync/domain/conflict_reconciliation_service.dart';
import 'package:rebirth/features/sync/domain/sync_record_baseline.dart';

void main() {
  const service = ConflictReconciliationService();

  test('baseline persists across database and repository recreation', () async {
    final directory = await Directory.systemTemp.createTemp(
      'rebirth_sync_baseline_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File(
      '${directory.path}${Platform.pathSeparator}rebirth.sqlite',
    );
    final firstDatabase = AppDatabase.forTesting(NativeDatabase(file));
    final bootstrap = await firstDatabase.bootstrapDao.bootstrap(
      createUnboundProfile: true,
    );
    final firstRepository = SyncRecordBaselineRepositoryImpl(firstDatabase);
    final baseline = _baseline(
      localUserId: bootstrap.activeUserId,
      hash: service.hashCanonicalValue('private journal body'),
    );

    await firstRepository.write(baseline);
    await firstDatabase.close();

    final secondDatabase = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(secondDatabase.close);
    final restored = await SyncRecordBaselineRepositoryImpl(secondDatabase)
        .read(
          localUserId: bootstrap.activeUserId,
          entityType: baseline.entityType,
          recordId: baseline.recordId,
        );

    expect(restored?.baseServerVersion, 7);
    expect(restored?.groupHashes, baseline.groupHashes);
    final raw = await secondDatabase
        .select(secondDatabase.syncRecordBaselines)
        .getSingle();
    expect(raw.groupHashesJson, isNot(contains('private journal body')));
  });

  test('baseline keys are isolated by local account', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final first = await database.bootstrapDao.bootstrap(
      createUnboundProfile: true,
    );
    await (database.update(database.userProfiles)
          ..where((row) => row.id.equals(first.activeUserId)))
        .write(const UserProfilesCompanion(isActive: Value(false)));
    const secondUser = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
    await database
        .into(database.userProfiles)
        .insert(
          UserProfilesCompanion.insert(
            id: const Value(secondUser),
            timezoneId: 'Etc/UTC',
          ),
        );
    final repository = SyncRecordBaselineRepositoryImpl(database);
    await repository.write(
      _baseline(
        localUserId: first.activeUserId,
        hash: service.hashCanonicalValue('account-a'),
      ),
    );
    await repository.write(
      _baseline(
        localUserId: secondUser,
        hash: service.hashCanonicalValue('account-b'),
      ),
    );

    final accountA = await repository.read(
      localUserId: first.activeUserId,
      entityType: 'journal_entries',
      recordId: 'record-id',
    );
    final accountB = await repository.read(
      localUserId: secondUser,
      entityType: 'journal_entries',
      recordId: 'record-id',
    );

    expect(accountA?.groupHashes, isNot(accountB?.groupHashes));
  });

  test('empty tombstone baseline and explicit delete are supported', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final bootstrap = await database.bootstrapDao.bootstrap(
      createUnboundProfile: true,
    );
    final repository = SyncRecordBaselineRepositoryImpl(database);
    final baseline = SyncRecordBaseline(
      localUserId: bootstrap.activeUserId,
      entityType: 'goals',
      recordId: 'deleted-record',
      baseExists: true,
      baseServerVersion: 4,
      baseTombstone: true,
      groupHashes: const {},
      capturedAt: 10,
    );

    await repository.write(baseline);
    expect(
      await repository.read(
        localUserId: bootstrap.activeUserId,
        entityType: baseline.entityType,
        recordId: baseline.recordId,
      ),
      isNotNull,
    );

    await repository.delete(
      localUserId: bootstrap.activeUserId,
      entityType: baseline.entityType,
      recordId: baseline.recordId,
    );
    expect(
      await repository.read(
        localUserId: bootstrap.activeUserId,
        entityType: baseline.entityType,
        recordId: baseline.recordId,
      ),
      isNull,
    );
  });

  test('baseline write rolls back with its surrounding transaction', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final bootstrap = await database.bootstrapDao.bootstrap(
      createUnboundProfile: true,
    );
    final repository = SyncRecordBaselineRepositoryImpl(database);

    await expectLater(
      database.transaction(() async {
        await repository.write(
          _baseline(
            localUserId: bootstrap.activeUserId,
            hash: service.hashCanonicalValue('rollback'),
          ),
        );
        throw StateError('rollback');
      }),
      throwsStateError,
    );

    expect(await database.select(database.syncRecordBaselines).get(), isEmpty);
  });

  test('v15 database upgrades to v16 with an empty baseline table', () async {
    final directory = await Directory.systemTemp.createTemp(
      'rebirth_v15_baseline_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File(
      '${directory.path}${Platform.pathSeparator}rebirth.sqlite',
    );
    final oldDatabase = AppDatabase.forTesting(NativeDatabase(file));
    final bootstrap = await oldDatabase.bootstrapDao.bootstrap(
      createUnboundProfile: true,
    );
    await oldDatabase.customStatement('DROP TABLE sync_record_baselines');
    await oldDatabase.customStatement('PRAGMA user_version = 15');
    await oldDatabase.close();

    final migrated = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(migrated.close);
    expect(migrated.schemaVersion, 16);
    expect(await migrated.select(migrated.syncRecordBaselines).get(), isEmpty);
    expect(
      await (migrated.select(
        migrated.userProfiles,
      )..where((row) => row.id.equals(bootstrap.activeUserId))).getSingle(),
      isNotNull,
    );
  });
}

SyncRecordBaseline _baseline({
  required String localUserId,
  required String hash,
}) => SyncRecordBaseline(
  localUserId: localUserId,
  entityType: 'journal_entries',
  recordId: 'record-id',
  baseExists: true,
  baseServerVersion: 7,
  baseTombstone: false,
  groupHashes: {'content': hash},
  capturedAt: 11,
);
