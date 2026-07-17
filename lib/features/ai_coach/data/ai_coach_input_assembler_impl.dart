import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/ai_coach/domain/ai_coach_exception.dart';
import 'package:rebirth/features/ai_coach/domain/ai_coach_input_assembler.dart';
import 'package:rebirth/features/ai_coach/domain/ai_coach_input_bundle.dart';
import 'package:rebirth/features/ai_coach/domain/ai_consent_repository.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_scope.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_selection.dart';
import 'package:rebirth/features/ai_coach/domain/ai_input_source_ref.dart';
import 'package:rebirth/features/ai_coach/domain/ai_input_contract.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_type.dart';
import 'package:rebirth/features/ai_coach/domain/canonical_json_encoder.dart';
import 'package:rebirth/features/ai_coach/domain/input_hash_service.dart';
import 'package:rebirth/features/growth/domain/growth_metric_summary.dart';
import 'package:rebirth/features/growth/domain/growth_period.dart';
import 'package:rebirth/features/growth/domain/growth_repository.dart';
import 'package:rebirth/features/growth/domain/growth_snapshot.dart';
import 'package:rebirth/features/health/domain/health_entry.dart';
import 'package:rebirth/features/health/domain/health_repository.dart';
import 'package:rebirth/features/journal/domain/journal_entry.dart';
import 'package:rebirth/features/journal/domain/journal_repository.dart';
import 'package:rebirth/features/today/domain/today_entry.dart';
import 'package:rebirth/features/today/domain/today_repository.dart';

final class AiCoachInputAssemblerImpl implements AiCoachInputAssembler {
  const AiCoachInputAssemblerImpl({
    required this.consentRepository,
    required this.growthRepository,
    required this.todayRepository,
    required this.healthRepository,
    required this.journalRepository,
    required this.dateTimeService,
    required this.canonicalJsonEncoder,
    required this.inputHashService,
  });

  final AiConsentRepository consentRepository;
  final GrowthRepository growthRepository;
  final TodayRepository todayRepository;
  final HealthRepository healthRepository;
  final JournalRepository journalRepository;
  final DateTimeService dateTimeService;
  final CanonicalJsonEncoder canonicalJsonEncoder;
  final InputHashService inputHashService;

  @override
  Future<AiCoachInputBundle> buildWeeklyReport({
    required AiDataSelection selection,
  }) {
    return build(reportType: AiReportType.weeklyReport, selection: selection);
  }

  @override
  Future<AiCoachInputBundle> build({
    required AiReportType reportType,
    required AiDataSelection selection,
  }) async {
    final authorization = await consentRepository.read();
    if (!authorization.enabled) throw const AiConsentRequiredException();
    if (selection.scopes.isEmpty) {
      throw const EmptyAiDataSelectionException();
    }
    if (reportType != AiReportType.weeklyReport) {
      throw UnsupportedAiReportTypeException(reportType.databaseValue);
    }
    for (final scope in selection.scopes) {
      if (!scope.supported) {
        throw UnsupportedAiDataScopeException(scope.contractValue);
      }
    }

    final snapshot = dateTimeService.currentSnapshot();
    final dates = dateTimeService.recentLocalDateRange(
      AiInputContract.weeklyPeriodDays,
      endingAt: snapshot.now,
    );
    final startDate = dates.first;
    final endDate = dates.last;

    GrowthSnapshot? growth;
    List<TodayEntry>? today;
    List<HealthEntry>? health;
    List<JournalEntry>? journals;
    final reads = <Future<void>>[];
    if (selection.scopes.contains(AiDataScope.growthSummary)) {
      reads.add(
        growthRepository.loadRecent(GrowthPeriod.sevenDays).then<void>(
          (value) => growth = value,
        ),
      );
    }
    if (selection.scopes.contains(AiDataScope.todayMetrics)) {
      reads.add(
        todayRepository
            .listByDateRange(startDate: startDate, endDate: endDate)
            .then<void>((value) => today = value),
      );
    }
    if (selection.scopes.contains(AiDataScope.healthMetrics)) {
      reads.add(
        healthRepository
            .listByDateRange(startDate: startDate, endDate: endDate)
            .then<void>((value) => health = value),
      );
    }
    if (selection.scopes.contains(AiDataScope.journalReflections)) {
      reads.add(
        journalRepository
            .listByDateRange(startDate: startDate, endDate: endDate)
            .then<void>((value) => journals = value),
      );
    }
    await Future.wait(reads);

    final data = <String, Object?>{};
    final sources = <AiInputSourceRef>[];
    final growthResult = growth;
    if (growthResult != null) {
      _validateGrowthPeriod(growthResult, startDate, endDate);
      data[AiDataScope.growthSummary.contractValue] = _growthData(growthResult);
    }
    final todayResult = today;
    if (todayResult != null) {
      final sorted = [...todayResult]
        ..sort((left, right) => left.recordDate.compareTo(right.recordDate));
      data[AiDataScope.todayMetrics.contractValue] = sorted
          .map(_todayData)
          .toList(growable: false);
      sources.addAll(
        sorted.map(
          (entry) => AiInputSourceRef(
            table: 'today_records',
            id: entry.id,
            updatedAt: entry.updatedAt,
          ),
        ),
      );
    }
    final healthResult = health;
    if (healthResult != null) {
      final sorted = [...healthResult]
        ..sort((left, right) => left.recordDate.compareTo(right.recordDate));
      data[AiDataScope.healthMetrics.contractValue] = sorted
          .map(_healthData)
          .toList(growable: false);
      sources.addAll(
        sorted.map(
          (entry) => AiInputSourceRef(
            table: 'health_records',
            id: entry.id,
            updatedAt: entry.updatedAt,
          ),
        ),
      );
    }
    final journalResult = journals;
    if (journalResult != null) {
      final sorted = [...journalResult]
        ..sort((left, right) => left.entryDate.compareTo(right.entryDate));
      data[AiDataScope.journalReflections.contractValue] = sorted
          .map(_journalData)
          .toList(growable: false);
      sources.addAll(
        sorted.map(
          (entry) => AiInputSourceRef(
            table: 'journal_entries',
            id: entry.id,
            updatedAt: entry.updatedAt,
          ),
        ),
      );
    }

    final normalizedSources = _normalizeSources(sources);
    final scopes = selection.scopes
            .map((scope) => scope.contractValue)
            .toList(growable: false)
          ..sort();
    final payload = <String, Object?>{
      'schema_version': AiInputContract.schemaVersion,
      'report_type': reportType.databaseValue,
      'prompt_version': AiInputContract.weeklyPromptVersion,
      'period': <String, Object?>{
        'start_date': startDate,
        'end_date': endDate,
      },
      'scopes': scopes,
      'data': data,
      'sources': normalizedSources
          .map((source) => source.toCanonicalMap())
          .toList(growable: false),
    };
    final canonicalJson = canonicalJsonEncoder.encode(payload);
    final inputHash = inputHashService.hashCanonicalJson(canonicalJson);
    return AiCoachInputBundle(
      reportType: reportType,
      promptVersion: AiInputContract.weeklyPromptVersion,
      periodStartDate: startDate,
      periodEndDate: endDate,
      selection: selection,
      sources: normalizedSources,
      canonicalPayload: payload,
      canonicalJson: canonicalJson,
      inputHash: inputHash,
    );
  }

