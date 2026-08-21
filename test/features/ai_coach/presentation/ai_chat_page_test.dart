import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/ai_coach/domain/ai_chat_conversation.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_authorization.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_scope.dart';
import 'package:rebirth/features/ai_coach/domain/ai_usage_snapshot.dart';
import 'package:rebirth/features/ai_coach/presentation/ai_chat_controller.dart';
import 'package:rebirth/features/ai_coach/presentation/ai_chat_page.dart';
import 'package:rebirth/features/ai_coach/presentation/ai_chat_view_state.dart';
import 'package:rebirth/features/ai_coach/presentation/ai_usage_controller.dart';
import 'package:rebirth/features/ai_coach/presentation/widgets/ai_chat_conversation_view.dart';
import 'package:rebirth/features/settings/presentation/ai_data_consent_controller.dart';

void main() {
  testWidgets('new chat renders and sends without direct data access', (
    tester,
  ) async {
    final controller = _ChatController(_state());
    await _pumpPage(tester, controller: controller, width: 412);

    expect(find.byKey(const ValueKey('aiChatEmptyState')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('aiChatComposerField')),
      '  今天想理清一件事  ',
    );
    await tester.tap(find.byKey(const ValueKey('sendAiChatButton')));
    await tester.pump();

    expect(controller.sent, ['  今天想理清一件事  ']);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('aiChatComposerField')))
          .controller
          ?.text,
      isEmpty,
    );
  });

  testWidgets('rejected send preserves composer content', (tester) async {
    final controller = _ChatController(_state())..acceptSend = false;
    await _pumpPage(tester, controller: controller, width: 360);

    await tester.enterText(
      find.byKey(const ValueKey('aiChatComposerField')),
      '保留这段输入',
    );
    await tester.tap(find.byKey(const ValueKey('sendAiChatButton')));
    await tester.pump();

    expect(find.text('保留这段输入'), findsOneWidget);
  });

  testWidgets('context selection changes locally without sending', (
    tester,
  ) async {
    final controller = _ChatController(_state());
    await _pumpPage(tester, controller: controller, width: 412);

    await tester.tap(find.byKey(const ValueKey('aiChatContextButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('aiChatScope-health_metrics')));
    await tester.pump();

    expect(controller.sent, isEmpty);
    expect(controller.selectedScopes, contains(AiDataScope.healthMetrics));
  });

  testWidgets('completed high-risk reply is readable and safely labelled', (
    tester,
  ) async {
    final controller = _ChatController(
      _state(conversation: _conversation(AiChatSafetyCategory.highRisk)),
    );
    await _pumpPage(tester, controller: controller, width: 412);

    expect(find.text('这是完整回复。'), findsOneWidget);
    expect(find.byKey(const ValueKey('aiChatHighRiskNotice')), findsOneWidget);
    expect(find.textContaining('联系当地紧急服务'), findsOneWidget);
    expect(find.textContaining('AI 不能替代专业帮助'), findsOneWidget);
  });

  for (final status in [
    AiChatMessageStatus.pending,
    AiChatMessageStatus.outcomeUnknown,
    AiChatMessageStatus.failed,
  ]) {
    testWidgets('$status action fits a narrow high-text viewport', (
      tester,
    ) async {
      final controller = _ChatController(
        _state(
          conversation: _conversation(
            AiChatSafetyCategory.normal,
            status: status,
          ),
        ),
      );
      await _pumpPage(
        tester,
        controller: controller,
        width: 320,
        textScale: 2,
        settle: false,
      );

      expect(tester.takeException(), isNull);
      switch (status) {
        case AiChatMessageStatus.pending:
          expect(find.text('检查结果'), findsOneWidget);
          break;
        case AiChatMessageStatus.outcomeUnknown:
          expect(
            find.byKey(const ValueKey('checkAiChatResultButton')),
            findsOneWidget,
          );
          break;
        case AiChatMessageStatus.failed:
          expect(
            find.byKey(const ValueKey('retryAiChatButton')),
            findsOneWidget,
          );
          break;
        case AiChatMessageStatus.completed:
          fail('completed is not part of this recovery-state test');
      }
    });
  }

  testWidgets('messages and send control expose readable semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final controller = _ChatController(
      _state(conversation: _conversation(AiChatSafetyCategory.normal)),
    );
    await _pumpPage(tester, controller: controller, width: 412);

    expect(find.bySemanticsLabel('你的消息'), findsOneWidget);
    expect(find.bySemanticsLabel('AI 教练回复'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('aiChatComposerField')),
      '准备发送',
    );
    await tester.pump();
    final sendSemantics = tester.getSemantics(
      find.byKey(const ValueKey('sendAiChatSemantics')),
    );
    expect(sendSemantics.label, contains('发送消息'));
    expect(sendSemantics.flagsCollection.isButton, isTrue);
    semantics.dispose();
  });

  testWidgets('Enter sends while Shift+Enter remains a newline', (
    tester,
  ) async {
    final textController = TextEditingController();
    var sends = 0;
    addTearDown(textController.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiChatComposer(
            controller: textController,
            selectedScopes: const {},
            enabled: true,
            sending: false,
            archived: false,
            blockedByUnresolved: false,
            onChooseContext: () {},
            onSend: () => sends += 1,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('aiChatComposerField')));
    await tester.enterText(
      find.byKey(const ValueKey('aiChatComposerField')),
      'hello',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(sends, 1);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(sends, 1);
  });

  for (final width in [320.0, 360.0, 412.0, 720.0, 1200.0]) {
    testWidgets('chat layout has no overflow at ${width.toInt()}px', (
      tester,
    ) async {
      final controller = _ChatController(
        _state(conversation: _conversation(AiChatSafetyCategory.caution)),
      );
      await _pumpPage(
        tester,
        controller: controller,
        width: width,
        textScale: 2,
      );

      expect(tester.takeException(), isNull);
      if (width >= 900) {
        expect(
          find.byKey(const ValueKey('aiChatThreadListPane')),
          findsOneWidget,
        );
      } else {
        expect(
          find.byKey(const ValueKey('aiChatThreadListPane')),
          findsNothing,
        );
      }
    });
  }
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required _ChatController controller,
  required double width,
  double textScale = 1,
  bool settle = true,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        aiChatControllerProvider.overrideWith(() => controller),
        aiDataConsentControllerProvider.overrideWith(
          _EnabledConsentController.new,
        ),
        aiUsageControllerProvider.overrideWith(_AvailableUsageController.new),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 900),
            textScaler: TextScaler.linear(textScale),
          ),
          child: const AiChatPage(),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }
}

