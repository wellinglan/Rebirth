import 'package:flutter/material.dart';
import 'package:rebirth/core/theme/app_layout.dart';
import 'package:rebirth/features/profile/domain/device_profile_status.dart';

class DeviceStatusCard extends StatelessWidget {
  const DeviceStatusCard({required this.status, super.key});

  final DeviceProfileStatus status;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey('deviceStatusCard'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DeviceValue(label: '数据模式', value: '本地 SQLite'),
            const _DeviceValue(label: '同步状态', value: '未启用'),
            _DeviceValue(
              label: '设备 ID',
              value: formatLocalIdentifier(status.localInstallationId),
            ),
            _DeviceValue(
              label: '资料 ID',
              value: formatLocalIdentifier(status.activeUserId),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '当前数据不会自动同步到其他设备。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

String formatLocalIdentifier(String value) {
  if (value.length <= 12) {
    return value;
  }
  return '${value.substring(0, 8)}...${value.substring(value.length - 4)}';
}

class _DeviceValue extends StatelessWidget {
  const _DeviceValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 88, child: Text(label)),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}
