import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rebirth/core/router/route_names.dart';
import 'package:rebirth/core/theme/app_layout.dart';

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
    final state = ref.watch(settingsControllerProvider);
    return Scaffold(
      key: const ValueKey('settingsPage'),
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: state.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
              key: ValueKey('settingsLoadingState'),
            ),
          ),
          error: (error, stackTrace) => _SettingsError(
            onRetry: () =>
                ref.read(settingsControllerProvider.notifier).reload(),
          ),
          data: (value) => _SettingsContent(
            state: value,
            onConnectAccount: () => _showAccountDialog(context),
            onOpenProfile: () => context.push(RoutePaths.settingsProfile),
          ),
        ),
      ),
    );
  }

  Future<void> _showAccountDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('accountConnectionDialog'),
        title: const Text('账号互联即将支持'),
        content: const Text('当前版本仍是本地优先模式，数据只保存在当前设备。后续版本将支持账号登录、设备绑定与跨端同步。'),
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
    required this.onConnectAccount,
    required this.onOpenProfile,
  });

  final SettingsViewState state;
  final VoidCallback onConnectAccount;
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
                  child: AccountStatusCard(onConnectAccount: onConnectAccount),
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
