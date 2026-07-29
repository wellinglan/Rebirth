import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/journal/journal_prompt_catalog.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/journal/data/journal_prompt_conflict_resolution_service.dart';
import 'package:rebirth/features/journal/data/journal_prompt_repository_impl.dart';
import 'package:rebirth/features/journal/data/journal_prompt_sync_adapter.dart';
import 'package:rebirth/features/journal/data/journal_prompt_sync_payload_codec.dart';
import 'package:rebirth/features/journal/data/journal_sync_payload_codec.dart';
import 'package:rebirth/features/journal/domain/journal_entry.dart';
import 'package:rebirth/features/journal/domain/journal_entry_prompt_item.dart';
import 'package:rebirth/features/journal/domain/journal_prompt.dart';
import 'package:rebirth/features/journal/domain/journal_prompt_sync_payload.dart';
import 'package:rebirth/features/journal/domain/journal_sync_payload.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_exception.dart';
import 'package:rebirth/features/sync/data/sync_conflict_repository_impl.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_record.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_repository.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';

void main() {
  const configurationId = 'a0000000-0000-4000-8000-000000000001';
  const promptId = 'a0000000-0000-4000-8000-000000000002';
  const deviceId = 'a0000000-0000-4000-8000-000000000004';

  test('Journal v2 codec round-trips dynamic snapshots', () {
    const codec = JournalSyncPayloadCodec();
    final payload = JournalSyncPayload(
      entryDate: '2026-07-29',
      timezoneOffsetMinutes: 480,
      status: JournalEntryStatus.draft,
      createdAt: 100,
      promptItems: [_item(answer: '保留完整自定义回答')],
    );

    final json = codec.encode(payload);
    final decoded = codec.decode(recordId: configurationId, json: json);

    expect(json['journal_payload_schema_version'], 2);
    expect(decoded.promptItems.single.questionTextSnapshot, '自定义问题');
    expect(decoded.promptItems.single.answerText, '保留完整自定义回答');
    expect(json, isNot(contains('learning')));
  });

  test('Journal codec deterministically converts v1 into five snapshots', () {
    const codec = JournalSyncPayloadCodec();
    final decoded = codec.decode(
      recordId: configurationId,
      json: {
        'created_at': 100,
        'emotion_source': null,
        'entry_date': '2026-07-29',
        'entry_status': 'completed',
        'learning': '旧版学习',
        'most_draining_event': null,
        'most_important_accomplishment': '旧版完成',
        'timezone_offset_minutes': 480,
        'tomorrow_adjustment': null,
      },
    );

    expect(decoded.promptItems, hasLength(5));
    expect(decoded.learning, '旧版学习');
    expect(decoded.mostImportantAccomplishment, '旧版完成');
    expect(
      decoded.promptItems.map((item) => item.sourcePromptStableKey),
      JournalPromptCatalog.prompts.map((prompt) => prompt.stableKey),
    );
  });

  test('Journal v2 rejects duplicate item IDs and all-empty answers', () {
    const codec = JournalSyncPayloadCodec();
    final duplicate = JournalSyncPayload(
      entryDate: '2026-07-29',
      timezoneOffsetMinutes: 480,
      status: JournalEntryStatus.draft,
      createdAt: 100,
      promptItems: [
        _item(answer: 'one'),
        _item(answer: 'two', displayOrder: 1),
      ],
    );
    final empty = JournalSyncPayload(
      entryDate: '2026-07-29',
      timezoneOffsetMinutes: 480,
      status: JournalEntryStatus.draft,
      createdAt: 100,
      promptItems: [_item(answer: null)],
    );

    expect(() => codec.encode(duplicate), throwsA(isA<SyncException>()));
    expect(() => codec.encode(empty), throwsA(isA<SyncException>()));
  });

  test('prompt configuration codec is strict and canonical', () {
    const codec = JournalPromptSyncPayloadCodec();
    final payload = _configurationPayload();
    final encoded = codec.encode(payload);
    final decoded = codec.decode(recordId: configurationId, json: encoded);

    expect(encoded['payload_schema_version'], 1);
    expect(decoded.logicalKey, 'default');
    expect(decoded.prompts.single.id, promptId);
    expect(codec.canonicalJson(decoded), codec.canonicalJson(payload));
  });

  test('prompt configuration rejects duplicate system stable keys', () {
    const codec = JournalPromptSyncPayloadCodec();
    final prompt = _prompt();
    final payload = JournalPromptConfigurationSyncPayload(
      logicalKey: 'default',
      configurationVersion: 1,
      createdAt: 100,
      prompts: [
        prompt,
        JournalPromptDefinition(
          id: 'a0000000-0000-4000-8000-000000000005',
          configurationId: configurationId,
          stableKey: prompt.stableKey,
          source: prompt.source,
          questionText: '重复系统问题',
          helperText: null,
          responseKind: JournalResponseKind.longText,
          displayOrder: 1,
          isEnabled: true,
          promptVersion: 1,
          createdAt: 100,
          updatedAt: 100,
          deletedAt: null,
        ),
      ],
    );

    expect(() => codec.encode(payload), throwsA(isA<SyncException>()));
  });

  test('prompt adapter pull stores one complete aggregate', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await database.bootstrapDao.bootstrap(createUnboundProfile: true);
    final repository = JournalPromptRepositoryImpl(
      database: database,
      dateTimeService: DateTimeService(now: () => DateTime.utc(2026, 7, 29, 8)),
    );
    final adapter = JournalPromptSyncAdapter(database, repository);

    final result = await adapter.applyRemoteChanges(
      changes: [
        SyncChange(
          entityType: SyncEntityType.journalPromptConfiguration,
          operation: SyncOperation.upsert,
          recordId: configurationId,
          payload: _configurationPayload(),
          updatedAt: 200,
          deletedAt: null,
          originDeviceId: deviceId,
          serverVersion: 1,
        ),
      ],
      syncedAt: 210,
    );

    expect(result.status, SyncEntityStatus.succeeded);
    final configuration = await repository.getConfiguration();
    expect(configuration.id, configurationId);
    expect(configuration.syncStatus, 'synced');
    expect(configuration.prompts.single.questionText, '系统问题');
  });

  test(
    'ack does not mark a configuration synced after a concurrent edit',
    () async {
      var now = DateTime.utc(2026, 7, 29, 8);
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await database.bootstrapDao.bootstrap(createUnboundProfile: true);
      final repository = JournalPromptRepositoryImpl(
        database: database,
        dateTimeService: DateTimeService(now: () => now),
      );
      final adapter = JournalPromptSyncAdapter(database, repository);
      final initial = await repository.ensureInitialized();
      final submitted = await adapter.collectPending();
      now = now.add(const Duration(minutes: 1));
      await repository.createUserPrompt(
        const JournalPromptInput(questionText: '上传期间的新问题'),
      );

      await adapter.acknowledgePush(
        submitted: submitted,
        accepted: [
          SyncAcknowledgement(
            entityType: SyncEntityType.journalPromptConfiguration,
            recordId: initial.id,
            serverVersion: 1,
          ),
        ],
        conflicts: const [],
        syncedAt: now.millisecondsSinceEpoch,
      );

      final current = await repository.getConfiguration();
      expect(current.syncStatus, 'pending');
      expect(current.activePrompts, hasLength(6));
    },
  );

  test(
    'Keep Local rekeys a complete configuration to the remote identity',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final bootstrap = await database.bootstrapDao.bootstrap(
        createUnboundProfile: true,
      );
      const clock = DateTimeService(now: _fixedNow);
      final repository = JournalPromptRepositoryImpl(
        database: database,
        dateTimeService: clock,
      );
      final adapter = JournalPromptSyncAdapter(database, repository);
      final local = await repository.ensureInitialized();
      final pending = (await adapter.collectPending()).single;
      final conflicts = SyncConflictRepositoryImpl(
        database,
        payloadCodecs: const [JournalPromptSyncPayloadCodec()],
      );
      const scope = SyncConflictScope(
        localUserId: '',
        endpointKey: 'http://server-a:8000',
        cloudUserId: 'cloud-user',
      );
      final accountScope = SyncConflictScope(
        localUserId: bootstrap.activeUserId,
        endpointKey: scope.endpointKey,
        cloudUserId: scope.cloudUserId,
      );
      await (database.update(
        database.journalPromptConfigurations,
      )..where((row) => row.id.equals(local.id))).write(
        const JournalPromptConfigurationsCompanion(
          syncStatus: Value('conflict'),
          serverVersion: Value(1),
        ),
      );
      final conflict = await conflicts.upsertDetectedConflict(
        SyncConflictDetection(
          scope: accountScope,
          entityType: SyncEntityType.journalPromptConfiguration,
          recordId: local.id,
          remoteRecordId: configurationId,
          localSnapshot: SyncConflictSnapshot(
            payload: pending.payload,
            updatedAt: pending.updatedAt,
            deletedAt: null,
            serverVersion: 1,
            originDeviceId: pending.originDeviceId,
          ),
          remoteSnapshot: SyncConflictSnapshot(
            payload: _configurationPayload(),
            updatedAt: 200,
            deletedAt: null,
            serverVersion: 7,
            originDeviceId: deviceId,
          ),
          remoteOperation: SyncConflictOperation.upsert,
          resolutionStatus: SyncConflictResolutionStatus.unresolved,
          detectedAt: 200,
        ),
      );
      final service = JournalPromptConflictResolutionService(
        database,
        conflicts,
        clock,
      );

      await service.requestKeepLocal(
        scope: accountScope,
        conflictId: conflict.id,
      );

      final rekeyed = await repository.getConfiguration();
      final requested = await conflicts.getConflict(accountScope, conflict.id);
      expect(rekeyed.id, configurationId);
      expect(rekeyed.prompts, hasLength(5));
      expect(
        rekeyed.prompts.every(
          (prompt) => prompt.configurationId == configurationId,
        ),
        isTrue,
      );
      expect(rekeyed.serverVersion, 7);
      expect(rekeyed.syncStatus, 'pending');
      expect(
        requested.resolutionStatus,
        SyncConflictResolutionStatus.keepLocalRequested,
      );
    },
  );
}

