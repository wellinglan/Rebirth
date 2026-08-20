import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/health/data/health_repository_impl.dart';
import 'package:rebirth/features/today/data/today_repository_impl.dart';

void main() {
  test('v2 to v13 preserves goals and adds current tables', () async {
    final fixture = await _createDatabaseFixture();
    addTearDown(fixture.dispose);
    final original = AppDatabase.forTesting(NativeDatabase(fixture.file));
    addTearDown(original.close);
    final bootstrap = await original.bootstrapDao.bootstrap(
      createUnboundProfile: true,
    );
    await original
        .into(original.goals)
        .insert(
          GoalsCompanion.insert(
            id: const Value('00000000-0000-4000-8000-000000000001'),
            userId: bootstrap.activeUserId,
            title: '迁移前目标',
            goalLevel: 'month',
            originDeviceId: Value(bootstrap.localInstallationId),
          ),
        );
    await _replaceGoalsWithVersionTwoDefinition(original);
    await original.close();

    final migrated = AppDatabase.forTesting(NativeDatabase(fixture.file));
    addTearDown(migrated.close);
    final version = await migrated
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 13);

    final goal =
        await (migrated.select(migrated.goals)..where(
              (row) => row.id.equals('00000000-0000-4000-8000-000000000001'),
            ))
            .getSingle();
    expect(goal.title, '迁移前目标');
    expect(goal.archivedAt, isNull);
    await _expectCoreTableSet(migrated);
  });

  test('v1 migration chain still preserves custom support and indexes', () async {
    final fixture = await _createDatabaseFixture();
    addTearDown(fixture.dispose);
    final original = AppDatabase.forTesting(NativeDatabase(fixture.file));
    addTearDown(original.close);
    final bootstrap = await original.bootstrapDao.bootstrap(
      createUnboundProfile: true,
    );
    await original
        .into(original.goals)
        .insert(
          GoalsCompanion.insert(
            id: const Value('00000000-0000-4000-8000-000000000011'),
            userId: bootstrap.activeUserId,
            title: 'v1 普通目标',
            goalLevel: 'year',
            originDeviceId: Value(bootstrap.localInstallationId),
          ),
        );
    await _replaceGoalsWithVersionOneDefinition(original);
    await original.close();

    final migrated = AppDatabase.forTesting(NativeDatabase(fixture.file));
    addTearDown(migrated.close);
    expect(migrated.schemaVersion, 13);
    final existing = await migrated.select(migrated.goals).getSingle();
    expect(existing.title, 'v1 普通目标');
    expect(existing.archivedAt, isNull);

    await migrated
        .into(migrated.goals)
        .insert(
          GoalsCompanion.insert(
            id: const Value('00000000-0000-4000-8000-000000000012'),
            userId: bootstrap.activeUserId,
            title: '自定义目标',
            goalLevel: 'custom',
            originDeviceId: Value(bootstrap.localInstallationId),
          ),
        );
    final indexes = await migrated
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = 'goals'",
        )
        .get();
    expect(
      indexes.map((row) => row.read<String>('name')).toSet(),
      containsAll(<String>{
        'goals_user_parent_sort_order',
        'goals_user_level_status',
        'goals_user_target_date',
      }),
    );
  });

  test('v3 to v13 preserves goals and creates conflict indexes', () async {
    final fixture = await _createDatabaseFixture();
    addTearDown(fixture.dispose);
    final original = AppDatabase.forTesting(NativeDatabase(fixture.file));
    final bootstrap = await original.bootstrapDao.bootstrap(
      createUnboundProfile: true,
    );
    await original
        .into(original.goals)
        .insert(
          GoalsCompanion.insert(
            id: const Value('00000000-0000-4000-8000-000000000021'),
            userId: bootstrap.activeUserId,
            title: '已有冲突目标',
            goalLevel: 'month',
            syncStatus: const Value('conflict'),
            serverVersion: const Value(4),
            originDeviceId: Value(bootstrap.localInstallationId),
          ),
        );
    await original.customStatement('DROP TABLE sync_conflicts');
    await original.customStatement('PRAGMA user_version = 3');
    await original.close();

    final migrated = AppDatabase.forTesting(NativeDatabase(fixture.file));
    addTearDown(migrated.close);
    final version = await migrated
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 13);
    final goal = await migrated.select(migrated.goals).getSingle();
    expect(goal.id, '00000000-0000-4000-8000-000000000021');
    expect(goal.syncStatus, 'conflict');
    expect(goal.serverVersion, 4);
    expect(await migrated.select(migrated.syncConflicts).get(), isEmpty);

    final indexes = await migrated
        .customSelect(
          "SELECT name FROM sqlite_master "
          "WHERE type = 'index' AND tbl_name = 'sync_conflicts'",
        )
        .get();
    expect(
      indexes.map((row) => row.read<String>('name')).toSet(),
      containsAll(<String>{
        'sync_conflicts_user_status_detected',
        'sync_conflicts_endpoint_user_entity',
        'sync_conflicts_entity_record',
        'sync_conflicts_one_active',
      }),
    );
  });

  test(
    'v4 to v13 preserves data and supersedes unhydrated legacy conflicts',
    () async {
      final fixture = await _createDatabaseFixture();
      addTearDown(fixture.dispose);
      final original = AppDatabase.forTesting(NativeDatabase(fixture.file));
      final bootstrap = await original.bootstrapDao.bootstrap(
        createUnboundProfile: true,
      );
      const goalId = '00000000-0000-4000-8000-000000000031';
      await original
          .into(original.goals)
          .insert(
            GoalsCompanion.insert(
              id: const Value(goalId),
              userId: bootstrap.activeUserId,
              title: 'v4 账号隔离迁移目标',
              goalLevel: 'month',
              syncStatus: const Value('conflict'),
              serverVersion: const Value(7),
              originDeviceId: Value(bootstrap.localInstallationId),
            ),
          );
      await original
          .into(original.syncConflicts)
          .insert(
            SyncConflictsCompanion.insert(
              id: const Value('00000000-0000-4000-8000-000000000032'),
              localUserId: bootstrap.activeUserId,
              endpointKey: 'https://alpha.example.test',
              cloudUserId: 'cloud-user-b',
              entityType: 'goals',
              recordId: goalId,
              localUpdatedAt: 100,
              localDeletedAt: const Value(100),
              localServerVersion: const Value(7),
              remoteOperation: 'unknown_pending_pull',
              remoteServerVersion: 0,
              detectedAt: 110,
              lastSeenAt: 120,
              resolutionStatus: 'awaiting_remote_snapshot',
            ),
          );
      await original.customStatement('DROP TABLE cloud_account_bindings');
      await original.customStatement('DROP TABLE installation_info');
      await original.customStatement('PRAGMA user_version = 4');
      await original.close();

      final migrated = AppDatabase.forTesting(NativeDatabase(fixture.file));
      addTearDown(migrated.close);
      expect(migrated.schemaVersion, 13);
      expect(await migrated.select(migrated.goals).get(), hasLength(1));
      expect(await migrated.select(migrated.userProfiles).get(), hasLength(1));
      expect(await migrated.select(migrated.appSettings).get(), hasLength(1));
      expect(
        await migrated.select(migrated.cloudAccountBindings).get(),
        isEmpty,
      );
      final installation = await migrated
          .select(migrated.installationInfo)
          .getSingle();
      expect(installation.installationId, bootstrap.localInstallationId);
      final conflict = await migrated
          .select(migrated.syncConflicts)
          .getSingle();
      expect(
        conflict.resolutionStatus,
        'superseded_by_account_isolation_migration',
      );
      expect(conflict.resolvedAt, 120);
      expect(conflict.localServerVersion, 7);
    },
  );

  test(
    'v5 to v13 backfills existing binding without claiming legacy data',
    () async {
      final fixture = await _createDatabaseFixture();
      addTearDown(fixture.dispose);
      final original = AppDatabase.forTesting(NativeDatabase(fixture.file));
      final bootstrap = await original.bootstrapDao.bootstrap(
        createUnboundProfile: true,
      );
      await original
          .into(original.cloudAccountBindings)
          .insert(
            CloudAccountBindingsCompanion.insert(
              id: const Value('70000000-0000-4000-8000-000000000001'),
              localUserId: bootstrap.activeUserId,
              endpointKey: 'https://alpha.example.test',
              cloudUserId: 'existing-cloud-user',
              createdAt: 100,
              lastUsedAt: 200,
              verificationTime: const Value(100),
              verificationMethod: const Value('account_space_creation'),
              verificationReason: const Value(
                'all_evidence_matches_current_user',
              ),
            ),
          );
      await original.customStatement(
        'DROP INDEX cloud_account_bindings_status_last_used',
      );
      await original.customStatement('''
CREATE TABLE cloud_account_bindings_v5 (
  id TEXT NOT NULL PRIMARY KEY,
  local_user_id TEXT NOT NULL REFERENCES user_profiles(id) ON DELETE RESTRICT,
  endpoint_key TEXT NOT NULL,
  cloud_user_id TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  last_used_at INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'active',
  UNIQUE(endpoint_key, cloud_user_id),
  UNIQUE(local_user_id),
  CHECK (length(trim(endpoint_key)) > 0),
  CHECK (length(trim(cloud_user_id)) > 0),
  CHECK (created_at >= 0),
  CHECK (last_used_at >= created_at),
  CHECK (status IN ('active', 'disabled'))
)
''');
      await original.customStatement(
        'INSERT INTO cloud_account_bindings_v5 '
        '(id, local_user_id, endpoint_key, cloud_user_id, created_at, '
        'last_used_at, status) '
        'SELECT id, local_user_id, endpoint_key, cloud_user_id, created_at, '
        'last_used_at, status FROM cloud_account_bindings',
      );
      await original.customStatement('DROP TABLE cloud_account_bindings');
      await original.customStatement(
        'ALTER TABLE cloud_account_bindings_v5 RENAME TO cloud_account_bindings',
      );
      await original.customStatement('PRAGMA user_version = 5');
      await original.close();

      final migrated = AppDatabase.forTesting(NativeDatabase(fixture.file));
      addTearDown(migrated.close);
      final binding = await migrated
          .select(migrated.cloudAccountBindings)
          .getSingle();
      expect(binding.bindingOrigin, 'clean_first_login');
      expect(binding.syncEligibilityStatus, 'ready');
      expect(binding.ownershipConfirmedAt, 100);
      expect(binding.verificationStatus, 'verified');
      expect(binding.verificationTime, 100);
      expect(binding.verificationMethod, 'account_space_creation');
      expect(binding.verificationReason, 'all_evidence_matches_current_user');
      expect(binding.localUserId, bootstrap.activeUserId);
      expect(await migrated.select(migrated.userProfiles).get(), hasLength(1));
      expect(
        await migrated.select(migrated.installationInfo).get(),
        hasLength(1),
      );

      await expectLater(
        migrated.customStatement(
          "UPDATE cloud_account_bindings SET binding_origin = 'invalid'",
        ),
        throwsA(isA<Exception>()),
      );
    },
  );

  test(
    'v6 to v13 preserves legacy quarantine and business sync metadata',
    () async {
      final fixture = await _createDatabaseFixture();
      addTearDown(fixture.dispose);
      final original = AppDatabase.forTesting(NativeDatabase(fixture.file));
      final bootstrap = await original.bootstrapDao.bootstrap(
        createUnboundProfile: true,
      );
      await (original.update(
        original.userProfiles,
      )..where((row) => row.id.equals(bootstrap.activeUserId))).write(
        const UserProfilesCompanion(
          syncStatus: Value('conflict'),
          serverVersion: Value(17),
          lastSyncedAt: Value(900),
        ),
      );
      await original
          .into(original.cloudAccountBindings)
          .insert(
            CloudAccountBindingsCompanion.insert(
              id: const Value('70000000-0000-4000-8000-000000000006'),
              localUserId: bootstrap.activeUserId,
              endpointKey: 'https://alpha.example.test',
              cloudUserId: 'legacy-cloud-user',
              createdAt: 100,
              lastUsedAt: 200,
              bindingOrigin: const Value('legacy_claim'),
              syncEligibilityStatus: const Value('legacy_review_required'),
              ownershipConfirmedAt: const Value(100),
              verificationStatus: const Value('not_verified'),
            ),
          );
      await original.customStatement(
        'DROP INDEX cloud_account_bindings_status_last_used',
      );
      await original.customStatement('''
CREATE TABLE cloud_account_bindings_v6 (
  id TEXT NOT NULL PRIMARY KEY,
  local_user_id TEXT NOT NULL REFERENCES user_profiles(id) ON DELETE RESTRICT,
  endpoint_key TEXT NOT NULL,
  cloud_user_id TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  last_used_at INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'active',
  binding_origin TEXT NOT NULL DEFAULT 'clean_first_login',
  sync_eligibility_status TEXT NOT NULL DEFAULT 'ready',
  ownership_confirmed_at INTEGER,
  UNIQUE(endpoint_key, cloud_user_id),
  UNIQUE(local_user_id)
)
''');
      await original.customStatement(
        'INSERT INTO cloud_account_bindings_v6 '
        '(id, local_user_id, endpoint_key, cloud_user_id, created_at, '
        'last_used_at, status, binding_origin, sync_eligibility_status, '
        'ownership_confirmed_at) '
        'SELECT id, local_user_id, endpoint_key, cloud_user_id, created_at, '
        'last_used_at, status, binding_origin, sync_eligibility_status, '
        'ownership_confirmed_at FROM cloud_account_bindings',
      );
      await original.customStatement('DROP TABLE cloud_account_bindings');
      await original.customStatement(
        'ALTER TABLE cloud_account_bindings_v6 '
        'RENAME TO cloud_account_bindings',
      );
      await original.customStatement('PRAGMA user_version = 6');
      await original.close();

      final migrated = AppDatabase.forTesting(NativeDatabase(fixture.file));
      addTearDown(migrated.close);
      final binding = await migrated
          .select(migrated.cloudAccountBindings)
          .getSingle();
      final profile = await migrated.select(migrated.userProfiles).getSingle();
      expect(migrated.schemaVersion, 13);
      expect(binding.syncEligibilityStatus, 'legacy_review_required');
      expect(binding.verificationStatus, 'not_verified');
      expect(binding.verificationTime, isNull);
      expect(binding.verificationMethod, isNull);
      expect(binding.verificationReason, isNull);
      expect(profile.serverVersion, 17);
      expect(profile.lastSyncedAt, 900);
      expect(profile.syncStatus, 'conflict');
    },
  );

  test('v7 to v13 adds nullable remote identity and prompt schema', () async {
    final fixture = await _createDatabaseFixture();
    addTearDown(fixture.dispose);
    final original = AppDatabase.forTesting(NativeDatabase(fixture.file));
    final bootstrap = await original.bootstrapDao.bootstrap(
      createUnboundProfile: true,
    );
    await original
        .into(original.syncConflicts)
        .insert(
          SyncConflictsCompanion.insert(
            id: const Value('70000000-0000-4000-8000-000000000080'),
            localUserId: bootstrap.activeUserId,
            endpointKey: 'https://alpha.example.test',
            cloudUserId: 'cloud-user-v7',
            entityType: 'today_records',
            recordId: '70000000-0000-4000-8000-000000000081',
            localUpdatedAt: 100,
            remoteOperation: 'upsert',
            remoteServerVersion: 2,
            detectedAt: 110,
            lastSeenAt: 110,
            resolutionStatus: 'unresolved',
          ),
        );
    final v7Columns =
        (await original.customSelect('PRAGMA table_info(sync_conflicts)').get())
            .map((row) => row.read<String>('name'))
            .where((name) => name != 'remote_record_id')
            .join(', ');
    await original.customStatement(
      'CREATE TABLE sync_conflicts_v7 AS '
      'SELECT $v7Columns FROM sync_conflicts',
    );
    await original.customStatement('DROP TABLE sync_conflicts');
    await original.customStatement(
      'ALTER TABLE sync_conflicts_v7 RENAME TO sync_conflicts',
    );
    await original.customStatement('PRAGMA user_version = 7');
    await original.close();

    final migrated = AppDatabase.forTesting(NativeDatabase(fixture.file));
    addTearDown(migrated.close);
    final conflict = await migrated.select(migrated.syncConflicts).getSingle();

    expect(migrated.schemaVersion, 13);
    expect(conflict.recordId, '70000000-0000-4000-8000-000000000081');
    expect(conflict.remoteRecordId, isNull);
  });

  test(
    'v8 to v13 backfills prompt configuration and Journal snapshots',
    () async {
      final fixture = await _createDatabaseFixture();
      addTearDown(fixture.dispose);
      final original = AppDatabase.forTesting(NativeDatabase(fixture.file));
      final bootstrap = await original.bootstrapDao.bootstrap(
        createUnboundProfile: true,
      );
      const journalId = '80000000-0000-4000-8000-000000000001';
      await original
          .into(original.journalEntries)
          .insert(
            JournalEntriesCompanion.insert(
              id: const Value(journalId),
              userId: bootstrap.activeUserId,
              entryDate: '2026-07-29',
              timezoneOffsetMinutes: 480,
              mostImportantAccomplishment: const Value('完成迁移验证'),
              learning: const Value('问题快照需要稳定'),
              originDeviceId: Value(bootstrap.localInstallationId),
            ),
          );
      await original.customStatement('DROP TABLE journal_entry_prompt_items');
      await original.customStatement('DROP TABLE journal_prompt_definitions');
      await original.customStatement(
        'DROP TABLE journal_prompt_configurations',
      );
      await original.customStatement('PRAGMA user_version = 8');
      await original.close();

      final migrated = AppDatabase.forTesting(NativeDatabase(fixture.file));
      addTearDown(migrated.close);
      final configuration = await migrated
          .select(migrated.journalPromptConfigurations)
          .getSingle();
      final prompts = await migrated
          .select(migrated.journalPromptDefinitions)
          .get();
      final items = await migrated
          .select(migrated.journalEntryPromptItems)
          .get();

      expect(migrated.schemaVersion, 13);
      expect(configuration.userId, bootstrap.activeUserId);
      expect(configuration.logicalKey, 'default');
      expect(prompts, hasLength(5));
      expect(items, hasLength(5));
      expect(
        items
            .singleWhere(
              (item) => item.sourcePromptStableKey == 'system.accomplishment',
            )
            .answerText,
        '完成迁移验证',
      );
      expect(
        items
            .singleWhere(
              (item) => item.sourcePromptStableKey == 'system.learning',
            )
            .answerText,
        '问题快照需要稳定',
      );
      expect(
        items.where((item) => item.journalEntryId == journalId),
        hasLength(5),
      );
      await migrated
          .into(migrated.syncConflicts)
          .insert(
            SyncConflictsCompanion.insert(
              id: const Value('80000000-0000-4000-8000-000000000009'),
              localUserId: bootstrap.activeUserId,
              endpointKey: 'https://alpha.example.test',
              cloudUserId: 'cloud-user-v8',
              entityType: 'journal_prompt_configurations',
              recordId: configuration.id,
              localUpdatedAt: configuration.updatedAt,
              remoteOperation: 'unknown_pending_pull',
              remoteServerVersion: 0,
              detectedAt: configuration.updatedAt,
              lastSeenAt: configuration.updatedAt,
              resolutionStatus: 'awaiting_remote_snapshot',
            ),
          );
      expect(await migrated.select(migrated.syncConflicts).get(), hasLength(1));
    },
  );

  test('v9 to v13 backfills immutable AI report version one', () async {
    final fixture = await _createDatabaseFixture();
    addTearDown(fixture.dispose);
    final original = AppDatabase.forTesting(NativeDatabase(fixture.file));
    final bootstrap = await original.bootstrapDao.bootstrap(
      createUnboundProfile: true,
    );
    const reportId = '90000000-0000-4000-8000-000000000001';
    await original
        .into(original.aiReports)
        .insert(
          AiReportsCompanion.insert(
            id: const Value(reportId),
            userId: bootstrap.activeUserId,
            reportType: 'weekly_report',
            periodStartDate: '2026-07-24',
            periodEndDate: '2026-07-30',
            inputHash: 'legacy-input-hash',
            promptVersion: 'weekly-report-v1',
            reportStatus: const Value('completed'),
            reportContent: const Value('旧版本周报正文'),
            requestedAt: 100,
            generatedAt: const Value(120),
            createdAt: const Value(100),
            updatedAt: const Value(120),
          ),
        );
    const failedReportId = '90000000-0000-4000-8000-000000000002';
    await original
        .into(original.aiReports)
        .insert(
          AiReportsCompanion.insert(
            id: const Value(failedReportId),
            userId: bootstrap.activeUserId,
            reportType: 'daily_insight',
            periodStartDate: '2026-07-30',
            periodEndDate: '2026-07-30',
            inputHash: 'legacy-failed-input-hash',
            promptVersion: 'daily-insight-v1',
            reportStatus: const Value('failed'),
            requestedAt: 130,
            createdAt: const Value(130),
            updatedAt: const Value(140),
          ),
        );
    await _replaceAiReportsWithVersionNineDefinition(original);
    await original.close();

    final migrated = AppDatabase.forTesting(NativeDatabase(fixture.file));
    addTearDown(migrated.close);
    final report = await (migrated.select(
      migrated.aiReports,
    )..where((row) => row.id.equals(reportId))).getSingle();
    final version = await (migrated.select(
      migrated.aiReportVersions,
    )..where((row) => row.reportId.equals(reportId))).getSingle();
    final failedVersion = await (migrated.select(
      migrated.aiReportVersions,
    )..where((row) => row.reportId.equals(failedReportId))).getSingle();

    expect(migrated.schemaVersion, 13);
    expect(report.id, reportId);
    expect(report.title, '每周回顾');
    expect(report.currentVersion, 1);
    expect(version.reportId, reportId);
    expect(version.version, 1);
    expect(version.content, '旧版本周报正文');
    expect(version.status, 'completed');
    expect(failedVersion.status, 'failed');
    expect(failedVersion.errorCode, 'unknown');

    await expectLater(
      (migrated.update(migrated.aiReportVersions)
            ..where((row) => row.id.equals(version.id)))
          .write(const AiReportVersionsCompanion(content: Value('覆盖'))),
      throwsA(isA<Exception>()),
    );
  });

  test(
    'v10 to v13 preserves conflicts and permits AI report conflicts',
    () async {
      final fixture = await _createDatabaseFixture();
      addTearDown(fixture.dispose);
      final original = AppDatabase.forTesting(NativeDatabase(fixture.file));
      final bootstrap = await original.bootstrapDao.bootstrap(
        createUnboundProfile: true,
      );
      await original
          .into(original.syncConflicts)
          .insert(
            SyncConflictsCompanion.insert(
              id: const Value('91000000-0000-4000-8000-000000000001'),
              localUserId: bootstrap.activeUserId,
              endpointKey: 'https://alpha.example.test',
              cloudUserId: 'cloud-user-v10',
              entityType: 'goals',
              recordId: '91000000-0000-4000-8000-000000000002',
              localUpdatedAt: 100,
              remoteOperation: 'upsert',
              remoteServerVersion: 4,
              detectedAt: 100,
              lastSeenAt: 100,
              resolutionStatus: 'unresolved',
            ),
          );
      await _replaceSyncConflictsWithVersionTenDefinition(original);
      await original.close();

      final migrated = AppDatabase.forTesting(NativeDatabase(fixture.file));
      addTearDown(migrated.close);
      expect(migrated.schemaVersion, 13);
      expect(await migrated.select(migrated.syncConflicts).get(), hasLength(1));

      await migrated
          .into(migrated.syncConflicts)
          .insert(
            SyncConflictsCompanion.insert(
              id: const Value('91000000-0000-4000-8000-000000000003'),
              localUserId: bootstrap.activeUserId,
              endpointKey: 'https://alpha.example.test',
              cloudUserId: 'cloud-user-v10',
              entityType: 'ai_reports',
              recordId: '91000000-0000-4000-8000-000000000004',
              localUpdatedAt: 120,
              remoteOperation: 'upsert',
              remoteServerVersion: 5,
              detectedAt: 120,
              lastSeenAt: 120,
              resolutionStatus: 'unresolved',
            ),
          );
      expect(await migrated.select(migrated.syncConflicts).get(), hasLength(2));
    },
  );

  test(
    'v11 to v13 preserves account data and creates feedback storage',
    () async {
      final fixture = await _createDatabaseFixture();
      addTearDown(fixture.dispose);
      final original = AppDatabase.forTesting(NativeDatabase(fixture.file));
      final bootstrap = await original.bootstrapDao.bootstrap(
        createUnboundProfile: true,
      );
      await original.customStatement('DROP TABLE ai_report_feedback');
      await original.customStatement('PRAGMA user_version = 11');
      await original.close();

      final migrated = AppDatabase.forTesting(NativeDatabase(fixture.file));
      addTearDown(migrated.close);
      expect(migrated.schemaVersion, 13);
      expect(
        await (migrated.select(migrated.userProfiles)
              ..where((row) => row.id.equals(bootstrap.activeUserId)))
            .getSingleOrNull(),
        isA<UserProfile>(),
      );
      expect(await migrated.select(migrated.aiReportFeedback).get(), isEmpty);
      final indexes = await migrated
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' "
            "AND name LIKE 'ai_report_feedback_%'",
          )
          .get();
      expect(indexes, hasLength(3));
      await migrated.close();

      final reopened = AppDatabase.forTesting(NativeDatabase(fixture.file));
      addTearDown(reopened.close);
      expect(await reopened.select(reopened.aiReportFeedback).get(), isEmpty);
      final reopenedIndexes = await reopened
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' "
            "AND name LIKE 'ai_report_feedback_%'",
          )
          .get();
      expect(reopenedIndexes, hasLength(3));
    },
  );

  test('v12 to v13 preserves legacy scores and normalizes on read', () async {
    final fixture = await _createDatabaseFixture();
    addTearDown(fixture.dispose);
    final original = AppDatabase.forTesting(NativeDatabase(fixture.file));
    final bootstrap = await original.bootstrapDao.bootstrap(
      createUnboundProfile: true,
    );
    await original.into(original.todayRecords).insert(
      TodayRecordsCompanion.insert(
        id: const Value('92000000-0000-4000-8000-000000000001'),
        userId: bootstrap.activeUserId,
        recordDate: '2026-08-20',
        timezoneOffsetMinutes: 480,
        moodScore: const Value(1),
        energyScore: const Value(5),
        createdAt: const Value(100),
        updatedAt: const Value(200),
        originDeviceId: Value(bootstrap.localInstallationId),
      ),
    );
    await original.into(original.healthRecords).insert(
      HealthRecordsCompanion.insert(
        id: const Value('92000000-0000-4000-8000-000000000002'),
        userId: bootstrap.activeUserId,
        recordDate: '2026-08-20',
        timezoneOffsetMinutes: 480,
        physicalStateScore: const Value(3),
        createdAt: const Value(110),
        updatedAt: const Value(210),
        originDeviceId: Value(bootstrap.localInstallationId),
      ),
    );
    await original.customStatement('PRAGMA user_version = 12');
    await original.close();

    final migrated = AppDatabase.forTesting(NativeDatabase(fixture.file));
    addTearDown(migrated.close);
    final todayRow = await migrated.select(migrated.todayRecords).getSingle();
    final healthRow = await migrated.select(migrated.healthRecords).getSingle();
    expect(todayRow.wellbeingScoreScale, isNull);
    expect(todayRow.updatedAt, 200);
    expect(healthRow.physicalStateScoreScale, isNull);
    expect(healthRow.updatedAt, 210);

    const clock = DateTimeService();
    final today = await TodayRepositoryImpl(
      database: migrated,
      dateTimeService: clock,
    ).getByDate('2026-08-20');
    final health = await HealthRepositoryImpl(
      database: migrated,
      dateTimeService: clock,
    ).getByDate('2026-08-20');
    expect(today?.moodScore, 2);
    expect(today?.energyScore, 10);
    expect(health?.physicalStateScore, 6);
  });

  test('schema 13 refuses an automatic downgrade to schema 9', () async {
    final fixture = await _createDatabaseFixture();
    addTearDown(fixture.dispose);
    final current = AppDatabase.forTesting(NativeDatabase(fixture.file));
    await current.customSelect('SELECT 1').get();
    await current.close();

    final oldApp = _SchemaNineAppDatabase(NativeDatabase(fixture.file));
    addTearDown(oldApp.close);
    await expectLater(
      oldApp.customSelect('SELECT 1').get(),
      throwsA(isA<StateError>()),
    );
  });
}

