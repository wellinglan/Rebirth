import 'device_profile_status.dart';
import 'profile_save_data.dart';
import 'user_profile.dart';

abstract interface class ProfileRepository {
  Future<UserProfile> getActiveProfile();

  Future<UserProfile> saveProfile(ProfileSaveData data);

  Future<DeviceProfileStatus> getDeviceStatus();
}
