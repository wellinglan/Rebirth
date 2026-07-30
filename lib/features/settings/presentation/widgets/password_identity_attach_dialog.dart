import 'package:flutter/material.dart';

final class PasswordIdentityAttachInput {
  const PasswordIdentityAttachInput({
    required this.devUserKey,
    required this.username,
    required this.password,
    this.displayName,
  });

  final String devUserKey;
  final String username;
  final String password;
  final String? displayName;
}

class PasswordIdentityAttachDialog extends StatefulWidget {
  const PasswordIdentityAttachDialog({super.key});

  @override
  State<PasswordIdentityAttachDialog> createState() =>
      _PasswordIdentityAttachDialogState();
}

class _PasswordIdentityAttachDialogState
    extends State<PasswordIdentityAttachDialog> {
  final _formKey = GlobalKey<FormState>();
  final _devUserKey = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _displayName = TextEditingController();

  @override
  void dispose() {
    _devUserKey.dispose();
    _username.dispose();
    _password.dispose();
    _displayName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('passwordIdentityAttachDialog'),
      title: const Text('绑定用户名和密码'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('绑定后仍使用同一个云账号。本操作不会创建第二个账号。'),
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('attachDevUserKeyField'),
                  controller: _devUserKey,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Development User Key',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? '请输入当前账号的 User Key'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('attachUsernameField'),
                  controller: _username,
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: '用户名'),
                  validator: _validateUsername,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('attachPasswordField'),
                  controller: _password,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: '密码'),
                  validator: _validatePassword,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('attachDisplayNameField'),
                  controller: _displayName,
                  decoration: const InputDecoration(labelText: '显示名称（可选）'),
                  maxLength: 128,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          key: const ValueKey('confirmPasswordIdentityAttachButton'),
          onPressed: _submit,
          icon: const Icon(Icons.link),
          label: const Text('确认绑定'),
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final displayName = _displayName.text.trim();
    Navigator.of(context).pop(
      PasswordIdentityAttachInput(
        devUserKey: _devUserKey.text.trim(),
        username: _username.text.trim(),
        password: _password.text,
        displayName: displayName.isEmpty ? null : displayName,
      ),
    );
  }

  String? _validateUsername(String? value) {
    final candidate = value?.trim() ?? '';
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_.-]{3,63}$').hasMatch(candidate)) {
      return '请输入 4–64 位 ASCII 用户名，并以字母或数字开头';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final candidate = value ?? '';
    if (candidate.length < 12 || candidate.length > 128) {
      return '密码长度需为 12–128 个字符';
    }
    if (candidate.runes.any((code) => code == 0 || code < 32 || code == 127)) {
      return '密码不能包含控制字符';
    }
    return null;
  }
}
