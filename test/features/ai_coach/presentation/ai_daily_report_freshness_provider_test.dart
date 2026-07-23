import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/ai_coach/data/ai_coach_repository_providers.dart';
import 'package:rebirth/features/ai_coach/domain/ai_coach_input_bundle.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_scope.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_type.dart';
import 'package:rebirth/features/ai_coach/domain/daily_report_freshness.dart';
import 'package:rebirth/features/ai_coach/presentation/ai_daily_report_freshness_provider.dart';

import '../ai_coach_test_support.dart';

void main() {
  late FakeAiCoachInputAssembler assembler;
  late FakeAiReportRepository reports;
  late ProviderContainer container;

  setUp(() {
    assembler = FakeAiCoachInputAssembler(
      bundle: buildAiBundle(
        reportType: AiReportType.dailyInsight,
        scopes: {AiDataScope.todayMetrics},
      ),
    );
    reports = FakeAiReportRepository(
      reports: [
        buildAiReport(id: 'daily', reportType: AiReportType.dailyInsight),
      ],
    );
    container = ProviderContainer(
      overrides: [
        aiCoachInputAssemblerProvider.overrideWithValue(assembler),
        aiReportRepositoryProvider.overrideWithValue(reports),
      ],
    );
  });

  tearDown(() => container.dispose());

  test('detail provider loads the report and evaluates freshness', () async {
    final result = await container.read(
      aiDailyReportFreshnessProvider('daily').future,
    );

    expect(result?.status, DailyReportFreshness.current);
    expect(reports.getCalls, 1);
    expect(assembler.dailyBuildCalls, 1);
  });

  test(
    'invalidating after a source update refreshes current to stale',
    () async {
      final provider = aiDailyReportFreshnessProvider('daily');
      expect(
        (await container.read(provider.future))?.status,
        DailyReportFreshness.current,
      );

      assembler.bundle = buildAiBundle(
        reportType: AiReportType.dailyInsight,
        scopes: {AiDataScope.todayMetrics},
        hash:
            'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
      );
      container.invalidate(provider);
      final refreshed = await container.read(provider.future);

      expect(refreshed?.status, DailyReportFreshness.stale);
      expect(assembler.dailyBuildCalls, 2);
    },
  );

  test('calculation failure becomes unavailable without escaping', () async {
    assembler.error = StateError('private source payload');

    final result = await container.read(
      aiDailyReportFreshnessProvider('daily').future,
    );

    expect(result?.status, DailyReportFreshness.unavailable);
    expect(result?.reason, DailyReportFreshnessReason.bundleBuildFailed);
  });

  test(
    'disposing during evaluation leaves no provider update behind',
    () async {
      final completer = Completer<AiCoachInputBundle>();
      assembler.queuedResponses.add(completer.future);
      final future = container.read(
        aiDailyReportFreshnessProvider('daily').future,
      );

      container.dispose();
      completer.complete(assembler.bundle);
      await expectLater(future, completes);
      container = ProviderContainer();
    },
  );

  test('re-entering through a new container recalculates freshness', () async {
    await container.read(aiDailyReportFreshnessProvider('daily').future);
    container.dispose();
    container = ProviderContainer(
      overrides: [
        aiCoachInputAssemblerProvider.overrideWithValue(assembler),
        aiReportRepositoryProvider.overrideWithValue(reports),
      ],
    );

    await container.read(aiDailyReportFreshnessProvider('daily').future);

    expect(assembler.dailyBuildCalls, 2);
  });
}
