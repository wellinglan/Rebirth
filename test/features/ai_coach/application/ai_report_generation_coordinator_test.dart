import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/config/server_endpoint_validator.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/account/domain/auth_session.dart';
import 'package:rebirth/features/account/domain/auth_user.dart';
import 'package:rebirth/features/ai_coach/application/ai_report_generation_coordinator.dart';
import 'package:rebirth/features/ai_coach/domain/ai_coach_input_bundle.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_authorization.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_scope.dart';
import 'package:rebirth/features/ai_coach/domain/ai_generation_gateway.dart';
import 'package:rebirth/features/ai_coach/domain/ai_generation_report_contract.dart';
import 'package:rebirth/features/ai_coach/domain/ai_generation_request_binding.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_status.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_type.dart';

import '../ai_coach_test_support.dart';

void main() {
  late _Harness harness;

  setUp(() {
    harness = _Harness();
  });

  test(
    'weekly generation uses one coordinator path and stores a terminal version',
    () async {
      final result = await harness.coordinator.generate(harness.weeklyBundle);

      expect(result.completed, isTrue);
      expect(result.reportId, 'pending-1');
      expect(harness.reports.createPendingCalls, 1);
      expect(harness.gateway.weeklyGenerationCalls, 1);
      expect(harness.gateway.dailyGenerationCalls, 0);
      expect(harness.reports.markCompletedCalls, 1);
      expect(harness.bindings.saveCalls, 1);
      expect(harness.bindings.values, isEmpty);
      expect(
        harness.reports.reports.single.generationEndpointHash,
        hasLength(64),
      );
    },
  );

  test(
    'daily generation shares the same coordinator and calls the daily endpoint',
    () async {
      harness.gateway.capabilities = _dailyCapabilities();
      final result = await harness.coordinator.generate(harness.dailyBundle);

      expect(result.completed, isTrue);
      expect(harness.gateway.dailyGenerationCalls, 1);
      expect(harness.gateway.weeklyGenerationCalls, 0);
      expect(
        harness.reports.lastPendingInput?.reportType,
        AiReportType.dailyInsight,
      );
    },
  );

  test('same account endpoint and input hash are single-flighted', () async {
    final gateway = _DelayedGateway();
    harness = _Harness(gateway: gateway);

    final first = harness.coordinator.generate(harness.weeklyBundle);
    await Future<void>.delayed(Duration.zero);
    final second = harness.coordinator.generate(harness.weeklyBundle);
    await Future<void>.delayed(Duration.zero);
    gateway.complete();

    final results = await Future.wait([first, second]);

    expect(results.map((item) => item.reportId).toSet(), {'pending-1'});
    expect(harness.reports.createPendingCalls, 1);
    expect(gateway.weeklyGenerationCalls, 1);
    expect(harness.bindings.saveCalls, 1);
    expect(harness.reports.markCompletedCalls, 1);
  });

  test('processing response preserves pending report and binding', () async {
    harness.gateway.generationResult = AiRemoteRequestResult(
      status: AiRemoteRequestStatus.processing,
      requestId: 'pending-1',
      inputHash: harness.weeklyBundle.inputHash,
      reportType: 'weekly_report',
      promptVersion: 'weekly-report-v1',
    );

    final result = await harness.coordinator.generate(harness.weeklyBundle);

    expect(result.awaitingRecovery, isTrue);
    expect(harness.reports.reports.single.status, AiReportStatus.pending);
    expect(
      harness.reports.markCompletedCalls + harness.reports.markFailedCalls,
      0,
    );
    expect(harness.bindings.values, contains('pending-1'));
  });

  test(
    'account switch before apply leaves original pending binding untouched',
    () async {
      final gateway = _DelayedGateway();
      harness = _Harness(gateway: gateway);

      final operation = harness.coordinator.generate(harness.weeklyBundle);
      await Future<void>.delayed(Duration.zero);
      harness.sessions.session = const AuthSession(
        accessToken: 'token',
        refreshToken: 'refresh',
        user: AuthUser(id: 'other-cloud-user', displayName: 'Other'),
      );
      gateway.complete();

      final result = await operation;

      expect(result.awaitingRecovery, isTrue);
      expect(harness.reports.markCompletedCalls, 0);
      expect(harness.reports.markFailedCalls, 0);
      expect(harness.bindings.values, contains('pending-1'));
    },
  );

  test(
    'consent revoked after submit does not apply returned content',
    () async {
      final gateway = _DelayedGateway();
      harness = _Harness(gateway: gateway);

      final operation = harness.coordinator.generate(harness.weeklyBundle);
      await Future<void>.delayed(Duration.zero);
      harness.consent.authorization = AiDataAuthorization(
        enabled: false,
        consentAt: harness.consent.authorization.consentAt,
      );
      gateway.complete();

      final result = await operation;

      expect(result.awaitingRecovery, isTrue);
      expect(harness.reports.markCompletedCalls, 0);
      expect(harness.reports.markFailedCalls, 0);
      expect(harness.bindings.values, contains('pending-1'));
    },
  );

  test('network uncertainty leaves the original request recoverable', () async {
    harness.gateway.generationError = const AiGenerationException(
      AiReportFailureCode.networkOutcomeUnknown,
    );

    final result = await harness.coordinator.generate(harness.weeklyBundle);

    expect(result.awaitingRecovery, isTrue);
    expect(harness.reports.reports.single.status, AiReportStatus.pending);
    expect(harness.reports.markFailedCalls, 0);
    expect(harness.bindings.values, contains('pending-1'));
  });

  test(
    'terminal failed status writes controlled failure and clears binding',
    () async {
      harness.gateway.generationResult = AiRemoteRequestResult(
        status: AiRemoteRequestStatus.failed,
        requestId: 'pending-1',
        inputHash: harness.weeklyBundle.inputHash,
        reportType: 'weekly_report',
        promptVersion: 'weekly-report-v1',
        failureCode: AiReportFailureCode.providerTimeout,
      );

      final result = await harness.coordinator.generate(harness.weeklyBundle);

      expect(result.status, AiReportGenerationResultStatus.failed);
      expect(result.failureCode, AiReportFailureCode.providerTimeout);
      expect(harness.reports.lastFailureCode, 'provider_timeout');
      expect(harness.bindings.values, isEmpty);
    },
  );

  test(
    'recovery checks only status and never submits a new generate POST',
    () async {
      final report = buildAiReport(
        id: 'pending-1',
        status: AiReportStatus.pending,
      );
      harness.reports.reports = [report];
      harness.bindings.values['pending-1'] = _binding(harness.weeklyBundle);
      harness.gateway.statusResult = _status(
        harness.weeklyBundle,
        AiRemoteRequestStatus.completed,
      );

      final result = await harness.coordinator.recoverPending(report);

      expect(result.status, AiReportGenerationRecoveryStatus.completed);
      expect(harness.gateway.statusCalls, 1);
      expect(harness.gateway.generationCalls, 0);
      expect(harness.reports.markCompletedCalls, 1);
      expect(harness.bindings.values, isEmpty);
    },
  );

  test('recovery endpoint mismatch does not query the server', () async {
    final report = buildAiReport(
      id: 'pending-1',
      status: AiReportStatus.pending,
    );
    harness.reports.reports = [report];
    harness.bindings.values['pending-1'] = AiGenerationRequestBinding(
      localReportId: 'pending-1',
      requestId: 'pending-1',
      normalizedEndpoint: 'http://192.168.31.129:8000',
      cloudUserId: 'cloud-user',
      inputHash: harness.weeklyBundle.inputHash,
      reportType: 'weekly_report',
      promptVersion: 'weekly-report-v1',
      createdAt: 1,
    );

    final result = await harness.coordinator.recoverPending(report);

    expect(result.status, AiReportGenerationRecoveryStatus.endpointMismatch);
    expect(harness.gateway.statusCalls, 0);
    expect(harness.gateway.generationCalls, 0);
  });
}

