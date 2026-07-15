import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/features/profile/data/profile_repository_provider.dart';
import 'package:rebirth/features/profile/domain/profile_save_data.dart';
import 'package:rebirth/features/profile/domain/user_profile.dart';
import 'package:rebirth/shared/state/profile_revision_provider.dart';

final profileControllerProvider =
    AsyncNotifierProvider<ProfileController, UserProfile>(
      ProfileController.new,
    );

class ProfileController extends AsyncNotifier<UserProfile> {
  bool _isSaving = false;

  @override
  Future<UserProfile> build() {
    ref.watch(profileRevisionProvider);
    return ref.watch(profileRepositoryProvider).getActiveProfile();
  }

  Future<void> reload() async {
    state = const AsyncLoading<UserProfile>();
    state = await AsyncValue.guard(
      () => ref.read(profileRepositoryProvider).getActiveProfile(),
    );
  }

  Future<void> saveProfile(ProfileSaveData data) async {
    if (_isSaving) {
      return;
    }
    _isSaving = true;
    try {
      final saved = await ref.read(profileRepositoryProvider).saveProfile(data);
      state = AsyncData(saved);
      ref.read(profileRevisionProvider.notifier).bump();
    } finally {
      _isSaving = false;
    }
  }
}
