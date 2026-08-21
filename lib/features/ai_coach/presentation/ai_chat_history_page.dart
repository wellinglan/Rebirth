import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rebirth/core/router/route_names.dart';
import 'package:rebirth/core/theme/app_layout.dart';

import 'ai_chat_controller.dart';

class AiChatHistoryPage extends ConsumerWidget {
  const AiChatHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(aiChatControllerProvider);
    return Scaffold(
      key: const ValueKey('aiChatHistoryPage'),
      appBar: AppBar(
        title: const Text('本地会话'),
        actions: [
          Tooltip(
            message: '新建会话',
            child: IconButton(
              key: const ValueKey('newAiChatFromHistoryButton'),
              onPressed: () {
                ref.read(aiChatControllerProvider.notifier).startNewThread();
                context.pushReplacement(RoutePaths.aiCoachChat);
              },
              icon: const Icon(Icons.add_comment_outlined),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: chat.when(
          loading: () => const Center(
            child: CircularProgressIndicator(semanticsLabel: '正在读取本地会话'),
          ),
          error: (_, _) => Center(
            child: OutlinedButton.icon(
              onPressed: () =>
                  ref.read(aiChatControllerProvider.notifier).reload(),
              icon: const Icon(Icons.refresh),
              label: const Text('重新读取'),
            ),
          ),
          data: (state) {
            if (state.threads.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Text('还没有本地会话。'),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              itemCount: state.threads.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final thread = state.threads[index];
                return ListTile(
                  key: ValueKey('aiChatHistoryThread-${thread.id}'),
                  leading: Icon(
                    thread.isArchived
                        ? Icons.archive_outlined
                        : Icons.chat_bubble_outline,
                  ),
                  title: Text(thread.title),
                  subtitle: Text(thread.isArchived ? '已归档 · 仅保存在本机' : '仅保存在本机'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.pushReplacement(
                    RoutePaths.aiCoachChatForThread(thread.id),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
