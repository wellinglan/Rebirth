import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rebirth/core/router/route_names.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/journal/data/journal_prompt_repository_provider.dart';
import 'package:rebirth/features/journal/data/journal_repository_provider.dart';
import 'package:rebirth/features/journal/domain/journal_entry.dart';
import 'package:rebirth/features/journal/domain/journal_prompt.dart';
import 'package:rebirth/features/journal/domain/journal_prompt_repository.dart';
import 'package:rebirth/features/journal/domain/journal_repository.dart';
import 'package:rebirth/features/journal/domain/journal_save_data.dart';
import 'package:rebirth/features/journal/presentation/journal_history_page.dart';
import 'package:rebirth/features/journal/presentation/journal_page.dart';

void main() {
  testWidgets('JournalHistoryPage shows loading independently', (tester) async {
    final gate = Completer<List<JournalEntry>>();
    final repository = _HistoryJournalRepository(pendingHistory: gate);

    await _pumpHistoryPage(tester, repository);

    expect(
      find.byKey(const ValueKey('journalHistoryLoadingState')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('journalPage')), findsNothing);
  });

  testWidgets('history empty and retryable error states stay on history page', (
    tester,
  ) async {
    final repository = _HistoryJournalRepository(
      historyError: StateError('history unavailable'),
    );
    await _pumpHistoryPage(tester, repository);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('journalHistoryPage')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('journalHistoryErrorState')),
      findsOneWidget,
    );

    repository.historyError = null;
    await tester.tap(find.byTooltip('重新加载历史复盘'));
    await tester.pumpAndSettle();

    expect(repository.listRecentCalls, 2);
    expect(
      find.byKey(const ValueKey('journalHistoryEmptyState')),
      findsOneWidget,
    );
  });

  testWidgets('history detail exposes edit and confirmed delete actions', (
    tester,
  ) async {
    final repository = _HistoryJournalRepository(
      historyEntries: [_historyEntry()],
    );
    await _pumpHistoryPage(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('journalHistoryItem_history-id')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('journalEntryDetailDialog')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('editJournalFromHistoryButton')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('journalEntryDetailDialog')),
        matching: find.text('历史复盘 · 草稿'),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('deleteJournalFromHistoryButton')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirmDeleteJournalButton')));
    await tester.pumpAndSettle();

    expect(repository.deletedIds, ['history-id']);
    expect(
      find.byKey(const ValueKey('journalHistoryEmptyState')),
      findsOneWidget,
    );
  });

  testWidgets('history navigation preserves current unsaved Journal text', (
    tester,
  ) async {
    final repository = _HistoryJournalRepository(
      todayEntry: _todayEntry(),
      historyEntries: [_historyEntry()],
    );
    final router = GoRouter(
      initialLocation: RoutePaths.journal,
      routes: [
        GoRoute(
          path: RoutePaths.journal,
          builder: (context, state) => Scaffold(
            body: JournalPage(targetDate: state.uri.queryParameters['date']),
          ),
          routes: [
            GoRoute(
              path: 'history',
              builder: (context, state) =>
                  const Scaffold(body: JournalHistoryPage()),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await _pumpRouter(tester, repository, router);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('journalLearningField')),
      '尚未保存但应当保留',
    );

    await tester.tap(find.byKey(const ValueKey('openJournalHistoryButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('journalHistoryPage')), findsOneWidget);
    expect(repository.listRecentCalls, 1);

    await tester.tap(
      find.byKey(const ValueKey('journalHistoryItem_history-id')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('editJournalFromHistoryButton')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('journalHistoricalEditorPage')),
      findsOneWidget,
    );
    expect(_fieldText(tester, 'journalLearningField'), '历史学习');

    await tester.tap(
      find.byKey(const ValueKey('journalHistoricalEditorBackButton')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('journalHistoryBackButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('journalPage')), findsOneWidget);
    expect(_fieldText(tester, 'journalLearningField'), '尚未保存但应当保留');
  });

  test('Journal history presentation has no data implementation imports', () {
    const paths = <String>[
      'lib/features/journal/presentation/journal_history_page.dart',
      'lib/features/journal/presentation/widgets/journal_history_list.dart',
      'lib/features/journal/presentation/widgets/journal_history_card.dart',
      'lib/features/journal/presentation/widgets/journal_entry_detail_dialog.dart',
    ];
    for (final path in paths) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('package:drift')));
      expect(source, isNot(contains('app_database')));
      expect(source, isNot(contains('journal_repository_impl.dart')));
    }
  });
}

Future<void> _pumpHistoryPage(
  WidgetTester tester,
  JournalRepository repository,
) async {
  await tester.binding.setSurfaceSize(const Size(900, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        journalRepositoryProvider.overrideWithValue(repository),
        dateTimeServiceProvider.overrideWithValue(
          DateTimeService(now: () => DateTime(2026, 7, 14, 9)),
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: JournalHistoryPage())),
    ),
  );
}

Future<void> _pumpRouter(
  WidgetTester tester,
  JournalRepository repository,
  GoRouter router,
) async {
  await tester.binding.setSurfaceSize(const Size(900, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        journalRepositoryProvider.overrideWithValue(repository),
        journalPromptRepositoryProvider.overrideWithValue(
          _HistoryPromptRepository(),
        ),
        dateTimeServiceProvider.overrideWithValue(
          DateTimeService(now: () => DateTime(2026, 7, 14, 9)),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
}

String _fieldText(WidgetTester tester, String key) {
  return tester
      .widget<TextFormField>(find.byKey(ValueKey(key)))
      .controller!
      .text;
}

JournalEntry _todayEntry() => const JournalEntry(
  id: 'today-id',
  userId: 'user-id',
  todayRecordId: null,
  entryDate: '2026-07-14',
  timezoneOffsetMinutes: 480,
  learning: '今日学习',
  status: JournalEntryStatus.draft,
  createdAt: 1,
  updatedAt: 1,
);

JournalEntry _historyEntry() => const JournalEntry(
  id: 'history-id',
  userId: 'user-id',
  todayRecordId: null,
  entryDate: '2026-07-13',
  timezoneOffsetMinutes: 480,
  mostImportantAccomplishment: '历史完成',
  mostDrainingEvent: '历史消耗',
  emotionSource: '历史情绪',
  learning: '历史学习',
  tomorrowAdjustment: '历史调整',
  status: JournalEntryStatus.draft,
  createdAt: 1,
  updatedAt: 1,
);

final class _HistoryJournalRepository implements JournalRepository {
  _HistoryJournalRepository({
    this.todayEntry,
    List<JournalEntry> historyEntries = const [],
    this.pendingHistory,
    this.historyError,
  }) : historyEntries = List.of(historyEntries);

  JournalEntry? todayEntry;
  final List<JournalEntry> historyEntries;
  final Completer<List<JournalEntry>>? pendingHistory;
  Object? historyError;
  int listRecentCalls = 0;
  final List<String> deletedIds = [];

  @override
  Future<JournalEntry?> getTodayEntry() async => todayEntry;

  @override
  Future<List<JournalEntry>> listRecent({int limit = 20}) async {
    listRecentCalls += 1;
    if (historyError != null) throw historyError!;
    if (pendingHistory != null) return pendingHistory!.future;
    return historyEntries.take(limit).toList(growable: false);
  }

  @override
  Future<List<JournalEntry>> listByDate(String entryDate) async =>
      historyEntries
          .where((entry) => entry.entryDate == entryDate)
          .toList(growable: false);

  @override
  Future<void> softDelete(String id) async {
    deletedIds.add(id);
    historyEntries.removeWhere((entry) => entry.id == id);
  }

  @override
  Future<JournalEntry> updateEntry({
    required String id,
    required JournalSaveData data,
  }) async {
    final index = historyEntries.indexWhere((entry) => entry.id == id);
    final previous = historyEntries[index];
    final saved = JournalEntry(
      id: previous.id,
      userId: previous.userId,
      todayRecordId: previous.todayRecordId,
      entryDate: previous.entryDate,
      timezoneOffsetMinutes: previous.timezoneOffsetMinutes,
      mostImportantAccomplishment: data.mostImportantAccomplishment,
      mostDrainingEvent: data.mostDrainingEvent,
      emotionSource: data.emotionSource,
      learning: data.learning,
      tomorrowAdjustment: data.tomorrowAdjustment,
      promptItems: data.promptItems,
      status: data.status,
      createdAt: previous.createdAt,
      updatedAt: previous.updatedAt + 1,
    );
    historyEntries[index] = saved;
    return saved;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _HistoryPromptRepository implements JournalPromptRepository {
  JournalPromptConfiguration get _configuration => JournalPromptConfiguration(
    id: 'configuration-id',
    userId: 'user-id',
    logicalKey: 'default',
    configurationVersion: 1,
    createdAt: 1,
    updatedAt: 1,
    syncStatus: 'synced',
    serverVersion: 1,
    lastSyncedAt: 1,
    originDeviceId: 'device-id',
    deletedAt: null,
    prompts: [],
  );

  @override
  Future<JournalPromptConfiguration> ensureInitialized() async =>
      _configuration;

  @override
  Future<JournalPromptConfiguration> getConfiguration() async => _configuration;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
