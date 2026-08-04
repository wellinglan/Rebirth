import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rebirth/core/router/route_names.dart';
import 'package:rebirth/core/theme/app_layout.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_status.dart';

import 'ai_report_library_controller.dart';

class AiReportLibraryPage extends ConsumerWidget {
  const AiReportLibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(aiReportLibraryControllerProvider);
    return Scaffold(
      key: const ValueKey('aiReportLibraryPage'),
      appBar: AppBar(
        title: const Text('AI 报告'),
        actions: [
          IconButton(
            key: const ValueKey('refreshAiReportLibraryButton'),
            tooltip: '刷新本地报告',
            onPressed: reports.isLoading
                ? null
                : () => ref
                      .read(aiReportLibraryControllerProvider.notifier)
                      .reload(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: reports.when(
          skipLoadingOnReload: true,
          loading: () => const Center(
            child: CircularProgressIndicator(
              key: ValueKey('aiReportLibraryLoading'),
            ),
          ),
          error: (_, _) => _LibraryError(
            onRetry: () =>
                ref.read(aiReportLibraryControllerProvider.notifier).reload(),
          ),
          data: (items) => items.isEmpty
              ? const _LibraryEmpty()
              : _ReportList(reports: items),
        ),
      ),
    );
  }
}

class _ReportList extends StatelessWidget {
  const _ReportList({required this.reports});

  final List<AiReport> reports;

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
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                key: ValueKey('aiReportLibraryCard-${report.id}'),
                child: ListTile(
                  title: Text(report.title),
                  subtitle: Text(
                    '${_period(report)}\n${_status(report.status)}'
                    '${report.currentVersion > 0 ? ' · v${report.currentVersion}' : ''}',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      context.push(RoutePaths.aiReportsDetail(report.id)),
                ),
              ),
            ),
          ),
        );
      },
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
        padding: EdgeInsets.all(24),
        child: Text('暂无本地 AI 报告。报告生成不会在此页面自动触发。'),
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
          const SizedBox(height: 12),
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

String _period(AiReport report) =>
    report.periodStartDate == report.periodEndDate
    ? report.periodStartDate
    : '${report.periodStartDate} 至 ${report.periodEndDate}';

String _status(AiReportStatus status) => switch (status) {
  AiReportStatus.pending => '待确认',
  AiReportStatus.draft => '草稿',
  AiReportStatus.generating => '生成中',
  AiReportStatus.completed => '已完成',
  AiReportStatus.failed => '失败',
  AiReportStatus.archived => '已归档',
};
