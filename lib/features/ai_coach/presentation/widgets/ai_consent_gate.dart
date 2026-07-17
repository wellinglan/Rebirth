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
            Text('AI 数据使用尚未启用', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('当前不会准备任何 AI 输入。你可以先在 Settings 的“AI 数据与隐私”中查看边界并明确授权。'),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('openAiConsentSettingsButton'),
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings_outlined),
              label: const Text('前往授权设置'),
            ),
          ],
        ),
      ),
    );
  }
}