  void _validateGrowthPeriod(
    GrowthSnapshot snapshot,
    String startDate,
    String endDate,
  ) {
    if (snapshot.period != GrowthPeriod.sevenDays ||
        snapshot.startDate != startDate ||
        snapshot.endDate != endDate) {
      throw const InvalidAiInputException(
        'Growth summary does not match the requested weekly period.',
      );
    }
  }

  Map<String, Object?> _growthData(GrowthSnapshot snapshot) => {
    'period_days': snapshot.period.days,
    'research': _summaryData(snapshot.researchSummary),
    'learning': _summaryData(snapshot.learningSummary),
    'exercise': _summaryData(snapshot.exerciseSummary),
    'sleep': _summaryData(snapshot.sleepSummary),
    'mood': _summaryData(snapshot.moodSummary),
    'energy': _summaryData(snapshot.energySummary),
    'journal_recorded_days': snapshot.journalRecordedDays,
    'journal_completed_days': snapshot.journalCompletedDays,
  };

  Map<String, Object?> _summaryData(GrowthMetricSummary summary) => {
    'recorded_day_count': summary.recordedDayCount,
    'total': summary.total,
    'average': summary.average,
    'minimum': summary.minimum,
    'maximum': summary.maximum,
  };

  Map<String, Object?> _todayData(TodayEntry entry) => {
    'record_date': entry.recordDate,
    'research_minutes': entry.researchMinutes,
    'learning_minutes': entry.learningMinutes,
    'mood_score': entry.moodScore,
    'energy_score': entry.energyScore,
    'populated_priority_count': entry.populatedPriorityCount,
    'completed_priority_count': entry.completedPriorityCount,
    'status': entry.status.name,
  };

  Map<String, Object?> _healthData(HealthEntry entry) => {
    'record_date': entry.recordDate,
    'sleep_duration_minutes': entry.sleepDurationMinutes,
    'exercise_duration_minutes': entry.exerciseDurationMinutes,
    'physical_state_score': entry.physicalStateScore,
    'water_intake_ml': entry.waterIntakeMl,
    'weight_kg': entry.weightKg,
  };

  Map<String, Object?> _journalData(JournalEntry entry) => {
    'entry_date': entry.entryDate,
    'status': entry.status.name,
    'most_important_accomplishment': _trimToNull(
      entry.mostImportantAccomplishment,
    ),
    'most_draining_event': _trimToNull(entry.mostDrainingEvent),
    'emotion_source': _trimToNull(entry.emotionSource),
    'learning': _trimToNull(entry.learning),
    'tomorrow_adjustment': _trimToNull(entry.tomorrowAdjustment),
  };

  String? _trimToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  List<AiInputSourceRef> _normalizeSources(
    Iterable<AiInputSourceRef> sources,
  ) {
    final byIdentity = <String, AiInputSourceRef>{};
    for (final source in sources) {
      final key = '${source.table}\u0000${source.id}';
      final existing = byIdentity[key];
      if (existing == null || source.updatedAt > existing.updatedAt) {
        byIdentity[key] = source;
      }
    }
    final result = byIdentity.values.toList(growable: false)
      ..sort((left, right) {
        final tableOrder = left.table.compareTo(right.table);
        return tableOrder != 0 ? tableOrder : left.id.compareTo(right.id);
      });
    return result;
  }
}
