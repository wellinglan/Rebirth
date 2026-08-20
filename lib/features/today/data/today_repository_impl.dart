import 'package:drift/drift.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/core/utils/metric_description.dart';
import 'package:rebirth/core/wellbeing/wellbeing_score.dart';
import 'package:rebirth/features/today/domain/today_entry.dart';
import 'package:rebirth/features/today/domain/today_repository.dart';
import 'package:rebirth/features/today/domain/today_save_data.dart';

import 'today_local_data_source.dart';

final class TodayRepositoryImpl implements TodayRepository {
  TodayRepositoryImpl({
    required AppDatabase database,
    required this.dateTimeService,
  }) : _database = database,
       _localDataSource = TodayLocalDataSource(database);

  final AppDatabase _database;
  final DateTimeService dateTimeService;
  final TodayLocalDataSource _localDataSource;

  @override
  Future<TodayEntry> getToday() async {
    final snapshot = dateTimeService.currentSnapshot();
    final bootstrap = await _database.bootstrapDao.bootstrap();
    final entry = await _localDataSource.getOrCreate(
      userId: bootstrap.activeUserId,
      recordDate: snapshot.localDateString,
      timezoneOffsetMinutes: snapshot.timezoneOffsetMinutes,
      timestamp: snapshot.utcMilliseconds,
      originDeviceId: bootstrap.localInstallationId,
    );

    return _toDomain(entry);
  }

  @override
  Future<TodayEntry?> getByDate(String recordDate) async {
    _validateRecordDate(recordDate);
    final bootstrap = await _database.bootstrapDao.bootstrap();
    final entry = await _localDataSource.getByDate(
      userId: bootstrap.activeUserId,
      recordDate: recordDate,
    );

    return entry == null ? null : _toDomain(entry);
  }

  @override
  Future<List<TodayEntry>> listByDateRange({
    required String startDate,
    required String endDate,
    int? limit,
  }) async {
    _validateRecordDate(startDate);
    _validateRecordDate(endDate);
    if (startDate.compareTo(endDate) > 0) {
      throw ArgumentError('startDate must not be after endDate.');
    }
    if (limit != null && limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'Limit must be positive.');
    }

