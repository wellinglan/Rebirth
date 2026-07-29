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
import 'package:rebirth/features/journal/presentation/journal_prompt_controller.dart';
import 'package:rebirth/features/sync/presentation/sync_center_controller.dart';

import 'settings_controller.dart';
import 'settings_view_state.dart';
import 'widgets/settings_section.dart';
import 'widgets/settings_tile.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final account = ref.watch(accountControllerProvider);
    final auth = ref.watch(appAuthStateProvider);
    final syncCenter = ref.watch(syncCenterControllerProvider);
    final promptConfiguration = ref.watch(journalPromptControllerProvider);
    final config = ref.watch(appConfigProvider);
    return Scaffold(
      key: const ValueKey('settingsPage'),
      appBar: AppBar(title: const Text('设置')),
      body: SafeArea(
        child: settings.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
              key: ValueKey('settingsLoadingState'),
            ),
          ),
          error: (_, _) => _SettingsError(onRetry: () => _reload(ref)),
          data: (settingsValue) => account.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                key: ValueKey('settingsLoadingState'),
              ),
            ),
            error: (_, _) => _SettingsError(onRetry: () => _reload(ref)),
            data: (accountValue) => _SettingsContent(
              settings: settingsValue,
              account: accountValue.status,
              auth: auth.value,
              syncStatus: syncCenter.value?.overallStatusLabel ?? '正在读取',
              conflictCount: syncCenter.value?.totalConflictCount ?? 0,
              enabledPromptCount: promptConfiguration.value?.activePromptCount,
              enableDeveloperOptions: config.enableDevLogin,
              appVersionLabel: config.appVersionLabel,
            ),
          ),
        ),
      ),
    );
  }

  void _reload(WidgetRef ref) {
    ref.read(settingsControllerProvider.notifier).reload();
    ref.read(accountControllerProvider.notifier).reload();
    ref.read(syncCenterControllerProvider.notifier).refresh();
  }
}

class _SettingsContent extends StatelessWidget {
  const _SettingsContent({
    required this.settings,
    required this.account,
    required this.auth,
    required this.syncStatus,
    required this.conflictCount,
    required this.enabledPromptCount,
    required this.enableDeveloperOptions,
    required this.appVersionLabel,
  });

  final SettingsViewState settings;
  final AccountStatus account;
  final AppAuthState? auth;
  final String syncStatus;
  final int conflictCount;
  final int? enabledPromptCount;
  final bool enableDeveloperOptions;
  final String appVersionLabel;

  @override
  Widget build(BuildContext context) {
    final displayName = settings.profile.displayName?.trim();
    return ListView(
      key: const ValueKey('settingsDataState'),
      padding: AppLayout.pagePadding,
      children: [
        SettingsSection(
          title: '账号',
          child: SettingsTile(
            key: const ValueKey('accountSettingsTile'),
            title: displayName?.isNotEmpty == true
                ? displayName!
                : 'Rebirth 用户',
            subtitle:
                '${_accountSummary(account, auth)} · '
                '${account.deviceRegistered ? '设备已准备' : '设备待准备'}',
            icon: Icons.account_circle_outlined,
            onTap: () => context.push(RoutePaths.settingsAccount),
          ),
        ),
        const SizedBox(height: AppLayout.sectionGap),
        SettingsSection(
          title: '数据与同步',
          child: SettingsTile(
            key: const ValueKey('syncCenterSettingsTile'),
            title: '同步中心',
            subtitle: conflictCount == 0
                ? '$syncStatus · 无待处理问题'
                : '$syncStatus · $conflictCount 项待处理问题',
            icon: Icons.sync_outlined,
            onTap: () => context.push(RoutePaths.syncCenter),
          ),
        ),
        const SizedBox(height: AppLayout.sectionGap),
        SettingsSection(
          title: '个人数据与隐私',
          child: Column(
            children: [
              SettingsTile(
                key: const ValueKey('profileSettingsTile'),
                title: '个人资料',
                subtitle: '昵称、成长方向与本地时区',
                icon: Icons.person_outline,
                onTap: () => context.push(RoutePaths.settingsProfile),
              ),
              SettingsTile(
                key: const ValueKey('personalDataSettingsTile'),
                title: '个人数据概览',
                subtitle: '查看本地数据覆盖情况，不会上传内容',
                icon: Icons.inventory_2_outlined,
                onTap: () => context.push(RoutePaths.personalDataOverview),
              ),
              SettingsTile(
                key: const ValueKey('aiCoachSettingsTile'),
                title: 'AI 数据与隐私',
                subtitle: '当前不进行真实 AI 分析，也不会自动发送数据',
                icon: Icons.shield_outlined,
                onTap: () => context.push(RoutePaths.aiCoach),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppLayout.sectionGap),
        SettingsSection(
          title: 'Journal',
          child: SettingsTile(
            key: const ValueKey('journalPromptSettingsTile'),
            title: '管理反思问题',
            subtitle: enabledPromptCount == null
                ? '正在读取问题配置'
                : '当前启用 $enabledPromptCount 个问题',
            icon: Icons.quiz_outlined,
            onTap: () => context.push(RoutePaths.journalPrompts),
          ),
        ),
        if (enableDeveloperOptions) ...[
          const SizedBox(height: AppLayout.sectionGap),
          SettingsSection(
            title: '高级设置',
            child: SettingsTile(
              key: const ValueKey('developerOptionsSettingsTile'),
              title: '开发者选项',
              subtitle: '开发云账号、服务器与同步诊断',
              icon: Icons.developer_mode_outlined,
              onTap: () => context.push(RoutePaths.settingsDeveloperOptions),
            ),
          ),
        ],
        const SizedBox(height: AppLayout.sectionGap),
        SettingsSection(
          title: '关于 Rebirth',
          child: SettingsTile(
            key: const ValueKey('aboutRebirthSettingsTile'),
            title: 'Rebirth Alpha',
            subtitle: '版本 $appVersionLabel · 帮助你持续成为更好的自己',
            icon: Icons.info_outline,
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

String _accountSummary(AccountStatus account, AppAuthState? auth) {
  return switch (auth?.status) {
    AppAuthStatus.authenticated => '云端已连接',
    AppAuthStatus.authenticatedOffline => '离线可用',
    AppAuthStatus.bindingRequired => '需要确认本地数据归属',
    AppAuthStatus.sessionRejected => '会话已失效',
    _ when account.mode == AccountMode.localOnly => '本地模式',
    _ => '当前未登录',
  };
}
