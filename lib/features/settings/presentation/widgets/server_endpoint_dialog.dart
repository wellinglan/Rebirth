import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/theme/app_layout.dart';
import 'package:rebirth/features/settings/presentation/server_endpoint_settings_controller.dart';

class ServerEndpointDialog extends ConsumerStatefulWidget {
  const ServerEndpointDialog({required this.initialValue, super.key});

  final String initialValue;

  @override
  ConsumerState<ServerEndpointDialog> createState() =>
      _ServerEndpointDialogState();
}

class _ServerEndpointDialogState extends ConsumerState<ServerEndpointDialog> {
  late final TextEditingController _controller;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(serverEndpointSettingsControllerProvider);
    final controller = ref.read(serverEndpointSettingsControllerProvider.notifier);
    final canSave = controller.canSave(_controller.text);
    return AlertDialog(
      key: const ValueKey('serverEndpointDialog'),
      title: const Text('修改开发服务器'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey('serverEndpointField'),
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: 'Server Base URL',
                hintText: 'http://192.168.x.x:8000',
                errorText: _validationError,
              ),
              onChanged: (_) => setState(() => _validationError = null),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (state.health case final health?)
              Text(
                '连接成功 · API ${health.apiVersion} · Sync ${health.syncProtocolVersion}',
                key: const ValueKey('serverEndpointTestSuccess'),
              ),
            if (state.errorMessage case final message?)
              Text(
                message,
                key: const ValueKey('serverEndpointTestError'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: state.isTesting ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        OutlinedButton.icon(
          key: const ValueKey('testServerEndpointButton'),
          onPressed: state.isTesting
              ? null
              : () async {
                  final error = controller.validate(_controller.text);
                  if (error != null) {
                    setState(() => _validationError = error);
                    return;
                  }
                  await controller.testConnection(_controller.text);
                  if (mounted) setState(() {});
                },
          icon: state.isTesting
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.monitor_heart_outlined),
          label: Text(state.isTesting ? '测试中...' : '测试连接'),
        ),
        FilledButton(
          key: const ValueKey('saveServerEndpointButton'),
          onPressed: canSave
              ? () => Navigator.of(context).pop(_controller.text.trim())
              : null,
          child: const Text('保存'),
        ),
      ],
    );
  }
}

