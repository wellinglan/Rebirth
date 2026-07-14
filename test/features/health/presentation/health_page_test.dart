import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/health/data/health_repository_provider.dart';
import 'package:rebirth/features/health/domain/health_entry.dart';
import 'package:rebirth/features/health/domain/health_repository.dart';
import 'package:rebirth/features/health/domain/health_save_data.dart';
import 'package:rebirth/features/health/domain/health_summary.dart';
import 'package:rebirth/features/health/presentation/health_page.dart';

void main() {
  testWidgets('HealthPage shows loading state', (tester) async {
    final repository = _FakeHealthRepository(loadGate: Completer<void>());
    await _pumpHealthPage(tester, repository);

    expect(find.byKey(const ValueKey('healthLoadingState')), findsOneWidget);
  });

  testWidgets('HealthPage shows error and retries', (tester) async {
    final repository = _FakeHealthRepository(loadError: StateError('failed'));
    await _pumpHealthPage(tester, repository);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('healthErrorState')), findsOneWidget);
    expect(find.text('健康记录暂时无法加载'), findsOneWidget);

    repository.loadError = null;
    await tester.tap(find.byKey(const ValueKey('retryHealthButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('healthDataState')), findsOneWidget);
  });

  testWidgets('data state shows header, form, summary, and empty history', (
    tester,
  ) async {
    final repository = _FakeHealthRepository(history: const []);
    await _pumpHealthPage(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('Health'), findsOneWidget);
    expect(find.text('记录身体状态与恢复质量'), findsOneWidget);
    expect(find.text('今日健康记录'), findsOneWidget);
    expect(find.text('近 7 日摘要'), findsOneWidget);
    expect(find.text('近 30 日历史'), findsOneWidget);
    expect(find.byKey(const ValueKey('saveHealthButton')), findsOneWidget);
    await _ensureVisible(tester, find.byKey(const ValueKey('healthHistoryEmpty')));
    expect(find.text('还没有健康记录'), findsOneWidget);
  });

  testWidgets('empty values remain null and zero remains zero', (tester) async {
    final repository = _FakeHealthRepository(history: const []);
    await _pumpHealthPage(tester, repository);
    await tester.pumpAndSettle();

    await _enterDuration(
      tester,
      const ValueKey('healthSleepDurationField'),
      hours: '0',
      minutes: '0',
    );
    await tester.enterText(
      find.byKey(const ValueKey('healthWaterField')),
      '0',
    );
    await _tapSave(tester);

    expect(repository.lastSaved?.sleepDurationMinutes, 0);
    expect(repository.lastSaved?.waterIntakeMl, 0);
    expect(repository.lastSaved?.weightKg, isNull);
    expect(repository.lastSaved?.exerciseDurationMinutes, isNull);
    expect(repository.lastSaved?.exerciseType, isNull);
    expect(repository.lastSaved?.note, isNull);
    expect(find.text('健康记录已保存'), findsOneWidget);
  });

  testWidgets('negative water shows validation and does not save', (
    tester,
  ) async {
    final repository = _FakeHealthRepository(history: const []);
    await _pumpHealthPage(tester, repository);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('healthWaterField')),
      '-1',
    );
    await _tapSave(tester);

    expect(find.text('请输入非负整数'), findsOneWidget);
    expect(repository.saveAttempts, 0);
  });

  testWidgets('saving disables button and prevents concurrent saves', (
    tester,
  ) async {
    final gate = Completer<void>();
    final repository = _FakeHealthRepository(saveGate: gate, history: const []);
    await _pumpHealthPage(tester, repository);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('healthNoteField')),
      '保存期间保留',
    );
    final button = find.byKey(const ValueKey('saveHealthButton'));
    await _ensureVisible(tester, button);
    await tester.tap(button);
    await tester.pump();

    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    expect(find.text('保存中...'), findsOneWidget);
    expect(_fieldText(tester, 'healthNoteField'), '保存期间保留');
    expect(repository.saveAttempts, 1);

    await tester.tap(button);
    expect(repository.saveAttempts, 1);
    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('failed save keeps input and can retry', (tester) async {
    final repository = _FakeHealthRepository(
      failuresBeforeSuccess: 1,
      history: const [],
    );
    await _pumpHealthPage(tester, repository);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('healthExerciseTypeField')),
      '骑行',
    );
    await _tapSave(tester);

    expect(find.text('保存失败，请重试'), findsOneWidget);
    expect(_fieldText(tester, 'healthExerciseTypeField'), '骑行');
    expect(find.byKey(const ValueKey('healthErrorState')), findsNothing);

    await _tapSave(tester);
    expect(repository.saveAttempts, 2);
    expect(repository.lastSaved?.exerciseType, '骑行');
    expect(find.text('健康记录已保存'), findsOneWidget);
  });

  testWidgets('history card opens a read-only detail dialog', (tester) async {
    final historyEntry = _entry(
      date: '2026-07-13',
      sleep: 450,
      exercise: 30,
      water: 1500,
      weight: 65.5,
    );
    final repository = _FakeHealthRepository(history: [historyEntry]);
    await _pumpHealthPage(tester, repository);
    await tester.pumpAndSettle();

    final item = find.byKey(ValueKey('healthHistory-${historyEntry.id}'));
    await _ensureVisible(tester, item);
    expect(find.text('2026-07-13'), findsOneWidget);
    expect(find.textContaining('睡眠 7小时30分钟'), findsOneWidget);
    await tester.tap(item);
    await tester.pumpAndSettle();

    final dialog = find.byKey(const ValueKey('healthEntryDetailDialog'));
    expect(dialog, findsOneWidget);
    expect(
      find.descendant(of: dialog, matching: find.text('健康记录详情')),
      findsOneWidget,
    );
    expect(find.descendant(of: dialog, matching: find.text('65.5 kg')), findsOneWidget);
    expect(find.descendant(of: dialog, matching: find.text('关闭')), findsOneWidget);
    expect(
      find.descendant(of: dialog, matching: find.byType(TextFormField)),
      findsNothing,
    );
  });

  test('presentation boundaries do not import data implementations', () {
    final healthFiles = Directory('lib/features/health/presentation')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    for (final file in healthFiles) {
      final source = file.readAsStringSync();
      expect(source, isNot(contains('package:drift')));
      expect(source, isNot(contains('app_database.dart')));
      expect(source, isNot(contains('health_repository_impl.dart')));
    }

    final todayFiles = Directory('lib/features/today/presentation')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    for (final file in todayFiles) {
      expect(
        file.readAsStringSync(),
        isNot(contains('features/health/presentation')),
      );
    }
  });
}

