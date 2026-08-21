import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rebirth/core/router/route_names.dart';
import 'package:rebirth/core/theme/app_layout.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_scope.dart';
import 'package:rebirth/features/settings/presentation/ai_data_consent_controller.dart';

import 'ai_chat_controller.dart';
import 'ai_chat_view_state.dart';
import 'ai_usage_controller.dart';
import 'widgets/ai_chat_conversation_view.dart';

class AiChatPage extends ConsumerStatefulWidget {
  const AiChatPage({this.initialThreadId, super.key});

  final String? initialThreadId;

  @override
  ConsumerState<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends ConsumerState<AiChatPage> {
  final _composerController = TextEditingController();
  final _scrollController = ScrollController();
  bool _initialThreadApplied = false;

  @override
  void dispose() {
    _composerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AiChatViewState>>(aiChatControllerProvider, (
      previous,
      next,
    ) {
      final threadId = widget.initialThreadId;
      if (_initialThreadApplied || threadId == null || next.value == null) {
        return;
      }
      _initialThreadApplied = true;
      unawaited(
        ref.read(aiChatControllerProvider.notifier).openThread(threadId),
      );
    });
    final chat = ref.watch(aiChatControllerProvider);
    final initialThreadId = widget.initialThreadId;
    if (!_initialThreadApplied &&
        initialThreadId != null &&
        chat.value != null) {
      _initialThreadApplied = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          ref
              .read(aiChatControllerProvider.notifier)
              .openThread(initialThreadId),
        );
      });
    }
    final consent = ref.watch(aiDataConsentControllerProvider);
    final usage = ref.watch(aiUsageControllerProvider);
    final conversation = chat.value?.conversation;
    return Scaffold(
      key: const ValueKey('aiChatPage'),
      appBar: AppBar(
        title: const Text('AI 对话'),
        actions: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = MediaQuery.sizeOf(context).width < 900;
              return compact
                  ? Tooltip(
                      message: '本地会话历史',
                      child: IconButton(
                        key: const ValueKey('openAiChatHistoryButton'),
                        onPressed: () =>
                            context.push(RoutePaths.aiCoachChatHistory),
                        icon: const Icon(Icons.history),
                      ),
                    )
                  : const SizedBox.shrink();
            },
          ),
          Tooltip(
            message: '新建会话',
            child: IconButton(
              key: const ValueKey('newAiChatButton'),
              onPressed: chat.value?.isBusy == true ? null : _startNew,
              icon: const Icon(Icons.add_comment_outlined),
            ),
          ),
          if (conversation != null)
            PopupMenuButton<_ThreadAction>(
              key: const ValueKey('aiChatThreadMenu'),
              tooltip: '会话操作',
              enabled: chat.value?.isBusy != true,
              onSelected: _handleThreadAction,
              itemBuilder: (context) => [
                if (!conversation.thread.isArchived)
                  const PopupMenuItem(
                    value: _ThreadAction.archive,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.archive_outlined),
                      title: Text('归档会话'),
                    ),
                  ),
                const PopupMenuItem(
                  value: _ThreadAction.delete,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.delete_outline),
                    title: Text('删除本地会话'),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: chat.when(
          loading: () => const Center(
            child: CircularProgressIndicator(semanticsLabel: '正在读取本地会话'),
          ),
          error: (_, _) => _ChatLoadError(
            onRetry: () => ref.read(aiChatControllerProvider.notifier).reload(),
          ),
          data: (state) => LayoutBuilder(
            builder: (context, constraints) {
              final conversationView = AiChatConversationView(
                state: state,
                consentEnabled:
                    consent.asData?.value.authorization.enabled ?? false,
                usage: usage.asData?.value,
                composerController: _composerController,
                scrollController: _scrollController,
                onOpenConsent: _openConsent,
                onChooseContext: () => _showContextPicker(state),
                onSend: _send,
                onRetry: () =>
                    ref.read(aiChatControllerProvider.notifier).retry(),
                onRecover: () =>
                    ref.read(aiChatControllerProvider.notifier).recover(),
              );
              if (constraints.maxWidth < 900) return conversationView;
              return Row(
                children: [
                  SizedBox(
                    width: 300,
                    child: AiChatThreadListPane(
                      threads: state.threads,
                      selectedThreadId: state.conversation?.thread.id,
                      onSelect: _openThread,
                      onNewThread: _startNew,
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: conversationView),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _startNew() {
    _composerController.clear();
    ref.read(aiChatControllerProvider.notifier).startNewThread();
  }

  void _openThread(String threadId) {
    _composerController.clear();
    unawaited(ref.read(aiChatControllerProvider.notifier).openThread(threadId));
  }

  Future<void> _send() async {
    final accepted = await ref
        .read(aiChatControllerProvider.notifier)
        .send(_composerController.text);
    if (!mounted || !accepted) return;
    _composerController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _openConsent() async {
    await context.push(RoutePaths.settingsAiConsent);
    if (!mounted) return;
    await Future.wait([
      ref.read(aiDataConsentControllerProvider.notifier).reload(),
      ref.read(aiUsageControllerProvider.notifier).refresh(),
    ]);
  }

  Future<void> _showContextPicker(AiChatViewState state) async {
    Widget picker() => Consumer(
      builder: (context, ref, _) {
        final selected =
            ref.watch(aiChatControllerProvider).value?.selectedScopes ??
            state.selectedScopes;
        final controller = ref.read(aiChatControllerProvider.notifier);
        return AiChatContextPicker(
          selectedScopes: selected,
          onChanged: (scope, value) =>
              controller.setScope(scope, selected: value),
          onClear: () {
            for (final scope in AiDataScope.values) {
              if (scope.supported) controller.setScope(scope, selected: false);
            }
          },
        );
      },
    );

    if (MediaQuery.sizeOf(context).width < 720) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) =>
            FractionallySizedBox(heightFactor: 0.82, child: picker()),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) =>
          Dialog(child: SizedBox(width: 560, height: 620, child: picker())),
    );
  }

  Future<void> _handleThreadAction(_ThreadAction action) async {
    final delete = action == _ThreadAction.delete;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(delete ? '删除本地会话？' : '归档会话？'),
        content: Text(
          delete
              ? '这会完整删除本机上的会话和消息，无法撤销。聊天记录不会从其他设备恢复。'
              : '归档后仍可在本地历史中阅读，但不能继续发送消息。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(delete ? '删除' : '归档'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final controller = ref.read(aiChatControllerProvider.notifier);
    final success = delete
        ? await controller.deleteCurrent()
        : await controller.archiveCurrent();
    if (!mounted || !success) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(delete ? '本地会话已删除' : '会话已归档')));
  }
}

enum _ThreadAction { archive, delete }

class _ChatLoadError extends StatelessWidget {
  const _ChatLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('aiChatLoadError'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('本地会话暂时无法读取。'),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
