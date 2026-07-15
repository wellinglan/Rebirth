import 'package:flutter/material.dart';
import 'package:rebirth/core/theme/app_layout.dart';
import 'package:rebirth/features/profile/domain/profile_save_data.dart';
import 'package:rebirth/features/profile/domain/user_profile.dart';

class ProfileForm extends StatefulWidget {
  const ProfileForm({required this.profile, required this.onSave, super.key});

  final UserProfile profile;
  final Future<void> Function(ProfileSaveData data) onSave;

  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<ProfileForm> {
  late final TextEditingController _displayNameController;
  late final TextEditingController _growthFocusController;
  late final TextEditingController _timezoneController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(
      text: widget.profile.displayName,
    );
    _growthFocusController = TextEditingController(
      text: widget.profile.growthFocus,
    );
    _timezoneController = TextEditingController(
      text: widget.profile.timezoneId,
    );
  }

  @override
  void didUpdateWidget(covariant ProfileForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.updatedAt != widget.profile.updatedAt && !_isSaving) {
      _displayNameController.text = widget.profile.displayName ?? '';
      _growthFocusController.text = widget.profile.growthFocus ?? '';
      _timezoneController.text = widget.profile.timezoneId;
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _growthFocusController.dispose();
    _timezoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving) {
      return;
    }
    setState(() => _isSaving = true);
    try {
      await widget.onSave(
        ProfileSaveData(
          displayName: _displayNameController.text,
          growthFocus: _growthFocusController.text,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('资料已保存')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('保存失败，请重试')));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('profileForm'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          key: const ValueKey('profileDisplayNameField'),
          controller: _displayNameController,
          enabled: !_isSaving,
          decoration: const InputDecoration(labelText: '昵称', hintText: '未设置昵称'),
        ),
        const SizedBox(height: AppLayout.fieldGap),
        TextFormField(
          key: const ValueKey('profileGrowthFocusField'),
          controller: _growthFocusController,
          enabled: !_isSaving,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: '成长关注',
            hintText: '你当前最关注的成长方向',
          ),
        ),
        const SizedBox(height: AppLayout.fieldGap),
        TextFormField(
          key: const ValueKey('profileTimezoneField'),
          controller: _timezoneController,
          readOnly: true,
          decoration: const InputDecoration(
            labelText: '时区',
            helperText: '当前版本由本地资料记录，只读显示',
          ),
        ),
        const SizedBox(height: AppLayout.sectionGap),
        FilledButton.icon(
          key: const ValueKey('saveProfileButton'),
          onPressed: _isSaving ? null : _submit,
          icon: _isSaving
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(
                    key: ValueKey('profileSaveProgressIndicator'),
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_isSaving ? '保存中...' : '保存资料'),
        ),
      ],
    );
  }
}
