import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/theme/app_layout.dart';
import 'package:rebirth/features/profile/domain/profile_save_data.dart';

import 'profile_controller.dart';
import 'widgets/profile_form.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileControllerProvider);
    return Scaffold(
      key: const ValueKey('profilePage'),
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: state.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
              key: ValueKey('profileLoadingState'),
            ),
          ),
          error: (error, stackTrace) => _ProfileError(
            onRetry: () =>
                ref.read(profileControllerProvider.notifier).reload(),
          ),
          data: (profile) => ListView(
            key: const ValueKey('profileDataState'),
            padding: AppLayout.pagePadding,
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppLayout.maxContentWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '管理你的本地身份资料',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppLayout.sectionGap),
                      ProfileForm(
                        profile: profile,
                        onSave: (data) => _save(ref, data),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save(WidgetRef ref, ProfileSaveData data) {
    return ref.read(profileControllerProvider.notifier).saveProfile(data);
  }
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('profileErrorState'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('个人资料暂时无法加载'),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            key: const ValueKey('retryProfileButton'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
