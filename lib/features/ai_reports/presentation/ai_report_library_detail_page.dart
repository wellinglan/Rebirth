import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/theme/app_layout.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_status.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_version.dart';

import 'ai_report_library_controller.dart';

class AiReportLibraryDetailPage extends ConsumerWidget {
  const AiReportLibraryDetailPage({required this.reportId, super.key});

  final String reportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(aiReportLibraryDetailProvider(reportId));
    return Scaffold(
      key: const ValueKey('aiReportLibraryDetailPage'),
      appBar: AppBar(title: const Text('报告详情')),
      body: SafeArea(
        child: detail.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
              key: ValueKey('aiReportLibraryDetailLoading'),
            ),
          ),
          error: (_, _) => const Center(child: Text('报告详情暂时无法读取。')),
          data: (value) => value == null
              ? const Center(child: Text('找不到这份本地报告。'))
              : ListView(
                  padding: AppLayout.pagePadding,
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: AppLayout.maxContentWidth,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              value.report.title,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '状态：${_status(value.report.status)}\n'
                              '日期：${value.report.periodStartDate} 至 ${value.report.periodEndDate}\n'
                              '敏感级别：高敏感本地数据',
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '版本历史',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            if (value.versions.isEmpty)
                              const Text(
                                '尚无已完成版本。草稿和生成中状态不会伪造报告正文。',
                                key: ValueKey('aiReportVersionEmpty'),
                              )
                            else
                              for (final version in value.versions) ...[
                                _VersionCard(version: version),
                                const SizedBox(height: 8),
                              ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _VersionCard extends StatelessWidget {
  const _VersionCard({required this.version});

  final AiReportVersion version;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: ValueKey('aiReportVersion-${version.version}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'v${version.version} · ${_status(version.status)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (version.status == AiReportStatus.completed)
              SelectableText(version.content ?? '正文不可用。')
            else
              const Text('该版本生成失败，未保存报告正文。'),
          ],
        ),
      ),
    );
  }
}

String _status(AiReportStatus status) => switch (status) {
  AiReportStatus.pending => '待确认',
  AiReportStatus.draft => '草稿',
  AiReportStatus.generating => '生成中',
  AiReportStatus.completed => '已完成',
  AiReportStatus.failed => '失败',
  AiReportStatus.archived => '已归档',
};
