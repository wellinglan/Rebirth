import 'package:flutter_test/flutter_test.dart';
import 'dart:async';
import 'package:rebirth/core/config/server_endpoint_validator.dart';
import 'package:rebirth/features/account/domain/auth_session.dart';
import 'package:rebirth/features/account/domain/auth_user.dart';
import 'package:rebirth/features/ai_coach/domain/ai_generation_gateway.dart';
import 'package:rebirth/features/ai_coach/domain/ai_generation_request_binding.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_status.dart';
import 'package:rebirth/features/ai_coach/presentation/ai_pending_recovery_controller.dart';

import '../ai_coach_test_support.dart';

void main() {
  late FakeAiReportRepository reports;
  late FakeAiGenerationGateway gateway;
  late FakeAiGenerationRequestBindingStore bindings;
  late FakeAuthSessionStore sessions;

  setUp(() {
    reports = FakeAiReportRepository(
      reports: [buildAiReport(id: 'pending-1', status: AiReportStatus.pending)],
    );
    gateway = FakeAiGenerationGateway();
    bindings = FakeAiGenerationRequestBindingStore();
    bindings.values['pending-1'] = _binding();
    sessions = FakeAuthSessionStore(
      session: const AuthSession(
        accessToken: 'token',
        refreshToken: 'refresh',
        serverBaseUrl: 'http://127.0.0.1:8000',
        user: AuthUser(id: 'cloud-user', displayName: 'Test'),
      ),
    );
  });

  AiPendingRecoveryController controller({String? endpoint}) =>
      AiPendingRecoveryController(
        gateway: gateway,
        reports: reports,
        bindings: bindings,
        sessionStore: sessions,
        currentEndpoint: endpoint ?? 'http://127.0.0.1:8000',
        endpointValidator: const ServerEndpointValidator(),
      );

  test('completed status restores local report and removes binding', () async {
    gateway.statusResult = _remote(AiRemoteRequestStatus.completed);
    final result = await controller().check(reports.reports.single);
    expect(result, AiPendingRecoveryState.completed);
    expect(reports.markCompletedCalls, 1);
    expect(bindings.values, isEmpty);
    expect(gateway.statusCalls, 1);
    expect(gateway.generationCalls, 0);
  });

  test(
    'failed status restores controlled failure and removes binding',
    () async {
      gateway.statusResult = _remote(
        AiRemoteRequestStatus.failed,
        failureCode: AiReportFailureCode.providerTimeout,
      );
      final result = await controller().check(reports.reports.single);
      expect(result, AiPendingRecoveryState.failed);
      expect(reports.lastFailureCode, 'provider_timeout');
      expect(bindings.values, isEmpty);
    },
  );

  test('processing and network uncertainty preserve pending binding', () async {
    gateway.statusResult = _remote(AiRemoteRequestStatus.processing);
    expect(
      await controller().check(reports.reports.single),
      AiPendingRecoveryState.processing,
    );
    expect(reports.markCompletedCalls + reports.markFailedCalls, 0);
    expect(bindings.values, isNotEmpty);

    gateway.statusError = const AiGenerationException(
      AiReportFailureCode.networkOutcomeUnknown,
    );
    expect(
      await controller().check(reports.reports.single),
      AiPendingRecoveryState.networkUnknown,
    );
    expect(bindings.values, isNotEmpty);
  });

  test(
    'outcome unknown and result expired become controlled local failures',
    () async {
      for (final status in [
        AiRemoteRequestStatus.outcomeUnknown,
        AiRemoteRequestStatus.resultExpired,
      ]) {
        reports.reports = [
          buildAiReport(id: 'pending-1', status: AiReportStatus.pending),
        ];
        bindings.values['pending-1'] = _binding();
        gateway.statusResult = _remote(status);
        final result = await controller().check(reports.reports.single);
        expect(
          result,
          status == AiRemoteRequestStatus.outcomeUnknown
              ? AiPendingRecoveryState.outcomeUnknown
              : AiPendingRecoveryState.resultExpired,
        );
        expect(
          reports.lastFailureCode,
          status == AiRemoteRequestStatus.outcomeUnknown
              ? 'outcome_unknown'
              : 'result_expired',
        );
      }
    },
  );

  test('endpoint and account mismatch never query the gateway', () async {
    expect(
      await controller(
        endpoint: 'http://192.168.31.129:8000',
      ).check(reports.reports.single),
      AiPendingRecoveryState.endpointMismatch,
    );
    sessions.session = const AuthSession(
      accessToken: 'token',
      refreshToken: 'refresh',
      user: AuthUser(id: 'other-user', displayName: 'Other'),
    );
    expect(
      await controller().check(reports.reports.single),
      AiPendingRecoveryState.accountMismatch,
    );
    expect(gateway.statusCalls, 0);
    expect(gateway.generationCalls, 0);
  });

  test('missing binding and not found safely preserve pending', () async {
    bindings.values.clear();
    expect(
      await controller().check(reports.reports.single),
      AiPendingRecoveryState.missingBinding,
    );
    bindings.values['pending-1'] = _binding();
    gateway.statusResult = _remote(AiRemoteRequestStatus.notFound);
    expect(
      await controller().check(reports.reports.single),
      AiPendingRecoveryState.serverNotFound,
    );
    expect(reports.markFailedCalls, 0);
    expect(bindings.values, isNotEmpty);
  });

  test('confirmed not found marks failed without a provider request', () async {
    final recovery = controller();
    await recovery.confirmServerNotFound(reports.reports.single);

    expect(reports.lastFailureCode, 'server_state_not_found');
    expect(reports.reports.single.status, AiReportStatus.failed);
    expect(bindings.values, isEmpty);
    expect(gateway.statusCalls, 0);
    expect(gateway.generationCalls, 0);
  });

  test('duplicate status checks are suppressed and never generate', () async {
    final completer = Completer<AiRemoteRequestResult>();
    gateway.statusCompleter = completer;
    final recovery = controller();
    final first = recovery.check(reports.reports.single);
    await Future<void>.delayed(Duration.zero);
    expect(
      await recovery.check(reports.reports.single),
      AiPendingRecoveryState.checking,
    );
    completer.complete(_remote(AiRemoteRequestStatus.processing));
    expect(await first, AiPendingRecoveryState.processing);
    expect(gateway.statusCalls, 1);
    expect(gateway.generationCalls, 0);
  });
}

