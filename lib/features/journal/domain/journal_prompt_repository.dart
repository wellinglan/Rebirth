import 'journal_prompt.dart';

abstract interface class JournalPromptRepository {
  Future<JournalPromptConfiguration> ensureInitialized();

  Future<JournalPromptConfiguration> getConfiguration();

  Future<JournalPromptConfiguration> createUserPrompt(JournalPromptInput input);

  Future<JournalPromptConfiguration> updateUserPrompt(
    String promptId,
    JournalPromptInput input,
  );

  Future<JournalPromptConfiguration> duplicateAsUserPrompt(String promptId);

  Future<JournalPromptConfiguration> setPromptEnabled(
    String promptId,
    bool isEnabled,
  );

  Future<JournalPromptConfiguration> reorderPrompts(
    List<String> enabledPromptIds,
  );

  Future<JournalPromptConfiguration> deleteUserPrompt(String promptId);
}
