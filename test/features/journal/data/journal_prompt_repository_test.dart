import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/journal/journal_prompt_catalog.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/journal/data/journal_prompt_repository_impl.dart';
import 'package:rebirth/features/journal/data/journal_repository_impl.dart';
import 'package:rebirth/features/journal/domain/journal_entry_prompt_item.dart';
import 'package:rebirth/features/journal/domain/journal_prompt.dart';
import 'package:rebirth/features/journal/domain/journal_save_data.dart';

void main() {
  late AppDatabase database;
  late DateTimeService clock;
  late JournalPromptRepositoryImpl prompts;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    await database.bootstrapDao.bootstrap(createUnboundProfile: true);
    clock = DateTimeService(now: () => DateTime.utc(2026, 7, 29, 8));
    prompts = JournalPromptRepositoryImpl(
      database: database,
      dateTimeService: clock,
    );
  });

  tearDown(() => database.close());

  test(
    'initialization is idempotent and creates the stable system catalog',
    () async {
      final first = await prompts.ensureInitialized();
      final second = await prompts.ensureInitialized();

      expect(second.id, first.id);
      expect(second.configurationVersion, 1);
      expect(second.activePrompts, hasLength(5));
      expect(
        second.activePrompts.map((prompt) => prompt.stableKey),
        JournalPromptCatalog.prompts.map((prompt) => prompt.stableKey),
      );
      expect(
        await database.select(database.journalPromptConfigurations).get(),
        hasLength(1),
      );
      expect(
        await database.select(database.journalPromptDefinitions).get(),
        hasLength(5),
      );
    },
  );

  test(
    'user prompt CRUD updates one pending configuration aggregate',
    () async {
      final initial = await prompts.ensureInitialized();
      final created = await prompts.createUserPrompt(
        const JournalPromptInput(
          questionText: '  今天有什么意外收获？  ',
          helperText: '  可以很小  ',
        ),
      );
      final user = created.activePrompts.singleWhere((prompt) => prompt.isUser);

      expect(user.questionText, '今天有什么意外收获？');
      expect(user.helperText, '可以很小');
      expect(user.promptVersion, 1);
      expect(created.configurationVersion, initial.configurationVersion + 1);
      expect(created.syncStatus, 'pending');

      final edited = await prompts.updateUserPrompt(
        user.id,
        const JournalPromptInput(questionText: '今天有哪些意外收获？'),
      );
      final editedUser = edited.prompts.singleWhere(
        (prompt) => prompt.id == user.id,
      );
      expect(editedUser.promptVersion, 2);
      expect(editedUser.questionText, '今天有哪些意外收获？');

      final disabled = await prompts.setPromptEnabled(user.id, false);
      expect(
        disabled.disabledPrompts.any((prompt) => prompt.id == user.id),
        isTrue,
      );
      final enabled = await prompts.setPromptEnabled(user.id, true);
      final ids = enabled.activePrompts.map((prompt) => prompt.id).toList();
      final reordered = await prompts.reorderPrompts([
        user.id,
        ...ids.where((id) => id != user.id),
      ]);
      expect(reordered.activePrompts.first.id, user.id);

      final deleted = await prompts.deleteUserPrompt(user.id);
      final deletedPrompt = deleted.prompts.singleWhere(
        (prompt) => prompt.id == user.id,
      );
      expect(deletedPrompt.isDeleted, isTrue);
      expect(deletedPrompt.isEnabled, isFalse);
    },
  );

  test(
    'system prompt is customized by duplication without editing history',
    () async {
      final initial = await prompts.ensureInitialized();
      final system = initial.activePrompts.first;
      final customized = await prompts.duplicateAsUserPrompt(system.id);

      expect(
        customized.disabledPrompts
            .singleWhere((prompt) => prompt.id == system.id)
            .isSystem,
        isTrue,
      );
      final copy = customized.activePrompts.singleWhere(
        (prompt) => prompt.isUser,
      );
      expect(copy.questionText, system.questionText);
      expect(copy.stableKey, isNull);
    },
  );

  test('system prompts cannot be edited or deleted directly', () async {
    final system = (await prompts.ensureInitialized()).activePrompts.first;

    await expectLater(
      prompts.updateUserPrompt(
        system.id,
        const JournalPromptInput(questionText: '不允许直接修改'),
      ),
      throwsA(isA<JournalPromptOperationException>()),
    );
    await expectLater(
      prompts.deleteUserPrompt(system.id),
      throwsA(isA<JournalPromptOperationException>()),
    );
  });

  test(
    'customizing an enabled system prompt works at the enabled limit',
    () async {
      var configuration = await prompts.ensureInitialized();
      for (
        var index = configuration.activePromptCount;
        index < JournalPromptLimits.enabledPromptCount;
        index += 1
      ) {
        configuration = await prompts.createUserPrompt(
          JournalPromptInput(questionText: '自定义问题 $index'),
        );
      }
      final system = configuration.activePrompts.firstWhere(
        (prompt) => prompt.isSystem,
      );

      final customized = await prompts.duplicateAsUserPrompt(system.id);

      expect(
        customized.activePromptCount,
        JournalPromptLimits.enabledPromptCount,
      );
      expect(
        customized.disabledPrompts.any((item) => item.id == system.id),
        isTrue,
      );
    },
  );

  test('at least one enabled prompt is always retained', () async {
    var configuration = await prompts.ensureInitialized();
    for (final prompt in configuration.activePrompts.take(4).toList()) {
      configuration = await prompts.setPromptEnabled(prompt.id, false);
    }

    await expectLater(
      prompts.setPromptEnabled(configuration.activePrompts.single.id, false),
      throwsA(isA<JournalPromptLimitException>()),
    );
  });

  test('repeating the current enabled state preserves the version', () async {
    final initial = await prompts.ensureInitialized();
    final prompt = initial.activePrompts.first;

    final unchanged = await prompts.setPromptEnabled(prompt.id, true);

    expect(unchanged.configurationVersion, initial.configurationVersion);
    expect(unchanged.updatedAt, initial.updatedAt);
    expect(unchanged.syncStatus, initial.syncStatus);
  });

  test('editing a prompt never rewrites a saved Journal snapshot', () async {
    final configuration = await prompts.ensureInitialized();
    final prompt = configuration.activePrompts.first;
    final journal = JournalRepositoryImpl(
      database: database,
      dateTimeService: clock,
    );
    final item = JournalEntryPromptItem(
      id: '90000000-0000-4000-8000-000000000001',
      sourcePromptId: prompt.id,
      sourcePromptStableKey: prompt.stableKey,
      sourcePromptVersion: prompt.promptVersion,
      promptSource: prompt.source,
      questionTextSnapshot: prompt.questionText,
      helperTextSnapshot: prompt.helperText,
      responseKind: prompt.responseKind,
      displayOrder: 0,
      answerText: '一个稳定的历史回答',
      createdAt: 1,
      updatedAt: 1,
    );
    final saved = await journal.saveTodayEntry(
      JournalSaveData(promptItems: [item]),
    );
    final customized = await prompts.duplicateAsUserPrompt(prompt.id);
    final userPrompt = customized.activePrompts.singleWhere(
      (candidate) => candidate.isUser,
    );
    await prompts.updateUserPrompt(
      userPrompt.id,
      const JournalPromptInput(questionText: '全新的问题文案'),
    );

    final reloaded = await journal.getById(saved.id);
    expect(
      reloaded!.promptItems.single.questionTextSnapshot,
      prompt.questionText,
    );
    expect(reloaded.promptItems.single.answerText, '一个稳定的历史回答');
  });
}
