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

  test('AI foundation adds no network client, vendor, or API key path', () {
    final sources = _dartSources('lib/features/ai_coach');
    for (final source in sources) {
      expect(source, isNot(contains('package:dio')));
      expect(source, isNot(contains('core/network')));
      expect(source, isNot(contains('ApiClient')));
      expect(source, isNot(contains('OpenAI')));
      expect(source, isNot(contains('Anthropic')));
      expect(source, isNot(contains('Gemini')));
      expect(source.toLowerCase(), isNot(contains('api_key')));
    }
  });

  test('schema remains version 3 and no AI Coach page is introduced', () {
    final database = File(
      'lib/core/database/app_database.dart',
    ).readAsStringSync();
    expect(database, contains('int get schemaVersion => 3;'));
    expect(
      Directory('lib/features/ai_coach/presentation')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart')),
      isEmpty,
    );
  });
}

Iterable<String> _dartSources(String path) {
  return Directory(path)
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .map((file) => file.readAsStringSync());
}