AiChatViewState _state({AiChatConversation? conversation}) {
  return AiChatViewState(
    threads: conversation == null ? const [] : [conversation.thread],
    conversation: conversation,
    selectedScopes: const {},
  );
}

AiChatConversation _conversation(
  AiChatSafetyCategory category, {
  AiChatMessageStatus status = AiChatMessageStatus.completed,
}) {
  const thread = AiChatThread(
    id: 'thread-1',
    title: '今天想理清一件事',
    createdAt: 1,
    updatedAt: 2,
    archivedAt: null,
  );
  return AiChatConversation(
    thread: thread,
    messages: [
      const AiChatMessage(
        id: 'user-1',
        threadId: 'thread-1',
        role: AiChatRole.user,
        sequence: 0,
        content: '这是用户消息。',
        requestId: null,
        status: AiChatMessageStatus.completed,
        promptVersion: null,
        safetyCategory: null,
        errorCode: null,
        createdAt: 1,
        updatedAt: 1,
      ),
      AiChatMessage(
        id: 'assistant-1',
        threadId: 'thread-1',
        role: AiChatRole.assistant,
        sequence: 1,
        content: status == AiChatMessageStatus.completed ? '这是完整回复。' : '',
        requestId: 'request-1',
        status: status,
        promptVersion: 'coach-chat-v1',
        safetyCategory: category,
        errorCode: null,
        createdAt: 2,
        updatedAt: 2,
      ),
    ],
  );
}

final class _ChatController extends AiChatController {
  _ChatController(this.initial);

  final AiChatViewState initial;
  final List<String> sent = [];
  bool acceptSend = true;

  Set<AiDataScope> get selectedScopes => state.requireValue.selectedScopes;

  @override
  Future<AiChatViewState> build() async => initial;

  @override
  Future<bool> send(String content) async {
    sent.add(content);
    return acceptSend;
  }

  @override
  void setScope(AiDataScope scope, {required bool selected}) {
    final current = state.requireValue;
    final scopes = {...current.selectedScopes};
    selected ? scopes.add(scope) : scopes.remove(scope);
    state = AsyncData(current.copyWith(selectedScopes: scopes));
  }
}

final class _EnabledConsentController extends AiDataConsentController {
  @override
  Future<AiDataConsentViewState> build() async => AiDataConsentViewState(
    authorization: AiDataAuthorization(enabled: true, consentAt: 1),
  );
}

final class _AvailableUsageController extends AiUsageController {
  @override
  Future<AiUsageSnapshot> build() async => const AiUsageSnapshot(
    availability: AiUsageAvailability.available,
    enabled: true,
    dailyLimit: 4,
    used: 0,
    remaining: 4,
    resetsAtUtcMilliseconds: 1,
  );
}
