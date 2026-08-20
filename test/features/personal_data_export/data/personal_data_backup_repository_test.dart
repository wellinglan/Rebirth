import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/features/personal_data_export/data/personal_data_backup_encoder.dart';
import 'package:rebirth/features/personal_data_export/data/personal_data_backup_repository_impl.dart';
import 'package:rebirth/features/personal_data_export/data/personal_data_export_modules.dart';
import 'package:rebirth/features/personal_data_export/domain/personal_data_backup_repository.dart';
import 'package:rebirth/features/personal_data_export/domain/personal_data_export_module.dart';

void main() {
  late AppDatabase database;
  late String userA;
  late PersonalDataBackupRepositoryImpl repository;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    userA = (await database.bootstrapDao.bootstrap(
      createUnboundProfile: true,
    )).activeUserId;
    repository = PersonalDataBackupRepositoryImpl(database);
    await _seed(database, userA);
  });

  tearDown(() => database.close());

  test(
    'all module exporters map the complete portable account snapshot',
    () async {
      final registry = PersonalDataExportModuleRegistry([
        ProfilePersonalDataExportModule(repository),
        PlanPersonalDataExportModule(repository),
        TodayPersonalDataExportModule(repository),
        JournalPersonalDataExportModule(repository),
        JournalPromptsPersonalDataExportModule(repository),
        HealthPersonalDataExportModule(repository),
        AiReportsPersonalDataExportModule(repository),
        AiReportFeedbackPersonalDataExportModule(repository),
      ]);
      final snapshots = await database.transaction(
        () => registry.exportAll(userA, checkBoundary: () {}),
      );
      const encoder = PersonalDataBackupEncoder();
      final document = encoder.createDocument(
        exportedAt: '2026-08-05T01:02:03.000Z',
        appVersion: 'test',
        databaseSchemaVersion: database.schemaVersion,
        modules: snapshots,
      );
      final json = encoder.encode(document);
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final data = decoded['data'] as Map<String, dynamic>;

      expect(snapshots.map((module) => module.id), [
        'profile',
        'plan',
        'today',
        'journal',
        'journal_prompt_configurations',
        'health',
        'ai_reports',
        'ai_report_feedback',
      ]);
      expect(database.schemaVersion, 13);

      final profile = _records(data, 'profile').single;
      expect(profile['display_name'], '账号 A');
      expect(profile['growth_focus'], '持续成长');
      expect(profile, isNot(contains('id')));

      final goals = _records(data, 'plan');
      expect(goals, hasLength(3));
      expect(
        goals.singleWhere((goal) => goal['id'] == _id(12))['parent_goal_id'],
        _id(11),
      );
      expect(
        goals.singleWhere((goal) => goal['id'] == _id(13))['deleted_at'],
        isNotNull,
      );

      final today = _records(data, 'today').single;
      expect(today['research_minutes'], 0);
      expect(today['learning_minutes'], isNull);
      expect(today['daily_note'], '');
      expect((today['priorities'] as List).first['goal_id'], _id(12));

      final journal = _records(data, 'journal').single;
      expect(journal['today_record_id'], _id(21));
      expect((journal['prompt_items'] as List).single['answer_text'], '动态回答');
      expect((journal['legacy_compatibility'] as Map)['learning'], '旧字段兼容回答');

      final promptConfiguration = _records(
        data,
        'journal_prompt_configurations',
      ).single;
      final definition =
          (promptConfiguration['definitions'] as List).single as Map;
      expect(definition['question_text'], '今天学到了什么？');
      expect(definition['is_enabled'], isTrue);
      expect(definition['prompt_version'], 2);

      final health = _records(data, 'health').single;
      expect(health['sleep_duration_minutes'], 450);
      expect(health['exercise_duration_minutes'], 0);
      expect(health['note'], '敏感健康备注');

      final report = _records(data, 'ai_reports').single;
      expect(report['current_content'], '当前报告正文');
      expect(report['lifecycle_status'], 'archived');
      expect((report['versions'] as List).map((item) => item['version']), [
        1,
        2,
      ]);
      expect((report['versions'] as List).map((item) => item['content']), [
        '第一版正文',
        '第二版正文',
      ]);

      final feedback = _records(data, 'ai_report_feedback').single;
      expect(feedback['report_id'], _id(61));
      expect(feedback['report_version'], 1);
      expect(feedback['helpfulness'], 'not_helpful');
      expect(feedback['reason_codes'], ['not_actionable', 'too_generic']);

      for (final forbidden in const [
        '账号 B 的秘密目标',
        'secret-input-hash',
        'secret-input-snapshot',
        'secret-provider',
        'secret-model',
        'secret-structured-output',
        'secret-model-metadata',
        'secret-health-source-id',
        'origin_device_id',
        'server_version',
        'sync_status',
        'last_synced_at',
        'cloud_user_id',
        'authorization',
        'refresh_token',
        'endpoint',
        'conflict_payload',
        'generation_ledger',
        'usage_ledger',
      ]) {
        expect(json.toLowerCase(), isNot(contains(forbidden.toLowerCase())));
      }
    },
  );

  test('export reads do not mutate business or sync metadata', () async {
    final beforeGoal = await (database.select(
      database.goals,
    )..where((row) => row.id.equals(_id(11)))).getSingle();
    final beforeReport = await (database.select(
      database.aiReports,
    )..where((row) => row.id.equals(_id(61)))).getSingle();
    final beforeVersionCount = await database
        .select(database.aiReportVersions)
        .get()
        .then((rows) => rows.length);

    await repository.readProfile(userA);
    await repository.readPlan(userA);
    await repository.readToday(userA);
    await repository.readJournal(userA);
    await repository.readJournalPrompts(userA);
    await repository.readHealth(userA);
    await repository.readAiReports(userA);
    await repository.readAiReportFeedback(userA);

    final afterGoal = await (database.select(
      database.goals,
    )..where((row) => row.id.equals(_id(11)))).getSingle();
    final afterReport = await (database.select(
      database.aiReports,
    )..where((row) => row.id.equals(_id(61)))).getSingle();
    final afterVersionCount = await database
        .select(database.aiReportVersions)
        .get()
        .then((rows) => rows.length);

    expect(afterGoal.updatedAt, beforeGoal.updatedAt);
    expect(afterGoal.syncStatus, beforeGoal.syncStatus);
    expect(afterGoal.serverVersion, beforeGoal.serverVersion);
    expect(afterReport.updatedAt, beforeReport.updatedAt);
    expect(afterReport.syncStatus, beforeReport.syncStatus);
    expect(afterReport.serverVersion, beforeReport.serverVersion);
    expect(afterVersionCount, beforeVersionCount);
  });

  test(
    'inconsistent AI report current version fails the whole source',
    () async {
      await (database.update(database.aiReports)
            ..where((row) => row.id.equals(_id(61))))
          .write(const AiReportsCompanion(currentVersion: Value(3)));

      await expectLater(
        repository.readAiReports(userA),
        throwsA(isA<PersonalDataBackupSourceException>()),
      );
    },
  );

  test(
    'historical Journal snapshot exports when its source prompt is absent',
    () async {
      final historicalSourceId = _id(99);
      await (database.update(
        database.journalEntryPromptItems,
      )..where((row) => row.id.equals(_id(42)))).write(
        JournalEntryPromptItemsCompanion(
          sourcePromptId: Value(historicalSourceId),
        ),
      );

      final records = await repository.readJournal(userA);

      expect(records, hasLength(1));
      expect(records.single.promptItems, hasLength(1));
      expect(
        records.single.promptItems.single.sourcePromptId,
        historicalSourceId,
      );
      expect(records.single.promptItems.single.answerText, isNotNull);
    },
  );

  test(
    'Journal snapshot rejects a source prompt owned by another account',
    () async {
      await database
          .into(database.journalPromptConfigurations)
          .insert(
            JournalPromptConfigurationsCompanion.insert(
              id: Value(_id(81)),
              userId: _id(2),
              createdAt: const Value(_now),
              updatedAt: const Value(_now),
            ),
          );
      await database
          .into(database.journalPromptDefinitions)
          .insert(
            JournalPromptDefinitionsCompanion.insert(
              id: Value(_id(82)),
              configurationId: _id(81),
              promptSource: 'user',
              questionText: 'Account B prompt',
              displayOrder: 0,
              createdAt: const Value(_now),
              updatedAt: const Value(_now),
            ),
          );
      await (database.update(
        database.journalEntryPromptItems,
      )..where((row) => row.id.equals(_id(42)))).write(
        JournalEntryPromptItemsCompanion(sourcePromptId: Value(_id(82))),
      );

      await expectLater(
        repository.readJournal(userA),
        throwsA(isA<PersonalDataBackupSourceException>()),
      );
    },
  );
}

