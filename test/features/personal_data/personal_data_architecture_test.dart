import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart';

void main() {
  test(
    'aggregation core has no feature, Flutter, Drift, Riverpod, or Sync imports',
    () {
      final coreFiles = [
        ...Directory(
          'lib/features/personal_data/domain',
        ).listSync().whereType<File>(),
        File(
          'lib/features/personal_data/application/'
          'personal_data_aggregation_engine.dart',
        ),
        File(
          'lib/features/personal_data/application/'
          'personal_data_provider_registry.dart',
        ),
      ];
      final forbidden = [
        'package:flutter/',
        'package:flutter_riverpod/',
        'package:drift/',
        '/features/profile/',
        '/features/plan/',
        '/features/today/',
        '/features/journal/',
        '/features/health/',
        '/features/sync/',
      ];

      for (final file in coreFiles) {
        final source = file.readAsStringSync();
        for (final token in forbidden) {
          expect(
            source,
            isNot(contains(token)),
            reason: '${file.path}: $token',
          );
        }
      }
    },
  );

  test('generic page has no provider switch or business data imports', () {
    final files = Directory(
      'lib/features/personal_data/presentation',
    ).listSync(recursive: true).whereType<File>();
    final forbidden = [
      'AppDatabase',
      'package:drift/',
      'RepositoryImpl',
      'features/profile/',
      'features/plan/',
      'features/today/',
      'features/journal/',
      'features/health/',
      'features/sync/',
      'features/ai_coach/',
      "case 'rebirth.",
      "== 'rebirth.",
    ];

    for (final file in files) {
      final source = file.readAsStringSync();
      for (final token in forbidden) {
        expect(source, isNot(contains(token)), reason: '${file.path}: $token');
      }
    }
  });

  test('aggregation adds no persistence and preserves current schema', () {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    expect(database.schemaVersion, 10);
    final databaseTables = File(
      'lib/core/database/app_database.dart',
    ).readAsStringSync();
    expect(databaseTables, isNot(contains('aggregation_results')));
    expect(databaseTables, isNot(contains('personal_snapshots')));
    expect(databaseTables, isNot(contains('aggregation_cache')));
  });
}
