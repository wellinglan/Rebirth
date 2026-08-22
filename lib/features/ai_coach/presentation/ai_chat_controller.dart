import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/features/ai_coach/application/ai_chat_coordinator.dart';
import 'package:rebirth/features/ai_coach/data/ai_coach_repository_providers.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_scope.dart';
import 'package:rebirth/features/ai_coach/domain/ai_generation_gateway.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_status.dart';

import 'ai_chat_view_state.dart';
import 'ai_usage_controller.dart';

final aiChatControllerProvider =
    AsyncNotifierProvider.autoDispose<AiChatController, AiChatViewState>(
      AiChatController.new,
    );

class AiChatController extends AsyncNotifier<AiChatViewState> {
  @override
  Future<AiChatViewState> build() => _load();

  Future<void> reload() async {
    final current = state.value;
    final threadId = current?.conversation?.thread.id;
    state = await AsyncValue.guard(
      () => _load(
        threadId: threadId,
        selectedScopes: current?.selectedScopes ?? const {},
      ),
    );
  }

  Future<void> openThread(String threadId) async {
    final current = state.value;
    if (current == null || current.isBusy) return;
    state = AsyncData(
      current.copyWith(
        interaction: AiChatInteraction.loadingConversation,
        clearFailure: true,
        clearRecovery: true,
      ),
    );
    try {
      final conversation = await ref
          .read(aiChatRepositoryProvider)
          .getConversation(threadId);
      if (!ref.mounted) return;
      if (conversation == null) {
        state = AsyncData(
          current.copyWith(
            interaction: AiChatInteraction.ready,
            failureCode: AiReportFailureCode.invalidInput,
          ),
        );
        return;
      }
      state = AsyncData(
        current.copyWith(
          conversation: conversation,
          selectedScopes: const {},
          interaction: AiChatInteraction.ready,
          clearFailure: true,
          clearRecovery: true,
        ),
      );
    } catch (error, stackTrace) {
      if (ref.mounted) state = AsyncError(error, stackTrace);
    }
  }

  void startNewThread() {
    final current = state.value;
    if (current == null || current.isBusy) return;
    state = AsyncData(
      current.copyWith(
        conversation: null,
        selectedScopes: const {},
        clearFailure: true,
        clearRecovery: true,
      ),
    );
  }

  void setScope(AiDataScope scope, {required bool selected}) {
    final current = state.value;
    if (current == null || current.isBusy || !scope.supported) return;
    final scopes = {...current.selectedScopes};
    selected ? scopes.add(scope) : scopes.remove(scope);
    state = AsyncData(
      current.copyWith(
        selectedScopes: scopes,
        clearFailure: true,
        clearRecovery: true,
      ),
    );
  }

  Future<bool> send(String content) async {
    final current = state.value;
    if (current == null || !current.canCompose) return false;
    state = AsyncData(
      current.copyWith(
        interaction: AiChatInteraction.sending,
        clearFailure: true,
        clearRecovery: true,
      ),
    );
    try {
      final result = await ref
          .read(aiChatCoordinatorProvider)
          .send(
            threadId: current.conversation?.thread.id,
            userContent: content,
            scopes: current.selectedScopes,
          );
      await _refreshAfterOperation(
        threadId: result.threadId,
        selectedScopes: current.selectedScopes,
        failureCode: result.failureCode,
        recoveryStatus: result.status == AiChatOperationStatus.pendingRecovery
            ? AiChatRecoveryStatus.outcomeUnknown
            : null,
      );
      if (ref.mounted) ref.invalidate(aiChatUsageControllerProvider);
      return true;
    } on AiGenerationException catch (error) {
      _showFailure(current, error.code);
      return false;
    } catch (_) {
      _showFailure(current, AiReportFailureCode.unknown);
      return false;
    }
  }