final class _Harness {
  _Harness({FakeAiGenerationGateway? gateway})
    : gateway = gateway ?? FakeAiGenerationGateway();

  late final FakeAiConsentRepository consent = FakeAiConsentRepository(
    authorization: AiDataAuthorization(enabled: true, consentAt: 1),
  );
  late final FakeAiReportRepository reports = FakeAiReportRepository();
  late final FakeAiGenerationRequestBindingStore bindings =
      FakeAiGenerationRequestBindingStore();
  late final FakeAuthSessionStore sessions = FakeAuthSessionStore(
    session: const AuthSession(
      accessToken: 'token',
      refreshToken: 'refresh',
      user: AuthUser(id: 'cloud-user', displayName: 'Test'),
    ),
  );
  final FakeAiGenerationGateway gateway;
  late final AiCoachInputBundle weeklyBundle = buildAiBundle(
    scopes: {AiDataScope.growthSummary},
    sourceCount: 0,
  );
  late final AiCoachInputBundle dailyBundle = buildAiBundle(
    reportType: AiReportType.dailyInsight,
    scopes: {AiDataScope.todayMetrics},
    targetDate: '2026-07-16',
  );
  late final AiReportGenerationCoordinator coordinator =
      AiReportGenerationCoordinator(
        gateway: gateway,
        reports: reports,
        consentRepository: consent,
        sessionStore: sessions,
        bindings: bindings,
        dateTimeService: DateTimeService(now: () => DateTime(2026, 7, 16, 9)),
        currentEndpoint: 'http://127.0.0.1:8000',
        endpointValidator: const ServerEndpointValidator(),
      );
}

