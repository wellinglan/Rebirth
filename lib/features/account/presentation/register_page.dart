import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rebirth/core/config/app_config_provider.dart';
import 'package:rebirth/core/theme/app_layout.dart';
import 'package:rebirth/features/account/domain/app_auth_state.dart';
import 'package:rebirth/features/account/domain/public_auth_input.dart';

import 'app_auth_controller.dart';

class PublicRegisterPage extends ConsumerStatefulWidget {
  const PublicRegisterPage({super.key});

  @override
  ConsumerState<PublicRegisterPage> createState() => _PublicRegisterPageState();
}

class _PublicRegisterPageState extends ConsumerState<PublicRegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final auth = ref.watch(appAuthStateProvider).value;
    final isSubmitting = auth?.status == AppAuthStatus.submittingRegister;
    return Scaffold(
      key: const ValueKey('publicRegisterPage'),
      appBar: AppBar(title: const Text('创建账号')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '加入 Rebirth',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Text('注册成功后将直接进入你的独立本地数据空间。'),
                      if (config.isAlpha) ...[
                        const SizedBox(height: AppSpacing.sm),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Chip(label: Text('Alpha 环境')),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      TextFormField(
                        key: const ValueKey('registerUsernameField'),
                        controller: _usernameController,
                        enabled: !isSubmitting,
                        autofocus: true,
                        keyboardType: TextInputType.text,
                        textCapitalization: TextCapitalization.none,
                        autocorrect: false,
                        enableSuggestions: false,
                        autofillHints: const [AutofillHints.newUsername],
                        maxLength: PublicAuthInput.usernameMaxLength,
                        decoration: const InputDecoration(
                          labelText: '用户名',
                          helperText: '4–64 位，可使用字母、数字、点、下划线或连字符',
                          border: OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.next,
                        validator: PublicAuthInput.usernameError,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        key: const ValueKey('registerDisplayNameField'),
                        controller: _displayNameController,
                        enabled: !isSubmitting,
                        maxLength: PublicAuthInput.displayNameMaxLength,
                        decoration: const InputDecoration(
                          labelText: '显示名称（可选）',
                          border: OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.next,
                        validator: PublicAuthInput.displayNameError,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        key: const ValueKey('registerPasswordField'),
                        controller: _passwordController,
                        enabled: !isSubmitting,
                        obscureText: _obscurePassword,
                        autocorrect: false,
                        enableSuggestions: false,
                        autofillHints: const [AutofillHints.newPassword],
                        maxLength: PublicAuthInput.passwordMaxLength,
                        decoration: InputDecoration(
                          labelText: '密码',
                          helperText: '12–128 个字符，空格会作为密码的一部分',
                          border: const OutlineInputBorder(),
                          suffixIcon: Semantics(
                            button: true,
                            label: _obscurePassword ? '显示密码' : '隐藏密码',
                            child: IconButton(
                              key: const ValueKey(
                                'registerPasswordVisibilityButton',
                              ),
                              tooltip: _obscurePassword ? '显示密码' : '隐藏密码',
                              onPressed: isSubmitting
                                  ? null
                                  : () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                        ),
                        textInputAction: TextInputAction.next,
                        validator: PublicAuthInput.registrationPasswordError,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        key: const ValueKey('registerConfirmationField'),
                        controller: _confirmationController,
                        enabled: !isSubmitting,
                        obscureText: _obscurePassword,
                        autocorrect: false,
                        enableSuggestions: false,
                        autofillHints: const [AutofillHints.newPassword],
                        maxLength: PublicAuthInput.passwordMaxLength,
                        decoration: const InputDecoration(
                          labelText: '确认密码',
                          border: OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.done,
                        validator: (value) =>
                            PublicAuthInput.confirmationPasswordError(
                              value,
                              _passwordController.text,
                            ),
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      if (auth?.message case final message?) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            message,
                            key: const ValueKey('registerErrorMessage'),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      FilledButton.icon(
                        key: const ValueKey('registerSubmitButton'),
                        onPressed: isSubmitting ? null : _submit,
                        icon: isSubmitting
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.person_add_outlined),
                        label: Text(isSubmitting ? '创建中...' : '创建账号'),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextButton(
                        key: const ValueKey('backToLoginButton'),
                        onPressed: isSubmitting ? null : () => context.pop(),
                        child: const Text('返回登录'),
                      ),
                    ],
                  ),
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
    final success = await ref
        .read(appAuthControllerProvider.notifier)
        .registerWithPassword(
          username: _usernameController.text,
          password: _passwordController.text,
          displayName: PublicAuthInput.normalizeDisplayName(
            _displayNameController.text,
          ),
        );
    if (!success && mounted) {
      _passwordController.clear();
      _confirmationController.clear();
    }
  }
}
