import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rebirth/core/config/app_config_provider.dart';
import 'package:rebirth/core/router/route_names.dart';
import 'package:rebirth/core/theme/app_layout.dart';
import 'package:rebirth/features/account/domain/account_status.dart';
import 'package:rebirth/features/account/domain/app_auth_state.dart';
import 'package:rebirth/features/account/presentation/account_controller.dart';
import 'package:rebirth/features/account/presentation/app_auth_controller.dart';

import 'settings_controller.dart';

class AccountDetailsPage extends ConsumerWidget {
  const AccountDetailsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final account = ref.watch(accountControllerProvider);
    final auth = ref.watch(appAuthStateProvider);
    final config = ref.watch(appConfigProvider);
    final enableDevLogin = config.enableDevLogin;
    return Scaffold(
      key: const ValueKey('accountDetailsPage'),
      appBar: AppBar(title: const Text('账号')),
      body: SafeArea(
        child: settings.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _LoadError(
            onRetry: () =>
                ref.read(settingsControllerProvider.notifier).reload(),
          ),
          data: (settingsValue) => account.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => _LoadError(
              onRetry: () =>
                  ref.read(accountControllerProvider.notifier).reload(),
            ),
            data: (accountValue) {
              final authValue = auth.value;
              return ListView(
                padding: AppLayout.pagePadding,
                children: [
                  Text(
                    settingsValue.profile.displayName?.trim().isNotEmpty == true
                        ? settingsValue.profile.displayName!
                        : 'Rebirth 用户',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _accountEnvironmentDescription(authValue, config.isAlpha),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Card(
                    child: Column(
                      children: [
                        _AccountRow(
                          icon: Icons.account_circle_outlined,
                          title: '账号模式',
                          value: _accountModeLabel(accountValue.status.mode),
                        ),
                        _AccountRow(
                          icon: Icons.login_outlined,
                          title: '登录方式',
                          value: _loginMethodLabel(authValue),
                        ),
                        _AccountRow(
                          icon: Icons.verified_user_outlined,
                          title: '会话状态',
                          value: _authStatusLabel(authValue),
                        ),
                        _AccountRow(
                          icon: Icons.cloud_outlined,
                          title: '云端连接',
                          value: authValue?.isOffline == true
                              ? '离线可用'
                              : accountValue.status.backendReachable
                              ? '已连接'
                              : '当前未连接',
                        ),
                        _AccountRow(
                          icon: Icons.devices_outlined,
                          title: '当前设备',
                          value: accountValue.status.deviceRegistered
                              ? '已具备同步准备'
                              : '尚未完成同步准备',
                        ),
                        _AccountRow(
                          icon: Icons.verified_user_outlined,
                          title: '同步资格',
                          value: authValue?.canUseCloudSync == true
                              ? '可手动同步'
                              : '暂不可同步',
                        ),
                      ],
                    ),
                  ),
                  if (accountValue.status.isAuthenticated &&
                      !accountValue.status.deviceRegistered) ...[
                    const SizedBox(height: AppSpacing.md),
                    FilledButton.icon(
                      key: const ValueKey('prepareCurrentDeviceButton'),
                      onPressed: accountValue.isBusy
                          ? null
                          : () => _prepareDevice(context, ref),
                      icon: const Icon(Icons.phonelink_setup_outlined),
                      label: Text(
                        accountValue.isRegisteringDevice ? '准备中...' : '准备当前设备',
                      ),
                    ),
                  ],
                  if (enableDevLogin) ...[
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton.icon(
                      key: const ValueKey('openDeveloperOptionsFromAccount'),
                      onPressed: () =>
                          context.push(RoutePaths.settingsDeveloperOptions),
                      icon: const Icon(Icons.developer_mode_outlined),
                      label: const Text('前往开发者选项'),
                    ),
                  ],
                  if (accountValue.status.isAuthenticated) ...[
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton.icon(
                      key: const ValueKey('accountLogoutButton'),
                      onPressed: accountValue.isBusy
                          ? null
                          : () => _logout(context, ref),
                      icon: const Icon(Icons.logout),
                      label: Text(
                        accountValue.isLoggingOut ? '退出中...' : '退出登录',
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '退出登录只会锁定当前账号的数据空间，不会删除保存在本机的数据。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _prepareDevice(BuildContext context, WidgetRef ref) async {
    final success = await ref
        .read(accountControllerProvider.notifier)
        .registerCurrentDevice();
    if (!context.mounted) return;
    _message(context, success ? '当前设备已准备完成' : '当前设备暂时无法完成同步准备');
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    await ref.read(appAuthControllerProvider.notifier).logout();
    if (context.mounted) _message(context, '已退出登录，本地数据保持不变');
  }

  void _message(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 180),
        child: Text(
          value,
          textAlign: TextAlign.end,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: OutlinedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('重新加载'),
      ),
    );
  }
}

String _accountModeLabel(AccountMode mode) => switch (mode) {
  AccountMode.localOnly => '本地模式',
  AccountMode.cloudReady => '云端准备中',
  AccountMode.cloud => '云端已连接',
};

String _authStatusLabel(AppAuthState? state) => switch (state?.status) {
  AppAuthStatus.authenticated => '已登录',
  AppAuthStatus.authenticatedOffline => '已登录，当前离线',
  AppAuthStatus.bindingRequired => '需要确认本地数据归属',
  AppAuthStatus.sessionRejected => '会话已失效',
  AppAuthStatus.signedOut => '未登录',
  _ => '正在确认',
};

String _loginMethodLabel(AppAuthState? state) =>
    switch (state?.identityProvider) {
      'password_username' => '用户名密码登录',
      'dev' => '开发账号',
      _ => '正在确认',
    };

String _accountEnvironmentDescription(AppAuthState? state, bool isAlpha) {
  final displayName = state?.displayName?.trim();
  final prefix = displayName?.isNotEmpty == true
      ? '当前登录：$displayName'
      : '当前账号已安全连接';
  return isAlpha ? '$prefix · Alpha 环境' : prefix;
}
