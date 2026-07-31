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

class _IdentityList extends ConsumerWidget {
  const _IdentityList({required this.state});

  final AccountSecurityState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providers = state.identities.map((item) => item.provider).toSet();
    final hasWechat = providers.contains(AuthIdentityProvider.wechat);
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
              _IdentityTile(
                key: ValueKey('wechatIdentityTile'),
                icon: Icons.chat_bubble_outline,
                title: '微信',
                subtitle: hasWechat
                    ? '已绑定'
                    : state.isOfflineSnapshot
                    ? '当前离线，无法绑定'
                    : '未绑定',
                isBound: hasWechat,
                enabled: hasWechat || !state.isOfflineSnapshot,
                trailing: hasWechat
                    ? const Icon(Icons.check_circle_outline)
                    : state.isStartingWechatBinding
                    ? const SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : TextButton(
                        key: const ValueKey('bindWechatButton'),
                        onPressed: state.isOfflineSnapshot
                            ? null
                            : () => _startWechatBinding(context, ref),
                        child: const Text('绑定'),
                      ),
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

  Future<void> _startWechatBinding(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('绑定微信'),
        content: const Text(
          '绑定第三方登录方式前，需要重新确认当前登录并由服务端验证身份。'
          '当前版本尚未接入真实微信授权。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const ValueKey('confirmWechatBindingButton'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('继续'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final result = await ref
          .read(accountSecurityControllerProvider.notifier)
          .startWechatBinding();
      if (!context.mounted) return;
      final message = result.isProviderUnavailable
          ? '当前版本尚未配置微信绑定'
          : '微信绑定流程已启动';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('无法启动微信绑定，请稍后再试')));
    }
  }
}

class _IdentityTile extends StatelessWidget {
  const _IdentityTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isBound,
    this.enabled = true,
    this.trailing,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isBound;
  final bool enabled;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      enabled: enabled,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing:
          trailing ?? Icon(isBound ? Icons.check_circle_outline : Icons.add),
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
