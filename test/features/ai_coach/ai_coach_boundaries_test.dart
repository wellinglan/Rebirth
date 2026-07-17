import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AI Coach domain remains pure Dart', () {
    final sources = _dartSources('lib/features/ai_coach/domain');
    for (final source in sources) {
      expect(source, isNot(contains('package:flutter')));
      expect(source, isNot(contains('package:drift')));
      expect(source, isNot(contains('package:dio')));
      expect(source, isNot(contains('app_database')));
    }
  });

  test('AI gateway contains no vendor URL or provider API key path', () {
    final sources = _dartSources('lib');
    for (final source in sources) {
      expect(source, isNot(contains('api.openai.com')));
      expect(source, isNot(contains('OPENAI_API_KEY')));
    }
  });

  test(
    'schema remains version 3 and presentation keeps local-only boundaries',
    () {
      final database = File(
        'lib/core/database/app_database.dart',
      ).readAsStringSync();
      expect(database, contains('int get schemaVersion => 3;'));
      final presentation = [
        ..._dartSources('lib/features/ai_coach/presentation/widgets'),
        File(
          'lib/features/ai_coach/presentation/ai_coach_page.dart',
        ).readAsStringSync(),
        File(
          'lib/features/ai_coach/presentation/ai_report_detail_page.dart',
        ).readAsStringSync(),
      ];
      expect(presentation, isNotEmpty);
      for (final source in presentation) {
        expect(source, isNot(contains('package:drift')));
        expect(source, isNot(contains('app_database')));
        expect(source, isNot(contains('local_ai_')));
        expect(source, isNot(contains('core/network')));
        expect(source, isNot(contains('ApiClient')));
        expect(source, isNot(contains('createPending(')));
        expect(source, isNot(contains('markCompleted(')));
        expect(source, isNot(contains('markFailed(')));
        expect(source, isNot(contains('DateTime.now')));
      }
    },
  );

  test('AI Coach UI does not expose canonical JSON or snapshot bodies', () {
    final presentation = _dartSources('lib/features/ai_coach/presentation');
    for (final source in presentation) {
      expect(source, isNot(contains('.canonicalJson')));
      expect(source, isNot(contains('inputSnapshotJson')));
    }
  });
}

Iterable<String> _dartSources(String path) {
  return Directory(path)
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .map((file) => file.readAsStringSync());
}