final class _SchemaNineAppDatabase extends AppDatabase {
  _SchemaNineAppDatabase(super.executor) : super.forTesting();

  @override
  int get schemaVersion => 9;
}

Future<void> _replaceAiReportsWithVersionNineDefinition(
  AppDatabase database,
) async {
  await database.customStatement('PRAGMA foreign_keys = OFF');
  await database.transaction(() async {
    await database.customStatement('DROP TRIGGER ai_report_versions_no_update');
    await database.customStatement('DROP TRIGGER ai_report_versions_no_delete');
    await database.customStatement('DROP TABLE ai_report_versions');
    await database.customStatement('''
CREATE TABLE ai_reports_v9 (
  id TEXT NOT NULL PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES user_profiles(id) ON DELETE RESTRICT,
  report_type TEXT NOT NULL,
  period_start_date TEXT NOT NULL,
  period_end_date TEXT NOT NULL,
  input_sources_json TEXT NOT NULL DEFAULT '[]',
  input_hash TEXT NOT NULL,
  input_snapshot_json TEXT,
  prompt_version TEXT NOT NULL,
  provider TEXT,
  model TEXT,
  generation_mode TEXT NOT NULL DEFAULT 'manual',
  report_status TEXT NOT NULL DEFAULT 'pending',
  report_content TEXT,
  structured_output_json TEXT,
  error_code TEXT,
  requested_at INTEGER NOT NULL,
  generated_at INTEGER,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  sync_status TEXT NOT NULL DEFAULT 'local_only',
  server_version INTEGER,
  last_synced_at INTEGER,
  origin_device_id TEXT,
  deleted_at INTEGER
)
''');
    const columns =
        'id, user_id, report_type, period_start_date, period_end_date, '
        'input_sources_json, input_hash, input_snapshot_json, prompt_version, '
        'provider, model, generation_mode, report_status, report_content, '
        'structured_output_json, error_code, requested_at, generated_at, '
        'created_at, updated_at, sync_status, server_version, last_synced_at, '
        'origin_device_id, deleted_at';
    await database.customStatement(
      'INSERT INTO ai_reports_v9 ($columns) SELECT $columns FROM ai_reports',
    );
    await database.customStatement('DROP TABLE ai_reports');
    await database.customStatement(
      'ALTER TABLE ai_reports_v9 RENAME TO ai_reports',
    );
    await database.customStatement('PRAGMA user_version = 9');
  });
}

