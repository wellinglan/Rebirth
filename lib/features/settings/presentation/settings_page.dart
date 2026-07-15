import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rebirth/core/config/app_config_provider.dart';
import 'package:rebirth/core/router/route_names.dart';
import 'package:rebirth/core/theme/app_layout.dart';
import 'package:rebirth/features/account/presentation/account_controller.dart';
import 'package:rebirth/features/account/presentation/account_view_state.dart';
import 'package:rebirth/features/sync/presentation/profile_sync_controller.dart';
import 'package:rebirth/features/sync/presentation/profile_sync_error_message.dart';
import 'package:rebirth/features/sync/presentation/profile_sync_view_state.dart';

import 'settings_controller.dart';
import 'settings_view_state.dart';
import 'widgets/account_status_card.dart';
import 'widgets/device_status_card.dart';
import 'widgets/settings_section.dart';
import 'widgets/settings_tile.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsState = ref.watch(settingsControllerProvider);
    final accountState = ref.watch(accountControllerProvider);
    final profileSyncState = ref.watch(profileSyncControllerProvider);
    final config = ref.watch(appConfigProvider);
    return Scaffold(
      key: const ValueKey('settingsPage'),
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: settingsState.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
              key: ValueKey('settingsLoadingState'),
            ),
          ),
          error: (error, stackTrace) =>
              _SettingsError(onRetry: () => _reload(ref)),
          data: (value) => accountState.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                key: ValueKey('settingsLoadingState'),
              ),
            ),
            error: (error, stackTrace) =>
                _SettingsError(onRetry: () => _reload(ref)),
            data: (account) => _SettingsContent(
              state: value,
              account: account,
              apiBaseUrl: config.apiBaseUrl,
              enableDevLogin: config.enableDevLogin,
              onCheckBackend: () => _checkBackend(context, ref),
              onDevLogin: () => _devLogin(context, ref),
              onRegisterDevice: () => _registerDevice(context, ref),
              onLogout: () => _logout(context, ref),
              profileSyncState: profileSyncState,
              onPushProfile: () => _pushProfile(context, ref),
              onPullProfile: () => _pullProfile(context, ref),
              onWeChatLogin: () => _showUnavailableDialog(
                context,
                key: 'wechatLoginDialog',
                title: '微信登录尚未启用',
                message: '微信登录需要微信开放平台配置和 Rebirth 后端支持，本版本尚未启用。',
              ),
              onSyncSettings: () => _showUnavailableDialog(
                context,
                key: 'syncSettingsDialog',
                title: '同步范围',
                message:
                    '当前仅支持 Profile 手动同步。Today、Journal、Plan 和 Health '
                    '暂未同步；同步失败不会删除本地数据。',
              ),
              onOpenProfile: () => context.push(RoutePaths.settingsProfile),
            ),
          ),
        ),
      ),
    );
  }

  void _reload(WidgetRef ref) {
    ref.read(settingsControllerProvider.notifier).reload();
    ref.read(accountControllerProvider.notifier).reload();
  }

  Future<void> _checkBackend(BuildContext context, WidgetRef ref) async {
    final success = await ref
        .read(accountControllerProvider.notifier)
        .checkBackendHealth();
    if (!context.mounted) return;
    _showMessage(context, success ? '开发后端已连接' : '无法连接开发后端');
  }

  Future<void> _devLogin(BuildContext context, WidgetRef ref) async {
    final key = await _showDevLoginDialog(context);
    if (key == null || !context.mounted) return;
    final success = await ref
        .read(accountControllerProvider.notifier)
        .devLogin(key);
    if (!context.mounted) return;
    final error = ref
        .read(accountControllerProvider)
        .value
        ?.status
        .errorMessage;
    _showMessage(context, success ? '开发登录成功' : error ?? '开发登录失败');
  }

  Future<void> _registerDevice(BuildContext context, WidgetRef ref) async {
    final success = await ref
        .read(accountControllerProvider.notifier)
        .registerCurrentDevice();
    if (!context.mounted) return;
    final error = ref
        .read(accountControllerProvider)
        .value
        ?.status
        .errorMessage;
    _showMessage(context, success ? '当前设备已注册' : error ?? '设备注册失败');
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final success = await ref.read(accountControllerProvider.notifier).logout();
    if (!context.mounted) return;
    _showMessage(context, success ? '已退出开发账号，本地数据保持不变' : '退出登录失败');
  }

  Future<void> _pushProfile(BuildContext context, WidgetRef ref) async {
    try {
      final result = await ref
          .read(profileSyncControllerProvider.notifier)
          .pushProfile();
      if (!context.mounted) return;
      _showMessage(context, result.message);
    } catch (error) {
      if (!context.mounted) return;
      _showMessage(context, profileSyncErrorMessage(error));
    }
  }

  Future<void> _pullProfile(BuildContext context, WidgetRef ref) async {
    try {
      final result = await ref
          .read(profileSyncControllerProvider.notifier)
          .pullProfile();
      if (!context.mounted) return;
      _showMessage(context, result.message);
    } catch (error) {
      if (!context.mounted) return;
      _showMessage(context, profileSyncErrorMessage(error));
    }
  }

  Future<String?> _showDevLoginDialog(BuildContext context) async {
    var devUserKey = 'local-test-user';
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('devLoginDialog'),
        title: const Text('开发登录'),
        content: TextFormField(
          key: const ValueKey('devUserKeyField'),
          initialValue: devUserKey,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'dev_user_key'),
          textInputAction: TextInputAction.done,
          onChanged: (value) => devUserKey = value,
          onFieldSubmitted: (value) => _submitDevLogin(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const ValueKey('confirmDevLoginButton'),
            onPressed: () => _submitDevLogin(context, devUserKey),
            child: const Text('登录'),
          ),
        ],
      ),
    );
  }

  void _submitDevLogin(BuildContext context, String value) {
    final key = value.trim();
    if (key.isEmpty) return;
    Navigator.of(context).pop(key);
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showUnavailableDialog(
    BuildContext context, {
    required String key,
    required String title,
    required String message,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: ValueKey(key),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}

class _SettingsContent extends StatelessWidget {
  const _SettingsContent({
    required this.state,
    required this.account,
    required this.apiBaseUrl,
    required this.enableDevLogin,
    required this.onCheckBackend,
    required this.onDevLogin,
    required this.onRegisterDevice,
    required this.onLogout,
    required this.profileSyncState,
    required this.onPushProfile,
    required this.onPullProfile,
    required this.onWeChatLogin,
    required this.onSyncSettings,
    required this.onOpenProfile,
  });

  final SettingsViewState state;
  final AccountViewState account;
  final String apiBaseUrl;
  final bool enableDevLogin;
  final VoidCallback onCheckBackend;
  final VoidCallback onDevLogin;
  final VoidCallback onRegisterDevice;
  final VoidCallback onLogout;
  final ProfileSyncViewState profileSyncState;
  final VoidCallback onPushProfile;
  final VoidCallback onPullProfile;
  final VoidCallback onWeChatLogin;
  final VoidCallback onSyncSettings;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final displayName = state.profile.displayName?.trim();
    return ListView(
      key: const ValueKey('settingsDataState'),
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
                  '管理账号、资料与本地数据',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppLayout.sectionGap),
                SettingsSection(
                  title: '账号与同步',
                  child: AccountStatusCard(
                    state: account,
                    apiBaseUrl: apiBaseUrl,
                    enableDevLogin: enableDevLogin,
                    onCheckBackend: onCheckBackend,
                    onDevLogin: onDevLogin,
                    onRegisterDevice: onRegisterDevice,
                    onLogout: onLogout,
                    profileSyncState: profileSyncState,
                    onPushProfile: onPushProfile,
                    onPullProfile: onPullProfile,
                    onWeChatLogin: onWeChatLogin,
                    onSyncSettings: onSyncSettings,
                  ),
                ),
                const SizedBox(height: AppLayout.sectionGap),
                SettingsSection(
                  title: '个人资料',
                  child: SettingsTile(
                    key: const ValueKey('profileSettingsTile'),
                    title: displayName == null || displayName.isEmpty
                        ? '未设置昵称'
                        : displayName,
                    subtitle: '本地资料',
                    icon: Icons.badge_outlined,
                    onTap: onOpenProfile,
                  ),
                ),
                const SizedBox(height: AppLayout.sectionGap),
                SettingsSection(
                  title: '本地数据与设备',
                  child: state.deviceStatus == null
                      ? const SettingsTile(
                          title: '无法读取设备信息',
                          subtitle: '请稍后重试',
                          icon: Icons.device_unknown_outlined,
                        )
                      : DeviceStatusCard(status: state.deviceStatus!),
                ),
                const SizedBox(height: AppLayout.sectionGap),
                const SettingsSection(
                  title: '关于 Rebirth',
                  child: SettingsTile(
                    title: 'Rebirth · alpha',
                    subtitle:
                        '版本 1.0.0+1\nAn AI-powered Personal Operating System for Growth',
                    icon: Icons.info_outline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsError extends StatelessWidget {
  const _SettingsError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('settingsErrorState'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('设置暂时无法加载'),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            key: const ValueKey('retrySettingsButton'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
