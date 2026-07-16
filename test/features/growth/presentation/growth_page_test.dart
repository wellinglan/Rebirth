import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/growth/data/growth_repository_provider.dart';
import 'package:rebirth/features/growth/domain/growth_period.dart';
import 'package:rebirth/features/growth/domain/growth_repository.dart';
import 'package:rebirth/features/growth/domain/growth_snapshot.dart';
import 'package:rebirth/features/growth/presentation/growth_page.dart';
import 'package:rebirth/features/growth/presentation/widgets/growth_period_selector.dart';

import '../growth_test_data.dart';

void main() {
  testWidgets('shows a dedicated initial loading state', (tester) async {
    final gate = Completer<GrowthSnapshot>();
    final repository = _FakeGrowthRepository()
      ..enqueue(GrowthPeriod.sevenDays, gate.future);

    await _pumpGrowthPage(tester, repository);

    expect(find.byKey(const ValueKey('growthLoadingState')), findsOneWidget);
    expect(find.byKey(const ValueKey('growthDataState')), findsNothing);
  });

  testWidgets('shows an initial error and retries successfully', (
    tester,
  ) async {
    final repository = _FakeGrowthRepository(error: StateError('failed'));
    await _pumpGrowthPage(tester, repository);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('growthErrorState')), findsOneWidget);
    expect(find.text('成长趋势暂时无法加载'), findsOneWidget);

    repository.error = null;
    await tester.tap(find.byKey(const ValueKey('retryGrowthButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('growthDataState')), findsOneWidget);
  });

  testWidgets(
    'complete empty data keeps header, selector, range, and calm empty card',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final repository = _FakeGrowthRepository();
      await _pumpGrowthPage(tester, repository);
      await tester.pumpAndSettle();

      expect(find.text('Growth'), findsOneWidget);
      expect(find.text('看见缓慢而真实的变化。'), findsOneWidget);
      expect(find.byType(GrowthPeriodSelector), findsOneWidget);
      expect(find.byKey(const ValueKey('refreshGrowthButton')), findsOneWidget);
      expect(find.text('7月10日 — 7月16日'), findsOneWidget);
      expect(find.byKey(const ValueKey('growthEmptyState')), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          '当前周期暂无成长趋势数据。随着 Today、Health 和 Journal 数据逐渐积累，这里会显示变化。',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('growthDailyDetails')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('growthSummary_research')),
        findsNothing,
      );
      semantics.dispose();
    },
  );

  testWidgets('partial data shows real sections and local empty states', (
    tester,
  ) async {
    final partial = growthTestSnapshot(
      dataForDay: (index, date) => index == 0
          ? const GrowthDayTestData(researchMinutes: 0)
          : const GrowthDayTestData(),
    );
    final repository = _FakeGrowthRepository(
      snapshots: {GrowthPeriod.sevenDays: partial},
    );
    await _pumpGrowthPage(tester, repository);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('growthEmptyState')), findsNothing);
    expect(
      find.byKey(const ValueKey('growthSummary_research')),
      findsOneWidget,
    );
    expect(find.text('0 分钟'), findsOneWidget);
    expect(find.byKey(const ValueKey('growthFocusLineChart')), findsOneWidget);

    await _scrollTo(tester, const ValueKey('growthSleepTrendEmpty'));
    expect(find.byKey(const ValueKey('growthSleepTrendEmpty')), findsOneWidget);
    await _scrollTo(tester, const ValueKey('growthExerciseTrendEmpty'));
    expect(
      find.byKey(const ValueKey('growthExerciseTrendEmpty')),
      findsOneWidget,
    );
  });

  testWidgets('complete data exposes every chart and Journal coverage', (
    tester,
  ) async {
    final repository = _FakeGrowthRepository(
      snapshots: {GrowthPeriod.sevenDays: _completeSnapshot()},
    );
    await _pumpGrowthPage(tester, repository);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('growthFocusLineChart')), findsOneWidget);
    await _scrollTo(tester, const ValueKey('growthSleepLineChart'));
    expect(find.byKey(const ValueKey('growthSleepLineChart')), findsOneWidget);
    await _scrollTo(tester, const ValueKey('growthExerciseBarChart'));
    expect(
      find.byKey(const ValueKey('growthExerciseBarChart')),
      findsOneWidget,
    );
    await _scrollTo(tester, const ValueKey('growthMoodEnergyLineChart'));
    expect(
      find.byKey(const ValueKey('growthMoodEnergyLineChart')),
      findsOneWidget,
    );
    await _scrollTo(tester, const ValueKey('growthJournalCoverage'));
    expect(find.byKey(const ValueKey('growthJournalCoverage')), findsOneWidget);
  });

  testWidgets(
    'seven days is selected by default and thirty-day switch refreshes',
    (tester) async {
      final gate = Completer<GrowthSnapshot>();
      final repository = _FakeGrowthRepository(
        snapshots: {GrowthPeriod.sevenDays: _completeSnapshot()},
      )..enqueue(GrowthPeriod.thirtyDays, gate.future);
      await _pumpGrowthPage(tester, repository);
      await tester.pumpAndSettle();

      expect(_selectedPeriod(tester), {GrowthPeriod.sevenDays});
      await tester.tap(find.byKey(const ValueKey('growthPeriodThirtyDays')));
      await tester.pump();

      expect(_selectedPeriod(tester), {GrowthPeriod.thirtyDays});
      expect(
        find.byKey(const ValueKey('growthRefreshingIndicator')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('growthFocusLineChart')),
        findsOneWidget,
      );

      gate.complete(_completeSnapshot(period: GrowthPeriod.thirtyDays));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('growthRefreshingIndicator')),
        findsNothing,
      );
      expect(find.text('6月17日 — 7月16日'), findsOneWidget);
      expect(repository.calls, [
        GrowthPeriod.sevenDays,
        GrowthPeriod.thirtyDays,
      ]);
    },
  );

  testWidgets(
    'refresh failure retains old charts and shows non-blocking feedback',
    (tester) async {
      final failure = Completer<GrowthSnapshot>();
      final repository = _FakeGrowthRepository(
        snapshots: {GrowthPeriod.sevenDays: _completeSnapshot()},
      )..enqueue(GrowthPeriod.thirtyDays, failure.future);
      await _pumpGrowthPage(tester, repository);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('growthPeriodThirtyDays')));
      await tester.pump();
      failure.completeError(StateError('refresh failed'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('growthRefreshError')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('growthFocusLineChart')),
        findsOneWidget,
      );
      expect(_selectedPeriod(tester), {GrowthPeriod.sevenDays});
    },
  );

  testWidgets('refresh button reloads the currently selected period', (
    tester,
  ) async {
    final repository = _FakeGrowthRepository(
      snapshots: {
        GrowthPeriod.sevenDays: _completeSnapshot(),
        GrowthPeriod.thirtyDays: _completeSnapshot(
          period: GrowthPeriod.thirtyDays,
        ),
      },
    );
    await _pumpGrowthPage(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('growthPeriodThirtyDays')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('refreshGrowthButton')));
    await tester.pumpAndSettle();

    expect(repository.calls, [
      GrowthPeriod.sevenDays,
      GrowthPeriod.thirtyDays,
      GrowthPeriod.thirtyDays,
    ]);
  });

  testWidgets('refresh keeps old content and disables the refresh button', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final gate = Completer<GrowthSnapshot>();
    final repository = _FakeGrowthRepository(
      snapshots: {GrowthPeriod.sevenDays: _completeSnapshot()},
    );
    await _pumpGrowthPage(tester, repository);
    await tester.pumpAndSettle();

    repository.enqueue(GrowthPeriod.sevenDays, gate.future);
    await tester.tap(find.byKey(const ValueKey('refreshGrowthButton')));
    await tester.pump();

    final button = tester.widget<IconButton>(
      find.byKey(const ValueKey('refreshGrowthButton')),
    );
    expect(button.onPressed, isNull);
    expect(
      find.byKey(const ValueKey('growthRefreshingIndicator')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('正在刷新成长趋势'), findsOneWidget);
    final refreshSemantics = tester.widget<Semantics>(
      find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.label == '刷新成长趋势',
      ),
    );
    expect(refreshSemantics.properties.enabled, isFalse);
    expect(find.byKey(const ValueKey('growthFocusLineChart')), findsOneWidget);

    gate.complete(_completeSnapshot());
    await tester.pump();
    await tester.pump();
    semantics.dispose();
  });

  testWidgets('successful refresh atomically replaces the snapshot', (
    tester,
  ) async {
    final replacement = growthTestSnapshot(
      dataForDay: (index, date) =>
          const GrowthDayTestData(researchMinutes: 100),
    );
    final repository = _FakeGrowthRepository(
      snapshots: {GrowthPeriod.sevenDays: _completeSnapshot()},
    );
    await _pumpGrowthPage(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('11 小时 40 分钟'), findsNothing);
    repository.enqueue(GrowthPeriod.sevenDays, Future.value(replacement));
    await tester.tap(find.byKey(const ValueKey('refreshGrowthButton')));
    await tester.pumpAndSettle();

    expect(find.text('11 小时 40 分钟'), findsWidgets);
  });

  testWidgets('refresh error can be retried without losing old content', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final repository = _FakeGrowthRepository(
      snapshots: {GrowthPeriod.sevenDays: _completeSnapshot()},
    );
    await _pumpGrowthPage(tester, repository);
    await tester.pumpAndSettle();

    final failure = Completer<GrowthSnapshot>();
    repository.enqueue(GrowthPeriod.sevenDays, failure.future);
    await tester.tap(find.byKey(const ValueKey('refreshGrowthButton')));
    await tester.pump();
    failure.completeError(StateError('refresh failed'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('growthRefreshError')), findsOneWidget);
    expect(find.byKey(const ValueKey('growthFocusLineChart')), findsOneWidget);
    final failureSemantics = tester.widget<Semantics>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == '刷新失败，已保留上次数据',
      ),
    );
    expect(failureSemantics.properties.liveRegion, isTrue);

    repository.enqueue(
      GrowthPeriod.sevenDays,
      Future.value(_completeSnapshot()),
    );
    await tester.tap(find.byTooltip('重新加载成长趋势'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('growthRefreshError')), findsNothing);
    expect(repository.calls, [
      GrowthPeriod.sevenDays,
      GrowthPeriod.sevenDays,
      GrowthPeriod.sevenDays,
    ]);
    semantics.dispose();
  });

  testWidgets('keyboard can activate refresh and daily details', (
    tester,
  ) async {
    final repository = _FakeGrowthRepository(
      snapshots: {GrowthPeriod.sevenDays: _completeSnapshot()},
    );
    await _pumpGrowthPage(tester, repository);
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(repository.calls, [GrowthPeriod.sevenDays, GrowthPeriod.thirtyDays]);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(repository.calls, [
      GrowthPeriod.sevenDays,
      GrowthPeriod.thirtyDays,
      GrowthPeriod.thirtyDays,
    ]);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('growthDailyDetailsContent')),
      findsOneWidget,
    );
  });

  testWidgets('key period and chart semantics are exposed', (tester) async {
    final semantics = tester.ensureSemantics();
    final repository = _FakeGrowthRepository(
      snapshots: {GrowthPeriod.sevenDays: _completeSnapshot()},
    );
    await _pumpGrowthPage(tester, repository);
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('成长趋势周期选择'), findsOneWidget);
    expect(find.bySemanticsLabel('近 7 天趋势'), findsOneWidget);
    final selectedPeriodSemantics = tester.widget<Semantics>(
      find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.label == '近 7 天趋势',
      ),
    );
    expect(selectedPeriodSemantics.properties.selected, isTrue);
    expect(find.bySemanticsLabel('Growth 成长趋势'), findsOneWidget);
    expect(
      find.bySemanticsLabel('当前周期，近 7 天，日期范围，7月10日 — 7月16日'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('刷新成长趋势'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('科研记录 7 天，学习记录 7 天')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('360px layout scrolls to Journal without overflow', (
    tester,
  ) async {
    final repository = _FakeGrowthRepository(
      snapshots: {GrowthPeriod.sevenDays: _completeSnapshot()},
    );
    await _pumpGrowthPage(tester, repository, size: const Size(360, 780));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await _scrollTo(tester, const ValueKey('growthJournalCoverage'));
    expect(find.byKey(const ValueKey('growthJournalCoverage')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Set<GrowthPeriod> _selectedPeriod(WidgetTester tester) {
  return tester
      .widget<SegmentedButton<GrowthPeriod>>(
        find.byKey(const ValueKey('growthPeriodSelector')),
      )
      .selected;
}

Future<void> _pumpGrowthPage(
  WidgetTester tester,
  GrowthRepository repository, {
  Size size = const Size(900, 1200),
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [growthRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const Scaffold(body: GrowthPage()),
      ),
    ),
  );
}

Future<void> _scrollTo(WidgetTester tester, Key key) async {
  await tester.scrollUntilVisible(
    find.byKey(key),
    500,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

GrowthSnapshot _completeSnapshot({
  GrowthPeriod period = GrowthPeriod.sevenDays,
}) {
  return growthTestSnapshot(
    period: period,
    dataForDay: (index, date) => GrowthDayTestData(
      researchMinutes: index == 0 ? 0 : 30 + index,
      learningMinutes: 45 + index,
      exerciseMinutes: index == 1 ? 0 : 20 + index,
      sleepMinutes: 420 + index,
      moodScore: 1 + index % 5,
      energyScore: 5 - index % 5,
      journalRecorded: index % 3 != 0,
      journalCompleted: index % 3 == 2,
    ),
  );
}

final class _FakeGrowthRepository implements GrowthRepository {
  _FakeGrowthRepository({
    this.error,
    Map<GrowthPeriod, GrowthSnapshot>? snapshots,
  }) : snapshots = snapshots ?? {};

  Object? error;
  final Map<GrowthPeriod, GrowthSnapshot> snapshots;
  final Map<GrowthPeriod, List<Future<GrowthSnapshot>>> _queued = {};
  final List<GrowthPeriod> calls = [];

  void enqueue(GrowthPeriod period, Future<GrowthSnapshot> result) {
    _queued.putIfAbsent(period, () => []).add(result);
  }

  @override
  Future<GrowthSnapshot> loadRecent(GrowthPeriod period) async {
    calls.add(period);
    final queued = _queued[period];
    if (queued != null && queued.isNotEmpty) {
      return queued.removeAt(0);
    }
    if (error != null) {
      throw error!;
    }
    return snapshots[period] ?? growthTestSnapshot(period: period);
  }
}