Future<void> _replaceSyncConflictsWithVersionTenDefinition(
  AppDatabase database,
) async {
  final schema = await database
      .customSelect(
        "SELECT sql FROM sqlite_master WHERE type = 'table' "
        "AND name = 'sync_conflicts'",
      )
      .getSingle();
  final oldSql = schema
      .read<String>('sql')
      .replaceFirst(
        'CREATE TABLE "sync_conflicts"',
        'CREATE TABLE "sync_conflicts_v10"',
      )
      .replaceFirst(", 'ai_reports'", '');
  const columns =
      'id, local_user_id, endpoint_key, cloud_user_id, entity_type, '
      'record_id, remote_record_id, local_payload_json, local_updated_at, '
      'local_deleted_at, local_server_version, local_origin_device_id, '
      'remote_payload_json, remote_operation, remote_updated_at, '
      'remote_deleted_at, remote_server_version, remote_origin_device_id, '
      'detected_at, last_seen_at, resolution_status, resolved_at';

  await database.customStatement('PRAGMA foreign_keys = OFF');
  await database.transaction(() async {
    for (final indexName in const <String>[
      'sync_conflicts_user_status_detected',
      'sync_conflicts_endpoint_user_entity',
      'sync_conflicts_entity_record',
      'sync_conflicts_one_active',
    ]) {
      await database.customStatement('DROP INDEX $indexName');
    }
    await database.customStatement(oldSql);
    await database.customStatement(
      'INSERT INTO sync_conflicts_v10 ($columns) '
      'SELECT $columns FROM sync_conflicts',
    );
    await database.customStatement('DROP TABLE sync_conflicts');
    await database.customStatement(
      'ALTER TABLE sync_conflicts_v10 RENAME TO sync_conflicts',
    );
    await database.customStatement('PRAGMA user_version = 10');
  });
  await database.customStatement('PRAGMA foreign_keys = ON');
}

