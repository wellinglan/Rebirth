import 'package:flutter/material.dart';
import 'package:rebirth/core/theme/app_layout.dart';
import 'package:rebirth/features/account/domain/account_status.dart';
import 'package:rebirth/features/account/domain/sync_status.dart';

class AccountStatusCard extends StatelessWidget {
  const AccountStatusCard({
    required this.accountStatus,
    required this.syncStatus,
    required this.onDevLogin,
    required this.onWeChatLogin,
    required this.onSyncSettings,
    super.key,
  });

  final AccountStatus accountStatus;
  final AccountSyncStatus syncStatus;
  final VoidCallback onDevLogin;
  final VoidCallback onWeChatLogin;
  final VoidCallback onSyncSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLocalOnly = accountStatus.mode == AccountMode.localOnly;
    final isSignedOut =
        accountStatus.authentication == AuthenticationStatus.signedOut;
    final syncUnavailable =
        syncStatus.availability == AccountSyncAvailability.disabled;
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
                  child: Text(
                    isLocalOnly ? '本地模式' : '云账号模式',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('云账号能力正在准备中。当前数据仍只保存在本设备。', style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            _StatusRow(label: '当前模式', value: isLocalOnly ? '本地模式' : '云账号模式'),
            _StatusRow(label: '登录状态', value: isSignedOut ? '未登录' : '已登录'),
            _StatusRow(
              label: '云账号',
              value: accountStatus.isAuthenticated ? '已连接' : '尚未连接',
            ),
            _StatusRow(label: '跨端同步', value: syncUnavailable ? '尚未启用' : '可以配置'),
            _StatusRow(
              label: '后端状态',
              value: accountStatus.backendConfigured ? '已配置' : '未配置',
            ),
            const _StatusRow(label: '数据位置', value: '本地 SQLite'),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('devLoginButton'),
                  onPressed: onDevLogin,
                  icon: const Icon(Icons.terminal_outlined),
                  label: const Text('开发登录'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('wechatLoginButton'),
                  onPressed: onWeChatLogin,
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('微信登录'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('syncSettingsButton'),
                  onPressed: onSyncSettings,
                  icon: const Icon(Icons.sync_outlined),
                  label: const Text('同步设置'),
                ),
              ],
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
