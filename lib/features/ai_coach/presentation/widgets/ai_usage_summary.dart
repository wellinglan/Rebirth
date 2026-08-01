import 'package:flutter/material.dart';
import 'package:rebirth/features/ai_coach/domain/ai_usage_snapshot.dart';

class AiUsageSummary extends StatelessWidget {
  const AiUsageSummary({required this.loading, required this.usage, super.key});

  final bool loading;
  final AiUsageSnapshot? usage;

  @override
  Widget build(BuildContext context) {
    final value = usage;
    if (loading && value == null) {
      return const Row(
        key: ValueKey('aiUsageLoading'),
        children: [
          SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10),
          Expanded(child: Text('正在读取今日 AI 额度...')),
        ],
      );
    }
    if (value == null || value.availability == AiUsageAvailability.unknown) {
      return const Text(
        '今日 AI 额度暂时无法读取；生成时服务器仍会执行额度校验。',
        key: ValueKey('aiUsageUnknown'),
      );
    }
    final reset = DateTime.fromMillisecondsSinceEpoch(
      value.resetsAtUtcMilliseconds!,
      isUtc: true,
    ).toLocal();
    final localTime =
        '${reset.hour.toString().padLeft(2, '0')}:'
        '${reset.minute.toString().padLeft(2, '0')}';
    final status = switch (value.availability) {
      AiUsageAvailability.available => '可用',
      AiUsageAvailability.disabled => '已关闭',
      AiUsageAvailability.limitReached => '额度暂不可用',
      AiUsageAvailability.unknown => '未知',
    };
    return Semantics(
      label:
          'AI 使用状态$status，今日已使用${value.used}次，'
          '剩余${value.remaining}次，共${value.dailyLimit}次，'
          '本地时间$localTime重置',
      child: Column(
        key: const ValueKey('aiUsageSummary'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AI 使用状态：$status'),
          const SizedBox(height: 4),
          Text(
            '今日已使用 ${value.used} / ${value.dailyLimit} 次，'
            '剩余 ${value.remaining} 次',
          ),
          const SizedBox(height: 4),
          Text('$localTime（本地时间）重置'),
        ],
      ),
    );
  }
}
