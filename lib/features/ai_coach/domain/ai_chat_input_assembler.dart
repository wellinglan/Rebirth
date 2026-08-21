import 'ai_chat_conversation.dart';
import 'ai_chat_input_bundle.dart';
import 'ai_data_scope.dart';

abstract interface class AiChatInputAssembler {
  Future<AiChatInputBundle> build({
    required List<AiChatMessage> conversationMessages,
    required Set<AiDataScope> scopes,
  });
}