  Future<void> retry() async {
    final current = state.value;
    final threadId = current?.conversation?.thread.id;
    if (current == null ||
        threadId == null ||
        current.isBusy ||
        !current.requiresRetry) {
      return;
    }
    state = AsyncData(
      current.copyWith(
        interaction: AiChatInteraction.sending,
        clearFailure: true,
        clearRecovery: true,
      ),
    );
    try {
      final result = await ref
          .read(aiChatCoordinatorProvider)
          .retry(threadId: threadId, scopes: current.selectedScopes);
      await _refreshAfterOperation(
        threadId: threadId,
        selectedScopes: current.selectedScopes,
        failureCode: result.failureCode,
        recoveryStatus: result.status == AiChatOperationStatus.pendingRecovery
            ? AiChatRecoveryStatus.outcomeUnknown
            : null,
      );
      if (ref.mounted) ref.invalidate(aiChatUsageControllerProvider);
    } on AiGenerationException catch (error) {
      _showFailure(current, error.code);
    } catch (_) {
      _showFailure(current, AiReportFailureCode.unknown);
    }
  }

  Future<void> recover() async {
    final current = state.value;
    final message = current?.latestAssistant;
    if (current == null ||
        message == null ||
        current.isBusy ||
        !current.requiresRecovery) {
      return;
    }
    state = AsyncData(
      current.copyWith(
        interaction: AiChatInteraction.recovering,
        clearFailure: true,
        clearRecovery: true,
      ),
    );
    final result = await ref.read(aiChatCoordinatorProvider).recover(message);
    await _refreshAfterOperation(
      threadId: message.threadId,
      selectedScopes: current.selectedScopes,
      failureCode: result.failureCode,
      recoveryStatus: result.status,
    );
    if (ref.mounted &&
        (result.status == AiChatRecoveryStatus.completed ||
            result.status == AiChatRecoveryStatus.failed)) {
      ref.invalidate(aiChatUsageControllerProvider);
    }
  }

  Future<bool> archiveCurrent() => _mutateCurrent(delete: false);

  Future<bool> deleteCurrent() => _mutateCurrent(delete: true);

  Future<bool> _mutateCurrent({required bool delete}) async {
    final current = state.value;
    final threadId = current?.conversation?.thread.id;
    if (current == null || threadId == null || current.isBusy) return false;
    state = AsyncData(
      current.copyWith(interaction: AiChatInteraction.mutating),
    );
    try {
      final repository = ref.read(aiChatRepositoryProvider);
      if (delete) {
        await repository.deleteThread(threadId);
      } else {
        await repository.archiveThread(threadId);
      }
      if (!ref.mounted) return true;
      state = AsyncData(
        await _load(
          threadId: delete ? null : threadId,
          selectedScopes: const {},
        ),
      );
      return true;
    } catch (_) {
      _showFailure(current, AiReportFailureCode.unknown);
      return false;
    }
  }

  Future<AiChatViewState> _load({
    String? threadId,
    Set<AiDataScope> selectedScopes = const {},
  }) async {
    final repository = ref.read(aiChatRepositoryProvider);
    final threads = await repository.listThreads(includeArchived: true);
    final conversation = threadId == null
        ? null
        : await repository.getConversation(threadId);
    return AiChatViewState(
      threads: threads,
      conversation: conversation,
      selectedScopes: selectedScopes,
    );
  }

  Future<void> _refreshAfterOperation({
    required String threadId,
    required Set<AiDataScope> selectedScopes,
    required AiReportFailureCode? failureCode,
    required AiChatRecoveryStatus? recoveryStatus,
  }) async {
    final loaded = await _load(
      threadId: threadId,
      selectedScopes: selectedScopes,
    );
    if (!ref.mounted) return;
    state = AsyncData(
      loaded.copyWith(
        failureCode: failureCode,
        recoveryStatus: recoveryStatus,
        clearFailure: failureCode == null,
        clearRecovery: recoveryStatus == null,
      ),
    );
  }

  void _showFailure(AiChatViewState previous, AiReportFailureCode code) {
    if (!ref.mounted) return;
    state = AsyncData(
      previous.copyWith(
        interaction: AiChatInteraction.ready,
        failureCode: code,
        clearRecovery: true,
      ),
    );
  }
}
