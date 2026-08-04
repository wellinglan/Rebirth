import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rebirth/core/router/route_names.dart';
import 'package:rebirth/core/theme/app_layout.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_status.dart';
import 'package:rebirth/features/ai_coach/presentation/ai_report_history_controller.dart';
import 'package:rebirth/features/ai_coach/presentation/models/ai_report_presentation_models.dart';
import 'package:rebirth/features/ai_reports/presentation/ai_report_export_controller.dart';
import 'package:rebirth/features/ai_reports/presentation/widgets/ai_report_export_dialog.dart';
import 'package:rebirth/features/sync/domain/sync_module.dart';

enum AiReportLibraryFilter {
  all('全部'),
  completed('已完成'),
  archived('已归档'),
  failed('失败');

  const AiReportLibraryFilter(this.label);

  final String label;

  bool includes(AiReportStatus status) => switch (this) {
    AiReportLibraryFilter.all => true,
    AiReportLibraryFilter.completed => status == AiReportStatus.completed,
    AiReportLibraryFilter.archived => status == AiReportStatus.archived,
    AiReportLibraryFilter.failed => status == AiReportStatus.failed,
  };
}

class AiReportLibraryPage extends ConsumerStatefulWidget {
  const AiReportLibraryPage({super.key});

  @override
  ConsumerState<AiReportLibraryPage> createState() =>
      _AiReportLibraryPageState();
}

class _AiReportLibraryPageState extends ConsumerState<AiReportLibraryPage> {
  AiReportLibraryFilter _filter = AiReportLibraryFilter.all;
  final FocusNode _exportAllFocusNode = FocusNode(
    debugLabel: 'exportAllAiReports',
  );

  @override
  void dispose() {
    _exportAllFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(aiReportHistoryControllerProvider);
    final export = ref.watch(aiReportExportControllerProvider);
    final refreshing = history.asData?.value.isRefreshing == true;
    return Scaffold(
      key: const ValueKey('aiReportLibraryPage'),
      appBar: AppBar(
        title: const Text('AI 报告库'),
        actions: [
          IconButton(
            key: const ValueKey('openAiReportSyncCenterButton'),
            tooltip: '同步中心',
            onPressed: () => context.push(RoutePaths.syncCenter),
            icon: const Icon(Icons.sync_outlined),
          ),
          IconButton(
            key: const ValueKey('openAiReportConflictCenterButton'),
            tooltip: 'AI 报告冲突',
            onPressed: () => context.push(
              RoutePaths.syncConflictsForModule(SyncModuleId.aiReport.stableId),
            ),
            icon: const Icon(Icons.warning_amber_outlined),
          ),
          IconButton(
            key: const ValueKey('refreshAiReportLibraryButton'),
            tooltip: '刷新本地报告',
            onPressed: history.isLoading || refreshing
                ? null
                : () => ref
                      .read(aiReportHistoryControllerProvider.notifier)
                      .reload(),
            icon: refreshing
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: history.when(
          skipLoadingOnReload: true,
          loading: () => const Center(
            child: CircularProgressIndicator(
              key: ValueKey('aiReportLibraryLoading'),
            ),
          ),
          error: (_, _) => _LibraryError(
            onRetry: () =>
                ref.read(aiReportHistoryControllerProvider.notifier).reload(),
          ),
          data: (state) {
            final visible = state.reports
                .where((report) => _filter.includes(report.status))
                .toList(growable: false);
            return Column(
              children: [
                _FilterBar(
                  filter: _filter,
                  onChanged: (value) => setState(() => _filter = value),
                ),
                _ExportAllAction(
                  enabled: state.reports.isNotEmpty && !export.isExporting,
                  exporting:
                      export.isExporting &&
                      export.target == AiReportExportTarget.allReports,
                  focusNode: _exportAllFocusNode,
                  onPressed: () => _exportAll(context),
                ),
                if (state.operationError case final message?)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: Text(
                      message,
                      key: const ValueKey('aiReportLibraryOperationError'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                Expanded(
                  child: state.reports.isEmpty
                      ? const _LibraryEmpty()
                      : visible.isEmpty
                      ? _FilteredEmpty(
                          onShowAll: () => setState(
                            () => _filter = AiReportLibraryFilter.all,
                          ),
                        )
                      : _ReportList(reports: visible),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _exportAll(BuildContext context) async {
    final confirmed = await showAiReportExportDialog(context, exportAll: true);
    if (!confirmed || !context.mounted) return;
    final result = await ref
        .read(aiReportExportControllerProvider.notifier)
        .exportAllReports();
    if (!context.mounted) return;
    _showExportResult(context, result);
  }
}

class _ExportAllAction extends StatelessWidget {
  const _ExportAllAction({
    required this.enabled,
    required this.exporting,
    required this.focusNode,
    required this.onPressed,
  });

  final bool enabled;
  final bool exporting;
  final FocusNode focusNode;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.maxContentWidth,
          ),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const ValueKey('exportAllAiReportsButton'),
              focusNode: focusNode,
              onPressed: enabled ? onPressed : null,
              icon: exporting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined),
              label: Text(exporting ? '导出中...' : '导出全部报告'),
            ),
          ),
        ),
      ),
    );
  }
}

void _showExportResult(BuildContext context, AiReportExportViewState result) {
  final message = switch (result.phase) {
    AiReportExportPhase.saved => 'AI 报告导出已保存',
    AiReportExportPhase.cancelled => '已取消导出，报告内容和状态均未改变',
    AiReportExportPhase.failed => result.message ?? '导出失败，请重试。',
    AiReportExportPhase.idle || AiReportExportPhase.exporting => null,
  };
  if (message == null) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.filter, required this.onChanged});

  final AiReportLibraryFilter filter;
  final ValueChanged<AiReportLibraryFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.maxContentWidth,
          ),
          child: DropdownButtonFormField<AiReportLibraryFilter>(
            key: const ValueKey('aiReportLibraryFilter'),
            initialValue: filter,
            decoration: const InputDecoration(
              labelText: '筛选报告状态',
              prefixIcon: Icon(Icons.filter_list),
            ),
            items: [
              for (final value in AiReportLibraryFilter.values)
                DropdownMenuItem(value: value, child: Text(value.label)),
            ],
            onChanged: (value) {
              if (value != null) onChanged(value);
            },
          ),
        ),
      ),
    );
  }
}

