import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/ai_coach/data/ai_coach_repository_providers.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_feedback.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_feedback_repository.dart';
import 'package:rebirth/features/ai_coach/presentation/widgets/ai_report_feedback_card.dart';

void main() {
  testWidgets(
    'helpful feedback saves without free text and shows privacy note',
    (tester) async {
      final repository = _FakeFeedbackRepository();
      await _pump(tester, repository);

      expect(find.byType(TextField), findsNothing);
      expect(
        find.byKey(const ValueKey('aiReportFeedbackPrivacyNote')),
        findsOneWidget,
      );
      await tester.tap(find.text('有帮助'));
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('saveAiReportFeedbackButton')),
      );
      await tester.pumpAndSettle();

      expect(repository.saveCount, 1);
      expect(repository.current?.helpfulness, AiReportHelpfulness.helpful);
      expect(repository.current?.reasons, isEmpty);
      expect(find.text('反馈已保存'), findsOneWidget);
    },
  );

  testWidgets('saving disables duplicate submission and keeps the selection', (
    tester,
  ) async {
    final gate = Completer<void>();
    final repository = _FakeFeedbackRepository(saveGate: gate);
    await _pump(tester, repository);
    await tester.tap(find.text('有帮助'));
    await tester.pump();
    final save = find.byKey(const ValueKey('saveAiReportFeedbackButton'));
    await tester.tap(save);
    await tester.pump();

    expect(find.text('保存中...'), findsOneWidget);
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    expect(find.text('有帮助'), findsOneWidget);
    gate.complete();
    await tester.pumpAndSettle();
    expect(repository.saveCount, 1);
  });

  testWidgets('existing feedback can be modified and cleared', (tester) async {
    final repository = _FakeFeedbackRepository(current: _feedback());
    await _pump(tester, repository);
    await tester.tap(find.text('没帮助'));
    await tester.pump();
    await tester.tap(find.text('建议不够可执行'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('saveAiReportFeedbackButton')));
    await tester.pumpAndSettle();
    expect(repository.current?.helpfulness, AiReportHelpfulness.notHelpful);
    expect(repository.current?.reasons, [AiReportFeedbackReason.notActionable]);

    await tester.tap(find.byKey(const ValueKey('clearAiReportFeedbackButton')));
    await tester.pumpAndSettle();
    expect(repository.current, isNull);
    expect(find.text('反馈已清除'), findsOneWidget);
  });

  testWidgets(
    'not-helpful requires a fixed reason and failure preserves retry',
    (tester) async {
      final repository = _FakeFeedbackRepository(failNextSave: true);
      await _pump(tester, repository);

      await tester.tap(find.text('没帮助'));
      await tester.pump();
      final save = find.byKey(const ValueKey('saveAiReportFeedbackButton'));
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      await tester.tap(find.text('内容过于笼统'));
      await tester.pump();
      expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(find.text('反馈操作未完成，本地报告未改变。'), findsOneWidget);
      expect(find.text('内容过于笼统'), findsOneWidget);
      expect(
        tester.widget<FilterChip>(find.byType(FilterChip).at(3)).selected,
        isTrue,
      );

      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(repository.saveCount, 2);
      expect(repository.current?.helpfulness, AiReportHelpfulness.notHelpful);
      expect(repository.current?.reasons, [AiReportFeedbackReason.tooGeneric]);
    },
  );

  testWidgets('conflict exposes explicit adopt-remote and keep-local actions', (
    tester,
  ) async {
    final repository = _FakeFeedbackRepository(
      current: _feedback(
        helpfulness: AiReportHelpfulness.notHelpful,
        reasons: const [AiReportFeedbackReason.tooGeneric],
        syncStatus: AiReportFeedbackSyncStatus.conflict,
        remoteSnapshot: AiReportFeedbackRemoteSnapshot(
          id: _feedbackId,
          helpfulness: AiReportHelpfulness.helpful,
          reasons: const [],
          serverVersion: 2,
          createdAt: 10,
          updatedAt: 20,
          deletedAt: null,
        ),
      ),
    );
    await _pump(tester, repository);

    expect(find.textContaining('本地选择：没帮助'), findsOneWidget);
    expect(find.text('云端选择：有帮助'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('adoptRemoteFeedbackButton')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('keepLocalFeedbackButton')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('adoptRemoteFeedbackButton')));
    await tester.pumpAndSettle();
    expect(repository.adoptCount, 1);
    expect(repository.current?.helpfulness, AiReportHelpfulness.helpful);
  });

  for (final width in const [320.0, 360.0, 412.0, 1200.0]) {
    testWidgets('$width px and TextScaler 2.0 remain scroll-safe', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pump(
        tester,
        _FakeFeedbackRepository(),
        textScaler: const TextScaler.linear(2),
      );

      await tester.tap(find.text('没帮助'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('内容难以理解'), findsOneWidget);
    });
  }

  testWidgets('keyboard and semantics expose the structured choices', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, _FakeFeedbackRepository());
    expect(find.bySemanticsLabel('有帮助'), findsOneWidget);
    expect(find.bySemanticsLabel('没帮助'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}

Future<void> _pump(
  WidgetTester tester,
  _FakeFeedbackRepository repository, {
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        aiReportFeedbackRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: textScaler),
          child: const Scaffold(
            body: SingleChildScrollView(
              child: AiReportFeedbackCard(
                reportId: _reportId,
                reportVersion: 1,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const _feedbackId = '11111111-1111-4111-8111-111111111111';
const _reportId = '22222222-2222-4222-8222-222222222222';

AiReportFeedback _feedback({
  AiReportHelpfulness helpfulness = AiReportHelpfulness.helpful,
  Iterable<AiReportFeedbackReason> reasons = const [],
  AiReportFeedbackSyncStatus syncStatus =
      AiReportFeedbackSyncStatus.pendingPush,
  AiReportFeedbackRemoteSnapshot? remoteSnapshot,
}) => AiReportFeedback(
  id: _feedbackId,
  userId: '33333333-3333-4333-8333-333333333333',
  reportId: _reportId,
  reportVersion: 1,
  reportType: 'weekly_report',
  helpfulness: helpfulness,
  reasons: reasons,
  promptId: 'weekly_report',
  promptVersion: 'weekly-report-v1',
  syncStatus: syncStatus,
  serverVersion: remoteSnapshot == null ? null : 1,
  lastSyncedAt: remoteSnapshot == null ? null : 10,
  createdAt: 10,
  updatedAt: 10,
  deletedAt: null,
  remoteSnapshot: remoteSnapshot,
);

final class _FakeFeedbackRepository implements AiReportFeedbackRepository {
  _FakeFeedbackRepository({
    this.current,
    this.failNextSave = false,
    this.saveGate,
  });

  AiReportFeedback? current;
  bool failNextSave;
  final Completer<void>? saveGate;
  int saveCount = 0;
  int adoptCount = 0;

  @override
  Future<AiReportFeedback?> getForVersion({
    required String reportId,
    required int reportVersion,
  }) async => current;

  @override
  Future<AiReportFeedback> save({
    required String reportId,
    required int reportVersion,
    required AiReportHelpfulness helpfulness,
    Iterable<AiReportFeedbackReason> reasons = const [],
  }) async {
    saveCount += 1;
    if (failNextSave) {
      failNextSave = false;
      throw StateError('controlled');
    }
    await saveGate?.future;
    current = _feedback(helpfulness: helpfulness, reasons: reasons);
    return current!;
  }

  @override
  Future<void> clear({
    required String reportId,
    required int reportVersion,
  }) async {
    current = null;
  }

  @override
  Future<void> adoptRemote(String id) async {
    adoptCount += 1;
    final remote = current!.remoteSnapshot!;
    current = _feedback(
      helpfulness: remote.helpfulness,
      reasons: remote.reasons,
      syncStatus: AiReportFeedbackSyncStatus.synced,
    );
  }

  @override
  Future<void> keepLocal(String id) async {
    current = _feedback(
      helpfulness: current!.helpfulness,
      reasons: current!.reasons,
    );
  }

  @override
  Future<void> applyRemote(AiReportFeedbackRemoteRecord remote) =>
      throw UnimplementedError();

  @override
  Future<List<AiReportFeedback>> listAllForActiveAccount() async =>
      current == null ? const [] : [current!];

  @override
  Future<List<AiReportFeedback>> listPending() async =>
      current == null ? const [] : [current!];

  @override
  Future<void> markConflict({
    required String id,
    required AiReportFeedbackRemoteSnapshot remote,
  }) => throw UnimplementedError();

  @override
  Future<void> markSynced({
    required String id,
    required int serverVersion,
    required int serverUpdatedAt,
  }) => throw UnimplementedError();
}
