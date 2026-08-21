import 'ai_chat_conversation.dart';
import 'ai_chat_input_bundle.dart';
import 'ai_report_status.dart';

enum AiChatRemoteStatus {
  processing,
  completed,
  failed,
  outcomeUnknown,
  resultExpired,
  notFound,
}

final class AiChatRemoteResult {
  const AiChatRemoteResult({
    required this.status,
    required this.requestId,
    required this.inputHash,
    required this.promptVersion,
    this.reply,
    this.safetyCategory,
    this.provider,
    this.model,
    this.failureCode,
  });

  final AiChatRemoteStatus status;
  final String requestId;
  final String inputHash;
  final String promptVersion;
  final String? reply;
  final AiChatSafetyCategory? safetyCategory;
  final String? provider;
  final String? model;
  final AiReportFailureCode? failureCode;
}

abstract interface class AiChatGateway {
  Future<AiChatRemoteResult> sendTurn({
    required String requestId,
    required AiChatInputBundle bundle,
  });

  Future<AiChatRemoteResult> getRequestStatus({
    required String requestId,
    required String inputHash,
    required String promptVersion,
  });
}
