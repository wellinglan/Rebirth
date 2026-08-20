import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'presentation cannot access Drift, database, JSON, or platform files',
    () {
      final files = Directory(
        'lib/features/personal_data_export/presentation',
      ).listSync(recursive: true).whereType<File>();
      for (final file in files) {
        final source = file.readAsStringSync();
        for (final forbidden in const [
          'package:drift/',
          'AppDatabase',
          "import 'dart:io'",
          "import 'dart:convert'",
          'file_selector',
          'flutter_file_dialog',
          'PlatformFileExportAdapter',
          'PersonalDataBackupRepositoryImpl',
        ]) {
          expect(source, isNot(contains(forbidden)), reason: file.path);
        }
      }
    },
  );

  test('domain is pure Dart and independent of database and sync payloads', () {
    final files = Directory(
      'lib/features/personal_data_export/domain',
    ).listSync(recursive: true).whereType<File>();
    for (final file in files) {
      final source = file.readAsStringSync();
      for (final forbidden in const [
        'package:flutter/',
        'flutter_riverpod',
        'package:drift/',
        'AppDatabase',
        'SyncPayload',
        'serverVersion',
        'syncStatus',
        'originDeviceId',
      ]) {
        expect(source, isNot(contains(forbidden)), reason: file.path);
      }
    }
  });

  test('feature has no network, AI generation, or sync dependencies', () {
    final files = Directory(
      'lib/features/personal_data_export',
    ).listSync(recursive: true).whereType<File>();
    for (final file in files) {
      final source = file.readAsStringSync();
      for (final forbidden in const [
        'package:dio/',
        'features/sync/',
        'features/ai_coach/',
        'AuthRepository',
        'SyncCoordinator',
        'AiProvider',
      ]) {
        expect(source, isNot(contains(forbidden)), reason: file.path);
      }
    }
  });

  test('Settings and router expose the dedicated protected export page', () {
    final settings = File(
      'lib/features/settings/presentation/settings_page.dart',
    ).readAsStringSync();
    final router = File('lib/core/router/app_router.dart').readAsStringSync();
    final routes = File('lib/core/router/route_names.dart').readAsStringSync();

    expect(settings, contains('fullPersonalDataExportSettingsTile'));
    expect(settings, contains('RoutePaths.fullPersonalDataExport'));
    expect(router, contains('FullPersonalDataExportPage'));
    expect(routes, contains('/settings/personal-data-export'));
  });

  test('Flutter schema remains 11 and no migration is introduced', () {
    final database = File(
      'lib/core/database/app_database.dart',
    ).readAsStringSync();
    expect(database, contains('int get schemaVersion => 13;'));
    expect(
      Directory('lib/features/personal_data_export')
          .listSync(recursive: true)
          .whereType<File>()
          .map((file) => file.readAsStringSync())
          .join(),
      isNot(contains('MigrationStrategy')),
    );
  });
}
