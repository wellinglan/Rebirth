import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/today/data/today_repository_provider.dart';
import 'package:rebirth/features/today/domain/today_entry.dart';
import 'package:rebirth/features/today/domain/today_repository.dart';
import 'package:rebirth/features/today/domain/today_save_data.dart';
import 'package:rebirth/features/today/presentation/today_page.dart';
import 'package:rebirth/features/today/presentation/today_history_controller.dart';

void main() {
  testWidgets('TodayPage renders loading state', (tester) async {
    final pending = Completer<TodayEntry>();
    final repository = _FakeTodayRepository(
      entry: _sampleEntry(),
      pendingLoad: pending,
    );

    await _pumpTodayPage(tester, repository);

    expect(find.byKey(const ValueKey('todayLoadingState')), findsOneWidget);
  });

  testWidgets('TodayPage renders error state', (tester) async {
    final repository = _FakeTodayRepository(
      entry: _sampleEntry(),
      loadError: StateError('test error'),
    );

    await _pumpTodayPage(tester, repository);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('todayErrorState')), findsOneWidget);
    expect(find.text('今日数据暂时无法加载'), findsOneWidget);
  });

  testWidgets('TodayPage shows an empty TodayEntry form', (tester) async {
    final repository = _FakeTodayRepository(entry: _sampleEntry());

    await _pumpTodayPage(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('2026-07-13'), findsOneWidget);
    expect(find.byKey(const ValueKey('todayEmptyState')), findsOneWidget);
    expect(find.byKey(const ValueKey('saveTodayButton')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('openTodayHistoryButton')),
      findsOneWidget,
    );
  });

  testWidgets('TodayPage displays values from an existing TodayEntry', (
    tester,
  ) async {
    final repository = _FakeTodayRepository(
      entry: _sampleEntry(
        priorities: const <TodayPriority>[
          TodayPriority(text: '完成实验', completed: true),
          TodayPriority(text: '阅读论文'),
          TodayPriority(),
        ],
        moodScore: 4,
        energyScore: 3,
        researchMinutes: 45,
        dailyNote: '已有的一句话',
      ),
    );

    await _pumpTodayPage(tester, repository);
    await tester.pumpAndSettle();

    expect(_fieldText(tester, 'priority1Field'), '完成实验');
    expect(_durationPartText(tester, 'researchMinutesField', 0), '0');
    expect(_durationPartText(tester, 'researchMinutesField', 1), '45');
    expect(_fieldText(tester, 'dailyNoteField'), '已有的一句话');
    expect(find.byKey(const ValueKey('todayEmptyState')), findsNothing);
  });

  testWidgets('editing daily note saves through TodayController', (
    tester,
  ) async {
    final repository = _FakeTodayRepository(entry: _sampleEntry());
    await _pumpTodayPage(tester, repository);
    await tester.pumpAndSettle();

    final noteField = find.byKey(const ValueKey('dailyNoteField'));
    await tester.ensureVisible(noteField);
    await tester.enterText(noteField, '今天完成了关键实验');
    await _tapSave(tester);

    expect(repository.lastSaved?.dailyNote, '今天完成了关键实验');
    expect(find.text('今日记录已保存'), findsOneWidget);
    expect(_fieldText(tester, 'dailyNoteField'), '今天完成了关键实验');
  });

  testWidgets('successful save invalidates previously loaded history', (
    tester,
  ) async {
    final repository = _FakeTodayRepository(entry: _sampleEntry());
    await _pumpTodayPage(tester, repository);
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TodayPage)),
    );
    await container.read(todayHistoryControllerProvider.future);
    expect(repository.historyLoadAttempts, 1);

    await tester.enterText(
      find.byKey(const ValueKey('dailyNoteField')),
      '刷新历史记录',
    );
    await _tapSave(tester);
    await container.read(todayHistoryControllerProvider.future);

    expect(repository.historyLoadAttempts, 2);
  });

  testWidgets('saving disables button and keeps the form visible', (
    tester,
  ) async {
    final saveGate = Completer<void>();
    final repository = _FakeTodayRepository(
      entry: _sampleEntry(),
      pendingSave: saveGate,
    );
    await _pumpTodayPage(tester, repository);
    await tester.pumpAndSettle();

    final noteField = find.byKey(const ValueKey('dailyNoteField'));
    await tester.ensureVisible(noteField);
    await tester.enterText(noteField, '保存期间保留这段内容');
    final saveButton = find.byKey(const ValueKey('saveTodayButton'));
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pump();

    expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);
    expect(find.text('保存中...'), findsOneWidget);
    expect(find.byKey(const ValueKey('saveProgressIndicator')), findsOneWidget);
    expect(find.byKey(const ValueKey('todayLoadingState')), findsNothing);
    expect(_fieldText(tester, 'dailyNoteField'), '保存期间保留这段内容');
    expect(repository.saveAttempts, 1);

    await tester.tap(saveButton);
    await tester.pump();
    expect(repository.saveAttempts, 1);

    saveGate.complete();
    await tester.pumpAndSettle();
    expect(find.text('今日记录已保存'), findsOneWidget);
  });

  testWidgets('failed save keeps input and can be retried', (tester) async {
    final repository = _FakeTodayRepository(
      entry: _sampleEntry(),
      failuresBeforeSuccess: 1,
    );
    await _pumpTodayPage(tester, repository);
    await tester.pumpAndSettle();

    final noteField = find.byKey(const ValueKey('dailyNoteField'));
    await tester.ensureVisible(noteField);
    await tester.enterText(noteField, '失败后不能丢失');
    await _tapSave(tester);

    expect(find.text('保存失败，请重试'), findsOneWidget);
    expect(_fieldText(tester, 'dailyNoteField'), '失败后不能丢失');
    expect(repository.saveAttempts, 1);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('saveTodayButton')))
          .onPressed,
      isNotNull,
    );

    await _tapSave(tester);
    expect(repository.saveAttempts, 2);
    expect(repository.lastSaved?.dailyNote, '失败后不能丢失');
    expect(find.text('今日记录已保存'), findsOneWidget);
  });

  testWidgets('research minutes keeps empty and zero distinct', (tester) async {
    final repository = _FakeTodayRepository(entry: _sampleEntry());
    await _pumpTodayPage(tester, repository);
    await tester.pumpAndSettle();

    expect(_durationPartText(tester, 'researchMinutesField', 0), isEmpty);
    expect(_durationPartText(tester, 'researchMinutesField', 1), isEmpty);

    await _enterDuration(tester, 'researchMinutesField', '0', '0');
    await _tapSave(tester);
    expect(repository.lastSaved?.researchMinutes, 0);
    expect(repository.lastSaved?.moodScore, isNull);
    expect(repository.lastSaved?.energyScore, isNull);
    expect(repository.lastSaved?.health, isNull);

    await _enterDuration(tester, 'researchMinutesField', '', '');
    await _tapSave(tester);
    expect(repository.lastSaved?.researchMinutes, isNull);
  });

  testWidgets('hour and minute fields save total minutes', (tester) async {
    final repository = _FakeTodayRepository(entry: _sampleEntry());
    await _pumpTodayPage(tester, repository);
    await tester.pumpAndSettle();

    await _enterDuration(tester, 'researchMinutesField', '1', '30');
    await _enterDuration(tester, 'learningMinutesField', '0', '0');
    await _enterDuration(tester, 'sleepMinutesField', '7', '30');
    await _tapSave(tester);

    expect(repository.lastSaved?.researchMinutes, 90);
    expect(repository.lastSaved?.learningMinutes, 0);
    expect(repository.lastSaved?.health?.sleepDurationMinutes, 450);
  });

  testWidgets('minute 60 and invalid text do not save or lose input', (
    tester,
  ) async {
    final repository = _FakeTodayRepository(entry: _sampleEntry());
    await _pumpTodayPage(tester, repository);
    await tester.pumpAndSettle();

    await _enterDuration(tester, 'researchMinutesField', '1', '60');
    await _tapSave(tester);

    expect(find.text('分钟需小于 60'), findsOneWidget);
    expect(repository.lastSaved, isNull);
    expect(repository.saveAttempts, 0);
    expect(_durationPartText(tester, 'researchMinutesField', 0), '1');
    expect(_durationPartText(tester, 'researchMinutesField', 1), '60');

    await tester.enterText(
      _durationPart('researchMinutesField', 1),
      'not-an-integer',
    );
    await _tapSave(tester);
    expect(find.text('请输入 0–59 的整数'), findsOneWidget);
    expect(repository.saveAttempts, 0);
    expect(
      _durationPartText(tester, 'researchMinutesField', 1),
      'not-an-integer',
    );
  });

  testWidgets('duration quick chip fills fields and saves total minutes', (
    tester,
  ) async {
    final repository = _FakeTodayRepository(entry: _sampleEntry());
    await _pumpTodayPage(tester, repository);
    await tester.pumpAndSettle();

    final research = find.byKey(const ValueKey('researchMinutesField'));
    await Scrollable.ensureVisible(tester.element(research), alignment: 0.4);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: research, matching: find.text('1小时30分钟')),
    );
    await tester.pump();

    expect(_durationPartText(tester, 'researchMinutesField', 0), '1');
    expect(_durationPartText(tester, 'researchMinutesField', 1), '30');
    await _tapSave(tester);
    expect(repository.lastSaved?.researchMinutes, 90);
  });

  testWidgets('clearing priority text also clears completed state', (
    tester,
  ) async {
    final repository = _FakeTodayRepository(
      entry: _sampleEntry(
        priorities: const <TodayPriority>[
          TodayPriority(text: '原有事项', completed: true),
          TodayPriority(),
          TodayPriority(),
        ],
      ),
    );
    await _pumpTodayPage(tester, repository);
    await tester.pumpAndSettle();

    final priorityField = find.byKey(const ValueKey('priority1Field'));
    await tester.enterText(priorityField, '');
    await _tapSave(tester);

    expect(repository.lastSaved?.priorities.first.text, isNull);
    expect(repository.lastSaved?.priorities.first.completed, isFalse);
  });

  testWidgets('health fields hidden by Today UI are preserved', (tester) async {
    final repository = _FakeTodayRepository(
      entry: _sampleEntry(
        health: const TodayHealthSummary(
          id: 'health-id',
          sleepDurationMinutes: 450,
          weightKg: 68.5,
          waterIntakeMl: 1800,
          exerciseType: 'running',
          exerciseDurationMinutes: 35,
          physicalStateScore: 4,
          note: '保留健康备注',
        ),
      ),
    );
    await _pumpTodayPage(tester, repository);
    await tester.pumpAndSettle();

    await _tapSave(tester);

    expect(repository.lastSaved?.health?.weightKg, 68.5);
    expect(repository.lastSaved?.health?.waterIntakeMl, 1800);
    expect(repository.lastSaved?.health?.exerciseType, 'running');
    expect(repository.lastSaved?.health?.note, '保留健康备注');
  });

  test('Today widgets do not import Drift or Repository implementations', () {
    const paths = <String>[
      'lib/features/today/presentation/today_page.dart',
      'lib/features/today/presentation/widgets/today_form.dart',
      'lib/shared/widgets/duration_input_field.dart',
    ];

    for (final path in paths) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('package:drift')));
      expect(source, isNot(contains('today_repository')));
      expect(source, isNot(contains('app_database')));
    }
  });
}

