import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/ai_coach/domain/ai_chat_conversation.dart';
import 'package:rebirth/features/ai_coach/domain/ai_chat_input_assembler.dart';
import 'package:rebirth/features/ai_coach/domain/ai_chat_input_bundle.dart';
import 'package:rebirth/features/ai_coach/domain/ai_coach_exception.dart';
import 'package:rebirth/features/ai_coach/domain/ai_consent_repository.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_scope.dart';
import 'package:rebirth/features/ai_coach/domain/ai_input_source_ref.dart';
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

final class AiChatInputAssemblerImpl implements AiChatInputAssembler {
  const AiChatInputAssemblerImpl({
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
  Future<AiChatInputBundle> build({
    required List<AiChatMessage> conversationMessages,
    required Set<AiDataScope> scopes,
  }) async {
    final authorization = await consentRepository.read();
    if (!authorization.enabled) throw const AiConsentRequiredException();
    if (scopes.any(
      (scope) => !AiChatInputContract.supportedScopes.contains(scope),
    )) {
      throw UnsupportedAiDataScopeException(
        scopes
            .firstWhere(
              (scope) => !AiChatInputContract.supportedScopes.contains(scope),
            )
            .contractValue,
      );
    }

    final messages = _recentPromptMessages(conversationMessages);
    final snapshot = dateTimeService.currentSnapshot();
    final dates = dateTimeService.recentLocalDateRange(
      AiChatInputContract.contextPeriodDays,
      endingAt: snapshot.now,
    );
    final startDate = dates.first;
    final endDate = dates.last;

    GrowthSnapshot? growth;
    List<TodayEntry>? today;
    List<HealthEntry>? health;
    List<JournalEntry>? journals;
    final reads = <Future<void>>[];
    if (scopes.contains(AiDataScope.growthSummary)) {
      reads.add(
        growthRepository
            .loadRecent(GrowthPeriod.sevenDays)
            .then<void>((value) => growth = value),
      );
    }
    if (scopes.contains(AiDataScope.todayMetrics)) {
      reads.add(
        todayRepository
            .listByDateRange(startDate: startDate, endDate: endDate)
            .then<void>((value) => today = value),
      );
    }
    if (scopes.contains(AiDataScope.healthMetrics)) {
      reads.add(
        healthRepository
            .listByDateRange(startDate: startDate, endDate: endDate)
            .then<void>((value) => health = value),
      );
    }
    if (scopes.contains(AiDataScope.journalReflections)) {
      reads.add(
        journalRepository
            .listByDateRange(startDate: startDate, endDate: endDate)
            .then<void>((value) => journals = value),
      );
    }
    await Future.wait(reads);

    final optionalContext = <String, Object?>{};
    final sources = <AiInputSourceRef>[];
    final growthResult = growth;
    if (growthResult != null) {
      if (growthResult.period != GrowthPeriod.sevenDays ||
          growthResult.startDate != startDate ||
          growthResult.endDate != endDate) {
        throw const InvalidAiInputException(
          'Growth context does not match the chat period.',
        );
      }
      optionalContext[AiDataScope.growthSummary.contractValue] = _growthData(
        growthResult,
      );
    }
    final todayResult = today;
    if (todayResult != null) {
      final sorted = [...todayResult]
        ..sort((left, right) => left.recordDate.compareTo(right.recordDate));
      _validateDates(
        sorted.map((entry) => entry.recordDate),
        startDate,
        endDate,
      );
      optionalContext[AiDataScope.todayMetrics.contractValue] = sorted
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
      _validateDates(
        sorted.map((entry) => entry.recordDate),
        startDate,
        endDate,
      );
      optionalContext[AiDataScope.healthMetrics.contractValue] = sorted
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
      _validateDates(
        sorted.map((entry) => entry.entryDate),
        startDate,
        endDate,
      );
      optionalContext[AiDataScope.journalReflections.contractValue] = sorted
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
    final scopeValues =
        scopes.map((scope) => scope.contractValue).toList(growable: false)
          ..sort();
    final contextJson = canonicalJsonEncoder.encode(optionalContext);
    if (contextJson.length > AiChatInputContract.maximumContextCharacters) {
      throw const InvalidAiInputException('AI chat context is too large.');
    }
    final payload = <String, Object?>{
      'schema_version': AiChatInputContract.schemaVersion,
      'request_type': AiChatInputContract.requestType,
      'prompt_version': AiChatInputContract.promptVersion,
      'messages': messages
          .map((message) => message.toCanonicalMap())
          .toList(growable: false),
      'context_period': <String, Object?>{
        'start_date': startDate,
        'end_date': endDate,
      },
      'scopes': scopeValues,
      'optional_context': optionalContext,
      'sources': normalizedSources
          .map((source) => source.toCanonicalMap())
          .toList(growable: false),
    };
    final canonicalJson = canonicalJsonEncoder.encode(payload);
    return AiChatInputBundle(
      periodStartDate: startDate,
      periodEndDate: endDate,
      scopes: scopes,
      messages: messages,
      sources: normalizedSources,
      canonicalPayload: payload,
      canonicalJson: canonicalJson,
      inputHash: inputHashService.hashCanonicalJson(canonicalJson),
    );
  }

  List<AiChatPromptMessage> _recentPromptMessages(
    List<AiChatMessage> conversationMessages,
  ) {
    final completed = conversationMessages
        .where(
          (message) =>
              message.status == AiChatMessageStatus.completed &&
              message.content.trim().isNotEmpty,
        )
        .map(
          (message) => AiChatPromptMessage(
            role: message.role,
            content: _boundedMessage(message.content.trim()),
          ),
        )
        .toList(growable: true);
    if (completed.isEmpty || completed.last.role != AiChatRole.user) {
      throw const InvalidAiInputException(
        'AI chat history must end with a user message.',
      );
    }
    for (var index = 1; index < completed.length; index += 1) {
      if (completed[index - 1].role == completed[index].role) {
        throw const InvalidAiInputException(
          'AI chat history roles must alternate.',
        );
      }
    }
    while (completed.length > 11) {
      completed.removeRange(0, 2);
    }
    while (_historyCharacters(completed) >
            AiChatInputContract.maximumHistoryCharacters &&
        completed.length > 1) {
      completed.removeRange(0, 2);
    }
    if (completed.first.role != AiChatRole.user) {
      throw const InvalidAiInputException('Invalid AI chat history window.');
    }
    return List.unmodifiable(completed);
  }

  String _boundedMessage(String value) {
    if (value.length <= AiChatInputContract.maximumMessageCharacters) {
      return value;
    }
    return value.substring(0, AiChatInputContract.maximumMessageCharacters);
  }

  int _historyCharacters(List<AiChatPromptMessage> messages) =>
      messages.fold<int>(0, (total, message) => total + message.content.length);

  void _validateDates(
    Iterable<String> dates,
    String startDate,
    String endDate,
  ) {
    if (dates.any(
      (date) => date.compareTo(startDate) < 0 || date.compareTo(endDate) > 0,
    )) {
      throw const InvalidAiInputException(
        'AI chat context date is outside the requested period.',
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

  // Chat context intentionally excludes the optional one-line descriptions.
  Map<String, Object?> _todayData(TodayEntry entry) => {
    'record_date': entry.recordDate,
    'research_minutes': entry.researchMinutes,
    'learning_minutes': entry.learningMinutes,
    'mood_score': entry.moodScore,
    'energy_score': entry.energyScore,
    'wellbeing_score_scale': 10,
    'populated_priority_count': entry.populatedPriorityCount,
    'completed_priority_count': entry.completedPriorityCount,
    'status': entry.status.name,
  };

  Map<String, Object?> _healthData(HealthEntry entry) => {
    'record_date': entry.recordDate,
    'sleep_duration_minutes': entry.sleepDurationMinutes,
    'exercise_duration_minutes': entry.exerciseDurationMinutes,
    'physical_state_score': entry.physicalStateScore,
    'physical_state_score_scale': 10,
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

  List<AiInputSourceRef> _normalizeSources(Iterable<AiInputSourceRef> sources) {
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
