import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/config/server_endpoint_provider.dart';
import 'package:rebirth/core/theme/app_layout.dart';

import 'app_auth_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _keyController = TextEditingController();

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(appAuthStateProvider);
    final authValue = auth.value;
    final endpoint = ref.watch(effectiveServerEndpointProvider);
    final isSubmitting = auth.isLoading;
    return Scaffold(
      key: const ValueKey('loginPage'),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Rebirth',
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '登录后进入你的本地数据空间',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    TextFormField(
                      key: const ValueKey('loginDevUserKeyField'),
                      controller: _keyController,
                      enabled: !isSubmitting,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Development User Key',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.done,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? '请输入 Development User Key'
                          : null,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    if (authValue?.message case final message?) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        message,
                        key: const ValueKey('loginErrorMessage'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    FilledButton.icon(
                      key: const ValueKey('loginSubmitButton'),
                      onPressed: isSubmitting ? null : _submit,
                      icon: isSubmitting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: Text(isSubmitting ? '登录中...' : '开发登录'),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            '当前 Alpha 服务器：${endpoint.baseUrl}',
                            key: const ValueKey('loginServerEndpoint'),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        IconButton(
                          key: const ValueKey(
                            'configureLoginServerEndpointButton',
                          ),
                          onPressed: isSubmitting
                              ? null
                              : () => _configureEndpoint(endpoint.baseUrl),
                          tooltip: '配置服务器',
                          icon: const Icon(Icons.settings_ethernet),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '本 Sprint 使用现有开发认证，不代表生产级账号系统。',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    await ref
        .read(appAuthControllerProvider.notifier)
        .devLogin(_keyController.text);
  }

  Future<void> _configureEndpoint(String currentValue) async {
    final candidate = await showDialog<String>(
      context: context,
      builder: (context) => _LoginServerEndpointDialog(
        initialValue: currentValue,
        validate: ref.read(serverEndpointValidatorProvider).errorFor,
      ),
    );
    if (candidate == null || !mounted) return;
    await ref.read(serverEndpointControllerProvider.notifier).save(candidate);
  }
}

class _LoginServerEndpointDialog extends StatefulWidget {
  const _LoginServerEndpointDialog({
    required this.initialValue,
    required this.validate,
  });

  final String initialValue;
  final String? Function(String value) validate;

  @override
  State<_LoginServerEndpointDialog> createState() =>
      _LoginServerEndpointDialogState();
}

class _LoginServerEndpointDialogState
    extends State<_LoginServerEndpointDialog> {
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
    return AlertDialog(
      key: const ValueKey('loginServerEndpointDialog'),
      title: const Text('配置 Alpha 服务器'),
      content: TextField(
        key: const ValueKey('loginServerEndpointField'),
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.url,
        decoration: InputDecoration(
          labelText: 'Server Base URL',
          hintText: 'http://192.168.x.x:8000',
          errorText: _validationError,
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) => setState(() => _validationError = null),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const ValueKey('saveLoginServerEndpointButton'),
          onPressed: () {
            final error = widget.validate(_controller.text);
            if (error != null) {
              setState(() => _validationError = error);
              return;
            }
            Navigator.of(context).pop(_controller.text.trim());
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
