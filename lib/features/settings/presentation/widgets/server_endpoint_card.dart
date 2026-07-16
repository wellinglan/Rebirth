import 'package:flutter/material.dart';
import 'package:rebirth/core/config/server_endpoint.dart';
import 'package:rebirth/core/theme/app_layout.dart';

class ServerEndpointCard extends StatelessWidget {
  const ServerEndpointCard({
    required this.endpoint,
    required this.backendReachable,
    required this.health,
    required this.onEdit,
    required this.onRestoreDefault,
    super.key,
  });

  final ServerEndpoint endpoint;
  final bool backendReachable;
  final ServerEndpointHealth? health;
  final VoidCallback onEdit;
  final VoidCallback onRestoreDefault;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const ValueKey('serverEndpointCard'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.dns_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text('开发服务器', style: theme.textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _EndpointRow(label: '当前地址', value: endpoint.baseUrl),
            _EndpointRow(label: '地址来源', value: endpoint.sourceLabel),
            _EndpointRow(
              label: '连接状态',
              value: backendReachable ? '已连接' : '尚未测试',
            ),
            _EndpointRow(
              label: 'API version',
              value: health?.apiVersion.toString() ?? '待测试',
            ),
            _EndpointRow(
              label: 'Sync protocol',
              value: health?.syncProtocolVersion.toString() ?? '待测试',
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'HTTP 仅用于本机、局域网与 alpha 测试；正式云服务必须使用 HTTPS。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                FilledButton.tonalIcon(
                  key: const ValueKey('editServerEndpointButton'),
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('修改服务器'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('restoreServerEndpointButton'),
                  onPressed: onRestoreDefault,
                  icon: const Icon(Icons.restore),
                  label: const Text('恢复默认'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EndpointRow extends StatelessWidget {
  const _EndpointRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 108, child: Text(label)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