DateTime _fixedNow() => DateTime.utc(2026, 7, 29, 8);

JournalEntryPromptItem _item({required String? answer, int displayOrder = 0}) {
  return JournalEntryPromptItem(
    id: 'a0000000-0000-4000-8000-000000000003',
    sourcePromptId: 'a0000000-0000-4000-8000-000000000002',
    sourcePromptStableKey: null,
    sourcePromptVersion: 1,
    promptSource: JournalPromptSource.user,
    questionTextSnapshot: '自定义问题',
    helperTextSnapshot: null,
    responseKind: JournalResponseKind.longText,
    displayOrder: displayOrder,
    answerText: answer,
    createdAt: 100,
    updatedAt: 100,
  );
}

JournalPromptDefinition _prompt() {
  return const JournalPromptDefinition(
    id: 'a0000000-0000-4000-8000-000000000002',
    configurationId: 'a0000000-0000-4000-8000-000000000001',
    stableKey: 'system.test',
    source: JournalPromptSource.system,
    questionText: '系统问题',
    helperText: null,
    responseKind: JournalResponseKind.longText,
    displayOrder: 0,
    isEnabled: true,
    promptVersion: 1,
    createdAt: 100,
    updatedAt: 100,
    deletedAt: null,
  );
}

JournalPromptConfigurationSyncPayload _configurationPayload() {
  return JournalPromptConfigurationSyncPayload(
    logicalKey: 'default',
    configurationVersion: 1,
    createdAt: 100,
    prompts: [_prompt()],
  );
}