Future<void> _replaceGoalsWithVersionTwoDefinition(AppDatabase database) {
  return _rebuildGoals(database: database, version: 2, removeCustom: false);
}

Future<void> _replaceGoalsWithVersionOneDefinition(AppDatabase database) {
  return _rebuildGoals(database: database, version: 1, removeCustom: true);
}

Future<void> _rebuildGoals({
  required AppDatabase database,
  required int version,
  required bool removeCustom,
}) async {
  final schemaRow = await database
      .customSelect(
        "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'goals'",
      )
      .getSingle();
  var oldSql = schemaRow
      .read<String>('sql')
      .replaceFirst('CREATE TABLE "goals"', 'CREATE TABLE "goals_old"')
      .replaceFirst(', "archived_at" INTEGER NULL', '')
      .replaceFirst(', archived_at INTEGER NULL', '')
      .replaceFirst(', CHECK (archived_at IS NULL OR archived_at >= 0)', '');
  if (removeCustom) {
    oldSql = oldSql.replaceFirst(", 'custom'", '');
  }
  const columns =
      'id, user_id, parent_goal_id, title, description, goal_level, status, '
      'start_date, target_date, completed_at, sort_order, created_at, '
      'updated_at, deleted_at, sync_status, server_version, '
      'origin_device_id, last_synced_at';

  await database.customStatement('PRAGMA foreign_keys = OFF');
  await database.transaction(() async {
    for (final indexName in const <String>[
      'goals_user_parent_sort_order',
      'goals_user_level_status',
      'goals_user_target_date',
    ]) {
      await database.customStatement('DROP INDEX $indexName');
    }
    await database.customStatement(oldSql);
    await database.customStatement(
      'INSERT INTO goals_old ($columns) SELECT $columns FROM goals',
    );
    await database.customStatement('DROP TABLE goals');
    await database.customStatement('ALTER TABLE goals_old RENAME TO goals');
    await database.customStatement(
      'CREATE INDEX goals_user_parent_sort_order '
      'ON goals (user_id, parent_goal_id, sort_order)',
    );
    await database.customStatement(
      'CREATE INDEX goals_user_level_status '
      'ON goals (user_id, goal_level, status)',
    );
    await database.customStatement(
      'CREATE INDEX goals_user_target_date ON goals (user_id, target_date)',
    );
    await database.customStatement('PRAGMA user_version = $version');
  });
}