    final bootstrap = await _database.bootstrapDao.bootstrap();
    final entries = await _localDataSource.selectByDateRange(
      userId: bootstrap.activeUserId,
      startDate: startDate,
      endDate: endDate,
      limit: limit,
    );
    return entries.map(_toDomain).toList(growable: false);
  }

  @override
  Future<List<TodayEntry>> listRecentEntries({int days = 30}) async {
    if (days <= 0) {
      throw ArgumentError.value(days, 'days', 'Days must be positive.');
    }
    final snapshot = dateTimeService.currentSnapshot();
    final dateRange = dateTimeService.recentLocalDateRange(
      days,
      endingAt: snapshot.now,
    );
    return listByDateRange(
      startDate: dateRange.first,
      endDate: dateRange.last,
      limit: days,
    );
  }

  @override
  Future<TodayEntry> saveToday(TodaySaveData data) async {
    final priorities = _normalizePriorities(data.priorities);
    _validateScore(data.moodScore, 'moodScore');
    _validateScore(data.energyScore, 'energyScore');
    final moodDescription = normalizeWellbeingDescription(data.moodDescription);
    final energyDescription = normalizeWellbeingDescription(
      data.energyDescription,
    );
    _validateMinutes(data.researchMinutes, 'researchMinutes');
    _validateMinutes(data.learningMinutes, 'learningMinutes');
    final researchDescription = normalizeMetricDescription(
      data.researchDescription,
      name: 'researchDescription',
    );
    final learningDescription = normalizeMetricDescription(
      data.learningDescription,
      name: 'learningDescription',
    );
    final health = _normalizeHealth(data.health);

    final snapshot = dateTimeService.currentSnapshot();
    final bootstrap = await _database.bootstrapDao.bootstrap();
    final entry = await _localDataSource.saveAggregate(
      userId: bootstrap.activeUserId,
      recordDate: snapshot.localDateString,
      timezoneOffsetMinutes: snapshot.timezoneOffsetMinutes,
      timestamp: snapshot.utcMilliseconds,
      originDeviceId: bootstrap.localInstallationId,
      todayChanges: TodayRecordsCompanion(
        priority1: Value(priorities[0].text),
        priority1Completed: Value(priorities[0].completed),
        priority1GoalId: Value(priorities[0].goalId),
        priority2: Value(priorities[1].text),
        priority2Completed: Value(priorities[1].completed),
        priority2GoalId: Value(priorities[1].goalId),
        priority3: Value(priorities[2].text),
        priority3Completed: Value(priorities[2].completed),
        priority3GoalId: Value(priorities[2].goalId),
        moodScore: Value(data.moodScore),
        wellbeingScoreScale: const Value(currentWellbeingScoreScale),
        moodDescription: Value(moodDescription),
        energyScore: Value(data.energyScore),
        energyDescription: Value(energyDescription),
        researchMinutes: Value(data.researchMinutes),
        researchDescription: Value(researchDescription),
        learningMinutes: Value(data.learningMinutes),
        learningDescription: Value(learningDescription),
        dailyNote: Value(data.dailyNote),
        recordStatus: Value(data.status.name),
        updatedAt: Value(snapshot.utcMilliseconds),
        syncStatus: const Value('pending'),
      ),
      health: health,
    );

    return _toDomain(entry);
  }

  @override
  Future<TodayEntry> updatePriorities({
    required String recordDate,
    required List<TodayPriority> priorities,
  }) async {
    _validateRecordDate(recordDate);
    final normalized = _normalizePriorities(priorities);
    final snapshot = dateTimeService.currentSnapshot();
    final bootstrap = await _database.bootstrapDao.bootstrap();

    return _toDomain(
      await _localDataSource.updateToday(
        userId: bootstrap.activeUserId,
        recordDate: recordDate,
        changes: TodayRecordsCompanion(
          priority1: Value(normalized[0].text),
          priority1Completed: Value(normalized[0].completed),
          priority1GoalId: Value(normalized[0].goalId),
          priority2: Value(normalized[1].text),
          priority2Completed: Value(normalized[1].completed),
          priority2GoalId: Value(normalized[1].goalId),
          priority3: Value(normalized[2].text),
          priority3Completed: Value(normalized[2].completed),
          priority3GoalId: Value(normalized[2].goalId),
          updatedAt: Value(snapshot.utcMilliseconds),
          syncStatus: const Value('pending'),
        ),
      ),
    );
  }

  @override
  Future<TodayEntry> updateMoodEnergy({
    required String recordDate,
    required int? moodScore,
    required int? energyScore,
    String? moodDescription,
    String? energyDescription,
  }) async {
    _validateRecordDate(recordDate);
    _validateScore(moodScore, 'moodScore');
    _validateScore(energyScore, 'energyScore');
    final normalizedMoodDescription = normalizeWellbeingDescription(
      moodDescription,
    );
    final normalizedEnergyDescription = normalizeWellbeingDescription(
      energyDescription,
    );
    return _updateToday(
      recordDate: recordDate,
      changesForTimestamp: (timestamp) => TodayRecordsCompanion(
        moodScore: Value(moodScore),
        wellbeingScoreScale: const Value(currentWellbeingScoreScale),
        moodDescription: Value(normalizedMoodDescription),
        energyScore: Value(energyScore),
        energyDescription: Value(normalizedEnergyDescription),
        updatedAt: Value(timestamp),
        syncStatus: const Value('pending'),
      ),
    );
  }

  @override
  Future<TodayEntry> updateResearchLearningMinutes({
    required String recordDate,
    required int? researchMinutes,
    required int? learningMinutes,
  }) async {
    _validateRecordDate(recordDate);
    _validateMinutes(researchMinutes, 'researchMinutes');
    _validateMinutes(learningMinutes, 'learningMinutes');
    return _updateToday(
      recordDate: recordDate,
      changesForTimestamp: (timestamp) => TodayRecordsCompanion(
        researchMinutes: Value(researchMinutes),
        learningMinutes: Value(learningMinutes),
        updatedAt: Value(timestamp),
        syncStatus: const Value('pending'),
      ),
    );
  }

  @override
  Future<TodayEntry> updateDailyNote({
    required String recordDate,
    required String? dailyNote,
  }) {
    _validateRecordDate(recordDate);
    return _updateToday(
      recordDate: recordDate,
      changesForTimestamp: (timestamp) => TodayRecordsCompanion(
        dailyNote: Value(dailyNote),
        updatedAt: Value(timestamp),
        syncStatus: const Value('pending'),
      ),
    );
  }

  @override
  Future<TodayEntry> markCompleted({
    required String recordDate,
    required bool completed,
  }) {
    _validateRecordDate(recordDate);
    return _updateToday(
      recordDate: recordDate,
      changesForTimestamp: (timestamp) => TodayRecordsCompanion(
        recordStatus: Value(
          completed
              ? TodayRecordStatus.completed.name
              : TodayRecordStatus.draft.name,
        ),
        updatedAt: Value(timestamp),
        syncStatus: const Value('pending'),
      ),
    );
  }

  @override
  Future<void> deleteTodayByDate(String recordDate) async {
    _validateRecordDate(recordDate);
    final snapshot = dateTimeService.currentSnapshot();
    final bootstrap = await _database.bootstrapDao.bootstrap();
    await _localDataSource.softDeleteToday(
      userId: bootstrap.activeUserId,
      recordDate: recordDate,
      timestamp: snapshot.utcMilliseconds,
      originDeviceId: bootstrap.localInstallationId,
    );
  }

  Future<TodayEntry> _updateToday({
    required String recordDate,
    required TodayRecordsCompanion Function(int timestamp) changesForTimestamp,
  }) async {
    final snapshot = dateTimeService.currentSnapshot();
    final bootstrap = await _database.bootstrapDao.bootstrap();
    final entry = await _localDataSource.updateToday(
      userId: bootstrap.activeUserId,
      recordDate: recordDate,
      changes: changesForTimestamp(snapshot.utcMilliseconds),
    );

    return _toDomain(entry);
  }

  TodayEntry _toDomain(TodayDatabaseEntry entry) {
    final today = entry.today;
    final health = entry.health;

    return TodayEntry(
      id: today.id,
      userId: today.userId,
      recordDate: today.recordDate,
      timezoneOffsetMinutes: today.timezoneOffsetMinutes,
      priorities: <TodayPriority>[
        TodayPriority(
          text: today.priority1,
          completed: today.priority1Completed,
          goalId: today.priority1GoalId,
        ),
        TodayPriority(
          text: today.priority2,
          completed: today.priority2Completed,
          goalId: today.priority2GoalId,
        ),
        TodayPriority(
          text: today.priority3,
          completed: today.priority3Completed,
          goalId: today.priority3GoalId,
        ),
      ],
      moodScore: normalizeWellbeingScore(
        today.moodScore,
        today.wellbeingScoreScale,
      ),
      moodDescription: today.moodDescription,
      energyScore: normalizeWellbeingScore(
        today.energyScore,
        today.wellbeingScoreScale,
      ),
      energyDescription: today.energyDescription,
      researchMinutes: today.researchMinutes,
      researchDescription: today.researchDescription,
      learningMinutes: today.learningMinutes,
      learningDescription: today.learningDescription,
      dailyNote: today.dailyNote,
      status: switch (today.recordStatus) {
        'draft' => TodayRecordStatus.draft,
        'completed' => TodayRecordStatus.completed,
        final value => throw StateError('Unknown Today record status: $value'),
      },
      createdAt: today.createdAt,
      updatedAt: today.updatedAt,
      health: health == null
          ? null
          : TodayHealthSummary(
              id: health.id,
              sleepDurationMinutes: health.sleepDurationMinutes,
              sleepDescription: health.sleepDescription,
              weightKg: health.weightKg,
              weightDescription: health.weightDescription,
              waterIntakeMl: health.waterIntakeMl,
              waterDescription: health.waterDescription,
              exerciseType: health.exerciseType,
              exerciseDurationMinutes: health.exerciseDurationMinutes,
              exerciseDescription: health.exerciseDescription,
              physicalStateScore: normalizeWellbeingScore(
                health.physicalStateScore,
                health.physicalStateScoreScale,
              ),
              physicalStateDescription: health.physicalStateDescription,
              note: health.note,
            ),
    );
  }

  List<TodayPriority> _normalizePriorities(List<TodayPriority> priorities) {
    if (priorities.length > 3) {
      throw ArgumentError.value(
        priorities.length,
        'priorities',
        'Today supports at most three priorities.',
      );
    }

    return List<TodayPriority>.generate(3, (index) {
      if (index >= priorities.length) {
        return const TodayPriority();
      }

      final priority = priorities[index];
      final text = priority.text?.trim();
      if (text == null || text.isEmpty) {
        return const TodayPriority();
      }
      return TodayPriority(
        text: text,
        completed: priority.completed,
        goalId: priority.goalId,
      );
    }, growable: false);
  }

  void _validateRecordDate(String recordDate) {
    if (!dateTimeService.isValidLocalDateString(recordDate)) {
      throw ArgumentError.value(
        recordDate,
        'recordDate',
        'Expected a valid date in YYYY-MM-DD format.',
      );
    }
  }

  void _validateScore(int? score, String name) {
    if (score != null && (score < 1 || score > 10)) {
      throw ArgumentError.value(score, name, 'Score must be between 1 and 10.');
    }
  }

  void _validateMinutes(int? minutes, String name) {
    if (minutes != null && minutes < 0) {
      throw ArgumentError.value(minutes, name, 'Minutes must not be negative.');
    }
  }

  TodayHealthInput? _normalizeHealth(TodayHealthInput? health) {
    if (health == null) {
      return null;
    }

    _validateMinutes(health.sleepDurationMinutes, 'sleepDurationMinutes');
    _validateMinutes(health.waterIntakeMl, 'waterIntakeMl');
    _validateMinutes(health.exerciseDurationMinutes, 'exerciseDurationMinutes');
    _validateScore(health.physicalStateScore, 'physicalStateScore');
    normalizeWellbeingDescription(health.physicalStateDescription);
    if (health.weightKg != null && health.weightKg! <= 0) {
      throw ArgumentError.value(
        health.weightKg,
        'weightKg',
        'Weight must be greater than zero.',
      );
    }
    return TodayHealthInput(
      sleepDurationMinutes: health.sleepDurationMinutes,
      sleepDescription: normalizeMetricDescription(
        health.sleepDescription,
        name: 'sleepDescription',
      ),
      weightKg: health.weightKg,
      weightDescription: normalizeMetricDescription(
        health.weightDescription,
        name: 'weightDescription',
      ),
      waterIntakeMl: health.waterIntakeMl,
      waterDescription: normalizeMetricDescription(
        health.waterDescription,
        name: 'waterDescription',
      ),
      exerciseType: health.exerciseType,
      exerciseDurationMinutes: health.exerciseDurationMinutes,
      exerciseDescription: normalizeMetricDescription(
        health.exerciseDescription,
        name: 'exerciseDescription',
      ),
      physicalStateScore: health.physicalStateScore,
      physicalStateDescription: normalizeWellbeingDescription(
        health.physicalStateDescription,
      ),
      note: health.note,
    );
  }
}
