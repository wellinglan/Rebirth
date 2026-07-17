import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/ai_coach/data/ai_coach_repository_providers.dart';
import 'package:rebirth/features/ai_coach/domain/ai_coach_input_bundle.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_authorization.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_scope.dart';
import 'package:rebirth/features/ai_coach/presentation/ai_request_preview_controller.dart';

import '../ai_coach_test_support.dart';

void main() {
  late FakeAiConsentRepository consent;
  late FakeAiCoachInputAssembler assembler;
  late FakeAiReportRepository reports;
  late ProviderContainer container;
  late ProviderSubscription subscription;

  setUp(() {
    consent = FakeAiConsentRepository(
      authorization: AiDataAuthorization(enabled: true, consentAt: 1),
    );
    assembler = FakeAiCoachInputAssembler();
    reports = FakeAiReportRepository();
    container = ProviderContainer(
      overrides: [
        aiConsentRepositoryProvider.overrideWithValue(consent),
        aiCoachInputAssemblerProvider.overrideWithValue(assembler),
        aiReportRepositoryProvider.overrideWithValue(reports),
        dateTimeServiceProvider.overrideWithValue(
          DateTimeService(now: () => DateTime(2026, 7, 16, 9)),
        ),
      ],
    );
    subscription = container.listen(
      aiRequestPreviewControllerProvider,
      (_, _) {},
    );
  });

  tearDown(() {
    subscription.close();
    container.dispose();
  });

  test(
    'defaults to empty selection and a fixed seven-day weekly period',
    () async {
      final state = await container.read(
        aiRequestPreviewControllerProvider.future,
      );

      expect(state.selectedScopes, isEmpty);
      expect(state.canBuild, isFalse);
      expect(state.periodStartDate, '2026-07-10');
      expect(state.periodEndDate, '2026-07-16');
      expect(state.promptVersion, 'weekly-report-v1');
    },
  );

  test('consent off rejects build without calling assembler', () async {
    consent.authorization = const AiDataAuthorization.disabled();
    await container.read(aiRequestPreviewControllerProvider.future);

    final built = await container
        .read(aiRequestPreviewControllerProvider.notifier)
        .buildPreview();

    expect(built, isFalse);
    expect(assembler.buildCalls, 0);
    expect(reports.findCalls, 0);
  });

  test(
    'scope selection enables build and changes clear prior results',
    () async {
      await container.read(aiRequestPreviewControllerProvider.future);
      final controller = container.read(
        aiRequestPreviewControllerProvider.notifier,
      );
      controller.toggleScope(AiDataScope.growthSummary, selected: true);
      expect(
        container
            .read(aiRequestPreviewControllerProvider)
            .requireValue
            .canBuild,
        isTrue,
      );
      await controller.buildPreview();
      expect(
        container.read(aiRequestPreviewControllerProvider).requireValue.preview,
        isNotNull,
      );

      controller.toggleScope(AiDataScope.todayMetrics, selected: true);
      final changed = container
          .read(aiRequestPreviewControllerProvider)
          .requireValue;
      expect(changed.preview, isNull);
      expect(changed.bundle, isNull);
      expect(changed.reusableCompletedReport, isNull);
    },
  );

  test(
    'build calls assembler once, never persists snapshot, and finds reusable',
    () async {
      reports.reusable = buildAiReport(id: 'reusable-report');
      await container.read(aiRequestPreviewControllerProvider.future);
      final controller = container.read(
        aiRequestPreviewControllerProvider.notifier,
      );
      controller.toggleScope(AiDataScope.growthSummary, selected: true);

      expect(await controller.buildPreview(), isTrue);
      final state = container
          .read(aiRequestPreviewControllerProvider)
          .requireValue;
      expect(assembler.buildCalls, 1);
      expect(assembler.selections.single.persistInputSnapshot, isFalse);
      expect(assembler.selections.single.scopes, {AiDataScope.growthSummary});
      expect(state.bundle, same(assembler.bundle));
      expect(state.reusableCompletedReport?.id, 'reusable-report');
      expect(reports.findCalls, 1);
      expect(reports.lastReusableHash, assembler.bundle.inputHash);
      expect(reports.lastReusablePromptVersion, 'weekly-report-v1');
      expect(reports.createPendingCalls, 0);
      expect(reports.markCompletedCalls, 0);
      expect(reports.markFailedCalls, 0);
    },
  );

  test(
    'Journal requires one-time confirmation and never changes consent',
    () async {
      await container.read(aiRequestPreviewControllerProvider.future);
      final controller = container.read(
        aiRequestPreviewControllerProvider.notifier,
      );

      expect(
        controller.toggleScope(AiDataScope.journalReflections, selected: true),
        AiScopeToggleResult.journalConfirmationRequired,
      );
      expect(
        container
            .read(aiRequestPreviewControllerProvider)
            .requireValue
            .selectedScopes,
        isNot(contains(AiDataScope.journalReflections)),
      );
      controller.cancelJournalScope();
      controller.confirmJournalScope();
      expect(
        container
            .read(aiRequestPreviewControllerProvider)
            .requireValue
            .selectedScopes,
        contains(AiDataScope.journalReflections),
      );
      expect(consent.grantCalls, 0);
      expect(consent.revokeCalls, 0);
    },
  );

  test('only the newest rapid build result is accepted', () async {
    final first = Completer<AiCoachInputBundle>();
    final second = Completer<AiCoachInputBundle>();
    final firstBundle = buildAiBundle(
      scopes: {AiDataScope.growthSummary},
      hash: '${List.filled(56, 'a').join()}11111111',
    );
    final secondBundle = buildAiBundle(
      scopes: {AiDataScope.growthSummary},
      hash: '${List.filled(56, 'b').join()}22222222',
    );
    assembler.queuedResponses.addAll([first.future, second.future]);
    await container.read(aiRequestPreviewControllerProvider.future);
    final controller = container.read(
      aiRequestPreviewControllerProvider.notifier,
    );
    controller.toggleScope(AiDataScope.growthSummary, selected: true);

    final firstBuild = controller.buildPreview();
    final secondBuild = controller.buildPreview();
    second.complete(secondBundle);
    expect(await secondBuild, isTrue);
    first.complete(firstBundle);
    expect(await firstBuild, isFalse);

    expect(
      container
          .read(aiRequestPreviewControllerProvider)
          .requireValue
          .bundle
          ?.inputHash,
      secondBundle.inputHash,
    );
  });

  test('build failure is sanitized and preserves selected scopes', () async {
    assembler.error = StateError('private Journal body and canonical JSON');
    await container.read(aiRequestPreviewControllerProvider.future);
    final controller = container.read(
      aiRequestPreviewControllerProvider.notifier,
    );
    controller.toggleScope(AiDataScope.todayMetrics, selected: true);

    expect(await controller.buildPreview(), isFalse);
    final state = container
        .read(aiRequestPreviewControllerProvider)
        .requireValue;
    expect(state.buildError, '暂时无法构建本地预览，请重试。');
    expect(state.buildError, isNot(contains('Journal body')));
    expect(state.selectedScopes, {AiDataScope.todayMetrics});
  });

  test(
    'consent revocation clears preview, reusable result, and scopes',
    () async {
      reports.reusable = buildAiReport(id: 'existing-history');
      await container.read(aiRequestPreviewControllerProvider.future);
      final controller = container.read(
        aiRequestPreviewControllerProvider.notifier,
      );
      controller.toggleScope(AiDataScope.growthSummary, selected: true);
      await controller.buildPreview();
      consent.authorization = AiDataAuthorization(
        enabled: false,
        consentAt: consent.authorization.consentAt,
      );

      await controller.reloadAuthorization();
      final state = container
          .read(aiRequestPreviewControllerProvider)
          .requireValue;
      expect(state.authorization.enabled, isFalse);
      expect(state.selectedScopes, isEmpty);
      expect(state.preview, isNull);
      expect(state.bundle, isNull);
      expect(state.reusableCompletedReport, isNull);
      expect(reports.deleteCalls, 0);
    },
  );
}
