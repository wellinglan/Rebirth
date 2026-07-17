import 'package:flutter/material.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report.dart';

import '../ai_coach_formatters.dart';

class AiReusableReportCard extends StatelessWidget {
  const AiReusableReportCard({
    required this.report,
    required this.onOpenReport,
    super.key,
  });

  final AiReport? report;
  final ValueChanged<String> onOpenReport;

  @override
  Widget build(BuildContext context) {
    final existing = report;
    if (existing == null) {
      return const Card(
        key: ValueKey('aiNoReusableReportCard'),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('当前没有相同输入的已完成报告。'),
        ),
      );
    }
    return Card(
      key: const ValueKey('aiReusableReportCard'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '本地已有相同输入生成的报告',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text('生成时间：${AiCoachFormatters.timestamp(existing.generatedAt)}'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const ValueKey('openReusableReportButton'),
              onPressed: () => onOpenReport(existing.id),
              icon: const Icon(Icons.open_in_new),
              label: const Text('查看报告'),
            ),
          ],
        ),
      ),
    );
  }
}
