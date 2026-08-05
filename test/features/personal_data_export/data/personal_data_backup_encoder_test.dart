import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/personal_data_export/data/personal_data_backup_encoder.dart';
import 'package:rebirth/features/personal_data_export/domain/personal_data_backup.dart';

void main() {
  const encoder = PersonalDataBackupEncoder();

  test('canonical JSON and SHA-256 repeat for identical fixed data', () {
    final first = encoder.createDocument(
      exportedAt: '2026-08-05T01:02:03.000Z',
      appVersion: '1.0.0+1',
      databaseSchemaVersion: 11,
      modules: [
        PersonalDataModuleSnapshot(
          id: 'test',
          records: [
            _MapRecord({'z': 0, 'a': null, 'text': '中文'}),
          ],
        ),
      ],
    );
    final second = encoder.createDocument(
      exportedAt: '2026-08-05T01:02:03.000Z',
      appVersion: '1.0.0+1',
      databaseSchemaVersion: 11,
      modules: [
        PersonalDataModuleSnapshot(
          id: 'test',
          records: [
            _MapRecord({'text': '中文', 'a': null, 'z': 0}),
          ],
        ),
      ],
    );

    expect(first.payloadSha256, hasLength(64));
    expect(first.payloadSha256, second.payloadSha256);
    expect(encoder.encode(first), encoder.encode(second));
    expect(encoder.verify(first), isTrue);
  });

  test('null, zero, empty text, Unicode, and long text remain distinct', () {
    final longText = '长' * 50000;
    final document = encoder.createDocument(
      exportedAt: '2026-08-05T01:02:03.000Z',
      appVersion: 'test',
      databaseSchemaVersion: 11,
      modules: [
        PersonalDataModuleSnapshot(
          id: 'test',
          records: [
            _MapRecord({
              'null_value': null,
              'zero_value': 0,
              'empty_value': '',
              'unicode_value': '成长🌱',
              'long_value': longText,
            }),
          ],
        ),
      ],
    );
    final decoded =
        jsonDecode(encoder.encode(document)) as Map<String, dynamic>;
    final record =
        (((decoded['data'] as Map)['test'] as Map)['records'] as List).single
            as Map;

    expect(record['null_value'], isNull);
    expect(record['zero_value'], 0);
    expect(record['empty_value'], '');
    expect(record['unicode_value'], '成长🌱');
    expect(record['long_value'], longText);
  });

  test('manifest records exclusions and restore remains unsupported', () {
    final document = encoder.createDocument(
      exportedAt: '2026-08-05T01:02:03.000Z',
      appVersion: 'test',
      databaseSchemaVersion: 11,
      modules: [
        PersonalDataModuleSnapshot(
          id: 'profile',
          records: [
            const ProfileBackupRecord(
              displayName: null,
              growthFocus: '',
              timezoneId: 'Asia/Shanghai',
              createdAt: '2026-08-05T00:00:00.000Z',
              updatedAt: '2026-08-05T00:00:00.000Z',
            ),
          ],
        ),
      ],
    );
    final decoded =
        jsonDecode(encoder.encode(document)) as Map<String, dynamic>;
    final manifest = decoded['manifest'] as Map<String, dynamic>;

    expect(decoded['format_id'], PersonalDataBackupDocument.currentFormatId);
    expect(decoded['format_version'], '1.0');
    expect(manifest['restore_supported'], isFalse);
    expect(
      manifest['derived_data_excluded'],
      containsAll(['growth', 'personal_data_aggregation']),
    );
    expect((manifest['record_counts'] as Map)['profile'], 1);
  });

  test('tampered payload fails verification and encoding', () {
    final document = encoder
        .createDocument(
          exportedAt: '2026-08-05T01:02:03.000Z',
          appVersion: 'test',
          databaseSchemaVersion: 11,
          modules: [
            PersonalDataModuleSnapshot(
              id: 'test',
              records: [
                _MapRecord({'value': 1}),
              ],
            ),
          ],
        )
        .copyWith(payloadSha256: '0' * 64);

    expect(encoder.verify(document), isFalse);
    expect(() => encoder.encode(document), throwsFormatException);
  });

  test('large history and multi-version reports encode without truncation', () {
    final history = List<PersonalDataBackupRecord>.generate(
      2000,
      (index) => _MapRecord({
        'id': 'history-$index',
        'sequence': index,
        'content': index == 1999
            ? 'final-entry-${'x' * 50000}'
            : 'entry-$index',
      }),
      growable: false,
    );
    final versions = List<AiReportVersionBackupRecord>.generate(
      250,
      (index) => AiReportVersionBackupRecord(
        version: index + 1,
        status: 'completed',
        content: 'report-version-${index + 1}',
        sensitivity: 'high',
        quality: 'unreviewed',
        createdAt: '2026-08-05T01:02:03.000Z',
        completedAt: '2026-08-05T01:02:04.000Z',
      ),
      growable: false,
    );
    final document = encoder.createDocument(
      exportedAt: '2026-08-05T01:02:03.000Z',
      appVersion: 'test',
      databaseSchemaVersion: 11,
      modules: [
        PersonalDataModuleSnapshot(id: 'history', records: history),
        PersonalDataModuleSnapshot(
          id: 'ai_reports',
          records: [
            AiReportBackupRecord(
              id: 'report-1',
              title: 'Long history report',
              reportType: 'weekly_report',
              periodStartDate: '2026-07-27',
              periodEndDate: '2026-08-02',
              lifecycleStatus: 'completed',
              currentVersion: 250,
              currentContent: 'report-version-250',
              sensitivity: 'high',
              quality: 'unreviewed',
              requestedAt: '2026-08-05T01:02:03.000Z',
              completedAt: '2026-08-05T01:02:04.000Z',
              createdAt: '2026-08-05T01:02:03.000Z',
              updatedAt: '2026-08-05T01:02:04.000Z',
              deletedAt: null,
              versions: versions,
            ),
          ],
        ),
      ],
    );

    final decoded =
        jsonDecode(encoder.encode(document)) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>;
    final decodedHistory =
        (data['history'] as Map<String, dynamic>)['records'] as List;
    final report =
        ((data['ai_reports'] as Map<String, dynamic>)['records'] as List).single
            as Map;
    final decodedVersions = report['versions'] as List;

    expect(decodedHistory, hasLength(2000));
    expect((decodedHistory.last as Map)['content'], endsWith('x' * 50000));
    expect(decodedVersions, hasLength(250));
    expect((decodedVersions.last as Map)['version'], 250);
    expect(encoder.verify(document), isTrue);
  });
}

final class _MapRecord implements PersonalDataBackupRecord {
  const _MapRecord(this.values);

  final Map<String, Object?> values;

  @override
  Map<String, Object?> toJson() => values;
}
