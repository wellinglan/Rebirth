import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/ai_coach/domain/ai_coach_input_bundle.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_scope.dart';
import 'package:rebirth/features/ai_coach/presentation/ai_request_preview_mapper.dart';

import '../ai_coach_test_support.dart';

void main() {
  const mapper = AiRequestPreviewMapper();

  test('maps top-level metadata, shortened hash, and stable scope order', () {
    final preview = mapper.map(buildAiBundle());

    expect(preview.reportTypeLabel, '每周回顾');
    expect(preview.periodStartDate, '2026-07-10');
    expect(preview.periodEndDate, '2026-07-16');
    expect(preview.promptVersion, 'weekly-report-v1');
    expect(preview.shortInputHash, '12345678…87654321');
    expect(preview.sourceCount, 1);
    expect(preview.scopes, [
      AiDataScope.growthSummary,
      AiDataScope.todayMetrics,
      AiDataScope.healthMetrics,
      AiDataScope.journalReflections,
    ]);
  });

  test('growth distinguishes unrecorded values from a recorded zero', () {
    final growth = mapper.map(buildAiBundle()).growth!;

    expect(growth.researchTotalMinutes, isNull);
    expect(growth.learningTotalMinutes, 0);
    expect(growth.exerciseTotalMinutes, 45);
    expect(growth.averageSleepMinutes, 420);
    expect(growth.averageMood, 4);
    expect(growth.averageEnergy, isNull);
    expect(growth.journalRecordedDays, 2);
    expect(growth.journalCompletedDays, 1);
  });

  test('Today is date-ascending and exposes only minimized metric fields', () {
    final days = mapper.map(buildAiBundle()).todayDays;

    expect(days.map((day) => day.date), ['2026-07-10', '2026-07-16']);
    expect(days.first.researchMinutes, 0);
    expect(days.first.learningMinutes, 60);
    expect(days.last.populatedPriorityCount, 2);
    expect(days.last.completedPriorityCount, 1);
    expect(days.last.statusLabel, '已完成');
    expect(
      days.first.toString(),
      isNot(anyOf(contains('daily_note'), contains('priority_text'))),
    );
  });

  test('Health exposes metrics without note or source identity', () {
    final day = mapper.map(buildAiBundle()).healthDays.single;

    expect(day.date, '2026-07-16');
    expect(day.sleepDurationMinutes, 450);
    expect(day.exerciseDurationMinutes, 30);
    expect(day.waterIntakeMl, 1800);
    expect(day.weightKg, 65.5);
    expect(day.toString(), isNot(contains('excluded health note')));
    expect(day.toString(), isNot(contains('excluded-source-id')));
  });

  test('Journal is absent unless explicitly selected', () {
    final preview = mapper.map(
      buildAiBundle(scopes: {AiDataScope.todayMetrics}),
    );

    expect(preview.journalDays, isEmpty);
    expect(preview.scopes, [AiDataScope.todayMetrics]);
  });

  test('selected Journal is sorted and blank answers become null', () {
    final days = mapper
        .map(buildAiBundle(scopes: {AiDataScope.journalReflections}))
        .journalDays;

    expect(days.map((day) => day.date), ['2026-07-10', '2026-07-16']);
    expect(days.first.learning, '保持耐心');
    expect(days.last.learning, isNull);
    expect(days.last.mostDrainingEvent, '一段私人经历');
  });

  test(
    'mapper uses typed payload contract and ignores canonical JSON body',
    () {
      final preview = mapper.map(
        buildAiBundle(canonicalJson: 'userId deviceId endpoint sync secret'),
      );

      expect(preview.shortInputHash, '12345678…87654321');
      expect(preview.reportTypeLabel, '每周回顾');
    },
  );

  test('invalid public payload becomes a sanitized mapping error', () {
    final source = buildAiBundle(scopes: {AiDataScope.todayMetrics});
    final broken = AiCoachInputBundle(
      reportType: source.reportType,
      promptVersion: source.promptVersion,
      periodStartDate: source.periodStartDate,
      periodEndDate: source.periodEndDate,
      selection: source.selection,
      sources: source.sources,
      canonicalPayload: const {'data': 'private Journal body'},
      canonicalJson: 'private canonical JSON',
      inputHash: source.inputHash,
    );

    expect(
      () => mapper.map(broken),
      throwsA(
        isA<AiPreviewMappingException>().having(
          (error) => error.toString(),
          'sanitized message',
          'AI preview data could not be prepared.',
        ),
      ),
    );
  });
}
