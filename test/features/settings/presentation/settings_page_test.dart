import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/profile/data/profile_repository_provider.dart';
import 'package:rebirth/features/profile/domain/device_profile_status.dart';
import 'package:rebirth/features/profile/domain/profile_repository.dart';
import 'package:rebirth/features/profile/domain/profile_save_data.dart';
import 'package:rebirth/features/profile/domain/user_profile.dart';
import 'package:rebirth/features/settings/presentation/settings_page.dart';
import 'package:rebirth/features/settings/presentation/widgets/device_status_card.dart';

void main() {
  testWidgets('SettingsPage shows loading state', (tester) async {
    final gate = Completer<UserProfile>();
    await _pumpSettings(tester, _FakeProfileRepository(profileGate: gate));

    expect(find.byKey(const ValueKey('settingsLoadingState')), findsOneWidget);
  });

  testWidgets('SettingsPage shows error and retries', (tester) async {
    final repository = _FakeProfileRepository(loadError: StateError('failed'));
    await _pumpSettings(tester, repository);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('settingsErrorState')), findsOneWidget);
    expect(find.text('设置暂时无法加载'), findsOneWidget);

    repository.loadError = null;
    await tester.tap(find.byKey(const ValueKey('retrySettingsButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('settingsDataState')), findsOneWidget);
    expect(repository.profileLoads, greaterThanOrEqualTo(2));
  });

  testWidgets('SettingsPage describes local account, profile, device and app', (
    tester,
  ) async {
    await _pumpSettings(tester, _FakeProfileRepository());
    await tester.pumpAndSettle();

    for (final text in [
      'Settings',
      '管理账号、资料与本地数据',
      '账号与同步',
      '本地模式',
      '未登录',
      '跨端同步暂未启用',
      '个人资料',
      '本地资料',
      '本地数据与设备',
      '关于 Rebirth',
      'Rebirth · alpha',
    ]) {
      expect(find.text(text), findsOneWidget);
    }
    expect(find.text('Local user'), findsOneWidget);
    expect(find.text('已登录'), findsNothing);
    expect(find.text('已同步'), findsNothing);
    expect(find.text(_installationId), findsNothing);
    expect(find.text('12345678...cdef'), findsOneWidget);
  });

  testWidgets('account connection opens an honest placeholder dialog', (
    tester,
  ) async {
    await _pumpSettings(tester, _FakeProfileRepository());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('accountConnectionButton')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('accountConnectionDialog')),
      findsOneWidget,
    );
    expect(find.text('账号互联即将支持'), findsOneWidget);
    expect(find.text('知道了'), findsOneWidget);
    expect(find.text('已登录'), findsNothing);
    expect(find.text('已同步'), findsNothing);
  });

  testWidgets('device read failure keeps Settings usable', (tester) async {
    await _pumpSettings(
      tester,
      _FakeProfileRepository(deviceError: StateError('device failed')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('settingsDataState')), findsOneWidget);
    expect(find.text('无法读取设备信息'), findsOneWidget);
    expect(find.text('Local user'), findsOneWidget);
  });

  test('identifier formatting exposes only a short local value', () {
    expect(formatLocalIdentifier(_installationId), '12345678...cdef');
    expect(formatLocalIdentifier('short-id'), 'short-id');
  });

  test(
    'Settings presentation has no database or Profile presentation imports',
    () {
      final directory = Directory('lib/features/settings/presentation');
      for (final file
          in directory.listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        final source = file.readAsStringSync();
        expect(source, isNot(contains('app_database')));
        expect(source, isNot(contains('package:drift')));
        expect(source, isNot(contains('RepositoryImpl')));
        expect(source, isNot(contains('features/profile/presentation')));
      }
    },
  );
}

Future<void> _pumpSettings(
  WidgetTester tester,
  ProfileRepository repository,
) async {
  await tester.binding.setSurfaceSize(const Size(900, 1100));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [profileRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(home: SettingsPage()),
    ),
  );
}

const _installationId = '12345678-1234-1234-1234-12345678cdef';

final class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository({this.profileGate, this.loadError, this.deviceError});

  final Completer<UserProfile>? profileGate;
  Object? loadError;
  Object? deviceError;
  int profileLoads = 0;
  UserProfile profile = const UserProfile(
    id: '87654321-1234-1234-1234-12345678dcba',
    displayName: 'Local user',
    growthFocus: '持续成长',
    timezoneId: 'Asia/Shanghai',
    createdAt: 1,
    updatedAt: 1,
  );

  @override
  Future<UserProfile> getActiveProfile() async {
    profileLoads += 1;
    if (loadError != null) throw loadError!;
    return profileGate?.future ?? profile;
  }

  @override
  Future<DeviceProfileStatus> getDeviceStatus() async {
    if (loadError != null) throw loadError!;
    if (deviceError != null) throw deviceError!;
    return const DeviceProfileStatus(
      localInstallationId: _installationId,
      activeUserId: '87654321-1234-1234-1234-12345678dcba',
      isLocalMode: true,
      syncEnabled: false,
    );
  }

  @override
  Future<UserProfile> saveProfile(ProfileSaveData data) async => profile;
}
