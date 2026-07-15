import 'package:flutter/material.dart';
import 'package:rebirth/core/theme/app_layout.dart';

class AccountStatusCard extends StatelessWidget {
  const AccountStatusCard({required this.onConnectAccount, super.key});

  final VoidCallback onConnectAccount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const ValueKey('accountStatusCard'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.person_outline, color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text('本地模式', style: theme.textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '当前数据仅保存在本设备。后续版本将支持账号登录、设备绑定与跨端同步。',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            const _StatusRow(label: '登录状态', value: '未登录'),
            const _StatusRow(label: '同步状态', value: '跨端同步暂未启用'),
            const _StatusRow(label: '数据位置', value: '本地 SQLite'),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: const ValueKey('accountConnectionButton'),
                onPressed: onConnectAccount,
                icon: const Icon(Icons.devices_outlined),
                label: const Text('账号互联'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 88, child: Text(label)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
