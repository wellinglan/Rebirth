import 'package:flutter/material.dart';
import 'package:rebirth/features/ai_coach/domain/ai_coach_input_bundle.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_scope.dart';
import 'package:rebirth/features/ai_coach/domain/ai_generation_gateway.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_type.dart';

Future<bool> showAiGenerationConfirmationDialog(
  BuildContext context, {
  required AiCoachInputBundle bundle,
  required AiGenerationCapabilities capabilities,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AiGenerationConfirmationDialog(
      bundle: bundle,
      capabilities: capabilities,
    ),
  );
  return confirmed ?? false;
}

class AiGenerationConfirmationDialog extends StatelessWidget {
  const AiGenerationConfirmationDialog({
    required this.bundle,
    required this.capabilities,
    super.key,
  });

  final AiCoachInputBundle bundle;
  final AiGenerationCapabilities capabilities;

  @override
  Widget build(BuildContext context) {
    final isDaily = bundle.reportType == AiReportType.dailyInsight;
    final reportLabel = isDaily ? '每日洞察' : '每周回顾';
    final journalIncluded = bundle.selection.scopes.contains(
      AiDataScope.journalReflections,
    );
    final scopes =
        bundle.selection.scopes.map(_scopeLabel).toList(growable: false)
          ..sort();
    return AlertDialog(
      key: const ValueKey('aiGenerationConfirmationDialog'),
      title: const Text('确认发送并生成'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          key: const ValueKey('aiGenerationConfirmationScrollView'),
          child: Semantics(
            key: const ValueKey('aiGenerationConfirmationSemantics'),
            label: 'AI $reportLabel最终发送确认',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _line('报告类型', reportLabel),
                _line(
                  isDaily ? '目标日期' : '日期范围',
                  isDaily
                      ? bundle.periodStartDate
                      : '${bundle.periodStartDate} 至 ${bundle.periodEndDate}',
                ),
                _line('AI 服务', capabilities.providerLabel),
                _line('模型', capabilities.model ?? '未配置'),
                _line('数据范围', scopes.join('、')),
                _line('Journal', journalIncluded ? '包含' : '不包含'),
                _line('来源记录', '${bundle.sources.length} 条'),
                const SizedBox(height: 12),
                const Text('确认后，所选数据会通过 Rebirth 服务发送给上述 AI 服务完成本次分析。'),
                const SizedBox(height: 6),
                const Text('记录标识不会发送给 AI；生成结果不会修改任何原始记录。'),
                const SizedBox(height: 6),
                Text(
                  '为恢复中断的请求，服务端最多临时保留结果 ${capabilities.resultRetentionHours} 小时；结果可能包含对所选数据的总结。',
                ),
                const SizedBox(height: 6),
                const Text('AI 输出可能不准确，本次操作可能产生服务费用；系统不会在失败后自动重新生成。'),
                if (journalIncluded) ...[
                  const SizedBox(height: 10),
                  Text(
                    isDaily
                        ? '将发送该日期已保存的五项结构化 Journal 回答。'
                        : '将发送最近 7 天已选择的结构化 Journal 文本。',
                    key: const ValueKey('aiJournalFinalWarning'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('cancelAiGenerationButton'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const ValueKey('confirmAiGenerationButton'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('确认并生成$reportLabel'),
        ),
      ],
    );
  }

  Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text('$label：$value'),
  );

  String _scopeLabel(AiDataScope scope) => switch (scope) {
    AiDataScope.growthSummary => '成长趋势汇总',
    AiDataScope.todayMetrics => '每日状态指标',
    AiDataScope.healthMetrics => '健康指标',
    AiDataScope.journalReflections => '复盘内容',
    AiDataScope.activeGoals => '当前目标',
  };
}
