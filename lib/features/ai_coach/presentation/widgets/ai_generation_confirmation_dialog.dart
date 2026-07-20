import 'package:flutter/material.dart';
import 'package:rebirth/features/ai_coach/domain/ai_coach_input_bundle.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_scope.dart';
import 'package:rebirth/features/ai_coach/domain/ai_generation_gateway.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_type.dart';

import '../ai_coach_formatters.dart';

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
                _line('Provider', capabilities.providerLabel),
                _line('Model', capabilities.model ?? '未配置'),
                _line('数据范围', scopes.join('、')),
                _line('输入 Hash', AiCoachFormatters.shortHash(bundle.inputHash)),
                _line('Journal', journalIncluded ? '包含' : '不包含'),
                _line('来源记录', '${bundle.sources.length} 条'),
                const SizedBox(height: 12),
                const Text('数据将发送到 Rebirth Server，再由服务器向 AI Provider 转发最小化字段。'),
                const SizedBox(height: 6),
                const Text('Source record IDs 不会转发给模型；AI 输出不会修改任何原始记录。'),
                const SizedBox(height: 6),
                const Text('请求明确设置 store=false，但这不代表绝对零保留。'),
                const SizedBox(height: 6),
                Text(
                  '服务器会临时保留已验证的生成结果 ${capabilities.resultRetentionHours} 小时，用于恢复丢失响应；结果可能包含对敏感数据的总结。',
                ),
                const SizedBox(height: 6),
                Text(
                  '最小请求 Tombstone 会保留 ${capabilities.dedupeRetentionDays} 天用于防止相同 request_id 重复调用。服务器不保存输入 Payload、Sources 或 Canonical JSON。',
                ),
                const SizedBox(height: 6),
                const Text(
                  '这不是 exactly-once 保证；极端崩溃窗口下结果可能变为 outcome unknown，无法确定是否已经产生结果或费用。',
                ),
                const SizedBox(height: 6),
                const Text('AI 输出可能不准确，本次操作可能产生 Provider 费用，当前不会自动重试。'),
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
    AiDataScope.growthSummary => 'Growth 汇总',
    AiDataScope.todayMetrics => 'Today 指标',
    AiDataScope.healthMetrics => 'Health 指标',
    AiDataScope.journalReflections => 'Journal 回顾',
    AiDataScope.activeGoals => 'Goals',
  };
}
