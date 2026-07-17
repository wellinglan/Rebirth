import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rebirth/core/router/route_names.dart';
import 'package:rebirth/core/theme/app_layout.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_status.dart';

import '../ai_report_history_controller.dart';
import '../ai_pending_recovery_controller.dart';
import '../models/ai_report_presentation_models.dart';
import 'ai_report_delete_dialog.dart';

class AiReportHistoryTab extends ConsumerWidget {
  const AiReportHistoryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(aiReportHistoryControllerProvider);
    return history.when(
      loading: () => const Center(
        child: CircularProgressIndicator(key: ValueKey('aiHistoryLoading')),
      ),
      error: (error, stackTrace) => _HistoryError(
        onRetry: () =>
            ref.read(aiReportHistoryControllerProvider.notifier).reload(),
      ),
      data: (state) => ListView(
        key: const ValueKey('aiReportHistoryList'),
        padding: AppLayout.pagePadding,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppLayout.wideContentWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '本地报告',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('refreshAiHistoryButton'),
                        tooltip: '刷新本地报告',
                        onPressed: state.isRefreshing
                            ? null
                            : () => ref
                                  .read(
                                    aiReportHistoryControllerProvider.notifier,
                                  )
                                  .reload(),
                        icon: state.isRefreshing
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text('这里仅显示保存在本地 SQLite 中的报告，不会触发网络请求。'),
                  if (state.operationError case final message?) ...[
                    const SizedBox(height: 8),
                    Text(
                      message,
                      key: const ValueKey('aiHistoryOperationError'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (state.reports.isEmpty)
                    const _HistoryEmptyState()
                  else
                    for (final report in state.reports) ...[
                      _ReportCard(
                        report: report,
                        isDeleting: state.deletingReportIds.contains(report.id),
                        recoveryState: state.pendingRecoveryStates[report.id],
                        onOpen: () =>
                            context.push(RoutePaths.aiCoachReport(report.id)),
                        onDelete: () => _delete(context, ref, report.id),
                        onCheckStatus: () => ref
                            .read(aiReportHistoryControllerProvider.notifier)
                            .checkPending(report.id),
                        onConfirmNotFound: () =>
                            _confirmServerNotFound(context, ref, report.id),
                      ),
                      const SizedBox(height: 8),
                    ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    String reportId,
  ) async {
    final confirmed = await showAiReportDeleteDialog(context);
    if (!confirmed || !context.mounted) return;
    final deleted = await ref
        .read(aiReportHistoryControllerProvider.notifier)
        .deleteReport(reportId);
    if (!deleted && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('本地报告删除失败，请重试。')));
    }
  }

  Future<void> _confirmServerNotFound(
    BuildContext context,
    WidgetRef ref,
    String reportId,
  ) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('确认服务器无此请求'),
            content: const Text('这只会将本地待处理报告标记为失败，不会重新生成，也不会删除任何源数据。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                key: const ValueKey('confirmServerNotFoundButton'),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('标记为失败'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) return;
    final updated = await ref
        .read(aiReportHistoryControllerProvider.notifier)
        .confirmServerNotFound(reportId);
    if (!updated && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('本地报告状态更新失败，请重试。')));
    }
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.isDeleting,
    required this.onOpen,
    required this.onDelete,
    required this.onCheckStatus,
    required this.onConfirmNotFound,
    required this.recoveryState,
  });

  final AiReportListItemModel report;
  final bool isDeleting;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final VoidCallback onCheckStatus;
  final VoidCallback onConfirmNotFound;
  final AiPendingRecoveryState? recoveryState;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = switch (report.status) {
      AiReportStatus.completed => colorScheme.secondaryContainer,
      AiReportStatus.pending => colorScheme.surfaceContainerHighest,
      AiReportStatus.failed => colorScheme.errorContainer,
    };
    return Card(
      key: ValueKey('aiReportCard-${report.id}'),
      child: InkWell(
        onTap: isDeleting ? null : onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      report.reportTypeLabel,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Semantics(
                    label: '报告状态：${report.statusLabel}',
                    excludeSemantics: true,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Text(report.statusLabel),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    key: ValueKey('deleteAiReport-${report.id}'),
                    tooltip: '删除本地报告',
                    onPressed: isDeleting ? null : onDelete,
                    icon: isDeleting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline),
                  ),
                ],
              ),
              Text('${report.periodStartDate} 至 ${report.periodEndDate}'),
              const SizedBox(height: 8),
              _HistoryLine(label: '请求时间', value: report.requestedAtLabel),
              _HistoryLine(label: '生成时间', value: report.generatedAtLabel),
              _HistoryLine(label: '生成信息', value: report.providerModelLabel),
              _HistoryLine(label: 'Input Hash', value: report.shortInputHash),
              _HistoryLine(
                label: '输入快照',
                value: report.hasInputSnapshot ? '已保存' : '未保存',
              ),
              if (report.contentPreview case final content?) ...[
                const Divider(height: 20),
                Text(content, maxLines: 3, overflow: TextOverflow.ellipsis),
              ],
              if (report.status == AiReportStatus.pending) ...[
                const Divider(height: 20),
                Text(
                  _pendingMessage(recoveryState),
                  key: ValueKey('aiPendingStatus-${report.id}'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: ValueKey('checkAiRequestStatus-${report.id}'),
                  onPressed: recoveryState == AiPendingRecoveryState.checking
                      ? null
                      : onCheckStatus,
                  icon: recoveryState == AiPendingRecoveryState.checking
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                  label: Text(
                    recoveryState == AiPendingRecoveryState.checking
                        ? '检查中...'
                        : '检查服务器状态',
                  ),
                ),
                if (recoveryState == AiPendingRecoveryState.serverNotFound)
                  TextButton.icon(
                    key: ValueKey('markServerNotFoundFailed-${report.id}'),
                    onPressed: onConfirmNotFound,
                    icon: const Icon(Icons.report_outlined),
                    label: const Text('将本地记录标记为失败'),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _pendingMessage(AiPendingRecoveryState? state) => switch (state) {
    AiPendingRecoveryState.processing => '服务器仍在处理；这不代表请求必然会完成。',
    AiPendingRecoveryState.networkUnknown => '网络中断，结果待确认。不会自动重新生成。',
    AiPendingRecoveryState.endpointMismatch => '请切回原服务器后再检查状态。',
    AiPendingRecoveryState.accountMismatch => '请切回原账号后再检查状态。',
    AiPendingRecoveryState.missingBinding => '缺少请求绑定，无法自动确认服务器状态。',
    AiPendingRecoveryState.serverNotFound => '原服务器未找到该请求；不会自动重试生成。',
    AiPendingRecoveryState.checking => '正在向原服务器查询状态...',
    _ => '请求结果待确认，可安全查询服务器状态。',
  };
}

class _HistoryLine extends StatelessWidget {
  const _HistoryLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text('$label：$value'),
    );
  }
}

class _HistoryEmptyState extends StatelessWidget {
  const _HistoryEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Card(
      key: ValueKey('aiHistoryEmptyState'),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Text('还没有本地 AIReport。当前版本不会自动生成或插入示例报告。'),
      ),
    );
  }
}

class _HistoryError extends StatelessWidget {
  const _HistoryError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('aiHistoryError'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('本地报告暂时无法读取。'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey('retryAiHistoryButton'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
