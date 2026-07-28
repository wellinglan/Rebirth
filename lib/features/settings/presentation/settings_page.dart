import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rebirth/core/config/app_config_provider.dart';
import 'package:rebirth/core/config/server_endpoint.dart';
import 'package:rebirth/core/config/server_endpoint_provider.dart';
import 'package:rebirth/core/router/route_names.dart';
import 'package:rebirth/core/theme/app_layout.dart';
import 'package:rebirth/features/account/presentation/account_controller.dart';
import 'package:rebirth/features/account/presentation/account_view_state.dart';
import 'package:rebirth/features/account/presentation/app_auth_controller.dart';
import 'package:rebirth/features/account/presentation/legacy_ownership_verification_controller.dart';
import 'package:rebirth/features/account/domain/account_boundary.dart';
import 'package:rebirth/features/account/domain/legacy_ownership_verification.dart';
import 'package:rebirth/features/profile/data/profile_sync_repository_provider.dart';
import 'package:rebirth/features/sync/presentation/profile_sync_controller.dart';
import 'package:rebirth/features/sync/presentation/profile_sync_error_message.dart';
import 'package:rebirth/features/sync/presentation/profile_sync_view_state.dart';
import 'package:rebirth/features/sync/presentation/plan_sync_controller.dart';
import 'package:rebirth/features/sync/presentation/plan_sync_view_state.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/data/sync_conflict_providers.dart';

