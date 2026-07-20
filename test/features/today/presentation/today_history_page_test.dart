import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/today/data/today_repository_provider.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/today/domain/today_entry.dart';
import 'package:rebirth/features/today/domain/today_repository.dart';
import 'package:rebirth/features/today/presentation/today_history_page.dart';

void main() {
  testWidgets('TodayHistoryPage shows loading', (tester) async {
    final gate = Completer<List<TodayEntry>>();
    final repository = _HistoryRepository(pendingLoad: gate);

    await _pumpHistoryPage(tester, repository);

    expect(
      find.byKey(const ValueKey('todayHistoryLoadingState')),
      findsOneWidget,
    );
  });

  testWidgets('TodayHistoryPage shows empty state', (tester) async {
    final repository = _HistoryRepository();
    await _pumpHistoryPage(tester, repository);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('todayHistoryPage')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('todayHistoryEmptyState')),
      findsOneWidget,
    );
  });

  testWidgets('history error shows retry and can recover', (tester) async {
    final repository = _HistoryRepository(
      loadError: StateError('history failed for test'),
    );
    await _pumpHistoryPage(tester, repository);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('todayHistoryErrorState')),
      findsOneWidget,
    );
    expect(find.text('历史记录暂时无法加载'), findsOneWidget);

    repository.loadError = null;
    await tester.tap(find.byTooltip('重新加载历史记录'));
    await tester.pumpAndSettle();

    expect(repository.loadAttempts, 2);
    expect(
      find.byKey(const ValueKey('todayHistoryEmptyState')),
      findsOneWidget,
    );
  });

  testWidgets('history data shows date and summary', (tester) async {
    final repository = _HistoryRepository(entries: [_sampleHistoryEntry()]);
    await _pumpHistoryPage(tester, repository);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('todayHistoryList')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('todayHistoryItem_history-id')),
      findsOneWidget,
    );
    expect(find.text('2026-07-12'), findsOneWidget);
    expect(find.text('完成实验'), findsOneWidget);
    expect(find.text('Mood 4 · Energy 3'), findsOneWidget);
    expect(find.text('科研 1小时30分钟 · 学习 0分钟'), findsOneWidget);
    expect(find.text('历史记录摘要'), findsOneWidget);
    expect(find.text('已记录'), findsOneWidget);
    expect(find.text('草稿'), findsNothing);
  });

  testWidgets('history item opens a complete read-only detail', (tester) async {
    final repository = _HistoryRepository(entries: [_sampleHistoryEntry()]);
    await _pumpHistoryPage(tester, repository);
    await tester.pumpAndSettle();
    final item = find.byKey(const ValueKey('todayHistoryItem_history-id'));
    await tester.tap(item);
    await tester.pumpAndSettle();

    final dialog = find.byKey(const ValueKey('todayEntryDetailDialog'));
    expect(dialog, findsOneWidget);
    for (final text in [
      '完成实验',
      '阅读论文',
      'Mood',
      'Energy',
      '科研时间',
      '学习时间',
      '历史记录摘要',
      '睡眠时长',
      '运动时长',
      '身体状态',
      '已记录',
      '1小时30分钟',
      '7小时30分钟',
      '30分钟',
      '0分钟',
    ]) {
      expect(
        find.descendant(of: dialog, matching: find.text(text)),
        findsWidgets,
      );
    }
    expect(
      find.descendant(of: dialog, matching: find.text('保存')),
      findsNothing,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('编辑')),
      findsNothing,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('删除')),
      findsNothing,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('草稿')),
      findsNothing,
    );
  });

  testWidgets('exact date opens only the matching read-only detail once', (
    tester,
  ) async {
    final repository = _HistoryRepository(
      entries: [
        _sampleHistoryEntry(),
        _sampleHistoryEntry(
          id: 'other-id',
          recordDate: '2026-07-11',
          dailyNote: '其他日期',
        ),
      ],
    );
    await _pumpHistoryPage(
      tester,
      repository,
      targetDate: '2026-07-12',
    );
    await tester.pumpAndSettle();

    final dialog = find.byKey(const ValueKey('todayEntryDetailDialog'));
    expect(dialog, findsOneWidget);
    expect(
      find.descendant(of: dialog, matching: find.text('历史记录摘要')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('其他日期')),
      findsNothing,
    );
    expect(repository.getByDateCalls, 1);

    tester
        .element(find.byKey(const ValueKey('todayHistoryPage')))
        .markNeedsBuild();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('todayEntryDetailDialog')), findsOneWidget);

    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('todayEntryDetailDialog')), findsNothing);
    tester
        .element(find.byKey(const ValueKey('todayHistoryPage')))
        .markNeedsBuild();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('todayEntryDetailDialog')), findsNothing);
  });

  testWidgets('missing exact date stays on history and explains the result', (
    tester,
  ) async {
    final repository = _HistoryRepository(entries: [_sampleHistoryEntry()]);
    await _pumpHistoryPage(
      tester,
      repository,
      targetDate: '2026-07-10',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('todayHistoryPage')), findsOneWidget);
    expect(find.text('未找到 2026-07-10 的 Today 记录。'), findsOneWidget);
    expect(find.byKey(const ValueKey('todayEntryDetailDialog')), findsNothing);
  });

  testWidgets('invalid exact date is safe and skips repository lookup', (
    tester,
  ) async {
    final repository = _HistoryRepository(entries: [_sampleHistoryEntry()]);
    await _pumpHistoryPage(
      tester,
      repository,
      targetDate: '2026-02-30',
    );
    await tester.pumpAndSettle();

    expect(find.text('日期参数无效，无法定位 Today 记录。'), findsOneWidget);
    expect(repository.getByDateCalls, 0);
    expect(find.byKey(const ValueKey('todayEntryDetailDialog')), findsNothing);
  });

  test('Today history presentation has no database implementation imports', () {
    const paths = <String>[
      'lib/features/today/presentation/today_history_controller.dart',
      'lib/features/today/presentation/today_history_page.dart',
      'lib/features/today/presentation/widgets/today_history_list.dart',
      'lib/features/today/presentation/widgets/today_history_card.dart',
      'lib/features/today/presentation/widgets/today_entry_detail_dialog.dart',
      'lib/features/today/presentation/widgets/today_history_formatters.dart',
    ];

    for (final path in paths) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('package:drift')));
      expect(source, isNot(contains('app_database')));
      expect(source, isNot(contains('today_repository_impl.dart')));
    }
  });
}

