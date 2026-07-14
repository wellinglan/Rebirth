import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/health/data/health_repository_provider.dart';
import 'package:rebirth/features/health/domain/health_entry.dart';
import 'package:rebirth/features/health/domain/health_repository.dart';
import 'package:rebirth/features/health/domain/health_save_data.dart';
import 'package:rebirth/features/health/domain/health_summary.dart';
import 'package:rebirth/features/health/presentation/health_controller.dart';
import 'package:rebirth/features/health/presentation/health_view_state.dart';

void main() {
  late _FakeHealthRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = _FakeHealthRepository();
    container = ProviderContainer(
      overrides: [
        healthRepositoryProvider.overrideWithValue(repository),
        dateTimeServiceProvider.overrideWithValue(
          DateTimeService(now: () => DateTime(2026, 7, 14, 9)),
        ),
      ],
    );
  });

  tearDown(() => container.dispose());

  test('initial load combines today, recent, and summary', () async {
    expect(
      container.read(healthControllerProvider),
      isA<AsyncLoading<HealthViewState>>(),
    );
    final state = await container.read(healthControllerProvider.future);

    expect(state.today.recordDate, '2026-07-14');
    expect(state.recentEntries, hasLength(1));
    expect(state.recentEntries.single.recordDate, '2026-07-13');
    expect(state.summary.recordsCount, 2);
    expect(repository.getTodayCalls, 1);
    expect(repository.listRecentCalls, 2);
  });

  test('successful save refreshes all state sections', () async {
    await container.read(healthControllerProvider.future);
    await container
        .read(healthControllerProvider.notifier)
        .saveToday(
          HealthSaveData(recordDate: '2026-07-14', waterIntakeMl: 2000),
        );

    final state = container.read(healthControllerProvider).requireValue;
    expect(state.today.waterIntakeMl, 2000);
    expect(state.recentEntries.single.recordDate, '2026-07-13');
    expect(state.summary.averageWaterIntakeMl, 2000);
    expect(state.isSaving, isFalse);
  });

  test('failed save keeps existing state and rethrows', () async {
    final initial = await container.read(healthControllerProvider.future);
    repository.saveError = StateError('save failed');

    await expectLater(
      container
          .read(healthControllerProvider.notifier)
          .saveToday(
            HealthSaveData(recordDate: '2026-07-14', waterIntakeMl: 2500),
          ),
      throwsStateError,
    );

    final state = container.read(healthControllerProvider).requireValue;
    expect(state.today.id, initial.today.id);
    expect(state.today.waterIntakeMl, initial.today.waterIntakeMl);
    expect(state.isSaving, isFalse);
  });

  test('reload failure enters AsyncError', () async {
    await container.read(healthControllerProvider.future);
    repository.loadError = StateError('load failed');

    await container.read(healthControllerProvider.notifier).reload();

    expect(container.read(healthControllerProvider), isA<AsyncError>());
  });

  test('saveForDate accepts a specified date', () async {
    await container.read(healthControllerProvider.future);
    await container
        .read(healthControllerProvider.notifier)
        .saveForDate(HealthSaveData(recordDate: '2026-07-13', weightKg: 65.5));

    expect(repository.lastSaved?.recordDate, '2026-07-13');
    expect(repository.savedByDate['2026-07-13']?.weightKg, 65.5);
  });

  test('history is empty when the only metric record is today', () async {
    repository.includePastEntry = false;

    final state = await container.read(healthControllerProvider.future);

    expect(state.recentEntries, isEmpty);
    expect(state.summary.recordsCount, 1);
  });
}

final class _FakeHealthRepository implements HealthRepository {
  HealthEntry today = _entry(date: '2026-07-14', water: 1000);
  final Map<String, HealthEntry> savedByDate = {};
  Object? loadError;
  Object? saveError;
  HealthSaveData? lastSaved;
  int getTodayCalls = 0;
  int listRecentCalls = 0;
  bool includePastEntry = true;

  @override
  Future<HealthEntry> getToday() async {
    getTodayCalls += 1;
    if (loadError != null) {
      throw loadError!;
    }
    return savedByDate[today.recordDate] ?? today;
  }

  @override
  Future<HealthEntry?> getByDate(String recordDate) async =>
      savedByDate[recordDate] ??
      (recordDate == today.recordDate ? today : null);

  @override
  Future<List<HealthEntry>> listRecent({int days = 30}) async {
    listRecentCalls += 1;
    final current = savedByDate[today.recordDate] ?? today;
    return [
      current,
      if (includePastEntry) _entry(date: '2026-07-13', water: 2000),
      ...savedByDate.values.where(
        (entry) => entry.id != current.id && entry.recordDate != '2026-07-13',
      ),
    ];
  }

  @override
  Future<List<HealthEntry>> listByDateRange({
    required String startDate,
    required String endDate,
  }) => listRecent();

  @override
  Future<HealthEntry> saveForDate(HealthSaveData data) async {
    if (saveError != null) {
      throw saveError!;
    }
    lastSaved = data;
    final entry = HealthEntry(
      id: data.recordDate == today.recordDate ? today.id : data.recordDate,
      userId: 'user',
      todayRecordId: null,
      recordDate: data.recordDate,
      sleepDurationMinutes: data.sleepDurationMinutes,
      weightKg: data.weightKg,
      waterIntakeMl: data.waterIntakeMl,
      exerciseDurationMinutes: data.exerciseDurationMinutes,
      exerciseType: data.exerciseType,
      physicalStateScore: data.physicalStateScore,
      note: data.note,
      timezoneOffsetMinutes: 480,
      createdAt: 1,
      updatedAt: 2,
    );
    savedByDate[data.recordDate] = entry;
    return entry;
  }

  @override
  Future<HealthSummary> getSummary({int days = 7}) async {
    return HealthSummary.fromEntries(days: days, entries: await listRecent());
  }
}

HealthEntry _entry({required String date, int? water}) {
  return HealthEntry(
    id: 'health-$date',
    userId: 'user',
    todayRecordId: null,
    recordDate: date,
    sleepDurationMinutes: 450,
    weightKg: 65.5,
    waterIntakeMl: water,
    exerciseDurationMinutes: 30,
    exerciseType: '跑步',
    physicalStateScore: 4,
    note: '状态稳定',
    timezoneOffsetMinutes: 480,
    createdAt: 1,
    updatedAt: 1,
  );
}
