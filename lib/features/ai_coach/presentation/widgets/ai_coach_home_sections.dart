import 'package:flutter/material.dart';
import 'package:rebirth/core/theme/app_layout.dart';
import 'package:rebirth/features/ai_coach/domain/ai_usage_snapshot.dart';

import '../models/ai_coach_home_models.dart';
import '../models/ai_report_presentation_models.dart';

class AiCoachConversationEntry extends StatelessWidget {
  const AiCoachConversationEntry({
    required this.onStart,
    required this.enabled,
    super.key,
  });

  final VoidCallback onStart;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey('aiCoachConversationEntry'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.forum_outlined),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '和 AI 教练聊一聊',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      const Text('默认只发送你输入的文字；个人记录需要每次明确选择。'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              key: const ValueKey('startAiChatButton'),
              onPressed: enabled ? onStart : null,
              icon: const Icon(Icons.chat_bubble_outline),
              label: Text(enabled ? '开始对话' : 'AI 暂不可用'),
            ),
          ],
        ),
      ),
    );
  }
}

class AiCoachAvailabilityPanel extends StatelessWidget {
  const AiCoachAvailabilityPanel({
    required this.usage,
    required this.loading,
    required this.onRetry,
    super.key,
  });

  final AiUsageSnapshot? usage;
  final bool loading;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final value = usage;
    if (loading && value == null) {
      return const _StatusRow(
        key: ValueKey('aiCoachUsageLoading'),
        icon: Icons.hourglass_top_outlined,
        title: '正在检查 AI 服务',
        detail: '稍后会显示今天的可用额度。',
        showProgress: true,
      );
    }
    if (value == null || value.availability == AiUsageAvailability.unknown) {
      return _StatusRow(
        key: const ValueKey('aiCoachUsageUnknown'),
        icon: Icons.cloud_off_outlined,
        title: '暂时无法确认 AI 使用状态',
        detail: '你仍可查看已有报告；生成前会再次检查。',
        actionLabel: '重新检查',
        onAction: onRetry,
      );
    }
    final resetLabel = _resetLabel(value.resetsAtUtcMilliseconds);
    final unitLabel = value.unit == AiUsageUnit.tokens ? ' Token' : ' 次';
    return switch (value.availability) {
      AiUsageAvailability.available => _StatusRow(
        key: const ValueKey('aiCoachUsageAvailable'),
        icon: Icons.check_circle_outline,
        title: 'AI 可用',
        detail: value.remaining == null
            ? '今天的剩余额度暂时未知。'
            : resetLabel.isEmpty
            ? '今天剩余 ${value.remaining}$unitLabel。'
            : '今天剩余 ${value.remaining}$unitLabel，$resetLabel 恢复。',
      ),
      AiUsageAvailability.disabled => const _StatusRow(
        key: ValueKey('aiCoachUsageDisabled'),
        icon: Icons.pause_circle_outline,
        title: 'AI 服务当前暂不可用',
        detail: '已有报告仍可查看，其他功能不受影响。',
      ),
      AiUsageAvailability.limitReached => _StatusRow(
        key: const ValueKey('aiCoachUsageLimitReached'),
        icon: Icons.schedule_outlined,
        title: '今天的 AI 额度已用完',
        detail: resetLabel.isEmpty
            ? '已有报告仍可查看。'
            : '将在 $resetLabel 恢复；已有报告仍可查看。',
      ),
      AiUsageAvailability.unknown => throw StateError('handled above'),
    };
  }

  String _resetLabel(int? utcMilliseconds) {
    if (utcMilliseconds == null) return '';
    final reset = DateTime.fromMillisecondsSinceEpoch(
      utcMilliseconds,
      isUtc: true,
    ).toLocal();
    final hour = reset.hour.toString().padLeft(2, '0');
    final minute = reset.minute.toString().padLeft(2, '0');
    return '$hour:$minute（本地时间）';
  }
}

class AiCoachTaskCard extends StatelessWidget {
  const AiCoachTaskCard({
    required this.task,
    required this.onPressed,
    super.key,
  });

  final AiCoachTaskCardModel task;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: ValueKey('aiCoachTask-${task.id}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_iconFor(task.iconName)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(task.periodLabel),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(task.message),
            const SizedBox(height: AppSpacing.md),
            FilledButton.tonalIcon(
              key: ValueKey('aiCoachTaskAction-${task.id}'),
              onPressed: task.actionEnabled ? onPressed : null,
              icon: Icon(
                task.opensReport ? Icons.open_in_new : Icons.auto_awesome,
              ),
              label: Text(task.actionLabel),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String value) => switch (value) {
    'daily' => Icons.today_outlined,
    'weekly' => Icons.date_range_outlined,
    _ => Icons.auto_awesome_outlined,
  };
}

class AiCoachRecentReports extends StatelessWidget {
  const AiCoachRecentReports({
    required this.reports,
    required this.onOpenReport,
    required this.onOpenAll,
    super.key,
  });

  final List<AiReportListItemModel> reports;
  final ValueChanged<String> onOpenReport;
  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('aiCoachRecentReports'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '最近报告',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            TextButton(
              key: const ValueKey('openAllAiReportsButton'),
              onPressed: onOpenAll,
              child: const Text('查看全部'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        if (reports.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Text('还没有 AI 报告。生成后会在这里出现。'),
          )
        else
          for (final report in reports.take(3)) ...[
            Card(
              key: ValueKey('aiCoachRecentReport-${report.id}'),
              child: ListTile(
                onTap: () => onOpenReport(report.id),
                title: Text(report.title),
                subtitle: Text(
                  '${report.reportTypeLabel} · ${report.periodLabel}\n${report.statusLabel}',
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
      ],
    );
  }
}

class AiCoachRecentReportsState extends StatelessWidget {
  const AiCoachRecentReportsState({
    required this.loading,
    required this.onRetry,
    super.key,
  });

  final bool loading;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        key: ValueKey('aiCoachReportsLoading'),
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: CircularProgressIndicator(semanticsLabel: '正在读取最近报告'),
        ),
      );
    }
    return Center(
      key: const ValueKey('aiCoachReportsError'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            const Text('最近报告暂时无法读取。'),
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

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    this.showProgress = false,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String detail;
  final bool showProgress;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: '$title，$detail',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showProgress)
              const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(icon),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(detail),
                ],
              ),
            ),
            if (actionLabel != null)
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ),
      ),
    );
  }
}