Future<void> _expectCoreTableSet(AppDatabase database) async {
  final tables = await database
      .customSelect(
        "SELECT name FROM sqlite_master "
        "WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
      )
      .get();
  expect(tables.map((row) => row.read<String>('name')).toSet(), <String>{
    'user_profiles',
    'app_settings',
    'today_records',
    'journal_entries',
    'goals',
    'health_records',
    'ai_reports',
    'ai_report_versions',
    'ai_report_feedback',
    'sync_conflicts',
    'installation_info',
    'cloud_account_bindings',
    'journal_prompt_configurations',
    'journal_prompt_definitions',
    'journal_entry_prompt_items',
  });
}

Future<_DatabaseFixture> _createDatabaseFixture() async {
  final directory = await Directory.systemTemp.createTemp(
    'rebirth_schema_migration_',
  );
  return _DatabaseFixture(
    directory,
    File('${directory.path}${Platform.pathSeparator}rebirth.sqlite'),
  );
}

final class _DatabaseFixture {
  const _DatabaseFixture(this.directory, this.file);

  final Directory directory;
  final File file;

  Future<void> dispose() async {
    for (var attempt = 0; attempt < 5; attempt += 1) {
      if (!directory.existsSync()) return;
      try {
        await directory.delete(recursive: true);
        return;
      } on FileSystemException {
        if (attempt == 4) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 50 * (attempt + 1)));
      }
    }
  }
}