Future<void> _pumpHealthPage(
  WidgetTester tester,
  HealthRepository repository,
) async {
  await tester.binding.setSurfaceSize(const Size(900, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [healthRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(home: Scaffold(body: HealthPage())),
    ),
  );
}

Future<void> _tapSave(WidgetTester tester) async {
  final messenger = tester.state<ScaffoldMessengerState>(
    find.byType(ScaffoldMessenger),
  );
  messenger.hideCurrentSnackBar();
  await tester.pumpAndSettle();
  final button = find.byKey(const ValueKey('saveHealthButton'));
  await _ensureVisible(tester, button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _ensureVisible(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
}

Future<void> _enterDuration(
  WidgetTester tester,
  Key key, {
  required String hours,
  required String minutes,
}) async {
  final container = find.byKey(key);
  final fields = find.descendant(of: container, matching: find.byType(TextFormField));
  await _ensureVisible(tester, container);
  await tester.enterText(fields.at(0), hours);
  await tester.enterText(fields.at(1), minutes);
}

String _fieldText(WidgetTester tester, String key) {
  return tester
      .widget<TextFormField>(find.byKey(ValueKey(key)))
      .controller!
      .text;
}

final class _FakeHealthRepository implements HealthRepository {
  _FakeHealthRepository({
    this.loadGate,
    this.saveGate,
    this.loadError,
    this.failuresBeforeSuccess = 0,
    List<HealthEntry>? history,
  }) : history = history ?? [_entry(date: '2026-07-14')];

  final Completer<void>? loadGate;
  final Completer<void>? saveGate;
  Object? loadError;
  int failuresBeforeSuccess;
  List<HealthEntry> history;
  HealthEntry today = _entry(date: '2026-07-14');
  HealthSaveData? lastSaved;
  int saveAttempts = 0;

  @override
  Future<HealthEntry> getToday() async {
    await loadGate?.future;
    if (loadError != null) {
      throw loadError!;
    }
    return today;
  }

  @override
  Future<HealthEntry?> getByDate(String recordDate) async =>
      recordDate == today.recordDate ? today : null;

  @override
  Future<List<HealthEntry>> listRecent({int days = 30}) async => history;

  @override
  Future<List<HealthEntry>> listByDateRange({
    required String startDate,
    required String endDate,
  }) async => history;

  @override
  Future<HealthEntry> saveForDate(HealthSaveData data) async {
    saveAttempts += 1;
    if (failuresBeforeSuccess > 0) {
      failuresBeforeSuccess -= 1;
      throw StateError('save failed');
    }
    await saveGate?.future;
    lastSaved = data;
    today = _entry(
      date: data.recordDate,
      sleep: data.sleepDurationMinutes,
      exercise: data.exerciseDurationMinutes,
      water: data.waterIntakeMl,
      weight: data.weightKg,
      exerciseType: data.exerciseType,
      physicalState: data.physicalStateScore,
      note: data.note,
      updatedAt: today.updatedAt + 1,
    );
    history = today.hasMetrics ? [today] : [];
    return today;
  }

  @override
  Future<HealthSummary> getSummary({int days = 7}) async =>
      HealthSummary.fromEntries(days: days, entries: history);
}

HealthEntry _entry({
  required String date,
  int? sleep,
  int? exercise,
  int? water,
  double? weight,
  String? exerciseType,
  int? physicalState,
  String? note,
  int updatedAt = 1,
}) {
  return HealthEntry(
    id: 'health-$date',
    userId: 'user',
    todayRecordId: null,
    recordDate: date,
    sleepDurationMinutes: sleep,
    weightKg: weight,
    waterIntakeMl: water,
    exerciseDurationMinutes: exercise,
    exerciseType: exerciseType,
    physicalStateScore: physicalState,
    note: note,
    timezoneOffsetMinutes: 480,
    createdAt: 1,
    updatedAt: updatedAt,
  );
}
