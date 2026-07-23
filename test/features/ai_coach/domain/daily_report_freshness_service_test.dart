import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/ai_coach/domain/ai_coach_input_bundle.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_scope.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_type.dart';
import 'package:rebirth/features/ai_coach/domain/daily_report_freshness.dart';
import 'package:rebirth/features/ai_coach/domain/daily_report_freshness_service.dart';

import '../ai_coach_test_support.dart';

void main() {
  late FakeAiCoachInputAssembler assembler;
  late DailyReportFreshnessService service;

  setUp(() {
    assembler = FakeAiCoachInputAssembler(
      bundle: buildAiBundle(
        reportType: AiReportType.dailyInsight,
        scopes: {AiDataScope.todayMetrics},
      ),
    );
    service = DailyReportFreshnessService(inputAssembler: assembler);
  });

  test('identical current bundle is current', () async {
    final result = await service.evaluate(_daily());

    expect(result.status, DailyReportFreshness.current);
    expect(result.reason, DailyReportFreshnessReason.currentHashMatch);
    expect(assembler.dailyBuildCalls, 1);
    expect(assembler.selections.single.scopes, {AiDataScope.todayMetrics});
  });

  for (final change in ['Today field', 'Health field', 'Journal text']) {
    test('$change hash change is stale', () async {
      assembler.bundle = _changedBundle(
        scopes: switch (change) {
          'Health field' => {AiDataScope.healthMetrics},
          'Journal text' => {AiDataScope.journalReflections},
          _ => {AiDataScope.todayMetrics},
        },
      );
      final result = await service.evaluate(
        _daily(scopes: assembler.bundle.selection.scopes),
      );

      expect(result.status, DailyReportFreshness.stale);
      expect(result.reason, DailyReportFreshnessReason.currentHashMismatch);
    });
  }

  for (final unchanged in ['null remains null', 'zero remains zero']) {
    test('$unchanged is current', () async {
      final result = await service.evaluate(_daily());
      expect(result.status, DailyReportFreshness.current);
    });
  }

  for (final change in ['null to zero', 'zero to null']) {
    test('$change is stale', () async {
      assembler.bundle = _changedBundle();
      final result = await service.evaluate(_daily());
      expect(result.status, DailyReportFreshness.stale);
    });
  }

  test('unselected scope changes do not alter the selected bundle', () async {
    final result = await service.evaluate(_daily());

    expect(result.status, DailyReportFreshness.current);
    expect(assembler.selections.single.scopes, {AiDataScope.todayMetrics});
  });

  test('selected missing followed by a new record is stale', () async {
    assembler.bundle = _changedBundle(scopes: {AiDataScope.healthMetrics});
    final result = await service.evaluate(
      _daily(scopes: {AiDataScope.healthMetrics}),
    );

    expect(result.status, DailyReportFreshness.stale);
  });

  test(
    'selected record deletion is stale under the current bundle contract',
    () async {
      assembler.bundle = _changedBundle(sourceCount: 0);
      final result = await service.evaluate(_daily());

      expect(result.status, DailyReportFreshness.stale);
    },
  );

  test('missing stored hash is unavailable', () async {
    final result = await service.evaluate(_daily(inputHash: ''));

    expect(result.status, DailyReportFreshness.unavailable);
    expect(result.reason, DailyReportFreshnessReason.missingStoredHash);
    expect(assembler.buildCalls, 0);
  });

  test('invalid stored hash is unavailable', () async {
    final result = await service.evaluate(_daily(inputHash: 'not-a-hash'));

    expect(result.status, DailyReportFreshness.unavailable);
    expect(result.reason, DailyReportFreshnessReason.invalidStoredHash);
  });

  test('unsupported metadata version is unavailable', () async {
    final result = await service.evaluate(_daily(inputMetadataVersion: 2));

    expect(result.status, DailyReportFreshness.unavailable);
    expect(result.reason, DailyReportFreshnessReason.unsupportedReportVersion);
  });

  test('legacy report without scope metadata is unavailable', () async {
    final result = await service.evaluate(
      _daily(includeFreshnessMetadata: false),
    );

    expect(result.status, DailyReportFreshness.unavailable);
    expect(result.reason, DailyReportFreshnessReason.missingRebuildMetadata);
  });

  test('weekly report never enters Daily freshness', () async {
    final result = await service.evaluate(
      buildAiReport(id: 'weekly', reportType: AiReportType.weeklyReport),
    );

    expect(result.status, DailyReportFreshness.unavailable);
    expect(result.reason, DailyReportFreshnessReason.notDailyReport);
    expect(assembler.buildCalls, 0);
  });

  test('bundle or source read failure is unavailable and sanitized', () async {
    assembler.error = StateError('private journal payload');
    final result = await service.evaluate(_daily());

    expect(result.status, DailyReportFreshness.unavailable);
    expect(result.reason, DailyReportFreshnessReason.bundleBuildFailed);
    expect(result.currentInputHash, isNull);
  });
}

AiReport _daily({
  Set<AiDataScope> scopes = const {AiDataScope.todayMetrics},
  String inputHash =
      '12345678aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa87654321',
  int? inputMetadataVersion,
  bool includeFreshnessMetadata = true,
}) {
  return buildAiReport(
    id: 'daily',
    reportType: AiReportType.dailyInsight,
    selectedScopes: scopes,
    inputHash: inputHash,
    inputMetadataVersion: inputMetadataVersion,
    includeFreshnessMetadata: includeFreshnessMetadata,
  );
}

AiCoachInputBundle _changedBundle({
  Set<AiDataScope> scopes = const {AiDataScope.todayMetrics},
  int sourceCount = 1,
}) {
  return buildAiBundle(
    reportType: AiReportType.dailyInsight,
    scopes: scopes,
    sourceCount: sourceCount,
    hash: 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
  );
}
