import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/ai_coach/domain/ai_coach_exception.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_authorization.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_scope.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_selection.dart';
import 'package:rebirth/features/ai_coach/domain/ai_generation_mode.dart';
import 'package:rebirth/features/ai_coach/domain/ai_input_source_ref.dart';
import 'package:rebirth/features/ai_coach/domain/ai_input_contract.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_status.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_type.dart';

void main() {
  test('AI report, status, and generation mode mappings are stable', () {
    expect(AiReportType.values.map((value) => value.databaseValue), [
      'daily_insight',
      'weekly_report',
      'monthly_reflection',
      'tomorrow_suggestion',
      'trend_explanation',
    ]);
    expect(AiReportStatus.values.map((value) => value.databaseValue), [
      'pending',
      'completed',
      'failed',
    ]);
    expect(AiGenerationMode.values.map((value) => value.databaseValue), [
      'manual',
      'automatic',
    ]);
  });

  test('AI data scopes expose stable contract values', () {
    expect(AiDataScope.values.map((value) => value.contractValue), [
      'growth_summary',
      'today_metrics',
      'health_metrics',
      'journal_reflections',
      'active_goals',
    ]);
    expect(AiDataScope.activeGoals.supported, isFalse);
  });

  test('Daily and Weekly have distinct supported report contracts', () {
    expect(
      AiInputContract.isSupportedReportType(AiReportType.dailyInsight),
      isTrue,
    );
    expect(
      AiInputContract.isSupportedReportType(AiReportType.weeklyReport),
      isTrue,
    );
    expect(
      AiInputContract.isSupportedReportType(AiReportType.monthlyReflection),
      isFalse,
    );
    expect(
      AiInputContract.promptVersionFor(AiReportType.dailyInsight),
      'daily-insight-v1',
    );
    expect(AiInputContract.supportedScopesFor(AiReportType.dailyInsight), {
      AiDataScope.todayMetrics,
      AiDataScope.healthMetrics,
      AiDataScope.journalReflections,
    });
    expect(
      AiInputContract.supportedScopesFor(AiReportType.dailyInsight),
      isNot(contains(AiDataScope.growthSummary)),
    );
  });

  test(
    'selection rejects empty scopes and defaults snapshot persistence off',
    () {
      expect(
        () => AiDataSelection(scopes: const {}),
        throwsA(isA<EmptyAiDataSelectionException>()),
      );
      final selection = AiDataSelection(scopes: {AiDataScope.todayMetrics});
      expect(selection.persistInputSnapshot, isFalse);
      expect(
        () => selection.scopes.add(AiDataScope.healthMetrics),
        throwsUnsupportedError,
      );
    },
  );

  test('enabled authorization requires a non-negative UTC timestamp', () {
    expect(
      () => AiDataAuthorization(enabled: true, consentAt: null),
      throwsArgumentError,
    );
    expect(
      () => AiDataAuthorization(enabled: false, consentAt: -1),
      throwsArgumentError,
    );
    expect(AiDataAuthorization(enabled: true, consentAt: 123).consentAt, 123);
  });

  test('source references enforce the table whitelist and timestamp', () {
    expect(
      () => AiInputSourceRef(table: 'growth_summary', id: 'one', updatedAt: 0),
      throwsA(isA<InvalidAiInputException>()),
    );
    expect(
      () => AiInputSourceRef(table: 'today_records', id: 'one', updatedAt: -1),
      throwsA(isA<InvalidAiInputException>()),
    );
    expect(
      AiInputSourceRef(
        table: 'today_records',
        id: 'one',
        updatedAt: 0,
      ).toCanonicalMap(),
      {'id': 'one', 'table': 'today_records', 'updated_at': 0},
    );
  });
}
