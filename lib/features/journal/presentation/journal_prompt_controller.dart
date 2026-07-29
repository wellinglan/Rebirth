import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/features/journal/data/journal_prompt_repository_provider.dart';
import 'package:rebirth/features/journal/domain/journal_prompt.dart';

final journalPromptControllerProvider =
    AsyncNotifierProvider<JournalPromptController, JournalPromptConfiguration>(
      JournalPromptController.new,
    );

class JournalPromptController
    extends AsyncNotifier<JournalPromptConfiguration> {
  bool _mutationInProgress = false;

  @override
  Future<JournalPromptConfiguration> build() {
    return ref.watch(journalPromptRepositoryProvider).getConfiguration();
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    final next = await AsyncValue.guard(
      ref.read(journalPromptRepositoryProvider).getConfiguration,
    );
    if (ref.mounted) state = next;
  }

  Future<void> createPrompt(JournalPromptInput input) {
    return _mutate(
      () => ref.read(journalPromptRepositoryProvider).createUserPrompt(input),
    );
  }

  Future<void> updatePrompt(String promptId, JournalPromptInput input) {
    return _mutate(
      () => ref
          .read(journalPromptRepositoryProvider)
          .updateUserPrompt(promptId, input),
    );
  }

  Future<void> duplicateAsUserPrompt(String promptId) {
    return _mutate(
      () => ref
          .read(journalPromptRepositoryProvider)
          .duplicateAsUserPrompt(promptId),
    );
  }

  Future<void> setEnabled(String promptId, bool isEnabled) {
    return _mutate(
      () => ref
          .read(journalPromptRepositoryProvider)
          .setPromptEnabled(promptId, isEnabled),
    );
  }

  Future<void> reorder(List<String> enabledPromptIds) {
    return _mutate(
      () => ref
          .read(journalPromptRepositoryProvider)
          .reorderPrompts(enabledPromptIds),
    );
  }

  Future<void> deletePrompt(String promptId) {
    return _mutate(
      () =>
          ref.read(journalPromptRepositoryProvider).deleteUserPrompt(promptId),
    );
  }

  Future<void> _mutate(
    Future<JournalPromptConfiguration> Function() operation,
  ) async {
    if (_mutationInProgress) return;
    _mutationInProgress = true;
    final previous = state;
    try {
      final next = await operation();
      if (ref.mounted) state = AsyncData(next);
    } catch (_) {
      if (ref.mounted) state = previous;
      rethrow;
    } finally {
      _mutationInProgress = false;
    }
  }
}