List<Map<String, dynamic>> _records(Map<String, dynamic> data, String module) {
  return ((data[module] as Map<String, dynamic>)['records'] as List)
      .cast<Map<String, dynamic>>();
}

Future<void> _seed(AppDatabase database, String userA) async {
  await (database.update(
    database.userProfiles,
  )..where((row) => row.id.equals(userA))).write(
    const UserProfilesCompanion(
      displayName: Value('账号 A'),
      growthFocus: Value('持续成长'),
      timezoneId: Value('Asia/Shanghai'),
      syncStatus: Value('synced'),
      serverVersion: Value(88),
      lastSyncedAt: Value(_now),
    ),
  );
  await database
      .into(database.userProfiles)
      .insert(
        UserProfilesCompanion.insert(
          id: Value(_id(2)),
          displayName: const Value('账号 B'),
          timezoneId: 'Etc/UTC',
          isActive: const Value(false),
          createdAt: const Value(_now),
          updatedAt: const Value(_now),
        ),
      );

  await database.batch((batch) {
    batch.insertAll(database.goals, [
      _goal(id: _id(11), userId: userA, title: '根目标'),
      _goal(
        id: _id(12),
        userId: userA,
        title: '子目标',
        parentGoalId: _id(11),
        archivedAt: _now,
      ),
      _goal(id: _id(13), userId: userA, title: '已删除目标', deletedAt: _now),
      _goal(id: _id(14), userId: _id(2), title: '账号 B 的秘密目标'),
    ]);
  });

  await database
      .into(database.todayRecords)
      .insert(
        TodayRecordsCompanion.insert(
          id: Value(_id(21)),
          userId: userA,
          recordDate: '2026-08-05',
          timezoneOffsetMinutes: 480,
          priority1: const Value('完成 15A'),
          priority1Completed: const Value(true),
          priority1GoalId: Value(_id(12)),
          researchMinutes: const Value(0),
          learningMinutes: const Value(null),
          dailyNote: const Value(''),
          recordStatus: const Value('completed'),
          createdAt: const Value(_now),
          updatedAt: const Value(_now),
          syncStatus: const Value('synced'),
          serverVersion: const Value(7),
          lastSyncedAt: const Value(_now),
        ),
      );

  await database
      .into(database.journalPromptConfigurations)
      .insert(
        JournalPromptConfigurationsCompanion.insert(
          id: Value(_id(31)),
          userId: userA,
          configurationVersion: const Value(3),
          createdAt: const Value(_now),
          updatedAt: const Value(_now),
          syncStatus: const Value('synced'),
          serverVersion: const Value(4),
        ),
      );
  await database
      .into(database.journalPromptDefinitions)
      .insert(
        JournalPromptDefinitionsCompanion.insert(
          id: Value(_id(32)),
          configurationId: _id(31),
          stableKey: const Value('learning'),
          promptSource: 'system',
          questionText: '今天学到了什么？',
          displayOrder: 0,
          promptVersion: const Value(2),
          createdAt: const Value(_now),
          updatedAt: const Value(_now),
        ),
      );
  await database
      .into(database.journalEntries)
      .insert(
        JournalEntriesCompanion.insert(
          id: Value(_id(41)),
          userId: userA,
          todayRecordId: Value(_id(21)),
          entryDate: '2026-08-05',
          timezoneOffsetMinutes: 480,
          learning: const Value('旧字段兼容回答'),
          entryStatus: const Value('completed'),
          createdAt: const Value(_now),
          updatedAt: const Value(_now),
          syncStatus: const Value('synced'),
          serverVersion: const Value(5),
        ),
      );
  await database
      .into(database.journalEntryPromptItems)
      .insert(
        JournalEntryPromptItemsCompanion.insert(
          id: Value(_id(42)),
          journalEntryId: _id(41),
          sourcePromptId: Value(_id(32)),
          sourcePromptStableKey: const Value('learning'),
          sourcePromptVersion: 2,
          promptSource: 'system',
          questionTextSnapshot: '今天学到了什么？',
          displayOrder: 0,
          answerText: const Value('动态回答'),
          createdAt: const Value(_now),
          updatedAt: const Value(_now),
        ),
      );

  await database
      .into(database.healthRecords)
      .insert(
        HealthRecordsCompanion.insert(
          id: Value(_id(51)),
          userId: userA,
          todayRecordId: Value(_id(21)),
          recordDate: '2026-08-05',
          timezoneOffsetMinutes: 480,
          sleepDurationMinutes: const Value(450),
          exerciseDurationMinutes: const Value(0),
          physicalStateScore: const Value(4),
          note: const Value('敏感健康备注'),
          dataSource: const Value('health_connect'),
          sourceRecordId: const Value('secret-health-source-id'),
          createdAt: const Value(_now),
          updatedAt: const Value(_now),
          syncStatus: const Value('synced'),
          serverVersion: const Value(6),
        ),
      );

  await database
      .into(database.aiReports)
      .insert(
        AiReportsCompanion.insert(
          id: Value(_id(61)),
          userId: userA,
          reportType: 'weekly_report',
          title: const Value('成长周报'),
          periodStartDate: '2026-07-27',
          periodEndDate: '2026-08-02',
          inputHash: 'secret-input-hash',
          inputSnapshotJson: const Value('secret-input-snapshot'),
          promptVersion: 'secret-prompt',
          provider: const Value('secret-provider'),
          model: const Value('secret-model'),
          reportStatus: const Value('archived'),
          currentVersion: const Value(2),
          reportContent: const Value('当前报告正文'),
          structuredOutputJson: const Value('secret-structured-output'),
          requestedAt: _now,
          generatedAt: const Value(_now),
          createdAt: const Value(_now),
          updatedAt: const Value(_now),
          syncStatus: const Value('synced'),
          serverVersion: const Value(9),
          lastSyncedAt: const Value(_now),
        ),
      );
  await database.batch((batch) {
    batch.insertAll(database.aiReportVersions, [
      _reportVersion(version: 2, content: '第二版正文'),
      _reportVersion(version: 1, content: '第一版正文'),
    ]);
  });
  await database
      .into(database.aiReportFeedback)
      .insert(
        AiReportFeedbackCompanion.insert(
          id: Value(_id(81)),
          userId: userA,
          reportId: _id(61),
          reportVersion: 1,
          reportType: 'weekly_report',
          helpfulness: 'not_helpful',
          reasonCodesJson: const Value('["not_actionable","too_generic"]'),
          promptId: 'weekly_report',
          promptVersion: 'weekly-report-v1',
          syncStatus: const Value('synced'),
          serverVersion: const Value(4),
          lastSyncedAt: const Value(_now),
          createdAt: const Value(_now),
          updatedAt: const Value(_now),
        ),
      );
}

