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
    expect(_fieldText(tester, 'researchMinutesField'), '45');
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

  testWidgets('research minutes keeps empty and zero distinct', (tester) async {
    final repository = _FakeTodayRepository(entry: _sampleEntry());
    await _pumpTodayPage(tester, repository);
    await tester.pumpAndSettle();

    final researchField = find.byKey(const ValueKey('researchMinutesField'));
    expect(_fieldText(tester, 'researchMinutesField'), isEmpty);

    await tester.ensureVisible(researchField);
    await tester.enterText(researchField, '0');
    await _tapSave(tester);
    expect(repository.lastSaved?.researchMinutes, 0);

    await tester.ensureVisible(researchField);
    await tester.enterText(researchField, '');
    await _tapSave(tester);
    expect(repository.lastSaved?.researchMinutes, isNull);
  });

  testWidgets('negative minutes fail validation without saving', (
    tester,
  ) async {
    final repository = _FakeTodayRepository(entry: _sampleEntry());
    await _pumpTodayPage(tester, repository);
    await tester.pumpAndSettle();

    final researchField = find.byKey(const ValueKey('researchMinutesField'));
    await tester.ensureVisible(researchField);
    await tester.enterText(researchField, '-1');
    await _tapSave(tester);

    expect(find.text('请输入非负整数'), findsOneWidget);
    expect(repository.lastSaved, isNull);
  });

  test('Today widgets do not import Drift or Repository implementations', () {
    const paths = <String>[
      'lib/features/today/presentation/today_page.dart',
      'lib/features/today/presentation/widgets/today_form.dart',
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
  final saveButton = find.byKey(const ValueKey('saveTodayButton'));
  await tester.ensureVisible(saveButton);
  await tester.tap(saveButton);
  await tester.pumpAndSettle();
}

String _fieldText(WidgetTester tester, String key) {
  return tester
      .widget<TextFormField>(find.byKey(ValueKey(key)))
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
  _FakeTodayRepository({required this.entry, this.pendingLoad, this.loadError});

  TodayEntry entry;
  final Completer<TodayEntry>? pendingLoad;
  final Object? loadError;
  TodaySaveData? lastSaved;

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
  Future<TodayEntry> saveToday(TodaySaveData data) async {
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
