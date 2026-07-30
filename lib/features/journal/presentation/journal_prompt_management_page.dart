import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/journal/journal_prompt_catalog.dart';
import 'package:rebirth/core/theme/app_layout.dart';
import 'package:rebirth/features/journal/domain/journal_prompt.dart';

import 'journal_prompt_controller.dart';

class JournalPromptManagementPage extends ConsumerWidget {
  const JournalPromptManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(journalPromptControllerProvider);
    return Scaffold(
      key: const ValueKey('journalPromptManagementPage'),
      appBar: AppBar(
        title: const Text('复盘问题'),
        actions: [
          IconButton(
            key: const ValueKey('addJournalPromptButton'),
            tooltip: '新增问题',
            onPressed: state.hasValue ? () => _showEditor(context, ref) : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            key: ValueKey('journalPromptLoadingState'),
          ),
        ),
        error: (_, _) => Center(
          key: const ValueKey('journalPromptErrorState'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('问题配置暂时无法加载'),
              const SizedBox(height: AppSpacing.sm),
              FilledButton.icon(
                onPressed: () =>
                    ref.read(journalPromptControllerProvider.notifier).reload(),
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
        data: (configuration) =>
            _PromptConfigurationBody(configuration: configuration),
      ),
    );
  }

  Future<void> _showEditor(
    BuildContext context,
    WidgetRef ref, {
    JournalPromptDefinition? prompt,
  }) async {
    final questionController = TextEditingController(
      text: prompt?.questionText,
    );
    final helperController = TextEditingController(text: prompt?.helperText);
    final formKey = GlobalKey<FormState>();
    var saving = false;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            key: const ValueKey('journalPromptEditorDialog'),
            title: Text(prompt == null ? '新增问题' : '编辑问题'),
            content: SizedBox(
              width: 520,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        key: const ValueKey('journalPromptQuestionField'),
                        controller: questionController,
                        enabled: !saving,
                        maxLength: JournalPromptLimits.questionTextLength,
                        minLines: 2,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: '问题',
                          alignLabelWithHint: true,
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? '请输入问题'
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        key: const ValueKey('journalPromptHelperField'),
                        controller: helperController,
                        enabled: !saving,
                        maxLength: JournalPromptLimits.helperTextLength,
                        minLines: 1,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: '填写提示（可选）',
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                key: const ValueKey('saveJournalPromptButton'),
                onPressed: saving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => saving = true);
                        final input = JournalPromptInput(
                          questionText: questionController.text,
                          helperText: helperController.text,
                        );
                        try {
                          final controller = ref.read(
                            journalPromptControllerProvider.notifier,
                          );
                          if (prompt == null) {
                            await controller.createPrompt(input);
                          } else {
                            await controller.updatePrompt(prompt.id, input);
                          }
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                        } catch (_) {
                          if (dialogContext.mounted) {
                            ScaffoldMessenger.of(dialogContext)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                const SnackBar(content: Text('保存失败，请检查内容后重试')),
                              );
                            setDialogState(() => saving = false);
                          }
                        }
                      },
                child: Text(saving ? '保存中...' : '保存'),
              ),
            ],
          ),
        ),
      );
    } finally {
      // The route future completes before the exit animation detaches fields.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      questionController.dispose();
      helperController.dispose();
    }
  }
}

class _PromptConfigurationBody extends ConsumerWidget {
  const _PromptConfigurationBody({required this.configuration});

