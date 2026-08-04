import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'AI Report presentation does not access persistence implementations',
    () {
      final files = Directory(
        'lib/features/ai_reports/presentation',
      ).listSync(recursive: true).whereType<File>();
      for (final file in files) {
        final source = file.readAsStringSync();
        expect(source, isNot(contains('package:drift/')), reason: file.path);
        expect(source, isNot(contains('AppDatabase')), reason: file.path);
        expect(
          source,
          isNot(contains('LocalAiReportRepository')),
          reason: file.path,
        );
        expect(source, isNot(contains('modelMetadataJson')), reason: file.path);
      }
    },
  );

  test('Growth and personal data do not consume AI Report', () {
    for (final root in const [
      'lib/features/growth',
      'lib/features/personal_data',
    ]) {
      final files = Directory(root).listSync(recursive: true).whereType<File>();
      for (final file in files) {
        final source = file.readAsStringSync();
        expect(source, isNot(contains('AiReport')), reason: file.path);
        expect(source, isNot(contains('ai_reports')), reason: file.path);
      }
    }
  });
}
