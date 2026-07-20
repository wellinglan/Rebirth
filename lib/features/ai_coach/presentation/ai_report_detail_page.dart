import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rebirth/core/router/route_names.dart';
import 'package:rebirth/core/theme/app_layout.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_status.dart';

import 'ai_report_history_controller.dart';
import 'ai_pending_recovery_controller.dart';
import 'models/ai_report_presentation_models.dart';
import 'widgets/ai_report_delete_dialog.dart';

class AiReportDetailPage extends ConsumerWidget {
  const AiReportDetailPage({required this.reportId, super.key});

  final String reportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(aiReportDetailProvider(reportId));
    return Scaffold(
      key: const ValueKey('aiReportDetailPage'),
      appBar: AppBar(title: const Text('本地报告详情')),
      body: SafeArea(
        child: detail.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
              key: ValueKey('aiReportDetailLoading'),
            ),
          ),
          error: (error, stackTrace) => const _DetailError(),
          data: (value) => value == null
              ? const _DetailNotFound()
              : _DetailContent(detail: value),
        ),
      ),
    );
  }
}

class _DetailContent extends ConsumerWidget {
  const _DetailContent({required this.detail});

  final AiReportDetailModel detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(aiReportHistoryControllerProvider).asData?.value;
    final deleting = history?.deletingReportIds.contains(detail.id) == true;
    return ListView(
      key: const ValueKey('aiReportDetailContent'),
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
                Text(
                  detail.reportTypeLabel,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DetailLine(label: '状态', value: detail.statusLabel),
                        _DetailLine(
                          label: detail.isDaily ? '目标日期' : '日期范围',
                          value: detail.periodLabel,
                        ),
                        _DetailLine(
                          label: 'Prompt Version',
                          value: detail.promptVersion,
                        ),
                        _DetailLine(
                          label: 'Input Hash',
                          value: detail.shortInputHash,
                        ),
                        _DetailLine(
                          label: '请求时间',
                          value: detail.requestedAtLabel,
                        ),
                        _DetailLine(
                          label: '生成时间',
                          value: detail.generatedAtLabel,
                        ),
                        _DetailLine(
                          label: 'Provider',
                          value: detail.providerLabel,
                        ),
                        _DetailLine(label: 'Model', value: detail.modelLabel),
                        _DetailLine(
                          label: '结构化输出',
                          value: detail.hasStructuredOutput ? '已保存' : '未保存',
                        ),
                        _DetailLine(
                          label: '输入快照',
                          value: detail.hasInputSnapshot ? '已保存' : '未保存',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _StatusContent(
                  detail: detail,
                  recoveryState: history?.pendingRecoveryStates[detail.id],
                  onCheckStatus: () => ref
                      .read(aiReportHistoryControllerProvider.notifier)
                      .checkPending(detail.id),
                ),
                const SizedBox(height: 16),
                if (detail.isDaily) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        key: const ValueKey('openDailySourceTodayButton'),
                        onPressed: () => context.push(
                          RoutePaths.todayHistoryForDate(
                            detail.periodStartDate,
                          ),
                        ),
                        icon: const Icon(Icons.today_outlined),
                        label: Text('打开 Today（${detail.periodStartDate}）'),
                      ),
                      OutlinedButton.icon(
                        key: const ValueKey('openDailySourceJournalButton'),
                        onPressed: () => context.push(
                          RoutePaths.journalForDate(detail.periodStartDate),
                        ),
                        icon: const Icon(Icons.menu_book_outlined),
                        label: Text('打开 Journal（${detail.periodStartDate}）'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'AI 分析是独立的本地报告，不会修改 Today、Journal、Health、Plan 或 Growth 原始记录。',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  key: const ValueKey('deleteAiReportDetailButton'),
                  onPressed: deleting ? null : () => _delete(context, ref),
                  icon: deleting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline),
                  label: Text(deleting ? '删除中...' : '删除本地报告'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAiReportDeleteDialog(context);
    if (!confirmed || !context.mounted) return;
    final deleted = await ref
        .read(aiReportHistoryControllerProvider.notifier)
        .deleteReport(detail.id);
    if (!context.mounted) return;
    if (deleted) {
      context.pop();
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('本地报告删除失败，请重试。')));
  }
}

class _StatusContent extends StatelessWidget {
  const _StatusContent({
    required this.detail,
    required this.recoveryState,
    required this.onCheckStatus,
  });

  final AiReportDetailModel detail;
  final AiPendingRecoveryState? recoveryState;
  final VoidCallback onCheckStatus;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey('aiReportStatusContent'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: switch (detail.status) {
          AiReportStatus.completed => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('报告内容', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              SelectableText(detail.reportContent ?? '报告正文不可用。'),
            ],
          ),
          AiReportStatus.pending => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_pendingMessage(recoveryState)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const ValueKey('checkAiRequestStatusDetailButton'),
                onPressed: recoveryState == AiPendingRecoveryState.checking
                    ? null
                    : onCheckStatus,
                icon: const Icon(Icons.sync),
                label: const Text('检查服务器状态'),
              ),
            ],
          ),
          AiReportStatus.failed => Text(
            '失败原因：${detail.failureMessage ?? '生成未完成'}。这里不会显示底层异常、StackTrace 或 HTTP 内容。',
          ),
        },
      ),
    );
  }

  String _pendingMessage(AiPendingRecoveryState? state) => switch (state) {
    AiPendingRecoveryState.processing => '服务器仍在处理；这不代表请求必然会完成。',
    AiPendingRecoveryState.endpointMismatch => '请切回原服务器和账号检查状态。',
    AiPendingRecoveryState.accountMismatch => '请切回原服务器和账号检查状态。',
    AiPendingRecoveryState.missingBinding => '缺少请求绑定，无法自动确认。',
    AiPendingRecoveryState.serverNotFound => '服务器未找到该请求，不会自动重新生成。',
    _ => '请求结果待确认。状态检查只发送 GET，不会再次调用 Provider。',
  };
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Text('$label：$value'),
    );
  }
}

class _DetailNotFound extends StatelessWidget {
  const _DetailNotFound();

  @override
  Widget build(BuildContext context) {
    return const Center(
      key: ValueKey('aiReportDetailNotFound'),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('找不到这份本地报告，它可能已被删除或路由参数无效。'),
      ),
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError();

  @override
  Widget build(BuildContext context) {
    return const Center(
      key: ValueKey('aiReportDetailError'),
      child: Padding(padding: EdgeInsets.all(24), child: Text('本地报告详情暂时无法读取。')),
    );
  }
}
