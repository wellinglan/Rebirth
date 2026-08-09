import 'package:flutter/material.dart';

class AiConsentGate extends StatelessWidget {
  const AiConsentGate({required this.onOpenSettings, super.key});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey('aiConsentGate'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '使用 AI 教练前，请先选择允许使用的数据',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text('在你授权并最终确认生成前，Rebirth 不会向 AI 发送个人数据。'),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('openAiConsentSettingsButton'),
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings_outlined),
              label: const Text('设置 AI 授权'),
            ),
          ],
        ),
      ),
    );
  }
}
