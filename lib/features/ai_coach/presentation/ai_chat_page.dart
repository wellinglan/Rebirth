import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rebirth/core/router/route_names.dart';
import 'package:rebirth/core/theme/app_layout.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_scope.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_status.dart';
import 'package:rebirth/features/settings/presentation/ai_data_consent_controller.dart';

import 'ai_chat_controller.dart';
import 'ai_chat_view_state.dart';
import 'ai_usage_controller.dart';
import 'ai_report_history_controller.dart';
import 'widgets/ai_chat_conversation_view.dart';
import 'widgets/ai_journal_scope_dialog.dart';

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
    final usage = ref.watch(aiChatUsageControllerProvider);
    final reports = ref.watch(aiReportHistoryControllerProvider);
    final recentReports =
        reports.value?.reports
            .where(
              (report) =>
                  report.status == AiReportStatus.completed ||
                  report.status == AiReportStatus.archived,
            )
            .toList(growable: false) ??
        const [];
    final conversation = chat.value?.conversation;
    return Scaffold(
      key: const ValueKey('aiChatPage'),
      appBar: AppBar(
        title: const Text('AI 教练'),
        actions: [
          Tooltip(
            message: 'AI 报告库',
            child: IconButton(
              key: const ValueKey('openAiReportLibraryButton'),
              onPressed: () => context.push(RoutePaths.aiReports),
              icon: const Icon(Icons.library_books_outlined),
            ),
          ),
          Tooltip(
            message: 'AI 数据授权',
            child: IconButton(
              key: const ValueKey('openAiConsentButton'),
              onPressed: _openConsent,
              icon: const Icon(Icons.privacy_tip_outlined),
            ),
          ),
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
                onGenerateDaily: () => _openReportFlow(daily: true),
                onGenerateWeekly: () => _openReportFlow(daily: false),
                recentReports: recentReports,
                onOpenReport: (id) =>
                    context.push(RoutePaths.aiReportsDetail(id)),
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
      ref.read(aiChatUsageControllerProvider.notifier).refresh(),
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

  Future<void> _openReportFlow({required bool daily}) async {
    final scopes = await _showReportScopePicker(daily: daily);
    if (!mounted || scopes == null || scopes.isEmpty) return;
    final values = scopes.map((scope) => scope.contractValue);
    final route = daily
        ? RoutePaths.aiCoachDaily(
            ref.read(dateTimeServiceProvider).currentLocalDateString(),
            scopes: values,
          )
        : RoutePaths.aiCoachWeeklyWithScopes(values);
    await context.push(route);
    if (!mounted) return;
    await Future.wait([
      ref.read(aiReportHistoryControllerProvider.notifier).reload(),
      ref.read(aiUsageControllerProvider.notifier).refresh(),
    ]);
  }

  Future<Set<AiDataScope>?> _showReportScopePicker({required bool daily}) {
    final picker = _QuickReportScopePicker(daily: daily);
    if (MediaQuery.sizeOf(context).width < 720) {
      return showModalBottomSheet<Set<AiDataScope>>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => FractionallySizedBox(heightFactor: 0.86, child: picker),
      );
    }
    return showDialog<Set<AiDataScope>>(
      context: context,
      builder: (_) =>
          Dialog(child: SizedBox(width: 600, height: 650, child: picker)),
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

class _QuickReportScopePicker extends StatefulWidget {
  const _QuickReportScopePicker({required this.daily});

  final bool daily;

  @override
  State<_QuickReportScopePicker> createState() =>
      _QuickReportScopePickerState();
}

class _QuickReportScopePickerState extends State<_QuickReportScopePicker> {
  final Set<AiDataScope> _selected = {};

  @override
  Widget build(BuildContext context) {
    final options = AiDataScope.values
        .where(
          (scope) =>
              scope.supported &&
              (!widget.daily || scope != AiDataScope.growthSummary),
        )
        .toList(growable: false);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.daily ? '生成今日洞察' : '生成每周回顾',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(widget.daily ? '范围：当前本地自然日' : '范围：最近 7 个本地自然日'),
            const SizedBox(height: AppSpacing.xs),
            const Text('请选择本次允许发送给 AI 的内容。下一步会显示来源数量、Provider、隐私边界和最终确认。'),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: ListView(
                children: [
                  for (final scope in options)
                    CheckboxListTile(
                      key: ValueKey('quickReportScope-${scope.contractValue}'),
                      value: _selected.contains(scope),
                      title: Text(_scopeTitle(scope)),
                      subtitle: scope == AiDataScope.journalReflections
                          ? const Text('包含你填写的反思正文，需要单独确认')
                          : null,
                      controlAffinity: ListTileControlAffinity.trailing,
                      onChanged: (value) => _toggle(scope, value ?? false),
                    ),
                ],
              ),
            ),
            const Text('AI 可能出错；报告只读取本次明确选择的数据，不会自动修改记录或加入聊天上下文。'),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                FilledButton.icon(
                  key: const ValueKey('continueQuickReportButton'),
                  onPressed: _selected.isEmpty
                      ? null
                      : () => Navigator.pop(context, Set.of(_selected)),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('查看数据并继续'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggle(AiDataScope scope, bool selected) async {
    if (scope == AiDataScope.journalReflections && selected) {
      final confirmed = await showAiJournalScopeDialog(
        context,
        isDaily: widget.daily,
      );
      if (!mounted || !confirmed) return;
    }
    setState(() {
      selected ? _selected.add(scope) : _selected.remove(scope);
    });
  }

  String _scopeTitle(AiDataScope scope) => switch (scope) {
    AiDataScope.growthSummary => '成长趋势',
    AiDataScope.todayMetrics => 'Today 指标',
    AiDataScope.healthMetrics => '健康指标',
    AiDataScope.journalReflections => 'Journal 复盘内容',
    AiDataScope.activeGoals => '目标',
  };
}

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
