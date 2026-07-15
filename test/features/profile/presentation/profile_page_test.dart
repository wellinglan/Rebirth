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
import 'package:rebirth/features/profile/presentation/profile_page.dart';

void main() {
  testWidgets('ProfilePage shows loading state', (tester) async {
    final gate = Completer<UserProfile>();
    await _pumpProfile(tester, _FakeProfileRepository(profileGate: gate));

    expect(find.byKey(const ValueKey('profileLoadingState')), findsOneWidget);
  });

  testWidgets('ProfilePage shows error and retries', (tester) async {
    final repository = _FakeProfileRepository(loadError: StateError('failed'));
    await _pumpProfile(tester, repository);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('profileErrorState')), findsOneWidget);
    repository.loadError = null;
    await tester.tap(find.byKey(const ValueKey('retryProfileButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('profileForm')), findsOneWidget);
    expect(repository.profileLoads, 2);
  });

  testWidgets(
    'ProfilePage displays editable local fields and read-only timezone',
    (tester) async {
      await _pumpProfile(tester, _FakeProfileRepository());
      await tester.pumpAndSettle();

      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('管理你的本地身份资料'), findsOneWidget);
      expect(_fieldText(tester, 'profileDisplayNameField'), 'Local user');
      expect(_fieldText(tester, 'profileGrowthFocusField'), '持续成长');
      expect(_fieldText(tester, 'profileTimezoneField'), 'Asia/Shanghai');
      final timezoneField = find.descendant(
        of: find.byKey(const ValueKey('profileTimezoneField')),
        matching: find.byType(TextField),
      );
      expect(tester.widget<TextField>(timezoneField).readOnly, isTrue);
    },
  );

  testWidgets('editing the profile saves trimmed local values', (tester) async {
    final repository = _FakeProfileRepository();
    await _pumpProfile(tester, repository);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('profileDisplayNameField')),
      '  New name  ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('profileGrowthFocusField')),
      '  深度工作  ',
    );
    await _tapSave(tester);

    expect(repository.lastSaved?.displayName, 'New name');
    expect(repository.lastSaved?.growthFocus, '深度工作');
    expect(find.text('资料已保存'), findsOneWidget);
  });

  testWidgets('failed save keeps input and can be retried', (tester) async {
    final repository = _FakeProfileRepository(failuresBeforeSuccess: 1);
    await _pumpProfile(tester, repository);
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('profileDisplayNameField'));
    await tester.enterText(field, '失败后保留');

    await _tapSave(tester);

    expect(find.text('保存失败，请重试'), findsOneWidget);
    expect(_fieldText(tester, 'profileDisplayNameField'), '失败后保留');
    expect(repository.saveAttempts, 1);

    await _tapSave(tester);
    expect(repository.saveAttempts, 2);
    expect(repository.lastSaved?.displayName, '失败后保留');
    expect(find.text('资料已保存'), findsOneWidget);
  });

  testWidgets('saving disables the button and keeps profile input', (
    tester,
  ) async {
    final saveGate = Completer<void>();
    final repository = _FakeProfileRepository(saveGate: saveGate);
    await _pumpProfile(tester, repository);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('profileDisplayNameField')),
      '保存中的昵称',
    );

    final button = find.byKey(const ValueKey('saveProfileButton'));
    await tester.tap(button);
    await tester.pump();

    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    expect(find.text('保存中...'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('profileSaveProgressIndicator')),
      findsOneWidget,
    );
    expect(_fieldText(tester, 'profileDisplayNameField'), '保存中的昵称');
    expect(repository.saveAttempts, 1);

    saveGate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('blank profile fields are normalized to null', (tester) async {
    final repository = _FakeProfileRepository();
    await _pumpProfile(tester, repository);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('profileDisplayNameField')),
      '   ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('profileGrowthFocusField')),
      '\n ',
    );
    await _tapSave(tester);

    expect(repository.lastSaved?.displayName, isNull);
    expect(repository.lastSaved?.growthFocus, isNull);
  });

  test(
    'Profile presentation has no database or Settings presentation imports',
    () {
      final directory = Directory('lib/features/profile/presentation');
      for (final file
          in directory.listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        final source = file.readAsStringSync();
        expect(source, isNot(contains('app_database')));
        expect(source, isNot(contains('package:drift')));
        expect(source, isNot(contains('RepositoryImpl')));
        expect(source, isNot(contains('features/settings/presentation')));
      }
    },
  );
}

Future<void> _pumpProfile(
  WidgetTester tester,
  ProfileRepository repository,
) async {
  await tester.binding.setSurfaceSize(const Size(800, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [profileRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(home: ProfilePage()),
    ),
  );
}

Future<void> _tapSave(WidgetTester tester) async {
  final messenger = tester.state<ScaffoldMessengerState>(
    find.byType(ScaffoldMessenger),
  );
  messenger.hideCurrentSnackBar();
  await tester.pumpAndSettle();
  final button = find.byKey(const ValueKey('saveProfileButton'));
  await Scrollable.ensureVisible(tester.element(button));
  await tester.tap(button);
  await tester.pumpAndSettle();
}

String _fieldText(WidgetTester tester, String key) {
  return tester
      .widget<TextFormField>(find.byKey(ValueKey(key)))
      .controller!
      .text;
}

final class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository({
    this.profileGate,
    this.saveGate,
    this.loadError,
    this.failuresBeforeSuccess = 0,
  });

  final Completer<UserProfile>? profileGate;
  final Completer<void>? saveGate;
  Object? loadError;
  int failuresBeforeSuccess;
  int profileLoads = 0;
  int saveAttempts = 0;
  ProfileSaveData? lastSaved;
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
  Future<UserProfile> saveProfile(ProfileSaveData data) async {
    saveAttempts += 1;
    if (failuresBeforeSuccess > 0) {
      failuresBeforeSuccess -= 1;
      throw StateError('save failed');
    }
    await saveGate?.future;
    lastSaved = data;
    profile = UserProfile(
      id: profile.id,
      displayName: data.displayName,
      growthFocus: data.growthFocus,
      timezoneId: profile.timezoneId,
      createdAt: profile.createdAt,
      updatedAt: profile.updatedAt + 1,
    );
    return profile;
  }

  @override
  Future<DeviceProfileStatus> getDeviceStatus() async {
    return const DeviceProfileStatus(
      localInstallationId: '12345678-1234-1234-1234-12345678cdef',
      activeUserId: '87654321-1234-1234-1234-12345678dcba',
      isLocalMode: true,
      syncEnabled: false,
    );
  }
}
