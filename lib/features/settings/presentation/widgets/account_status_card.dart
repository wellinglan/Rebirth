import 'package:flutter/material.dart';
import 'package:rebirth/core/theme/app_layout.dart';
import 'package:rebirth/features/account/domain/account_status.dart';
import 'package:rebirth/features/account/presentation/account_view_state.dart';

class AccountStatusCard extends StatelessWidget {
  const AccountStatusCard({
    required this.state,
    required this.apiBaseUrl,
    required this.enableDevLogin,
    required this.onCheckBackend,
    required this.onDevLogin,
    required this.onRegisterDevice,
    required this.onLogout,
    required this.onWeChatLogin,
    required this.onSyncSettings,
    super.key,
  });

  final AccountViewState state;
  final String apiBaseUrl;
  final bool enableDevLogin;
  final VoidCallback onCheckBackend;
  final VoidCallback onDevLogin;
  final VoidCallback onRegisterDevice;
  final VoidCallback onLogout;
  final VoidCallback onWeChatLogin;
  final VoidCallback onSyncSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accountStatus = state.status;
    final isSignedIn = accountStatus.isAuthenticated;
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
                    _modeLabel(accountStatus.mode),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('账号连接不会改变本地优先保存。跨端同步仍未启用。', style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            _StatusRow(label: '当前模式', value: _modeLabel(accountStatus.mode)),
            _StatusRow(label: '登录状态', value: isSignedIn ? '已登录，开发账号' : '未登录'),
            _StatusRow(label: '云账号', value: isSignedIn ? '开发账号已连接' : '尚未连接'),
            _StatusRow(
              label: '后端状态',
              value: !accountStatus.backendConfigured
                  ? '未配置'
                  : accountStatus.backendReachable
                  ? '开发服务已连接'
                  : '未连接',
            ),
            const _StatusRow(label: '跨端同步', value: '尚未启用'),
            _StatusRow(
              label: '设备注册',
              value: accountStatus.deviceRegistered ? '已注册' : '未注册',
            ),
            if (isSignedIn)
              _StatusRow(
                label: '用户',
                value: accountStatus.user?.displayName ?? '开发用户',
              ),
            if (accountStatus.deviceIdShort case final deviceId?)
              _StatusRow(label: '设备 ID', value: deviceId),
            const _StatusRow(label: '数据位置', value: '本地 SQLite'),
            _StatusRow(label: '开发后端', value: apiBaseUrl),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Android 真机请使用电脑局域网 IP，例如 http://192.168.x.x:8000',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (accountStatus.errorMessage case final error?) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                error,
                key: const ValueKey('accountActionError'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('checkBackendButton'),
                  onPressed: state.isBusy ? null : onCheckBackend,
                  icon: const Icon(Icons.monitor_heart_outlined),
                  label: Text(state.isCheckingBackend ? '检查中...' : '检查后端连接'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('devLoginButton'),
                  onPressed: state.isBusy || !enableDevLogin
                      ? null
                      : onDevLogin,
                  icon: const Icon(Icons.terminal_outlined),
                  label: Text(state.isLoggingIn ? '登录中...' : '开发登录'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('registerDeviceButton'),
                  onPressed: state.isBusy ? null : onRegisterDevice,
                  icon: const Icon(Icons.devices_outlined),
                  label: Text(state.isRegisteringDevice ? '注册中...' : '注册当前设备'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('logoutButton'),
                  onPressed: state.isBusy || !isSignedIn ? null : onLogout,
                  icon: const Icon(Icons.logout),
                  label: Text(state.isLoggingOut ? '退出中...' : '退出登录'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('wechatLoginButton'),
                  onPressed: state.isBusy ? null : onWeChatLogin,
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('微信登录'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('syncSettingsButton'),
                  onPressed: state.isBusy ? null : onSyncSettings,
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

  String _modeLabel(AccountMode mode) {
    return switch (mode) {
      AccountMode.localOnly => '本地模式',
      AccountMode.cloudReady => '开发云账号',
      AccountMode.cloud => '云账号',
    };
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
