import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rebirth/core/theme/app_layout.dart';
import 'package:rebirth/features/ai_coach/application/ai_chat_coordinator.dart';
import 'package:rebirth/features/ai_coach/domain/ai_chat_conversation.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_scope.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_status.dart';
import 'package:rebirth/features/ai_coach/domain/ai_usage_snapshot.dart';
import 'package:rebirth/features/ai_coach/presentation/ai_chat_view_state.dart';

class AiChatConversationView extends StatelessWidget {
  const AiChatConversationView({
    required this.state,
    required this.consentEnabled,
    required this.usage,
    required this.composerController,
    required this.scrollController,
    required this.onOpenConsent,
    required this.onChooseContext,
    required this.onSend,
    required this.onRetry,
    required this.onRecover,
    super.key,
  });

  final AiChatViewState state;
  final bool consentEnabled;
  final AiUsageSnapshot? usage;
  final TextEditingController composerController;
  final ScrollController scrollController;
  final VoidCallback onOpenConsent;
  final VoidCallback onChooseContext;
  final VoidCallback onSend;
  final VoidCallback onRetry;
  final VoidCallback onRecover;

  @override
  Widget build(BuildContext context) {
    final conversation = state.conversation;
    final usageBlocked = usage?.preventsGeneration ?? false;
    final canSend = state.canCompose && consentEnabled && !usageBlocked;
    return Column(
      key: const ValueKey('aiChatConversationView'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ConversationHeader(conversation: conversation),
        if (!consentEnabled)
          _InlineNotice(
            key: const ValueKey('aiChatConsentRequired'),
            icon: Icons.privacy_tip_outlined,
            message: '发送消息前需要允许 AI 使用本次由你选择的数据。历史会话仍可阅读。',
            actionLabel: '前往授权设置',
            onAction: onOpenConsent,
          )
        else if (usage?.availability == AiUsageAvailability.limitReached)
          const _InlineNotice(
            key: ValueKey('aiChatUsageLimitReached'),
            icon: Icons.schedule_outlined,
            message: '今天的 AI 次数已用完，历史会话仍可阅读。',
          )
        else if (usage?.availability == AiUsageAvailability.disabled)
          const _InlineNotice(
            key: ValueKey('aiChatProviderDisabled'),
            icon: Icons.pause_circle_outline,
            message: 'AI 服务当前暂不可用，历史会话仍可阅读。',
          ),
        if (state.failureCode case final failure?)
          _InlineNotice(
            key: const ValueKey('aiChatControlledFailure'),
            icon: Icons.info_outline,
            message: aiChatFailureMessage(failure),
          ),
        if (state.recoveryStatus case final recovery?)
          _RecoveryNotice(status: recovery),
        Expanded(
          child: _MessageTimeline(
            conversation: conversation,
            scrollController: scrollController,
            latestAssistant: state.latestAssistant,
            busy: state.isBusy,
            onRetry: onRetry,
            onRecover: onRecover,
          ),
        ),
        const Divider(height: 1),
        AiChatComposer(
          controller: composerController,
          selectedScopes: state.selectedScopes,
          enabled: canSend,
          sending: state.interaction == AiChatInteraction.sending,
          archived: conversation?.thread.isArchived ?? false,
          blockedByUnresolved: state.requiresRecovery || state.requiresRetry,
          onChooseContext: onChooseContext,
          onSend: onSend,
        ),
      ],
    );
  }
}

class AiChatThreadListPane extends StatelessWidget {
  const AiChatThreadListPane({
    required this.threads,
    required this.selectedThreadId,
    required this.onSelect,
    required this.onNewThread,
    super.key,
  });

