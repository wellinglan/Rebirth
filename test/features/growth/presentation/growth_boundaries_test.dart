import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Growth presentation does not access Drift, database, or implementation',
    () {
      final files = Directory('lib/features/growth/presentation')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));

      for (final file in files) {
        final source = file.readAsStringSync();
        expect(source, isNot(contains('package:drift/')), reason: file.path);
        expect(source, isNot(contains('AppDatabase')), reason: file.path);
        expect(
          source,
          isNot(contains('growth_repository_impl.dart')),
          reason: file.path,
        );
        expect(source, isNot(contains('features/sync/')), reason: file.path);
      }
    },
  );

  test('fl_chart stays in presentation and domain remains Flutter-free', () {
    final domainFiles = Directory('lib/features/growth/domain')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    for (final file in domainFiles) {
      final source = file.readAsStringSync();
      expect(source, isNot(contains('fl_chart')), reason: file.path);
      expect(source, isNot(contains('package:flutter/')), reason: file.path);
    }
  });

  test('schema and main navigation order remain unchanged', () {
    final database = File(
      'lib/core/database/app_database.dart',
    ).readAsStringSync();
    final shell = File('lib/core/app/home_shell.dart').readAsStringSync();

    expect(database, contains('int get schemaVersion => 3'));
    final labels = ['今日', '复盘', '计划', '健康', '成长'];
    var previousIndex = -1;
    for (final label in labels) {
      final index = shell.indexOf("label: '$label'");
      expect(index, greaterThan(previousIndex), reason: label);
      previousIndex = index;
    }
    expect(RegExp(r'NavigationDestination\(').allMatches(shell), hasLength(5));
  });

  test('all primary pages and Settings remain registered in the router', () {
    final router = File('lib/core/router/app_router.dart').readAsStringSync();

    for (final page in [
      'TodayPage',
      'JournalPage',
      'PlanPage',
      'HealthPage',
      'GrowthPage',
      'SettingsPage',
    ]) {
      expect(router, contains('const $page()'), reason: page);
    }
  });
}