Future<void> _pumpHistoryPage(
  WidgetTester tester,
  TodayRepository repository, {
  String? targetDate,
}) async {
  await tester.binding.setSurfaceSize(const Size(900, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        todayRepositoryProvider.overrideWithValue(repository),
        dateTimeServiceProvider.overrideWithValue(
          DateTimeService(now: () => DateTime(2026, 7, 14, 9)),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(body: TodayHistoryPage(targetDate: targetDate)),
      ),
    ),
  );
}

TodayEntry _sampleHistoryEntry({
  String id = 'history-id',
  String recordDate = '2026-07-12',
  String dailyNote = '历史记录摘要',
}) {
  return TodayEntry(
    id: id,
    userId: 'user-id',
    recordDate: recordDate,
    timezoneOffsetMinutes: 480,
    priorities: const [
      TodayPriority(text: '完成实验', completed: true),
      TodayPriority(text: '阅读论文'),
      TodayPriority(),
    ],
    moodScore: 4,
    energyScore: 3,
    researchMinutes: 90,
    learningMinutes: 0,
    dailyNote: dailyNote,
    status: TodayRecordStatus.completed,
    createdAt: 1,
    updatedAt: 2,
    health: const TodayHealthSummary(
      id: 'health-id',
      sleepDurationMinutes: 450,
      exerciseDurationMinutes: 30,
      physicalStateScore: 4,
    ),
  );
}

final class _HistoryRepository implements TodayRepository {
  _HistoryRepository({
    List<TodayEntry> entries = const [],
    this.pendingLoad,
    this.loadError,
  }) : entries = List.of(entries);

  final List<TodayEntry> entries;
  final Completer<List<TodayEntry>>? pendingLoad;
  Object? loadError;
  int loadAttempts = 0;
  int getByDateCalls = 0;

  @override
  Future<TodayEntry?> getByDate(String recordDate) async {
    getByDateCalls += 1;
    for (final entry in entries) {
      if (entry.recordDate == recordDate) return entry;
    }
    return null;
  }

  @override
  Future<List<TodayEntry>> listRecentEntries({int days = 30}) async {
    loadAttempts += 1;
    if (loadError != null) {
      throw loadError!;
    }
    return pendingLoad?.future ?? entries;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