  final List<AiChatThread> threads;
  final String? selectedThreadId;
  final ValueChanged<String> onSelect;
  final VoidCallback onNewThread;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('aiChatThreadListPane'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '本地会话',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Tooltip(
                message: '新建会话',
                child: IconButton(
                  key: const ValueKey('newAiChatThreadButton'),
                  onPressed: onNewThread,
                  icon: const Icon(Icons.add_comment_outlined),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: threads.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Text('还没有本地会话。'),
                  ),
                )
              : ListView.builder(
                  itemCount: threads.length,
                  itemBuilder: (context, index) {
                    final thread = threads[index];
                    return ListTile(
                      key: ValueKey('aiChatThread-${thread.id}'),
                      selected: thread.id == selectedThreadId,
                      leading: Icon(
                        thread.isArchived
                            ? Icons.archive_outlined
                            : Icons.chat_bubble_outline,
                      ),
                      title: Text(
                        thread.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        thread.isArchived ? '已归档 · 仅保存在本机' : '仅保存在本机',
                      ),
                      onTap: () => onSelect(thread.id),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class AiChatContextPicker extends StatelessWidget {
  const AiChatContextPicker({
    required this.selectedScopes,
    required this.onChanged,
    required this.onClear,
    super.key,
  });

  final Set<AiDataScope> selectedScopes;
  final void Function(AiDataScope scope, bool selected) onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    const options = [
      (
        AiDataScope.growthSummary,
        '成长趋势',
        '最近 7 天的聚合趋势',
        Icons.insights_outlined,
      ),
      (
        AiDataScope.todayMetrics,
        'Today 指标',
        '最近 7 天的评分与时间指标，不含一句话描述',
        Icons.today_outlined,
      ),
      (
        AiDataScope.healthMetrics,
        '健康指标',
        '最近 7 天的睡眠、运动、饮水等指标，不含一句话描述',
        Icons.favorite_border,
      ),
      (
        AiDataScope.journalReflections,
        '复盘内容',
        '最近 7 天由你填写的反思正文',
        Icons.menu_book_outlined,
      ),
    ];
    return SafeArea(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '本次参考资料',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: selectedScopes.isEmpty ? null : onClear,
                    icon: const Icon(Icons.clear_all),
                    label: const Text('清空'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text('默认不读取个人记录。只有勾选后，下一次发送才会附带对应资料。'),
              const SizedBox(height: AppSpacing.sm),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final option in options)
                      CheckboxListTile(
                        key: ValueKey('aiChatScope-${option.$1.contractValue}'),
                        value: selectedScopes.contains(option.$1),
                        onChanged: (value) =>
                            onChanged(option.$1, value ?? false),
                        secondary: Icon(option.$4),
                        title: Text(option.$2),
                        subtitle: Text(option.$3),
                        controlAffinity: ListTileControlAffinity.trailing,
                        contentPadding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text('修改选择不会发送消息、调用 AI 或触发同步；目标数据暂不支持。'),
            ],
          ),
        ),
      ),
    );
  }
}

class AiChatComposer extends StatelessWidget {
  const AiChatComposer({
    required this.controller,
    required this.selectedScopes,
    required this.enabled,
    required this.sending,
    required this.archived,
    required this.blockedByUnresolved,
    required this.onChooseContext,
    required this.onSend,
    super.key,
  });

