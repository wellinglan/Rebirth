import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_scope.dart';
import 'package:rebirth/features/ai_coach/domain/ai_generation_gateway.dart';
import 'package:rebirth/features/ai_coach/presentation/widgets/ai_generation_confirmation_dialog.dart';

import '../ai_coach_test_support.dart';

void main() {
  testWidgets('dialog shows provider, privacy, cost, and Journal warning', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showAiGenerationConfirmationDialog(
                context,
                bundle: buildAiBundle(
                  scopes: {
                    AiDataScope.growthSummary,
                    AiDataScope.journalReflections,
                  },
                ),
                capabilities: _capabilities(),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('aiGenerationConfirmationDialog')),
      findsOneWidget,
    );
    for (final text in [
      'Development Fake',
      'deterministic-test-provider',
      '2026-07-10 至 2026-07-16',
      'Rebirth Server',
      'Source record IDs',
      'store=false',
      '不代表绝对零保留',
      '可能产生 Provider 费用',
      '不会自动重试',
      '临时保留已验证的生成结果 24 小时',
      'Tombstone 会保留 30 天',
      '不是 exactly-once',
      '不保存输入 Payload',
    ]) {
      expect(find.textContaining(text), findsOneWidget);
    }
    expect(
      find.byKey(const ValueKey('aiJournalFinalWarning')),
      findsOneWidget,
    );
    final semantics = tester.widget<Semantics>(
      find.byKey(const ValueKey('aiGenerationConfirmationSemantics')),
    );
    expect(semantics.properties.label, 'AI 每周回顾最终发送确认');
  });

  testWidgets('cancel and close return false without implicit confirmation', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                result = await showAiGenerationConfirmationDialog(
                  context,
                  bundle: buildAiBundle(
                    scopes: {AiDataScope.growthSummary},
                  ),
                  capabilities: _capabilities(),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cancelAiGenerationButton')));
    await tester.pumpAndSettle();
    expect(result, isFalse);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('explicit confirmation returns true', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                result = await showAiGenerationConfirmationDialog(
                  context,
                  bundle: buildAiBundle(
                    scopes: {AiDataScope.growthSummary},
                  ),
                  capabilities: _capabilities(),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirmAiGenerationButton')));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('dialog is scrollable on a narrow high-text viewport', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(320, 520));
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showAiGenerationConfirmationDialog(
                context,
                bundle: buildAiBundle(),
                capabilities: _capabilities(),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('aiGenerationConfirmationScrollView')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

AiGenerationCapabilities _capabilities() => AiGenerationCapabilities(
  enabled: true,
  provider: 'fake',
  providerLabel: 'Development Fake',
  model: 'deterministic-test-provider',
  supportedReportTypes: const ['weekly_report'],
  promptVersions: const ['weekly-report-v1'],
  inputSchemaVersion: 1,
  outputSchemaVersion: 1,
  streaming: false,
  responseStorageRequested: false,
);
