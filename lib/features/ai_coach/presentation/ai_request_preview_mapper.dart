import 'package:rebirth/features/ai_coach/domain/ai_coach_input_bundle.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_scope.dart';

import 'ai_coach_formatters.dart';
import 'models/ai_request_preview_model.dart';

final class AiPreviewMappingException implements Exception {
  const AiPreviewMappingException();

  @override
  String toString() => 'AI preview data could not be prepared.';
}

final class AiRequestPreviewMapper {
  const AiRequestPreviewMapper();

  static const _scopeOrder = [
    AiDataScope.growthSummary,
    AiDataScope.todayMetrics,
    AiDataScope.healthMetrics,
    AiDataScope.journalReflections,
  ];

  AiRequestPreviewModel map(AiCoachInputBundle bundle) {
    try {
      final data = _map(bundle.canonicalPayload['data']);
      final scopes = _scopeOrder
          .where(bundle.selection.scopes.contains)
          .toList(growable: false);
      return AiRequestPreviewModel(
        reportTypeLabel: AiCoachFormatters.reportType(bundle.reportType),
        periodStartDate: bundle.periodStartDate,
        periodEndDate: bundle.periodEndDate,
        promptVersion: bundle.promptVersion,
        shortInputHash: AiCoachFormatters.shortHash(bundle.inputHash),
        sourceCount: bundle.sources.length,
        scopes: scopes,
        growth: scopes.contains(AiDataScope.growthSummary)
            ? _growth(_map(data[AiDataScope.growthSummary.contractValue]))
            : null,
        todayDays: scopes.contains(AiDataScope.todayMetrics)
            ? _today(_list(data[AiDataScope.todayMetrics.contractValue]))
            : const [],
        healthDays: scopes.contains(AiDataScope.healthMetrics)
            ? _health(_list(data[AiDataScope.healthMetrics.contractValue]))
            : const [],
        journalDays: scopes.contains(AiDataScope.journalReflections)
            ? _journal(
                _list(data[AiDataScope.journalReflections.contractValue]),
              )
            : const [],
      );
    } catch (_) {
      throw const AiPreviewMappingException();
    }
  }

  AiGrowthPreviewModel _growth(Map<String, Object?> data) {
    return AiGrowthPreviewModel(
      researchTotalMinutes: _recordedTotal(_map(data['research'])),
      learningTotalMinutes: _recordedTotal(_map(data['learning'])),
      exerciseTotalMinutes: _recordedTotal(_map(data['exercise'])),
      averageSleepMinutes: _recordedAverage(_map(data['sleep'])),
      averageMood: _recordedAverage(_map(data['mood'])),
      averageEnergy: _recordedAverage(_map(data['energy'])),
      journalRecordedDays: _int(data['journal_recorded_days']) ?? 0,
      journalCompletedDays: _int(data['journal_completed_days']) ?? 0,
      periodDays: _int(data['period_days']) ?? 7,
    );
  }

  List<AiTodayDayPreviewModel> _today(List<Object?> rows) {
    final result = rows
        .map((row) {
          final data = _map(row);
          return AiTodayDayPreviewModel(
            date: _string(data['record_date']),
            researchMinutes: _int(data['research_minutes']),
            learningMinutes: _int(data['learning_minutes']),
            moodScore: _int(data['mood_score']),
            energyScore: _int(data['energy_score']),
            populatedPriorityCount: _int(data['populated_priority_count']) ?? 0,
            completedPriorityCount: _int(data['completed_priority_count']) ?? 0,
            statusLabel: AiCoachFormatters.recordStatus(
              _string(data['status']),
            ),
          );
        })
        .toList(growable: false);
    result.sort((left, right) => left.date.compareTo(right.date));
    return result;
  }

  List<AiHealthDayPreviewModel> _health(List<Object?> rows) {
    final result = rows
        .map((row) {
          final data = _map(row);
          return AiHealthDayPreviewModel(
            date: _string(data['record_date']),
            sleepDurationMinutes: _int(data['sleep_duration_minutes']),
            exerciseDurationMinutes: _int(data['exercise_duration_minutes']),
            physicalStateScore: _int(data['physical_state_score']),
            waterIntakeMl: _int(data['water_intake_ml']),
            weightKg: _double(data['weight_kg']),
          );
        })
        .toList(growable: false);
    result.sort((left, right) => left.date.compareTo(right.date));
    return result;
  }

  List<AiJournalDayPreviewModel> _journal(List<Object?> rows) {
    final result = rows
        .map((row) {
          final data = _map(row);
          return AiJournalDayPreviewModel(
            date: _string(data['entry_date']),
            statusLabel: AiCoachFormatters.recordStatus(
              _string(data['status']),
            ),
            mostImportantAccomplishment: _text(
              data['most_important_accomplishment'],
            ),
            mostDrainingEvent: _text(data['most_draining_event']),
            emotionSource: _text(data['emotion_source']),
            learning: _text(data['learning']),
            tomorrowAdjustment: _text(data['tomorrow_adjustment']),
          );
        })
        .toList(growable: false);
    result.sort((left, right) => left.date.compareTo(right.date));
    return result;
  }

  int? _recordedTotal(Map<String, Object?> summary) {
    if ((_int(summary['recorded_day_count']) ?? 0) == 0) return null;
    return _int(summary['total']);
  }

  double? _recordedAverage(Map<String, Object?> summary) {
    if ((_int(summary['recorded_day_count']) ?? 0) == 0) return null;
    return _double(summary['average']);
  }

  Map<String, Object?> _map(Object? value) {
    if (value is! Map) throw const AiPreviewMappingException();
    return value.map((key, item) {
      if (key is! String) throw const AiPreviewMappingException();
      return MapEntry(key, item);
    });
  }

  List<Object?> _list(Object? value) {
    if (value is! List) throw const AiPreviewMappingException();
    return value.cast<Object?>();
  }

  String _string(Object? value) {
    if (value is! String) throw const AiPreviewMappingException();
    return value;
  }

  int? _int(Object? value) {
    if (value == null) return null;
    if (value is! int) throw const AiPreviewMappingException();
    return value;
  }

  double? _double(Object? value) {
    if (value == null) return null;
    if (value is! num) throw const AiPreviewMappingException();
    return value.toDouble();
  }

  String? _text(Object? value) {
    if (value == null) return null;
    final text = _string(value).trim();
    return text.isEmpty ? null : text;
  }
}
