import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/journal/data/journal_prompt_repository_provider.dart';
import 'package:rebirth/features/journal/domain/journal_entry.dart';
import 'package:rebirth/features/journal/domain/journal_entry_prompt_item.dart';
import 'package:rebirth/features/journal/domain/journal_prompt.dart';
import 'package:rebirth/features/journal/domain/journal_prompt_repository.dart';
import 'package:rebirth/features/journal/domain/journal_save_data.dart';
import 'package:rebirth/features/journal/presentation/journal_prompt_management_page.dart';
import 'package:rebirth/features/journal/presentation/widgets/journal_form.dart';

void main() {
  testWidgets('dynamic custom prompt renders and saves by item identity', (
    tester,
  ) async {
    JournalSaveData? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: JournalForm(
              entry: null,
              recordDate: '2026-07-29',
              prompts: [_prompt()],
              onSaveDraft: (data) async => saved = data,
              onComplete: (_) async {},
            ),
          ),
        ),
      ),
    );

    final field = find.widgetWithText(
      TextFormField,
      '今天还有什么值得记录？',
    );
    expect(field, findsOneWidget);
    expect(find.text('今天还有什么值得记录？'), findsOneWidget);
    await tester.enterText(field, '  一段自定义回答  ');
    await tester.tap(find.byKey(const ValueKey('saveJournalButton')));
    await tester.pumpAndSettle();

    expect(saved!.promptItems, hasLength(1));
    expect(saved!.promptItems!.single.sourcePromptId, _prompt().id);
    expect(saved!.promptItems!.single.answerText, '一段自定义回答');
  });

  testWidgets(
    'historical entry renders its snapshot instead of latest prompt',
    (tester) async {
      final prompt = _prompt();
      final saved = JournalEntry(
        id: 'b0000000-0000-4000-8000-000000000010',
        userId: 'user',
        todayRecordId: null,
        entryDate: '2026-07-28',
        timezoneOffsetMinutes: 480,
        promptItems: [_itemFrom(prompt, question: '历史问题文案', answer: '历史回答')],
        status: JournalEntryStatus.draft,
        createdAt: 1,
        updatedAt: 1,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: JournalForm(
                entry: saved,
                recordDate: saved.entryDate,
                prompts: [_copyPrompt(prompt, question: '最新问题文案')],
                onSaveDraft: (_) async {},
                onComplete: (_) async {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('历史问题文案'), findsOneWidget);
      expect(find.text('最新问题文案'), findsNothing);
    },
  );

  testWidgets('prompt management is readable at 320px and text scale 2', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _MemoryPromptRepository(
      JournalPromptConfiguration(
        id: 'b0000000-0000-4000-8000-000000000001',
        userId: 'user',
        logicalKey: 'default',
        configurationVersion: 1,
        createdAt: 1,
        updatedAt: 1,
        syncStatus: 'pending',
        serverVersion: null,
        lastSyncedAt: null,
        originDeviceId: null,
        deletedAt: null,
        prompts: [_prompt()],
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          journalPromptRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const JournalPromptManagementPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('复盘问题'), findsOneWidget);
    expect(find.text('使用中的问题'), findsOneWidget);
    expect(find.textContaining('自定义问题'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('add prompt dialog validates and creates through controller', (
    tester,
  ) async {
    final repository = _MemoryPromptRepository(
      JournalPromptConfiguration(
        id: 'b0000000-0000-4000-8000-000000000001',
        userId: 'user',
        logicalKey: 'default',
        configurationVersion: 1,
        createdAt: 1,
        updatedAt: 1,
        syncStatus: 'synced',
        serverVersion: 1,
        lastSyncedAt: 1,
        originDeviceId: null,
        deletedAt: null,
        prompts: [_prompt()],
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          journalPromptRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: JournalPromptManagementPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('addJournalPromptButton')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('journalPromptQuestionField')),
      '一个新增问题',
    );
    await tester.tap(find.byKey(const ValueKey('saveJournalPromptButton')));
    await tester.pumpAndSettle();

    expect(repository.created?.questionText, '一个新增问题');
    expect(
      find.byKey(const ValueKey('journalPromptEditorDialog')),
      findsNothing,
    );
  });
}

JournalPromptDefinition _prompt() {
  return const JournalPromptDefinition(
    id: 'b0000000-0000-4000-8000-000000000002',
    configurationId: 'b0000000-0000-4000-8000-000000000001',
    stableKey: null,
    source: JournalPromptSource.user,
    questionText: '今天还有什么值得记录？',
    helperText: '只写对你有意义的部分',
    responseKind: JournalResponseKind.longText,
    displayOrder: 0,
    isEnabled: true,
    promptVersion: 1,
    createdAt: 1,
    updatedAt: 1,
    deletedAt: null,
  );
}

JournalPromptDefinition _copyPrompt(
  JournalPromptDefinition source, {
  required String question,
}) {
  return JournalPromptDefinition(
    id: source.id,
    configurationId: source.configurationId,
    stableKey: source.stableKey,
    source: source.source,
    questionText: question,
    helperText: source.helperText,
    responseKind: source.responseKind,
    displayOrder: source.displayOrder,
    isEnabled: source.isEnabled,
    promptVersion: source.promptVersion + 1,
    createdAt: source.createdAt,
    updatedAt: source.updatedAt + 1,
    deletedAt: null,
  );
}

JournalEntryPromptItem _itemFrom(
  JournalPromptDefinition prompt, {
  required String question,
  required String answer,
}) {
  return JournalEntryPromptItem(
    id: 'b0000000-0000-4000-8000-000000000003',
    sourcePromptId: prompt.id,
    sourcePromptStableKey: prompt.stableKey,
    sourcePromptVersion: prompt.promptVersion,
    promptSource: prompt.source,
    questionTextSnapshot: question,
    helperTextSnapshot: prompt.helperText,
    responseKind: prompt.responseKind,
    displayOrder: prompt.displayOrder,
    answerText: answer,
    createdAt: 1,
    updatedAt: 1,
  );
}

final class _MemoryPromptRepository implements JournalPromptRepository {
  _MemoryPromptRepository(this.configuration);

  JournalPromptConfiguration configuration;
  JournalPromptInput? created;

  @override
  Future<JournalPromptConfiguration> ensureInitialized() async => configuration;

  @override
  Future<JournalPromptConfiguration> getConfiguration() async => configuration;

  @override
  Future<JournalPromptConfiguration> createUserPrompt(
    JournalPromptInput input,
  ) async {
    created = input;
    return configuration;
  }

  @override
  Future<JournalPromptConfiguration> deleteUserPrompt(String promptId) async =>
      configuration;

  @override
  Future<JournalPromptConfiguration> duplicateAsUserPrompt(
    String promptId,
  ) async => configuration;

  @override
  Future<JournalPromptConfiguration> reorderPrompts(
    List<String> enabledPromptIds,
  ) async => configuration;

  @override
  Future<JournalPromptConfiguration> setPromptEnabled(
    String promptId,
    bool isEnabled,
  ) async => configuration;

  @override
  Future<JournalPromptConfiguration> updateUserPrompt(
    String promptId,
    JournalPromptInput input,
  ) async => configuration;
}