GoalsCompanion _goal({
  required String id,
  required String userId,
  required String title,
  String? parentGoalId,
  int? archivedAt,
  int? deletedAt,
}) {
  return GoalsCompanion.insert(
    id: Value(id),
    userId: userId,
    parentGoalId: Value(parentGoalId),
    title: title,
    description: const Value('说明'),
    goalLevel: 'month',
    status: const Value('in_progress'),
    startDate: const Value('2026-08-01'),
    targetDate: const Value('2026-08-31'),
    archivedAt: Value(archivedAt),
    deletedAt: Value(deletedAt),
    createdAt: const Value(_now),
    updatedAt: const Value(_now),
    syncStatus: const Value('synced'),
    serverVersion: const Value(3),
    lastSyncedAt: const Value(_now),
  );
}

AiReportVersionsCompanion _reportVersion({
  required int version,
  required String content,
}) {
  return AiReportVersionsCompanion.insert(
    id: Value(_id(70 + version)),
    reportId: _id(61),
    version: version,
    status: 'completed',
    generationSource: 'secret-provider-source',
    modelMetadataJson: const Value('secret-model-metadata'),
    content: Value(content),
    sensitivity: 'high',
    quality: 'unreviewed',
    completedAt: const Value(_now),
    createdAt: const Value(_now),
    updatedAt: const Value(_now),
  );
}

const _now = 1785891723000;

String _id(int value) =>
    '00000000-0000-4000-8000-${value.toString().padLeft(12, '0')}';
