import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/journal/data/journal_repository_provider.dart';
import 'package:rebirth/features/journal/domain/journal_entry.dart';
import 'package:rebirth/features/journal/domain/journal_repository.dart';
import 'package:rebirth/features/journal/domain/journal_save_data.dart';
import 'package:rebirth/features/journal/presentation/journal_page.dart';

void main() {
  testWidgets('JournalPage shows loading', (tester) async {
    final loadGate = Completer<JournalEntry?>();
    final repository = _FakeJournalRepository(pendingLoad: loadGate);

    await _pumpJournalPage(tester, repository);

    expect(find.byKey(const ValueKey('journalLoadingState')), findsOneWidget);
  });

  testWidgets('JournalPage shows a gentle initial load error', (tester) async {
    final repository = _FakeJournalRepository(
      loadError: StateError('load failed for test'),
    );

    await _pumpJournalPage(tester, repository);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('journalErrorState')), findsOneWidget);
    expect(find.text('今日复盘暂时无法加载'), findsOneWidget);
    expect(find.byTooltip('重新加载'), findsOneWidget);
  });

  testWidgets('JournalPage shows an empty five-question form', (tester) async {
    final repository = _FakeJournalRepository();
    await _pumpJournalPage(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('今日复盘'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('journalAccomplishmentField')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('journalDrainingField')), findsOneWidget);
    expect(find.byKey(const ValueKey('journalEmotionField')), findsOneWidget);
    expect(find.byKey(const ValueKey('journalLearningField')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('journalAdjustmentField')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('saveJournalButton')), findsOneWidget);
    expect(find.text('最近复盘'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('journalHistoryEmptyState')),
      findsOneWidget,
    );
  });

  testWidgets('history loading does not replace the today form', (
    tester,
  ) async {
    final historyGate = Completer<List<JournalEntry>>();
    final repository = _FakeJournalRepository(pendingHistoryLoad: historyGate);
    await _pumpJournalPage(tester, repository);
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('saveJournalButton')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('journalHistoryLoadingState')),
      findsOneWidget,
    );
  });

  testWidgets('history error has an independent retry action', (tester) async {
    final repository = _FakeJournalRepository(
      historyLoadError: StateError('history failed for test'),
    );
    await _pumpJournalPage(tester, repository);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('saveJournalButton')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('journalHistoryErrorState')),
      findsOneWidget,
    );
    expect(find.text('历史复盘暂时无法加载'), findsOneWidget);

    repository.historyLoadError = null;
    await tester.tap(find.byTooltip('重新加载历史复盘'));
    await tester.pumpAndSettle();

    expect(repository.listRecentCalls, 2);
    expect(
      find.byKey(const ValueKey('journalHistoryEmptyState')),
      findsOneWidget,
    );
  });

  testWidgets('JournalPage fills an existing today entry', (tester) async {
    final repository = _FakeJournalRepository(entry: _sampleEntry());
    await _pumpJournalPage(tester, repository);
    await tester.pumpAndSettle();

    expect(_fieldText(tester, 'journalAccomplishmentField'), '完成关键实验');
    expect(_fieldText(tester, 'journalDrainingField'), '等待实验结果');
    expect(_fieldText(tester, 'journalEmotionField'), '对进度的担心');
    expect(_fieldText(tester, 'journalLearningField'), '先验证最小假设');
    expect(_fieldText(tester, 'journalAdjustmentField'), '优先整理数据');
    expect(find.byKey(const ValueKey('journalHistoryList')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('journalHistoryItem_journal-id')),
      findsOneWidget,
    );
    expect(find.text('完成关键实验'), findsWidgets);
  });

  testWidgets('tapping history opens a read-only detail dialog', (
    tester,
  ) async {
    final historyEntry = _sampleEntry();
    final repository = _FakeJournalRepository(
      entry: historyEntry,
      historyEntries: [historyEntry],
    );
    await _pumpJournalPage(tester, repository);
    await tester.pumpAndSettle();
    final item = find.byKey(const ValueKey('journalHistoryItem_journal-id'));
    await Scrollable.ensureVisible(tester.element(item), alignment: 0.5);
    await tester.tap(item);
    await tester.pumpAndSettle();

    final dialog = find.byKey(const ValueKey('journalEntryDetailDialog'));
    expect(dialog, findsOneWidget);
    expect(
      find.descendant(of: dialog, matching: find.text('2026-07-13')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('今天最重要的完成是什么？')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('完成关键实验')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('等待实验结果')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('对进度的担心')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('先验证最小假设')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('优先整理数据')),
      findsOneWidget,
    );
  });

  testWidgets('all-empty form shows validation and does not save', (
    tester,
  ) async {
    final repository = _FakeJournalRepository();
    await _pumpJournalPage(tester, repository);
    await tester.pumpAndSettle();

    await _tapSave(tester);

    expect(find.text('至少填写一项复盘内容'), findsOneWidget);
    expect(repository.saveAttempts, 0);
  });

  testWidgets('saving one answer succeeds and trims content', (tester) async {
    final repository = _FakeJournalRepository();
    await _pumpJournalPage(tester, repository);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('journalLearningField')),
      '  学会拆分问题  ',
    );
    await _tapSave(tester);

    expect(repository.lastSaved?.learning, '学会拆分问题');
    expect(repository.lastSaved?.mostImportantAccomplishment, isNull);
    expect(find.text('今日复盘已保存'), findsOneWidget);
    expect(repository.listRecentCalls, 2);
    expect(
      find.byKey(const ValueKey('journalHistoryItem_journal-id')),
      findsOneWidget,
    );
  });

  testWidgets('saving disables the button and keeps form content', (
    tester,
  ) async {
    final saveGate = Completer<void>();
    final repository = _FakeJournalRepository(pendingSave: saveGate);
    await _pumpJournalPage(tester, repository);
    await tester.pumpAndSettle();
    final learningField = find.byKey(const ValueKey('journalLearningField'));
    await tester.enterText(learningField, '保存期间保留内容');

    final saveButton = find.byKey(const ValueKey('saveJournalButton'));
    await Scrollable.ensureVisible(tester.element(saveButton), alignment: 0.5);
    await tester.tap(saveButton);
    await tester.pump();

    expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);
    expect(find.text('保存中...'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('journalSaveProgressIndicator')),
      findsOneWidget,
    );
    expect(_fieldText(tester, 'journalLearningField'), '保存期间保留内容');
    expect(repository.saveAttempts, 1);

    await tester.tap(saveButton);
    await tester.pump();
    expect(repository.saveAttempts, 1);

    saveGate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('failed save keeps input and can be retried', (tester) async {
    final repository = _FakeJournalRepository(failuresBeforeSuccess: 1);
    await _pumpJournalPage(tester, repository);
    await tester.pumpAndSettle();
    final emotionField = find.byKey(const ValueKey('journalEmotionField'));
    await tester.enterText(emotionField, '失败后仍然保留');

    await _tapSave(tester);

    expect(find.text('保存失败，请重试'), findsOneWidget);
    expect(_fieldText(tester, 'journalEmotionField'), '失败后仍然保留');
    expect(find.byKey(const ValueKey('journalErrorState')), findsNothing);
    expect(repository.saveAttempts, 1);
    expect(repository.listRecentCalls, 1);

    await _tapSave(tester);
    expect(repository.saveAttempts, 2);
    expect(repository.lastSaved?.emotionSource, '失败后仍然保留');
    expect(find.text('今日复盘已保存'), findsOneWidget);
    expect(repository.listRecentCalls, 2);
  });

  testWidgets('saved content is filled when the page is opened again', (
    tester,
  ) async {
    final repository = _FakeJournalRepository();
    await _pumpJournalPage(tester, repository);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('journalAdjustmentField')),
      '明天先做最重要的事情',
    );
    await _tapSave(tester);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await _pumpJournalPage(tester, repository);
    await tester.pumpAndSettle();

    expect(_fieldText(tester, 'journalAdjustmentField'), '明天先做最重要的事情');
  });

  test('Journal presentation has no database implementation imports', () {
    const paths = <String>[
      'lib/features/journal/presentation/journal_page.dart',
      'lib/features/journal/presentation/journal_controller.dart',
      'lib/features/journal/presentation/journal_today_controller.dart',
      'lib/features/journal/presentation/widgets/journal_form.dart',
      'lib/features/journal/presentation/widgets/journal_question_field.dart',
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

Future<void> _pumpJournalPage(
  WidgetTester tester,
  JournalRepository repository,
) async {
  await tester.binding.setSurfaceSize(const Size(900, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [journalRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(home: Scaffold(body: JournalPage())),
    ),
  );
}

Future<void> _tapSave(WidgetTester tester) async {
  final messenger = tester.state<ScaffoldMessengerState>(
    find.byType(ScaffoldMessenger),
  );
  messenger.hideCurrentSnackBar();
  await tester.pumpAndSettle();
  final saveButton = find.byKey(const ValueKey('saveJournalButton'));
  await Scrollable.ensureVisible(tester.element(saveButton), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(saveButton);
  await tester.pumpAndSettle();
}

String _fieldText(WidgetTester tester, String key) {
  return tester
      .widget<TextFormField>(find.byKey(ValueKey(key)))
      .controller!
      .text;
}

JournalEntry _sampleEntry() {
  return const JournalEntry(
    id: 'journal-id',
    userId: 'user-id',
    todayRecordId: null,
    entryDate: '2026-07-13',
    timezoneOffsetMinutes: 480,
    mostImportantAccomplishment: '完成关键实验',
    mostDrainingEvent: '等待实验结果',
    emotionSource: '对进度的担心',
    learning: '先验证最小假设',
    tomorrowAdjustment: '优先整理数据',
    status: JournalEntryStatus.draft,
    createdAt: 1,
    updatedAt: 1,
  );
}

final class _FakeJournalRepository implements JournalRepository {
  _FakeJournalRepository({
    this.entry,
    this.pendingLoad,
    this.loadError,
    this.pendingSave,
    this.pendingHistoryLoad,
    this.historyLoadError,
    this.historyEntries,
    this.failuresBeforeSuccess = 0,
  });

  JournalEntry? entry;
  final Completer<JournalEntry?>? pendingLoad;
  final Object? loadError;
  final Completer<void>? pendingSave;
  final Completer<List<JournalEntry>>? pendingHistoryLoad;
  Object? historyLoadError;
  final List<JournalEntry>? historyEntries;
  int failuresBeforeSuccess;
  int saveAttempts = 0;
  int listRecentCalls = 0;
  JournalSaveData? lastSaved;

  @override
  Future<JournalEntry?> getTodayEntry() async {
    if (loadError != null) {
      throw loadError!;
    }
    return pendingLoad?.future ?? entry;
  }

  @override
  Future<JournalEntry> saveTodayEntry(JournalSaveData data) async {
    saveAttempts += 1;
    if (failuresBeforeSuccess > 0) {
      failuresBeforeSuccess -= 1;
      throw StateError('save failed for test');
    }
    await pendingSave?.future;
    lastSaved = data;
    final previous = entry;
    entry = JournalEntry(
      id: previous?.id ?? 'journal-id',
      userId: previous?.userId ?? 'user-id',
      todayRecordId: previous?.todayRecordId,
      entryDate: previous?.entryDate ?? '2026-07-13',
      timezoneOffsetMinutes: previous?.timezoneOffsetMinutes ?? 480,
      mostImportantAccomplishment: data.mostImportantAccomplishment,
      mostDrainingEvent: data.mostDrainingEvent,
      emotionSource: data.emotionSource,
      learning: data.learning,
      tomorrowAdjustment: data.tomorrowAdjustment,
      status: data.status,
      createdAt: previous?.createdAt ?? 1,
      updatedAt: (previous?.updatedAt ?? 0) + 1,
    );
    return entry!;
  }

  @override
  Future<JournalEntry> createEntry(JournalSaveData data) =>
      saveTodayEntry(data);

  @override
  Future<JournalEntry?> getById(String id) async =>
      entry?.id == id ? entry : null;

  @override
  Future<List<JournalEntry>> listByDate(String entryDate) async =>
      entry?.entryDate == entryDate ? [entry!] : [];

  @override
  Future<List<JournalEntry>> listByDateRange({
    required String startDate,
    required String endDate,
    int? limit,
  }) async => entry == null ? [] : [entry!];

  @override
  Future<List<JournalEntry>> listRecent({int limit = 20}) async {
    listRecentCalls += 1;
    if (historyLoadError != null) {
      throw historyLoadError!;
    }
    if (pendingHistoryLoad != null) {
      return pendingHistoryLoad!.future;
    }
    final entries = historyEntries ?? (entry == null ? [] : [entry!]);
    return entries.take(limit).toList(growable: false);
  }

  @override
  Future<void> softDelete(String id) async {
    if (entry?.id == id) {
      entry = null;
    }
  }

  @override
  Future<JournalEntry> updateEntry({
    required String id,
    required JournalSaveData data,
  }) => saveTodayEntry(data);
}
