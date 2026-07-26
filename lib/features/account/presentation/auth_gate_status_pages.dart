import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/theme/app_layout.dart';

import 'app_auth_controller.dart';

class AuthStartupPage extends StatelessWidget {
  const AuthStartupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      key: ValueKey('authStartupPage'),
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class AccountBindingRequiredPage extends ConsumerWidget {
  const AccountBindingRequiredPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(appAuthStateProvider).value;
    return _AuthStatusScaffold(
      pageKey: const ValueKey('accountBindingRequiredPage'),
      icon: Icons.inventory_2_outlined,
      title: '需要确认本地数据归属',
      message:
          '检测到 ${auth?.unboundProfileCount ?? 0} 个未绑定的本地数据空间。'
          '为避免把旧账号数据交给当前账号，本版本不会自动绑定或同步。',
      actions: [
        FilledButton.icon(
          key: const ValueKey('bindingRequiredLogoutButton'),
          onPressed: () =>
              ref.read(appAuthControllerProvider.notifier).logout(),
          icon: const Icon(Icons.logout),
          label: const Text('退出登录'),
        ),
      ],
    );
  }
}

class SessionRejectedPage extends ConsumerWidget {
  const SessionRejectedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message =
        ref.watch(appAuthStateProvider).value?.message ?? '当前会话无法继续使用。';
    return _AuthStatusScaffold(
      pageKey: const ValueKey('sessionRejectedPage'),
      icon: Icons.lock_reset_outlined,
      title: '需要重新登录',
      message: message,
      actions: [
        FilledButton.icon(
          key: const ValueKey('sessionRejectedLogoutButton'),
          onPressed: () =>
              ref.read(appAuthControllerProvider.notifier).logout(),
          icon: const Icon(Icons.login),
          label: const Text('返回登录'),
        ),
      ],
    );
  }
}

class FatalMigrationErrorPage extends ConsumerWidget {
  const FatalMigrationErrorPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message =
        ref.watch(appAuthStateProvider).value?.message ?? '本地数据空间初始化失败。';
    return _AuthStatusScaffold(
      pageKey: const ValueKey('fatalMigrationErrorPage'),
      icon: Icons.error_outline,
      title: '无法打开账号数据',
      message: '$message\n本地数据没有被删除。',
      actions: [
        FilledButton.icon(
          key: const ValueKey('retryAuthStartupButton'),
          onPressed: () => ref.read(appAuthControllerProvider.notifier).retry(),
          icon: const Icon(Icons.refresh),
          label: const Text('重试'),
        ),
      ],
    );
  }
}

class _AuthStatusScaffold extends StatelessWidget {
  const _AuthStatusScaffold({
    required this.pageKey,
    required this.icon,
    required this.title,
    required this.message,
    required this.actions,
  });

  final Key pageKey;
  final IconData icon;
  final String title;
  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: pageKey,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  Icon(icon, size: 48),
                  const SizedBox(height: AppSpacing.md),
                  Text(title, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: AppSpacing.sm),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: actions,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