  final TextEditingController controller;
  final Set<AiDataScope> selectedScopes;
  final bool enabled;
  final bool sending;
  final bool archived;
  final bool blockedByUnresolved;
  final VoidCallback onChooseContext;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final contextLabel = selectedScopes.isEmpty
        ? '本次仅发送你输入的文字'
        : '本次参考：${_scopeLabels(selectedScopes).join('、')}';
    final disabledHint = archived
        ? '此会话已归档，只能阅读。'
        : blockedByUnresolved
        ? '请先重试或检查上一条回复。'
        : null;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xxs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('aiChatContextButton'),
                onPressed: sending || archived ? null : onChooseContext,
                icon: const Icon(Icons.dataset_outlined),
                label: const Text('本次参考资料'),
              ),
              Text(contextLabel, key: const ValueKey('aiChatContextSummary')),
            ],
          ),
          if (disabledHint != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(disabledHint),
          ],
          const SizedBox(height: AppSpacing.xs),
          Shortcuts(
            shortcuts: <ShortcutActivator, Intent>{
              const SingleActivator(LogicalKeyboardKey.enter):
                  const _SendChatIntent(),
            },
            child: Actions(
              actions: <Type, Action<Intent>>{
                _SendChatIntent: CallbackAction<_SendChatIntent>(
                  onInvoke: (_) {
                    if (enabled && controller.text.trim().isNotEmpty) onSend();
                    return null;
                  },
                ),
              },
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('aiChatComposerField'),
                      controller: controller,
                      enabled: !sending && !archived && !blockedByUnresolved,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: 2000,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        labelText: '输入消息',
                        hintText: '写下你想讨论的事情',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Tooltip(
                    message: sending ? '正在发送' : '发送消息',
                    child: Semantics(
                      key: const ValueKey('sendAiChatSemantics'),
                      container: true,
                      button: true,
                      label: sending ? '正在发送消息' : '发送消息',
                      child: SizedBox.square(
                        dimension: 48,
                        child: sending
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : IconButton.filled(
                                key: const ValueKey('sendAiChatButton'),
                                onPressed: enabled ? onSend : null,
                                icon: const Icon(Icons.send),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationHeader extends StatelessWidget {
  const _ConversationHeader({required this.conversation});

  final AiChatConversation? conversation;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            conversation?.thread.title ?? '新对话',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            conversation?.thread.isArchived == true
                ? '已归档 · 本地保存 · 不跨设备同步'
                : '本地保存 · 不跨设备同步',
          ),
        ],
      ),
    );
  }
}

class _MessageTimeline extends StatelessWidget {
  const _MessageTimeline({
    required this.conversation,
    required this.scrollController,
    required this.latestAssistant,
    required this.busy,
    required this.onRetry,
    required this.onRecover,
  });

  final AiChatConversation? conversation;
  final ScrollController scrollController;
  final AiChatMessage? latestAssistant;
  final bool busy;
  final VoidCallback onRetry;
  final VoidCallback onRecover;

  @override
  Widget build(BuildContext context) {
    final messages = conversation?.messages ?? const <AiChatMessage>[];
    if (messages.isEmpty) {
      return const Center(
        key: ValueKey('aiChatEmptyState'),
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chat_bubble_outline, size: 36),
              SizedBox(height: AppSpacing.sm),
              Text('从一件你此刻在意的事情开始。'),
              SizedBox(height: AppSpacing.xs),
              Text('AI 可能出错，重要决定请由你自己确认。'),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      key: const ValueKey('aiChatMessageTimeline'),
      controller: scrollController,
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: messages.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final message = messages[index];
        return _MessageItem(
          message: message,
          isLatestAssistant: message.id == latestAssistant?.id,
          busy: busy,
          onRetry: onRetry,
          onRecover: onRecover,
        );
      },
    );
  }
}

class _MessageItem extends StatelessWidget {
  const _MessageItem({
    required this.message,
    required this.isLatestAssistant,
    required this.busy,
    required this.onRetry,
    required this.onRecover,
  });

  final AiChatMessage message;
  final bool isLatestAssistant;
  final bool busy;
  final VoidCallback onRetry;
  final VoidCallback onRecover;

  @override
  Widget build(BuildContext context) {
    final user = message.role == AiChatRole.user;
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: user ? 0.78 : 0.9,
        child: Column(
          crossAxisAlignment: user
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Semantics(
              container: true,
              label: user ? '你的消息' : 'AI 教练回复',
              child: Container(
                decoration: BoxDecoration(
                  color: user
                      ? colors.primaryContainer
                      : colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: _messageBody(context),
              ),
            ),
            if (!user && message.status == AiChatMessageStatus.completed)
              Tooltip(
                message: '复制回复',
                child: IconButton(
                  key: ValueKey('copyAiChatMessage-${message.id}'),
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: message.content),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('回复已复制')));
                    }
                  },
                  icon: const Icon(Icons.content_copy, size: 20),
                ),
              ),
            if (!user && message.status == AiChatMessageStatus.completed)
              _SafetyNotice(category: message.safetyCategory),
          ],
        ),
      ),
    );
  }

  Widget _messageBody(BuildContext context) {
    if (message.role == AiChatRole.user) {
      return SelectableText(message.content);
    }
    return switch (message.status) {
      AiChatMessageStatus.completed => SelectableText(message.content),
      AiChatMessageStatus.pending => Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const Text('正在等待完整回复…'),
          if (isLatestAssistant)
            TextButton(
              onPressed: busy ? null : onRecover,
              child: const Text('检查结果'),
            ),
        ],
      ),
      AiChatMessageStatus.outcomeUnknown => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('网络中断后，暂时无法确认这次请求的结果。'),
          if (isLatestAssistant)
            TextButton.icon(
              key: const ValueKey('checkAiChatResultButton'),
              onPressed: busy ? null : onRecover,
              icon: const Icon(Icons.refresh),
              label: const Text('检查结果（不会重新生成）'),
            ),
        ],
      ),
      AiChatMessageStatus.failed => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('这次回复未能完成，你的消息仍保留在本机。'),
          if (isLatestAssistant)
            TextButton.icon(
              key: const ValueKey('retryAiChatButton'),
              onPressed: busy ? null : onRetry,
              icon: const Icon(Icons.replay),
              label: const Text('重新尝试'),
            ),
        ],
      ),
    };
  }
}