final class _DelayedGateway extends FakeAiGenerationGateway {
  final _completer = Completer<void>();

  void complete() => _completer.complete();

  @override
  Future<AiRemoteRequestResult> generateWeekly({
    required String requestId,
    required AiCoachInputBundle bundle,
  }) async {
    generationCalls += 1;
    weeklyGenerationCalls += 1;
    lastRequestId = requestId;
    lastBundle = bundle;
    await _completer.future;
    return _completed(bundle, requestId: requestId);
  }
}

AiGenerationCapabilities _dailyCapabilities() => AiGenerationCapabilities(
  enabled: true,
  provider: 'fake',
  providerLabel: 'Development Fake',
  model: 'deterministic-test-provider',
  supportedReportTypes: const ['daily_insight'],
  promptVersions: const ['daily-insight-v1'],
  reportContracts: [
    AiGenerationReportContract(
      reportType: 'daily_insight',
      promptVersions: const ['daily-insight-v1'],
      inputSchemaVersion: 1,
      outputSchemaVersion: 1,
      periodKind: AiReportPeriodKind.singleDay,
      supportedScopes: const [
        'today_metrics',
        'health_metrics',
        'journal_reflections',
      ],
    ),
  ],
  inputSchemaVersion: 1,
  outputSchemaVersion: 1,
  streaming: false,
  responseStorageRequested: false,
);

AiGenerationRequestBinding _binding(AiCoachInputBundle bundle) =>
    AiGenerationRequestBinding(
      localReportId: 'pending-1',
      requestId: 'pending-1',
      normalizedEndpoint: 'http://127.0.0.1:8000',
      cloudUserId: 'cloud-user',
      inputHash: bundle.inputHash,
      reportType: bundle.reportType.databaseValue,
      promptVersion: bundle.promptVersion,
      createdAt: 1,
    );

AiRemoteRequestResult _status(
  AiCoachInputBundle bundle,
  AiRemoteRequestStatus status,
) {
  return AiRemoteRequestResult(
    status: status,
    requestId: 'pending-1',
    inputHash: bundle.inputHash,
    reportType: bundle.reportType.databaseValue,
    promptVersion: bundle.promptVersion,
    completedResult: status == AiRemoteRequestStatus.completed
        ? _completed(bundle, requestId: 'pending-1').completedResult
        : null,
  );
}

AiRemoteRequestResult _completed(
  AiCoachInputBundle bundle, {
  required String requestId,
}) {
  return AiRemoteRequestResult(
    status: AiRemoteRequestStatus.completed,
    requestId: requestId,
    inputHash: bundle.inputHash,
    reportType: bundle.reportType.databaseValue,
    promptVersion: bundle.promptVersion,
    completedResult: AiGenerationResult(
      requestId: requestId,
      reportType: bundle.reportType.databaseValue,
      promptVersion: bundle.promptVersion,
      inputHash: bundle.inputHash,
      provider: 'fake',
      model: 'fake-model',
      outputSchemaVersion: 1,
      reportContent: '# result',
      structuredOutputJson:
          '{"title":"t","summary":"s","observations":[],"suggestions":[],"data_limitations":[]}',
    ),
  );
}