AiGenerationRequestBinding _binding() => const AiGenerationRequestBinding(
  localReportId: 'pending-1',
  requestId: 'pending-1',
  normalizedEndpoint: 'http://127.0.0.1:8000',
  cloudUserId: 'cloud-user',
  inputHash: '12345678aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa87654321',
  reportType: 'weekly_report',
  promptVersion: 'weekly-report-v1',
  createdAt: 1,
);

AiRemoteRequestResult _remote(
  AiRemoteRequestStatus status, {
  AiReportFailureCode? failureCode,
}) {
  final completed = status == AiRemoteRequestStatus.completed
      ? const AiGenerationResult(
          requestId: 'pending-1',
          reportType: 'weekly_report',
          promptVersion: 'weekly-report-v1',
          inputHash:
              '12345678aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa87654321',
          provider: 'fake',
          model: 'fake-model',
          outputSchemaVersion: 1,
          reportContent: '# recovered',
          structuredOutputJson:
              '{"title":"t","summary":"s","observations":[],"suggestions":[],"data_limitations":[]}',
        )
      : null;
  return AiRemoteRequestResult(
    status: status,
    requestId: 'pending-1',
    inputHash:
        '12345678aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa87654321',
    reportType: 'weekly_report',
    promptVersion: 'weekly-report-v1',
    completedResult: completed,
    failureCode: failureCode,
  );
}