  final JournalPromptConfiguration configuration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = configuration.activePrompts;
    final disabled = configuration.disabledPrompts;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppLayout.maxContentWidth),
        child: ListView(
          padding: AppLayout.pagePadding,
          children: [
            Text(
              '这些问题只用于你的 Journal。历史记录保留当时的问题快照，修改配置不会重写过去。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              switch (configuration.syncStatus) {
                'conflict' => '同步状态：存在冲突，请到同步中心处理',
                'pending' || 'local_only' => '同步状态：待手动同步',
                _ => '同步状态：已同步',
              },
              key: const ValueKey('journalPromptSyncStatus'),
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('使用中的问题', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            ReorderableListView.builder(
              key: const ValueKey('activeJournalPromptList'),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: active.length,
              onReorderItem: (oldIndex, newIndex) {
                final ids = active.map((prompt) => prompt.id).toList();
                final moved = ids.removeAt(oldIndex);
                ids.insert(newIndex, moved);
                _run(
                  context,
                  ref
                      .read(journalPromptControllerProvider.notifier)
                      .reorder(ids),
                );
              },
              itemBuilder: (context, index) => _PromptTile(
                key: ValueKey('journalPrompt_${active[index].id}'),
                prompt: active[index],
                index: index,
                activeCount: active.length,
                enabled: true,
              ),
            ),
            if (disabled.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xl),
              Text('已停用', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              for (final prompt in disabled)
                _PromptTile(
                  key: ValueKey('journalPrompt_${prompt.id}'),
                  prompt: prompt,
                  index: -1,
                  activeCount: active.length,
                  enabled: false,
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _run(BuildContext context, Future<void> operation) async {
    try {
      await operation;
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('操作失败，原配置已保留')));
    }
  }
}

class _PromptTile extends ConsumerWidget {
  const _PromptTile({
    required this.prompt,
    required this.index,
    required this.activeCount,
    required this.enabled,
    super.key,
  });

  final JournalPromptDefinition prompt;
  final int index;
  final int activeCount;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(journalPromptControllerProvider.notifier);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: enabled
          ? ReorderableDragStartListener(
              index: index,
              child: const Icon(Icons.drag_handle),
            )
          : const Icon(Icons.pause_circle_outline),
      title: Text(prompt.questionText),
      subtitle: Text(
        [
          prompt.isSystem ? '系统问题' : '自定义问题',
          if (prompt.helperText != null) prompt.helperText!,
        ].join(' · '),
      ),
      trailing: Wrap(
        spacing: 0,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (enabled)
            IconButton(
              tooltip: '上移',
              onPressed: index <= 0
                  ? null
                  : () => _move(context, ref, index, index - 1),
              icon: const Icon(Icons.arrow_upward),
            ),
          if (enabled)
            IconButton(
              tooltip: '下移',
              onPressed: index >= activeCount - 1
                  ? null
                  : () => _move(context, ref, index, index + 1),
              icon: const Icon(Icons.arrow_downward),
            ),
          PopupMenuButton<String>(
            tooltip: '更多操作',
            onSelected: (action) =>
                _handleAction(context, ref, controller, action),
            itemBuilder: (context) => [
              if (prompt.isUser)
                const PopupMenuItem(value: 'edit', child: Text('编辑')),
              if (prompt.isSystem)
                const PopupMenuItem(value: 'duplicate', child: Text('自定义此问题')),
              PopupMenuItem(
                value: 'toggle',
                child: Text(enabled ? '停用' : '启用'),
              ),
              if (prompt.isUser)
                const PopupMenuItem(value: 'delete', child: Text('删除')),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _move(
    BuildContext context,
    WidgetRef ref,
    int from,
    int to,
  ) async {
    final active =
        ref.read(journalPromptControllerProvider).asData?.value.activePrompts ??
        const [];
    final ids = active.map((prompt) => prompt.id).toList();
    final moved = ids.removeAt(from);
    ids.insert(to, moved);
    await _guard(
      context,
      ref.read(journalPromptControllerProvider.notifier).reorder(ids),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    JournalPromptController controller,
    String action,
  ) async {
    switch (action) {
      case 'edit':
        await const JournalPromptManagementPage()._showEditor(
          context,
          ref,
          prompt: prompt,
        );
      case 'duplicate':
        await _guard(context, controller.duplicateAsUserPrompt(prompt.id));
      case 'toggle':
        await _guard(context, controller.setEnabled(prompt.id, !enabled));
      case 'delete':
        final confirmed =
            await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                key: const ValueKey('confirmDeleteJournalPromptDialog'),
                title: const Text('删除这个自定义问题？'),
                content: const Text('历史 Journal 中的问题和回答仍会保留。'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('取消'),
                  ),
                  FilledButton(
                    key: const ValueKey('confirmDeleteJournalPromptButton'),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('删除'),
                  ),
                ],
              ),
            ) ??
            false;
        if (confirmed && context.mounted) {
          await _guard(context, controller.deletePrompt(prompt.id));
        }
    }
  }

  Future<void> _guard(BuildContext context, Future<void> operation) async {
    try {
      await operation;
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('操作失败，原配置已保留')));
    }
  }
}
