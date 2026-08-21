import 'dart:collection';

import 'package:rebirth/features/ai_coach/application/ai_chat_coordinator.dart';
import 'package:rebirth/features/ai_coach/domain/ai_chat_conversation.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_scope.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_status.dart';

enum AiChatInteraction {
  ready,
  loadingConversation,
  sending,
  recovering,
  mutating,
}

final class AiChatViewState {
  AiChatViewState({
    required List<AiChatThread> threads,
    required this.conversation,
    required Set<AiDataScope> selectedScopes,
    this.interaction = AiChatInteraction.ready,
    this.failureCode,
    this.recoveryStatus,
  }) : threads = UnmodifiableListView(threads),
       selectedScopes = Set<AiDataScope>.unmodifiable(selectedScopes);

  final List<AiChatThread> threads;
  final AiChatConversation? conversation;
  final Set<AiDataScope> selectedScopes;
  final AiChatInteraction interaction;
  final AiReportFailureCode? failureCode;
  final AiChatRecoveryStatus? recoveryStatus;

  bool get isBusy => interaction != AiChatInteraction.ready;

  AiChatMessage? get latestAssistant {
    final messages = conversation?.messages;
    if (messages == null) return null;
    for (final message in messages.reversed) {
      if (message.role == AiChatRole.assistant) return message;
    }
    return null;
  }

  bool get requiresRecovery {
    final status = latestAssistant?.status;
    return status == AiChatMessageStatus.pending ||
        status == AiChatMessageStatus.outcomeUnknown;
  }

  bool get requiresRetry =>
      latestAssistant?.status == AiChatMessageStatus.failed;

  bool get canCompose =>
      !isBusy &&
      conversation?.thread.isArchived != true &&
      !requiresRecovery &&
      !requiresRetry;

  AiChatViewState copyWith({
    List<AiChatThread>? threads,
    Object? conversation = _unchanged,
    Set<AiDataScope>? selectedScopes,
    AiChatInteraction? interaction,
    AiReportFailureCode? failureCode,
    AiChatRecoveryStatus? recoveryStatus,
    bool clearFailure = false,
    bool clearRecovery = false,
  }) {
    return AiChatViewState(
      threads: threads ?? this.threads,
      conversation: identical(conversation, _unchanged)
          ? this.conversation
          : conversation as AiChatConversation?,
      selectedScopes: selectedScopes ?? this.selectedScopes,
      interaction: interaction ?? this.interaction,
      failureCode: clearFailure ? null : failureCode ?? this.failureCode,
      recoveryStatus: clearRecovery
          ? null
          : recoveryStatus ?? this.recoveryStatus,
    );
  }
}

const _unchanged = Object();