class _SafetyNotice extends StatelessWidget {
  const _SafetyNotice({required this.category});

  final AiChatSafetyCategory? category;

  @override
  Widget build(BuildContext context) {
    return switch (category) {
      AiChatSafetyCategory.highRisk => Container(
        key: const ValueKey('aiChatHighRiskNotice'),
        margin: const EdgeInsets.only(top: AppSpacing.xs),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('如果你或他人正处于立即危险，请联系当地紧急服务、专业支持或你信任的人。AI 不能替代专业帮助。'),
      ),
      AiChatSafetyCategory.caution => const Padding(
        key: ValueKey('aiChatCautionNotice'),
        padding: EdgeInsets.only(top: AppSpacing.xs),
        child: Text('这段回复涉及健康或情绪话题，仅供参考，不构成诊断或治疗建议。'),
      ),
      AiChatSafetyCategory.normal || null => const SizedBox.shrink(),
    };
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xxs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(icon, size: 20),
          Text(message),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

class _RecoveryNotice extends StatelessWidget {
  const _RecoveryNotice({required this.status});

  final AiChatRecoveryStatus status;

  @override
  Widget build(BuildContext context) {
    final message = switch (status) {
      AiChatRecoveryStatus.processing => '服务端仍在处理，请稍后再次检查。',
      AiChatRecoveryStatus.networkUnknown => '暂时无法连接服务器，本地消息保持不变。',
      AiChatRecoveryStatus.endpointMismatch => '当前服务器与原请求不一致，未查询结果。',
      AiChatRecoveryStatus.accountMismatch => '当前账号与原请求不一致，未查询结果。',
      AiChatRecoveryStatus.missingBinding => '缺少安全查询信息，无法自动重发。',
      AiChatRecoveryStatus.completed => '已找回完整回复。',
      AiChatRecoveryStatus.failed => '服务端确认这次回复未能完成。',
      AiChatRecoveryStatus.outcomeUnknown => '服务端仍无法确认结果，不会自动重发。',
      AiChatRecoveryStatus.resultExpired => '服务端结果已过期，不会自动重发。',
      AiChatRecoveryStatus.serverNotFound => '服务端没有找到这次请求，不会自动重发。',
    };
    return _InlineNotice(
      key: const ValueKey('aiChatRecoveryNotice'),
      icon: Icons.info_outline,
      message: message,
    );
  }
}

String aiChatFailureMessage(AiReportFailureCode code) => switch (code) {
  AiReportFailureCode.authenticationRequired => '登录状态需要重新确认，请重新登录后再试。',
  AiReportFailureCode.usageLimitReached => '今天的 AI 次数已用完。',
  AiReportFailureCode.aiDisabled ||
  AiReportFailureCode.gatewayDisabled => 'AI 服务当前暂不可用。',
  AiReportFailureCode.providerTimeout => 'AI 回复超时，你的消息已保留，可以重新尝试。',
  AiReportFailureCode.providerUnavailable ||
  AiReportFailureCode.providerRateLimited => 'AI 服务暂时繁忙，你的消息已保留。',
  AiReportFailureCode.cancelled => '授权或账号状态已变化，本次没有发送。',
  AiReportFailureCode.invalidInput ||
  AiReportFailureCode.unsupportedScope => '请检查输入、授权和本次参考资料后再试。',
  AiReportFailureCode.requestBindingFailed => '本地安全信息保存失败，本次没有调用 AI。',
  _ => '这次操作未能完成，你的本地内容没有丢失。',
};

List<String> _scopeLabels(Set<AiDataScope> scopes) {
  final result = <String>[];
  for (final scope in AiDataScope.values) {
    if (!scopes.contains(scope)) continue;
    result.add(switch (scope) {
      AiDataScope.growthSummary => '成长趋势',
      AiDataScope.todayMetrics => 'Today 指标',
      AiDataScope.healthMetrics => '健康指标',
      AiDataScope.journalReflections => '复盘内容',
      AiDataScope.activeGoals => '目标',
    });
  }
  return result;
}

final class _SendChatIntent extends Intent {
  const _SendChatIntent();
}
