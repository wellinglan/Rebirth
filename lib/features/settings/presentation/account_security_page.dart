import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/theme/app_layout.dart';
import 'package:rebirth/features/account/domain/auth_identity.dart';
import 'package:rebirth/features/account/presentation/account_security_controller.dart';
import 'package:rebirth/features/account/presentation/account_security_state.dart';

class AccountSecurityPage extends ConsumerWidget {
  const AccountSecurityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accountSecurityControllerProvider);
    return Scaffold(
      key: const ValueKey('accountSecurityPage'),
      appBar: AppBar(title: const Text('账号安全')),
      body: SafeArea(
        child: state.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
              key: ValueKey('accountSecurityLoading'),
            ),
          ),
          error: (_, _) => _LoadError(
            onRetry: () =>
                ref.read(accountSecurityControllerProvider.notifier).reload(),
          ),
          data: (value) => _IdentityList(state: value),
        ),
      ),
    );
  }
}

class _IdentityList extends StatelessWidget {
  const _IdentityList({required this.state});

  final AccountSecurityState state;

  @override
  Widget build(BuildContext context) {
    final providers = state.identities.map((item) => item.provider).toSet();
    return ListView(
      key: const ValueKey('accountSecurityData'),
      padding: AppLayout.pagePadding,
      children: [
        Text('登录方式', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppLayout.cardGap),
        Card(
          child: Column(
            children: [
              if (providers.contains(AuthIdentityProvider.password))
                const _IdentityTile(
                  key: ValueKey('passwordIdentityTile'),
                  icon: Icons.password_outlined,
                  title: '用户名密码',
                  subtitle: '已绑定',
                  isBound: true,
                ),
              if (providers.contains(AuthIdentityProvider.developer))
                const _IdentityTile(
                  key: ValueKey('developerIdentityTile'),
                  icon: Icons.developer_mode_outlined,
                  title: '开发账号',
                  subtitle: '已绑定',
                  isBound: true,
                ),
              const _IdentityTile(
                key: ValueKey('wechatIdentityTile'),
                icon: Icons.chat_bubble_outline,
                title: '微信',
                subtitle: '后续版本开放',
                isBound: false,
              ),
            ],
          ),
        ),
        if (state.isOfflineSnapshot) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            '离线状态仅显示当前登录方式。',
            key: const ValueKey('accountSecurityOfflineNote'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _IdentityTile extends StatelessWidget {
  const _IdentityTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isBound,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isBound;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      enabled: isBound,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Icon(isBound ? Icons.check_circle_outline : Icons.add),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('accountSecurityError'),
      child: OutlinedButton.icon(
        key: const ValueKey('retryAccountSecurityButton'),
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('重新加载'),
      ),
    );
  }
}
