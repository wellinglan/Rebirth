import 'package:flutter/material.dart';
import 'package:rebirth/core/theme/app_layout.dart';

import 'widgets/ai_data_privacy_card.dart';

class AiConsentSettingsPage extends StatelessWidget {
  const AiConsentSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('aiConsentSettingsPage'),
      appBar: AppBar(title: const Text('AI 数据与隐私')),
      body: SafeArea(
        child: ListView(
          key: const ValueKey('aiConsentSettingsContent'),
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
                      'AI 授权设置',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text('你可以在这里查看、开启或撤销 AI 数据使用授权。授权不会触发自动生成。'),
                    const SizedBox(height: AppLayout.sectionGap),
                    const AiDataPrivacyCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
