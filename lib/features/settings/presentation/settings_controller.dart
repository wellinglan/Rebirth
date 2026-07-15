import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/features/profile/data/profile_repository_provider.dart';
import 'package:rebirth/features/profile/domain/device_profile_status.dart';
import 'package:rebirth/shared/state/profile_revision_provider.dart';

import 'settings_view_state.dart';

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, SettingsViewState>(
      SettingsController.new,
    );

class SettingsController extends AsyncNotifier<SettingsViewState> {
  @override
  Future<SettingsViewState> build() {
    ref.watch(profileRevisionProvider);
    return _load();
  }

  Future<void> reload() async {
    state = const AsyncLoading<SettingsViewState>();
    state = await AsyncValue.guard(_load);
  }

  Future<SettingsViewState> _load() async {
    final repository = ref.read(profileRepositoryProvider);
    final profile = await repository.getActiveProfile();
    DeviceProfileStatus? deviceStatus;
    try {
      deviceStatus = await repository.getDeviceStatus();
    } catch (_) {
      deviceStatus = null;
    }
    return SettingsViewState(profile: profile, deviceStatus: deviceStatus);
  }
}