class _ReportList extends StatelessWidget {
  const _ReportList({required this.reports});

  final List<AiReportListItemModel> reports;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: const ValueKey('aiReportLibraryList'),
      padding: AppLayout.pagePadding,
      itemCount: reports.length,
      itemBuilder: (context, index) {
        final report = reports[index];
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.maxContentWidth,
            ),
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Card(
                key: ValueKey('aiReportLibraryCard-${report.id}'),
                child: InkWell(
                  onTap: () =>
                      context.push(RoutePaths.aiReportsDetail(report.id)),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          report.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '${report.reportTypeLabel} · ${report.periodLabel}',
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: [
                            _StatusLabel(
                              icon: _statusIcon(report.status),
                              label: report.statusLabel,
                            ),
                            _StatusLabel(
                              icon: _syncIcon(report.syncStatus),
                              label: _syncLabel(report.syncStatus),
                            ),
                            if (report.currentVersion > 0)
                              _StatusLabel(
                                icon: Icons.history,
                                label: '${report.currentVersion} 个版本',
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text('创建：${report.createdAtLabel}'),
                        Text('更新：${report.updatedAtLabel}'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 18), const SizedBox(width: 4), Text(label)],
      ),
    );
  }
}

class _LibraryEmpty extends StatelessWidget {
  const _LibraryEmpty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      key: ValueKey('aiReportLibraryEmpty'),
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Text('暂无本地 AI 报告。报告生成不会在此页面自动触发。'),
      ),
    );
  }
}

class _FilteredEmpty extends StatelessWidget {
  const _FilteredEmpty({required this.onShowAll});

  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('aiReportLibraryFilteredEmpty'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('当前筛选条件下没有报告。'),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(onPressed: onShowAll, child: const Text('查看全部')),
        ],
      ),
    );
  }
}

class _LibraryError extends StatelessWidget {
  const _LibraryError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('aiReportLibraryError'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('本地报告暂时无法读取'),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }
}

IconData _statusIcon(AiReportStatus status) => switch (status) {
  AiReportStatus.completed => Icons.check_circle_outline,
  AiReportStatus.archived => Icons.archive_outlined,
  AiReportStatus.failed => Icons.error_outline,
  AiReportStatus.pending ||
  AiReportStatus.draft ||
  AiReportStatus.generating => Icons.schedule_outlined,
};

String _syncLabel(String status) => switch (status) {
  'synced' => '已同步',
  'conflict' => '存在冲突',
  _ => '等待同步',
};

IconData _syncIcon(String status) => switch (status) {
  'synced' => Icons.cloud_done_outlined,
  'conflict' => Icons.cloud_off_outlined,
  _ => Icons.cloud_upload_outlined,
};
