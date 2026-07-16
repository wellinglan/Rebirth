import 'ai_coach_exception.dart';
import 'ai_data_scope.dart';

final class AiDataSelection {
  AiDataSelection({
    required Set<AiDataScope> scopes,
    this.persistInputSnapshot = false,
  }) : scopes = Set<AiDataScope>.unmodifiable(scopes) {
    if (scopes.isEmpty) {
      throw const EmptyAiDataSelectionException();
    }
  }

  final Set<AiDataScope> scopes;
  final bool persistInputSnapshot;
}
