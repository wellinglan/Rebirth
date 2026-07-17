import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/account/data/account_repository_provider.dart';
import 'package:rebirth/features/account/data/auth_session_store.dart';
import 'package:rebirth/features/account/domain/auth_session.dart';
import 'package:rebirth/features/account/domain/auth_user.dart';
import 'package:rebirth/features/ai_coach/data/ai_coach_repository_providers.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_authorization.dart';
import 'package:rebirth/features/ai_coach/domain/ai_coach_input_bundle.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_scope.dart';
import 'package:rebirth/features/ai_coach/domain/ai_generation_gateway.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_status.dart';
import 'package:rebirth/features/ai_coach/presentation/ai_manual_generation_controller.dart';
import 'package:rebirth/features/ai_coach/presentation/ai_manual_generation_view_state.dart';
import 'package:rebirth/features/ai_coach/presentation/ai_request_preview_controller.dart';

import '../ai_coach_test_support.dart';

void main() {
  late ProviderContainer container;
  late FakeAiConsentRepository consent;
  late FakeAiReportRepository reports;
  late FakeAiGenerationGateway gateway;
  late FakeSessionStore sessions;
  late FakeAiCoachInputAssembler assembler;
  late FakeAiGenerationRequestBindingStore bindings;

  setUp(() {
    consent = FakeAiConsentRepository(
      authorization: AiDataAuthorization(enabled: true, consentAt: 1),
    );
    reports = FakeAiReportRepository();
    gateway = FakeAiGenerationGateway();
    sessions = FakeSessionStore(_session());
    assembler = FakeAiCoachInputAssembler(
      bundle: buildAiBundle(scopes: {AiDataScope.growthSummary}),
    );
    bindings = FakeAiGenerationRequestBindingStore();
    container = ProviderContainer(
      overrides: [
        aiConsentRepositoryProvider.overrideWithValue(consent),
        aiReportRepositoryProvider.overrideWithValue(reports),
        aiGenerationGatewayProvider.overrideWithValue(gateway),
        aiGenerationRequestBindingStoreProvider.overrideWithValue(bindings),
        authSessionStoreProvider.overrideWithValue(sessions),
        aiCoachInputAssemblerProvider.overrideWithValue(assembler),
        dateTimeServiceProvider.overrideWithValue(
          DateTimeService(now: () => DateTime(2026, 7, 16, 9)),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  test('no preview is rejected before pending creation', () async {
    await container.read(aiRequestPreviewControllerProvider.future);
    await container.read(aiManualGenerationControllerProvider.future);
    final result = await container
        .read(aiManualGenerationControllerProvider.notifier)
        .submit(assembler.bundle);

    expect(result, isNull);
    expect(reports.createPendingCalls, 0);
    expect(gateway.generationCalls, 0);
  });

  test('confirmed success creates one pending and completes it', () async {
    final bundle = await _buildPreview(container);
    await container.read(aiManualGenerationControllerProvider.future);

    final result = await container
        .read(aiManualGenerationControllerProvider.notifier)
        .submit(bundle);

    expect(result?.completed, isTrue);
    expect(reports.createPendingCalls, 1);
    expect(gateway.generationCalls, 1);
    expect(gateway.lastRequestId, 'pending-1');
    expect(reports.markCompletedCalls, 1);
    expect(reports.lastCompletedId, 'pending-1');
    expect(reports.lastStructuredOutput, contains('data_limitations'));
    expect(reports.markFailedCalls, 0);
    expect(bindings.saveCalls, 1);
    expect(bindings.deleteCalls, 1);
  });

  test('gateway failure marks only a controlled failure code', () async {
    final bundle = await _buildPreview(container);
    gateway.generationError = const AiGenerationException(
      AiReportFailureCode.providerTimeout,
    );
    await container.read(aiManualGenerationControllerProvider.future);

    final result = await container
        .read(aiManualGenerationControllerProvider.notifier)
        .submit(bundle);

    expect(result?.completed, isFalse);
    expect(reports.createPendingCalls, 1);
    expect(reports.markFailedCalls, 1);
    expect(reports.lastFailureCode, 'provider_timeout');
    expect(gateway.generationCalls, 1);
    expect(bindings.values, isEmpty);
    expect(
      container
          .read(aiManualGenerationControllerProvider)
          .requireValue
          .phase,
      AiManualGenerationPhase.failure,
    );
  });

  test('binding save failure blocks POST and marks controlled failure', () async {
    final bundle = await _buildPreview(container);
    bindings.saveError = StateError('disk unavailable');
    await container.read(aiManualGenerationControllerProvider.future);

    final result = await container
        .read(aiManualGenerationControllerProvider.notifier)
        .submit(bundle);

    expect(result?.completed, isFalse);
    expect(gateway.generationCalls, 0);
    expect(reports.lastFailureCode, 'request_binding_failed');
  });

  test('network timeout keeps pending and binding without POST retry', () async {
    final bundle = await _buildPreview(container);
    gateway.generationError = const AiGenerationException(
      AiReportFailureCode.networkOutcomeUnknown,
    );
    await container.read(aiManualGenerationControllerProvider.future);

    final result = await container
        .read(aiManualGenerationControllerProvider.notifier)
        .submit(bundle);

    expect(result?.awaitingRecovery, isTrue);
    expect(reports.markFailedCalls, 0);
    expect(reports.reports.single.status, AiReportStatus.pending);
    expect(bindings.values, contains('pending-1'));
    expect(gateway.generationCalls, 1);
  });

  test('disabled provider blocks before pending creation', () async {
    final bundle = await _buildPreview(container);
    gateway.capabilities = AiGenerationCapabilities(
      enabled: false,
      provider: 'disabled',
      providerLabel: 'Disabled',
      model: null,
      supportedReportTypes: const ['weekly_report'],
      promptVersions: const ['weekly-report-v1'],
      inputSchemaVersion: 1,
      outputSchemaVersion: 1,
      streaming: false,
      responseStorageRequested: false,
    );
    await container.read(aiManualGenerationControllerProvider.future);

    final result = await container
        .read(aiManualGenerationControllerProvider.notifier)
        .submit(bundle);

    expect(result, isNull);
    expect(reports.createPendingCalls, 0);
    expect(gateway.generationCalls, 0);
  });

  test('reusable report is opened without pending creation', () async {
    final bundle = await _buildPreview(container);
    reports.reusable = buildAiReport(id: 'existing-report');
    await container.read(aiManualGenerationControllerProvider.future);

    final result = await container
        .read(aiManualGenerationControllerProvider.notifier)
        .submit(bundle);

    expect(result?.reportId, 'existing-report');
    expect(reports.createPendingCalls, 0);
    expect(gateway.generationCalls, 0);
  });

  test('consent revocation after preview blocks generation', () async {
    final bundle = await _buildPreview(container);
    consent.authorization = AiDataAuthorization(enabled: false, consentAt: 1);
    await container.read(aiManualGenerationControllerProvider.future);

    final result = await container
        .read(aiManualGenerationControllerProvider.notifier)
        .submit(bundle);

    expect(result, isNull);
    expect(reports.createPendingCalls, 0);
    expect(gateway.generationCalls, 0);
  });

  test('rapid duplicate submit is suppressed', () async {
    final delayed = DelayedAiGenerationGateway();
    container.dispose();
    container = ProviderContainer(
      overrides: [
        aiConsentRepositoryProvider.overrideWithValue(consent),
        aiReportRepositoryProvider.overrideWithValue(reports),
        aiGenerationGatewayProvider.overrideWithValue(delayed),
        aiGenerationRequestBindingStoreProvider.overrideWithValue(bindings),
        authSessionStoreProvider.overrideWithValue(sessions),
        aiCoachInputAssemblerProvider.overrideWithValue(assembler),
        dateTimeServiceProvider.overrideWithValue(
          DateTimeService(now: () => DateTime(2026, 7, 16, 9)),
        ),
      ],
    );
    final bundle = await _buildPreview(container);
    await container.read(aiManualGenerationControllerProvider.future);
    final controller = container.read(
      aiManualGenerationControllerProvider.notifier,
    );

    final first = controller.submit(bundle);
    await Future<void>.delayed(Duration.zero);
    final second = await controller.submit(bundle);
    expect(second, isNull);
    delayed.complete();
    await first;

    expect(reports.createPendingCalls, 1);
    expect(delayed.generationCalls, 1);
  });
}

Future<AiCoachInputBundle> _buildPreview(ProviderContainer container) async {
  await container.read(aiRequestPreviewControllerProvider.future);
  final preview = container.read(aiRequestPreviewControllerProvider.notifier);
  preview.toggleScope(AiDataScope.growthSummary, selected: true);
  expect(await preview.buildPreview(), isTrue);
  return container
      .read(aiRequestPreviewControllerProvider)
      .requireValue
      .bundle!;
}

AuthSession _session() => const AuthSession(
  accessToken: 'access-token',
  refreshToken: 'refresh-token',
  user: AuthUser(id: 'cloud-user', displayName: 'Test'),
);

final class FakeSessionStore implements AuthSessionStore {
  FakeSessionStore(this.session);

  AuthSession? session;

  @override
  Future<AuthSession?> read() async => session;

  @override
  Future<void> save(AuthSession session) async => this.session = session;

  @override
  Future<void> clear() async => session = null;
}

final class DelayedAiGenerationGateway implements AiGenerationGateway {
  final _completer = Completer<void>();
  int generationCalls = 0;

  void complete() => _completer.complete();

  @override
  Future<AiGenerationCapabilities> getCapabilities() async {
    return FakeAiGenerationGateway().capabilities;
  }

  @override
  Future<AiRemoteRequestResult> generateWeekly({
    required String requestId,
    required AiCoachInputBundle bundle,
  }) async {
    generationCalls += 1;
    await _completer.future;
    final completed = AiGenerationResult(
      requestId: requestId,
      reportType: 'weekly_report',
      promptVersion: bundle.promptVersion,
      inputHash: bundle.inputHash,
      provider: 'fake',
      model: 'deterministic-test-provider',
      outputSchemaVersion: 1,
      reportContent: '# result',
      structuredOutputJson:
          '{"title":"t","summary":"s","observations":[],"suggestions":[],"data_limitations":[]}',
    );
    return AiRemoteRequestResult(
      status: AiRemoteRequestStatus.completed,
      requestId: requestId,
      inputHash: bundle.inputHash,
      reportType: 'weekly_report',
      promptVersion: bundle.promptVersion,
      completedResult: completed,
    );
  }

  @override
  Future<AiRemoteRequestResult> getRequestStatus({
    required String requestId,
    required String inputHash,
    required String reportType,
    required String promptVersion,
  }) => throw UnimplementedError();
}
