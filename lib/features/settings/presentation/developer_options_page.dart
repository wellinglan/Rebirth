import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/config/app_config_provider.dart';
import 'package:rebirth/core/config/server_endpoint_provider.dart';
import 'package:rebirth/core/theme/app_layout.dart';
import 'package:rebirth/features/account/domain/legacy_ownership_verification.dart';
import 'package:rebirth/features/account/presentation/account_controller.dart';
import 'package:rebirth/features/account/presentation/app_auth_controller.dart';
import 'package:rebirth/features/account/presentation/legacy_ownership_verification_controller.dart';
import 'package:rebirth/features/sync/data/sync_conflict_providers.dart';

import 'server_endpoint_settings_controller.dart';
import 'widgets/server_endpoint_card.dart';
import 'widgets/server_endpoint_dialog.dart';
import 'widgets/settings_section.dart';
import 'widgets/password_identity_attach_dialog.dart';

class DeveloperOptionsPage extends ConsumerWidget {
  const DeveloperOptionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    if (!config.enableDevLogin) {
      return const Scaffold(
        key: ValueKey('developerOptionsUnavailable'),
        body: SafeArea(child: Center(child: Text('当前构建未启用开发者选项'))),
      );
    }
    final account = ref.watch(accountControllerProvider);
    final endpoint = ref.watch(effectiveServerEndpointProvider);
    final endpointState = ref.watch(serverEndpointSettingsControllerProvider);
    final verification = ref.watch(
      legacyOwnershipVerificationControllerProvider,
    );
    return Scaffold(
      key: const ValueKey('developerOptionsPage'),
      appBar: AppBar(title: const Text('开发者选项')),
      body: SafeArea(
        child: account.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: OutlinedButton.icon(
              onPressed: () =>
                  ref.read(accountControllerProvider.notifier).reload(),
              icon: const Icon(Icons.refresh),
              label: const Text('重新加载'),
            ),
          ),
          data: (value) => ListView(
            padding: AppLayout.pagePadding,
            children: [
              const Text('这些选项仅用于 Alpha 调试。打开本页不会自动检查网络、登录、注册设备或同步。'),
              const SizedBox(height: AppLayout.sectionGap),
              SettingsSection(
                title: '开发云账号',
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        FilledButton.icon(
                          key: const ValueKey('devLoginButton'),
                          onPressed: value.isBusy
                              ? null
                              : () => _devLogin(context, ref),
                          icon: const Icon(Icons.login),
                          label: Text(
                            value.isLoggingIn ? '登录中...' : '使用 User Key 登录',
                          ),
                        ),
                        OutlinedButton.icon(
                          key: const ValueKey('checkBackendButton'),
                          onPressed: value.isBusy
                              ? null
                              : () => _checkBackend(context, ref),
                          icon: const Icon(Icons.monitor_heart_outlined),
                          label: Text(
                            value.isCheckingBackend ? '检查中...' : '检查后端连接',
                          ),
                        ),
                        if (value.status.isAuthenticated)
                          OutlinedButton.icon(
                            key: const ValueKey('attachPasswordIdentityButton'),
                            onPressed: value.isBusy
                                ? null
                                : () => _attachPasswordIdentity(context, ref),
                            icon: const Icon(Icons.link),
                            label: Text(
                              value.isAttachingPassword ? '绑定中...' : '绑定用户名和密码',
                            ),
                          ),
                        if (value.status.isAuthenticated)
                          OutlinedButton.icon(
                            key: const ValueKey('developerLogoutButton'),
                            onPressed: value.isBusy
                                ? null
                                : () => _logout(context, ref),
                            icon: const Icon(Icons.logout),
                            label: const Text('退出开发账号'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppLayout.sectionGap),
              SettingsSection(
                title: '开发服务器',
                child: ServerEndpointCard(
                  endpoint: endpoint,
                  backendReachable: value.status.backendReachable,
                  health: endpointState.health,
                  onEdit: () => _editEndpoint(context, ref),
                  onRestoreDefault: () => _restoreEndpoint(context, ref),
                ),
              ),
              const SizedBox(height: AppLayout.sectionGap),
              SettingsSection(
                title: '同步诊断',
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          value.status.deviceRegistered
                              ? '当前设备已完成同步准备'
                              : '当前设备尚未完成同步准备',
                        ),
                        if (value.status.deviceIdShort case final shortId?) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text('短设备标识：$shortId'),
                        ],
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            OutlinedButton.icon(
                              key: const ValueKey('registerDeviceButton'),
                              onPressed: value.isBusy
                                  ? null
                                  : () => _registerDevice(context, ref),
                              icon: const Icon(Icons.phonelink_setup_outlined),
                              label: const Text('准备当前设备'),
                            ),
                            OutlinedButton.icon(
                              key: const ValueKey('verifyOwnershipButton'),
                              onPressed: verification.isLoading
                                  ? null
                                  : () => _verifyOwnership(context, ref),
                              icon: const Icon(Icons.verified_user_outlined),
                              label: Text(
                                verification.isLoading ? '验证中...' : '验证云同步资格',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppLayout.sectionGap),
              Text(
                '配置来源：${endpoint.sourceLabel} · Alpha 技术环境',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _devLogin(BuildContext context, WidgetRef ref) async {
    final key = await _showDevLoginDialog(context);
    if (key == null || !context.mounted) return;
    final success = await ref
        .read(appAuthControllerProvider.notifier)
        .devLogin(key);
    _refreshConflictScope(ref);
    if (context.mounted) {
      _message(context, success ? '开发登录成功' : '开发登录失败');
    }
  }

  Future<void> _checkBackend(BuildContext context, WidgetRef ref) async {
    final success = await ref
        .read(accountControllerProvider.notifier)
        .checkBackendHealth();
    if (context.mounted) {
      _message(context, success ? '开发后端已连接' : '无法连接开发后端');
    }
  }

  Future<void> _attachPasswordIdentity(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final input = await showDialog<PasswordIdentityAttachInput>(
      context: context,
      builder: (_) => const PasswordIdentityAttachDialog(),
    );
    if (input == null || !context.mounted) return;
    final success = await ref
        .read(accountControllerProvider.notifier)
        .attachPasswordIdentity(
          devUserKey: input.devUserKey,
          username: input.username,
          password: input.password,
          displayName: input.displayName,
        );
    if (context.mounted) {
      _message(context, success ? '用户名和密码已绑定到当前账号' : '绑定失败，请检查输入后重试');
    }
  }

  Future<void> _registerDevice(BuildContext context, WidgetRef ref) async {
    final success = await ref
        .read(accountControllerProvider.notifier)
        .registerCurrentDevice();
    _refreshConflictScope(ref);
    if (context.mounted) {
      _message(context, success ? '当前设备已准备完成' : '设备准备失败');
    }
  }

  Future<void> _verifyOwnership(BuildContext context, WidgetRef ref) async {
    try {
      final result = await ref
          .read(legacyOwnershipVerificationControllerProvider.notifier)
          .verify();
      if (!context.mounted) return;
      final message = switch (result.outcome) {
        LegacyOwnershipVerificationOutcome.verified => '云同步资格验证成功',
        LegacyOwnershipVerificationOutcome.unknown => '暂时无法确认旧数据归属',
        LegacyOwnershipVerificationOutcome.rejected => '旧数据归属验证失败',
      };
      _message(context, message);
    } catch (_) {
      if (context.mounted) _message(context, '云同步资格验证失败');
    }
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    await ref.read(appAuthControllerProvider.notifier).logout();
    _refreshConflictScope(ref);
    if (context.mounted) _message(context, '已退出登录，本地数据保持不变');
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
      if (context.mounted) {
        _message(
          context,
          changed && signedIn ? '服务器已切换，请重新登录；本地数据保持不变' : '服务器地址已保存',
        );
      }
    } catch (_) {
      if (context.mounted) _message(context, '服务器地址保存失败，旧设置保持不变');
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
    if (context.mounted) {
      _message(context, '已恢复 ${fallback.sourceLabel}');
    }
  }

  Future<bool> _confirmEndpointChange(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            key: const ValueKey('confirmServerEndpointChangeDialog'),
            title: const Text('切换服务器并退出登录？'),
            content: const Text(
              '切换后需要在新服务器重新登录。Profile、Today、Journal、Plan、'
              'Health 和本地数据库都会保留。',
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

  Future<String?> _showDevLoginDialog(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('devLoginDialog'),
        title: const Text('开发云账号登录'),
        content: TextField(
          key: const ValueKey('devUserKeyField'),
          controller: controller,
          autofocus: true,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Development User Key'),
          onSubmitted: (value) =>
              Navigator.of(context).pop(value.trim().isEmpty ? null : value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const ValueKey('confirmDevLoginButton'),
            onPressed: () {
              final value = controller.text.trim();
              Navigator.of(context).pop(value.isEmpty ? null : value);
            },
            child: const Text('登录'),
          ),
        ],
      ),
    ).whenComplete(() => controller.dispose());
  }

  void _refreshConflictScope(WidgetRef ref) {
    ref.invalidate(syncConflictScopeProvider);
    ref.invalidate(activeSyncConflictCountProvider);
    ref.invalidate(activeSyncConflictListProvider);
  }

  void _message(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
