import 'package:flutter/foundation.dart';

final class DeviceInfo {
  const DeviceInfo({required this.platform, required this.deviceName});

  final String platform;
  final String deviceName;
}

class DeviceInfoService {
  const DeviceInfoService({this.platform, this.isWeb});

  final TargetPlatform? platform;
  final bool? isWeb;

  DeviceInfo current() {
    if (isWeb ?? kIsWeb) {
      return const DeviceInfo(platform: 'web', deviceName: 'Web Browser');
    }

    return switch (platform ?? defaultTargetPlatform) {
      TargetPlatform.windows => const DeviceInfo(
        platform: 'windows',
        deviceName: 'Windows PC',
      ),
      TargetPlatform.android => const DeviceInfo(
        platform: 'android',
        deviceName: 'Android Device',
      ),
      TargetPlatform.iOS => const DeviceInfo(
        platform: 'ios',
        deviceName: 'iOS Device',
      ),
      TargetPlatform.macOS => const DeviceInfo(
        platform: 'macos',
        deviceName: 'macOS Device',
      ),
      TargetPlatform.linux || TargetPlatform.fuchsia => throw UnsupportedError(
        'Current platform cannot register a device.',
      ),
    };
  }
}