import 'settings_controller.dart';
import 'settings_view_state.dart';
import 'server_endpoint_settings_controller.dart';
import 'widgets/account_status_card.dart';
import 'widgets/ai_data_privacy_card.dart';
import 'widgets/device_status_card.dart';
import 'widgets/settings_section.dart';
import 'widgets/settings_tile.dart';
import 'widgets/server_endpoint_card.dart';
import 'widgets/server_endpoint_dialog.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsState = ref.watch(settingsControllerProvider);
    final accountState = ref.watch(accountControllerProvider);
    final authState = ref.watch(appAuthStateProvider).value;
    final ownershipVerificationState = ref.watch(
      legacyOwnershipVerificationControllerProvider,
    );
    final profileSyncState = ref.watch(profileSyncControllerProvider);
    final profileHasConflict =
        ref.watch(profileSyncConflictProvider).value ?? false;
    final planSyncState = ref.watch(planSyncControllerProvider);
    final activeConflictCount =
        ref.watch(activeSyncConflictCountProvider).value ?? 0;
    final config = ref.watch(appConfigProvider);
    final endpoint = ref.watch(effectiveServerEndpointProvider);
    final endpointSettings = ref.watch(
      serverEndpointSettingsControllerProvider,
    );
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
              syncEligibility:
                  authState?.syncEligibility ?? AccountSyncEligibility.ready,
              verificationStatus:
                  authState?.verificationStatus ??
                  AccountOwnershipVerificationStatus.verified,
              verificationInProgress: ownershipVerificationState.isLoading,
              onVerifyOwnership: () => _verifyOwnership(context, ref),
              apiBaseUrl: endpoint.baseUrl,
              endpoint: endpoint,
              endpointHealth: endpointSettings.health,
              onEditEndpoint: () => _editEndpoint(context, ref),
              onRestoreEndpoint: () => _restoreEndpoint(context, ref),
              enableDevLogin: config.enableDevLogin,
              onCheckBackend: () => _checkBackend(context, ref),
              onDevLogin: () => _devLogin(context, ref),
              onRegisterDevice: () => _registerDevice(context, ref),
              onLogout: () => _logout(context, ref),
              profileSyncState: profileSyncState,
              profileHasConflict: profileHasConflict,
              onPushProfile: () => _pushProfile(context, ref),
              onPullProfile: () => _pullProfile(context, ref),
              planSyncState: planSyncState,
              activeConflictCount: activeConflictCount,
              onSyncPlan: () => _syncPlan(context, ref),
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
                    'Profile 与 Plan 已支持手动同步。Today、Journal 和 Health '
                    '尚未同步；当前没有后台自动同步。',
              ),
              onOpenProfile: () => context.push(RoutePaths.settingsProfile),
              onOpenSyncConflicts:
                  account.status.isAuthenticated &&
                      authState?.canUseCloudSync == true
                  ? () => context.push(RoutePaths.syncConflicts)
                  : null,
              onOpenAiCoach: () => context.push(RoutePaths.aiCoach),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editEndpoint(BuildContext context, WidgetRef ref) async {
    final current = ref.read(effectiveServerEndpointProvider);
    final candidate = await showDialog<String>(
      context: context,
      builder: (context) => ServerEndpointDialog(initialValue: current.baseUrl),
    );
    if (candidate == null || !context.mounted) return;
    final normalized = ref
        .read(serverEndpointValidatorProvider)
        .normalize(candidate);
    final changed = normalized != current.baseUrl;
    final signedIn =
        ref.read(accountControllerProvider).value?.status.isAuthenticated ==
        true;
    if (changed && signedIn) {
      final confirmed = await _confirmEndpointChange(context);
      if (!confirmed || !context.mounted) return;
    }
    try {
      await ref
          .read(serverEndpointSettingsControllerProvider.notifier)
          .save(candidate);
      if (changed && signedIn) {
        await ref.read(appAuthControllerProvider.notifier).logout();
      } else {
        await ref.read(accountControllerProvider.notifier).reload();
      }
      _refreshConflictScope(ref);
      if (!context.mounted) return;
      _showMessage(
        context,
        changed && signedIn ? '服务器已切换，请在新服务器重新登录；本地数据保持不变' : '服务器地址已保存',
      );
    } catch (_) {
      if (context.mounted) _showMessage(context, '服务器地址保存失败，旧设置保持不变');
    }
  }

  Future<void> _restoreEndpoint(BuildContext context, WidgetRef ref) async {
    final current = ref.read(effectiveServerEndpointProvider);
    final fallback = ref.read(fallbackServerEndpointProvider);
    final changed = current.baseUrl != fallback.baseUrl;
    final signedIn =
        ref.read(accountControllerProvider).value?.status.isAuthenticated ==
        true;
    if (changed && signedIn) {
      final confirmed = await _confirmEndpointChange(context);
      if (!confirmed || !context.mounted) return;
    }
    await ref
        .read(serverEndpointSettingsControllerProvider.notifier)
        .restoreDefault();
    if (changed && signedIn) {
      await ref.read(appAuthControllerProvider.notifier).logout();
    } else {
      await ref.read(accountControllerProvider.notifier).reload();
    }
    _refreshConflictScope(ref);
    if (!context.mounted) return;
    _showMessage(context, '已恢复 ${fallback.sourceLabel}：${fallback.baseUrl}');
  }

  Future<bool> _confirmEndpointChange(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            key: const ValueKey('confirmServerEndpointChangeDialog'),
            title: const Text('切换服务器并退出登录？'),
            content: const Text(
              '当前 token 和设备注册只属于旧服务器。切换后将退出登录，但不会删除 '
              'Profile、Today、Journal、Plan、Health 或本地数据库。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                key: const ValueKey('confirmServerEndpointChangeButton'),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('切换并退出'),
              ),
            ],
          ),
        ) ??
        false;
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
        .read(appAuthControllerProvider.notifier)
        .devLogin(key);
    _refreshConflictScope(ref);
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
    _refreshConflictScope(ref);
    if (!context.mounted) return;
    final error = ref
        .read(accountControllerProvider)
        .value
        ?.status
        .errorMessage;
    _showMessage(context, success ? '当前设备已注册' : error ?? '设备注册失败');
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    await ref.read(appAuthControllerProvider.notifier).logout();
    _refreshConflictScope(ref);
    if (!context.mounted) return;
    _showMessage(context, '已退出开发账号，本地数据保持不变');
  }

  Future<void> _pushProfile(BuildContext context, WidgetRef ref) async {
    final hasConflict = ref.read(profileSyncConflictProvider).value ?? false;
    if (hasConflict) {
      final confirmed = await _confirmProfileConflictResolution(
        context,
        useCloud: false,
      );
      if (!confirmed || !context.mounted) return;
    }
    try {
      final controller = ref.read(profileSyncControllerProvider.notifier);
      final result = await (hasConflict
          ? controller.resolveConflictKeepingLocal()
          : controller.pushProfile());
      if (!context.mounted) return;
      _showMessage(context, result.message);
    } catch (error) {
      if (!context.mounted) return;
      _showMessage(context, profileSyncErrorMessage(error));
    }
  }

  Future<void> _pullProfile(BuildContext context, WidgetRef ref) async {
    final hasConflict = ref.read(profileSyncConflictProvider).value ?? false;
    if (hasConflict) {
      final confirmed = await _confirmProfileConflictResolution(
        context,
        useCloud: true,
      );
      if (!confirmed || !context.mounted) return;
    }
    try {
      final controller = ref.read(profileSyncControllerProvider.notifier);
      final result = await (hasConflict
          ? controller.resolveConflictUsingCloud()
          : controller.pullProfile());
      if (!context.mounted) return;
      _showMessage(context, result.message);
    } catch (error) {
      if (!context.mounted) return;
      _showMessage(context, profileSyncErrorMessage(error));
    }
  }

  Future<bool> _confirmProfileConflictResolution(
    BuildContext context, {
    required bool useCloud,
  }) async {
    final title = useCloud ? '采用云端 Profile？' : '保留本地 Profile？';
    final message = useCloud
        ? '云端 Profile 将覆盖本地昵称、成长方向和时区。本操作不会自动合并内容。'
        : '本地 Profile 将覆盖云端昵称、成长方向和时区。本操作不会自动合并内容。';
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            key: const ValueKey('profileConflictResolutionDialog'),
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                key: const ValueKey('confirmProfileConflictResolutionButton'),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(useCloud ? '采用云端' : '保留本地'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _syncPlan(BuildContext context, WidgetRef ref) async {
    try {
      final result = await ref
          .read(planSyncControllerProvider.notifier)
          .syncPlan();
      if (!context.mounted) return;
      final entity = result.resultFor(SyncEntityType.plan);
      _showMessage(
        context,
        entity?.message ?? result.failure?.message ?? 'Plan 同步完成',
      );
    } catch (_) {
      if (context.mounted) {
        _showMessage(context, 'Plan 同步失败，本地数据未受影响');
      }
    }
  }

  Future<void> _verifyOwnership(BuildContext context, WidgetRef ref) async {
    try {
      final result = await ref
          .read(legacyOwnershipVerificationControllerProvider.notifier)
          .verify();
      if (!context.mounted) return;
      final message = switch (result.outcome) {
        LegacyOwnershipVerificationOutcome.verified =>
          '云同步资格验证通过；同步不会自动执行，请按需手动同步',
        LegacyOwnershipVerificationOutcome.unknown => '无法确认旧同步数据归属，同步继续保持关闭',
        LegacyOwnershipVerificationOutcome.rejected => '旧同步数据归属验证失败，同步继续保持关闭',
      };
      _showMessage(context, message);
    } catch (_) {
      if (context.mounted) {
        _showMessage(context, '同步资格验证请求失败，本地数据未变化，可稍后重试');
      }
    }
  }

  void _refreshConflictScope(WidgetRef ref) {
    ref.invalidate(profileSyncConflictProvider);
    ref.invalidate(syncConflictScopeProvider);
    ref.invalidate(activeSyncConflictCountProvider);
    ref.invalidate(activeSyncConflictListProvider);
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
    required this.syncEligibility,
    required this.verificationStatus,
    required this.verificationInProgress,
    required this.apiBaseUrl,
    required this.endpoint,
    required this.endpointHealth,
    required this.onEditEndpoint,
    required this.onRestoreEndpoint,
    required this.enableDevLogin,
    required this.onCheckBackend,
    required this.onDevLogin,
    required this.onRegisterDevice,
    required this.onLogout,
    required this.profileSyncState,
    required this.profileHasConflict,
    required this.onPushProfile,
    required this.onPullProfile,
    required this.planSyncState,
    required this.activeConflictCount,
    required this.onSyncPlan,
    required this.onVerifyOwnership,
    required this.onWeChatLogin,
    required this.onSyncSettings,
    required this.onOpenProfile,
    required this.onOpenSyncConflicts,
    required this.onOpenAiCoach,
  });

  final SettingsViewState state;
  final AccountViewState account;
  final AccountSyncEligibility syncEligibility;
  final AccountOwnershipVerificationStatus verificationStatus;
  final bool verificationInProgress;
  final String apiBaseUrl;
  final ServerEndpoint endpoint;
  final ServerEndpointHealth? endpointHealth;
  final VoidCallback onEditEndpoint;
  final VoidCallback onRestoreEndpoint;
  final bool enableDevLogin;
  final VoidCallback onCheckBackend;
  final VoidCallback onDevLogin;
  final VoidCallback onRegisterDevice;
  final VoidCallback onLogout;
  final ProfileSyncViewState profileSyncState;
  final bool profileHasConflict;
  final VoidCallback onPushProfile;
  final VoidCallback onPullProfile;
  final PlanSyncViewState planSyncState;
  final int activeConflictCount;
  final VoidCallback onSyncPlan;
  final VoidCallback onVerifyOwnership;
  final VoidCallback onWeChatLogin;
  final VoidCallback onSyncSettings;
  final VoidCallback onOpenProfile;
  final VoidCallback? onOpenSyncConflicts;
  final VoidCallback onOpenAiCoach;

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
                  title: '同步冲突',
                  child: SettingsTile(
                    key: const ValueKey('syncConflictsSettingsTile'),
                    title: '同步冲突',
                    subtitle: activeConflictCount == 0
                        ? '无待处理冲突'
                        : '待处理 $activeConflictCount 项',
                    icon: Icons.alt_route_outlined,
                    onTap: onOpenSyncConflicts,
                  ),
                ),
                const SizedBox(height: AppLayout.sectionGap),
                SettingsSection(
                  title: '账号与同步',
                  child: AccountStatusCard(
                    state: account,
                    apiBaseUrl: apiBaseUrl,
                    syncEligibility: syncEligibility,
                    verificationStatus: verificationStatus,
                    verificationInProgress: verificationInProgress,
                    enableDevLogin: enableDevLogin,
                    onCheckBackend: onCheckBackend,
                    onDevLogin: onDevLogin,
                    onRegisterDevice: onRegisterDevice,
                    onLogout: onLogout,
                    profileSyncState: profileSyncState,
                    profileHasConflict: profileHasConflict,
                    onPushProfile: onPushProfile,
                    onPullProfile: onPullProfile,
                    planSyncState: planSyncState,
                    onSyncPlan: onSyncPlan,
                    onVerifyOwnership: onVerifyOwnership,
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
                  title: 'AI 数据与隐私',
                  child: AiDataPrivacyCard(),
                ),
                const SizedBox(height: AppLayout.sectionGap),
                SettingsSection(
                  title: '开发服务器',
                  child: ServerEndpointCard(
                    endpoint: endpoint,
                    backendReachable: account.status.backendReachable,
                    health: endpointHealth,
                    onEdit: onEditEndpoint,
                    onRestoreDefault: onRestoreEndpoint,
                  ),
                ),
                const SizedBox(height: AppLayout.sectionGap),
                SettingsSection(
                  title: 'AI Coach',
                  child: SettingsTile(
                    key: const ValueKey('aiCoachSettingsTile'),
                    title: 'AI Coach',
                    subtitle: '预览 AI 将使用的数据，并查看本地报告',
                    icon: Icons.psychology_outlined,
                    onTap: onOpenAiCoach,
                  ),
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
