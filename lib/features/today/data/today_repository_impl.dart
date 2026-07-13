import 'package:drift/drift.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
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
  Future<TodayEntry> saveToday(TodaySaveData data) async {
    final priorities = _normalizePriorities(data.priorities);
    _validateScore(data.moodScore, 'moodScore');
    _validateScore(data.energyScore, 'energyScore');
    _validateMinutes(data.researchMinutes, 'researchMinutes');
    _validateMinutes(data.learningMinutes, 'learningMinutes');
    _validateHealth(data.health);

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
        energyScore: Value(data.energyScore),
        researchMinutes: Value(data.researchMinutes),
        learningMinutes: Value(data.learningMinutes),
        dailyNote: Value(data.dailyNote),
        recordStatus: Value(data.status.name),
        updatedAt: Value(snapshot.utcMilliseconds),
      ),
      health: data.health,
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
        ),
      ),
    );
  }

  @override
  Future<TodayEntry> updateMoodEnergy({
    required String recordDate,
    required int? moodScore,
    required int? energyScore,
  }) async {
    _validateRecordDate(recordDate);
    _validateScore(moodScore, 'moodScore');
    _validateScore(energyScore, 'energyScore');
    return _updateToday(
      recordDate: recordDate,
      changesForTimestamp: (timestamp) => TodayRecordsCompanion(
        moodScore: Value(moodScore),
        energyScore: Value(energyScore),
        updatedAt: Value(timestamp),
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
      ),
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
      moodScore: today.moodScore,
      energyScore: today.energyScore,
      researchMinutes: today.researchMinutes,
      learningMinutes: today.learningMinutes,
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
              weightKg: health.weightKg,
              waterIntakeMl: health.waterIntakeMl,
              exerciseType: health.exerciseType,
              exerciseDurationMinutes: health.exerciseDurationMinutes,
              physicalStateScore: health.physicalStateScore,
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
      return TodayPriority(
        text: text == null || text.isEmpty ? null : text,
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
    if (score != null && (score < 1 || score > 5)) {
      throw ArgumentError.value(score, name, 'Score must be between 1 and 5.');
    }
  }

  void _validateMinutes(int? minutes, String name) {
    if (minutes != null && minutes < 0) {
      throw ArgumentError.value(minutes, name, 'Minutes must not be negative.');
    }
  }

  void _validateHealth(TodayHealthInput? health) {
    if (health == null) {
      return;
    }

    _validateMinutes(health.sleepDurationMinutes, 'sleepDurationMinutes');
    _validateMinutes(health.waterIntakeMl, 'waterIntakeMl');
    _validateMinutes(health.exerciseDurationMinutes, 'exerciseDurationMinutes');
    _validateScore(health.physicalStateScore, 'physicalStateScore');
    if (health.weightKg != null && health.weightKg! <= 0) {
      throw ArgumentError.value(
        health.weightKg,
        'weightKg',
        'Weight must be greater than zero.',
      );
    }
  }
}