Future<void> _pumpTodayPage(
  WidgetTester tester,
  TodayRepository repository,
) async {
  await tester.binding.setSurfaceSize(const Size(900, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [todayRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(home: Scaffold(body: TodayPage())),
    ),
  );
}

Future<void> _tapSave(WidgetTester tester) async {
  final messenger = tester.state<ScaffoldMessengerState>(
    find.byType(ScaffoldMessenger),
  );
  messenger.hideCurrentSnackBar();
  await tester.pumpAndSettle();

  final saveButton = find.byKey(const ValueKey('saveTodayButton'));
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

Future<void> _enterDuration(
  WidgetTester tester,
  String key,
  String hours,
  String minutes,
) async {
  final durationField = find.byKey(ValueKey(key));
  await Scrollable.ensureVisible(tester.element(durationField), alignment: 0.4);
  await tester.pumpAndSettle();
  await tester.enterText(_durationPart(key, 0), hours);
  await tester.enterText(_durationPart(key, 1), minutes);
}

Finder _durationPart(String key, int index) {
  return find
      .descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(TextFormField),
      )
      .at(index);
}

String _durationPartText(WidgetTester tester, String key, int index) {
  return tester
      .widget<TextFormField>(_durationPart(key, index))
      .controller!
      .text;
}

TodayEntry _sampleEntry({
  List<TodayPriority> priorities = const <TodayPriority>[
    TodayPriority(),
    TodayPriority(),
    TodayPriority(),
  ],
  int? moodScore,
  int? energyScore,
  int? researchMinutes,
  int? learningMinutes,
  String? dailyNote,
  TodayHealthSummary? health,
}) {
  return TodayEntry(
    id: 'today-id',
    userId: 'user-id',
    recordDate: '2026-07-13',
    timezoneOffsetMinutes: 480,
    priorities: priorities,
    moodScore: moodScore,
    energyScore: energyScore,
    researchMinutes: researchMinutes,
    learningMinutes: learningMinutes,
    dailyNote: dailyNote,
    status: TodayRecordStatus.draft,
    createdAt: 1,
    updatedAt: 1,
    health: health,
  );
}

final class _FakeTodayRepository implements TodayRepository {
  _FakeTodayRepository({
    required this.entry,
    this.pendingLoad,
    this.loadError,
    this.pendingSave,
    this.failuresBeforeSuccess = 0,
  });

  TodayEntry entry;
  final Completer<TodayEntry>? pendingLoad;
  final Object? loadError;
  final Completer<void>? pendingSave;
  int failuresBeforeSuccess;
  TodaySaveData? lastSaved;
  int saveAttempts = 0;
  int historyLoadAttempts = 0;

  @override
  Future<TodayEntry> getToday() async {
    if (loadError != null) {
      throw loadError!;
    }
    return pendingLoad?.future ?? entry;
  }

  @override
  Future<TodayEntry?> getByDate(String recordDate) async => entry;

  @override
  Future<List<TodayEntry>> listByDateRange({
    required String startDate,
    required String endDate,
    int? limit,
  }) async => [entry];

  @override
  Future<List<TodayEntry>> listRecentEntries({int days = 30}) async {
    historyLoadAttempts += 1;
    return [entry];
  }

  @override
  Future<TodayEntry> saveToday(TodaySaveData data) async {
    saveAttempts += 1;
    if (failuresBeforeSuccess > 0) {
      failuresBeforeSuccess -= 1;
      throw StateError('save failed for test');
    }
    await pendingSave?.future;
    lastSaved = data;
    final health = data.health == null
        ? entry.health
        : TodayHealthSummary(
            id: entry.health?.id ?? 'health-id',
            sleepDurationMinutes: data.health!.sleepDurationMinutes,
            weightKg: data.health!.weightKg,
            waterIntakeMl: data.health!.waterIntakeMl,
            exerciseType: data.health!.exerciseType,
            exerciseDurationMinutes: data.health!.exerciseDurationMinutes,
            physicalStateScore: data.health!.physicalStateScore,
            note: data.health!.note,
          );
    entry = TodayEntry(
      id: entry.id,
      userId: entry.userId,
      recordDate: entry.recordDate,
      timezoneOffsetMinutes: entry.timezoneOffsetMinutes,
      priorities: data.priorities,
      moodScore: data.moodScore,
      energyScore: data.energyScore,
      researchMinutes: data.researchMinutes,
      learningMinutes: data.learningMinutes,
      dailyNote: data.dailyNote,
      status: data.status,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt + 1,
      health: health,
    );
    return entry;
  }

  @override
  Future<TodayEntry> markCompleted({
    required String recordDate,
    required bool completed,
  }) async => entry;

  @override
  Future<TodayEntry> updateDailyNote({
    required String recordDate,
    required String? dailyNote,
  }) async => entry;

  @override
  Future<TodayEntry> updateMoodEnergy({
    required String recordDate,
    required int? moodScore,
    required int? energyScore,
  }) async => entry;

  @override
  Future<TodayEntry> updatePriorities({
    required String recordDate,
    required List<TodayPriority> priorities,
  }) async => entry;

  @override
  Future<TodayEntry> updateResearchLearningMinutes({
    required String recordDate,
    required int? researchMinutes,
    required int? learningMinutes,
  }) async => entry;
}
