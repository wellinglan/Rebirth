import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/config/server_endpoint_provider.dart';
import 'package:rebirth/core/theme/app_layout.dart';
import 'package:rebirth/features/account/domain/app_auth_state.dart';

import 'app_auth_controller.dart';

class DeveloperLoginPage extends ConsumerStatefulWidget {
  const DeveloperLoginPage({super.key});

  @override
  ConsumerState<DeveloperLoginPage> createState() => _DeveloperLoginPageState();
}

class _DeveloperLoginPageState extends ConsumerState<DeveloperLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _keyController = TextEditingController();

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(appAuthStateProvider).value;
    final endpoint = ref.watch(effectiveServerEndpointProvider);
    final isSubmitting = auth?.status == AppAuthStatus.submittingDeveloperLogin;
    return Scaffold(
      key: const ValueKey('developerLoginPage'),
      appBar: AppBar(title: const Text('开发者登录')),
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
                    const Icon(Icons.developer_mode_outlined, size: 44),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Alpha / Development 辅助入口',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextFormField(
                      key: const ValueKey('developerUserKeyField'),
                      controller: _keyController,
                      enabled: !isSubmitting,
                      autofocus: true,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
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
                    if (auth?.message case final message?) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        message,
                        key: const ValueKey('developerLoginErrorMessage'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    FilledButton.icon(
                      key: const ValueKey('developerLoginSubmitButton'),
                      onPressed: isSubmitting ? null : _submit,
                      icon: isSubmitting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.terminal_outlined),
                      label: Text(isSubmitting ? '登录中...' : '开发登录'),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            '开发服务器：${endpoint.baseUrl}',
                            key: const ValueKey('developerServerEndpoint'),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        IconButton(
                          key: const ValueKey(
                            'configureDeveloperServerEndpointButton',
                          ),
                          onPressed: isSubmitting
                              ? null
                              : () => _configureEndpoint(endpoint.baseUrl),
                          tooltip: '配置开发服务器',
                          icon: const Icon(Icons.settings_ethernet),
                        ),
                      ],
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
    final key = _keyController.text;
    _keyController.clear();
    await ref.read(appAuthControllerProvider.notifier).devLogin(key);
  }

  Future<void> _configureEndpoint(String currentValue) async {
    final candidate = await showDialog<String>(
      context: context,
      builder: (context) => _DeveloperServerEndpointDialog(
        initialValue: currentValue,
        validate: ref.read(serverEndpointValidatorProvider).errorFor,
      ),
    );
    if (candidate == null || !mounted) return;
    await ref.read(serverEndpointControllerProvider.notifier).save(candidate);
  }
}

class _DeveloperServerEndpointDialog extends StatefulWidget {
  const _DeveloperServerEndpointDialog({
    required this.initialValue,
    required this.validate,
  });

  final String initialValue;
  final String? Function(String value) validate;

  @override
  State<_DeveloperServerEndpointDialog> createState() =>
      _DeveloperServerEndpointDialogState();
}

class _DeveloperServerEndpointDialogState
    extends State<_DeveloperServerEndpointDialog> {
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
      key: const ValueKey('developerServerEndpointDialog'),
      title: const Text('配置开发服务器'),
      content: TextField(
        key: const ValueKey('developerServerEndpointField'),
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
          key: const ValueKey('saveDeveloperServerEndpointButton'),
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
