import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/account/data/device_info_service.dart';

void main() {
  test('maps Windows to the server device contract', () {
    final info = const DeviceInfoService(
      platform: TargetPlatform.windows,
      isWeb: false,
    ).current();

    expect(info.platform, 'windows');
    expect(info.deviceName, 'Windows PC');
  });

  test('maps Android to the server device contract', () {
    final info = const DeviceInfoService(
      platform: TargetPlatform.android,
      isWeb: false,
    ).current();

    expect(info.platform, 'android');
    expect(info.deviceName, 'Android Device');
  });

  test('web takes precedence over the target platform', () {
    final info = const DeviceInfoService(
      platform: TargetPlatform.windows,
      isWeb: true,
    ).current();

    expect(info.platform, 'web');
    expect(info.deviceName, 'Web Browser');
  });
}
