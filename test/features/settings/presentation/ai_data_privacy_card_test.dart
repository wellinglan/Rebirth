import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/ai_coach/data/ai_coach_repository_providers.dart';
import 'package:rebirth/features/ai_coach/domain/ai_consent_repository.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_authorization.dart';
import 'package:rebirth/features/settings/presentation/widgets/ai_data_privacy_card.dart';

void main() {
  testWidgets('disabled state exposes consent action and semantics', (tester) async {
    await _pumpCard(tester, _FakeConsentRepository());
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('aiDataPrivacyCard')), findsOneWidget);
    expect(find.text('未启用'), findsOneWidget);
    expect(find.byKey(const ValueKey('enableAiDataSharingButton')), findsOneWidget);
    expect(find.textContaining('不会向网络发送'), findsOneWidget);
    expect(find.bySemanticsLabel('AI 数据使用未启用'), findsOneWidget);
    final actionSemantics = tester.widget<Semantics>(
      find.byKey(const ValueKey('aiDataConsentActionSemantics')),
    );
    expect(actionSemantics.properties.label, '启用 AI 数据使用');
    expect(actionSemantics.properties.button, isTrue);
    expect(actionSemantics.properties.enabled, isTrue);
  });

  testWidgets('grant dialog requires explicit confirmation and states boundaries', (
    tester,
  ) async {
    final repository = _FakeConsentRepository();
    await _pumpCard(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('enableAiDataSharingButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('aiDataConsentDialog')), findsOneWidget);
    expect(find.textContaining('不会向网络发送数据'), findsOneWidget);
    expect(find.textContaining('主动操作时准备输入'), findsOneWidget);
    expect(find.textContaining('选择具体数据范围'), findsOneWidget);
    expect(find.textContaining('Journal 文本不会自动包含'), findsOneWidget);
    expect(find.textContaining('随时撤销'), findsOneWidget);
    expect(find.textContaining('不会删除已有本地报告'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('cancelAiDataConsentButton')));
    await tester.pumpAndSettle();
    expect(repository.grantCalls, 0);
    expect(find.text('未启用'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('enableAiDataSharingButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirmAiDataConsentButton')));
    await tester.pumpAndSettle();

    expect(repository.grantCalls, 1);
    expect(find.text('已启用'), findsOneWidget);
    expect(find.byKey(const ValueKey('aiDataConsentTimestamp')), findsOneWidget);
  });

  testWidgets('revoke dialog preserves consent timestamp and returns disabled state', (
    tester,
  ) async {
    final repository = _FakeConsentRepository(
      authorization: AiDataAuthorization(enabled: true, consentAt: 1000),
    );
    await _pumpCard(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('revokeAiDataSharingButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('revokeAiDataConsentDialog')), findsOneWidget);
    expect(find.textContaining('已有本地报告会保留'), findsOneWidget);
    expect(find.textContaining('原始数据不受影响'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('confirmRevokeAiDataConsentButton')),
    );
    await tester.pumpAndSettle();

    expect(repository.revokeCalls, 1);
    expect(find.text('未启用'), findsOneWidget);
    expect(find.byKey(const ValueKey('aiDataConsentTimestamp')), findsOneWidget);
  });

  testWidgets('saving disables action and prevents duplicate grants', (tester) async {
    final gate = Completer<void>();
    final repository = _FakeConsentRepository(grantGate: gate);
    await _pumpCard(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('enableAiDataSharingButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirmAiDataConsentButton')));
    await tester.pump();

    expect(repository.grantCalls, 1);
    expect(find.text('保存中...'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('enableAiDataSharingButton')),
    );
    expect(button.onPressed, isNull);

    gate.complete();
    await tester.pumpAndSettle();
    expect(repository.grantCalls, 1);
    expect(find.text('已启用'), findsOneWidget);
  });

  testWidgets('save failure is readable and can be retried', (tester) async {
    final repository = _FakeConsentRepository(grantError: StateError('failed'));
    await _pumpCard(tester, repository);
    await tester.pumpAndSettle();

    await _confirmGrant(tester);
    expect(find.byKey(const ValueKey('aiDataConsentSaveError')), findsOneWidget);
    expect(find.text('未启用'), findsOneWidget);
    expect(find.byKey(const ValueKey('enableAiDataSharingButton')), findsOneWidget);

    repository.grantError = null;
    await _confirmGrant(tester);
    expect(repository.grantCalls, 2);
    expect(find.text('已启用'), findsOneWidget);
  });

  testWidgets('initial read error exposes a retry action', (tester) async {
    final repository = _FakeConsentRepository(readError: StateError('failed'));
    await _pumpCard(tester, repository);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('aiDataConsentLoadError')), findsOneWidget);

    repository.readError = null;
    await tester.tap(find.byKey(const ValueKey('retryAiDataConsentButton')));
    await tester.pumpAndSettle();
    expect(find.text('未启用'), findsOneWidget);
    expect(repository.readCalls, 2);
  });

  testWidgets('read gate displays a dedicated loading state', (tester) async {
    final gate = Completer<void>();
    final repository = _FakeConsentRepository(readGate: gate);
    await _pumpCard(tester, repository);
    await tester.pump();

    expect(find.byKey(const ValueKey('aiDataConsentLoadingState')), findsOneWidget);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('未启用'), findsOneWidget);
  });

  test('AI privacy Widget has no Drift, database, or implementation import', () {
    final source = File(
      'lib/features/settings/presentation/widgets/ai_data_privacy_card.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('package:drift')));
    expect(source, isNot(contains('app_database')));
    expect(source, isNot(contains('RepositoryImpl')));
    expect(source, isNot(contains('local_ai_')));
    expect(source, isNot(contains('DateTime.now')));
  });
}

Future<void> _pumpCard(
  WidgetTester tester,
  AiConsentRepository repository,
) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [aiConsentRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: AiDataPrivacyCard()),
        ),
      ),
    ),
  );
}

Future<void> _confirmGrant(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('enableAiDataSharingButton')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('confirmAiDataConsentButton')));
  await tester.pumpAndSettle();
}

final class _FakeConsentRepository implements AiConsentRepository {
  _FakeConsentRepository({
    AiDataAuthorization? authorization,
    this.readGate,
    this.grantGate,
    this.readError,
    this.grantError,
  }) : authorization = authorization ?? const AiDataAuthorization.disabled();

  AiDataAuthorization authorization;
  final Completer<void>? readGate;
  final Completer<void>? grantGate;
  Object? readError;
  Object? grantError;
  int readCalls = 0;
  int grantCalls = 0;
  int revokeCalls = 0;

  @override
  Future<AiDataAuthorization> read() async {
    readCalls += 1;
    await readGate?.future;
    if (readError case final error?) throw error;
    return authorization;
  }

  @override
  Future<AiDataAuthorization> grant() async {
    grantCalls += 1;
    await grantGate?.future;
    if (grantError case final error?) throw error;
    return authorization = AiDataAuthorization(
      enabled: true,
      consentAt: DateTime.utc(2026, 7, 16, 1).millisecondsSinceEpoch,
    );
  }

  @override
  Future<AiDataAuthorization> revoke() async {
    revokeCalls += 1;
    return authorization = AiDataAuthorization(
      enabled: false,
      consentAt: authorization.consentAt,
    );
  }
}
