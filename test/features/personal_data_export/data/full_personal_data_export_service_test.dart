import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/files/file_export.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/personal_data_export/data/full_personal_data_export_service_impl.dart';
import 'package:rebirth/features/personal_data_export/data/personal_data_backup_encoder.dart';
import 'package:rebirth/features/personal_data_export/domain/full_personal_data_export.dart';
import 'package:rebirth/features/personal_data_export/domain/personal_data_backup.dart';
import 'package:rebirth/features/personal_data_export/domain/personal_data_export_module.dart';

void main() {
  late String? activeUserId;
  late _RecordingFileAdapter adapter;

  setUp(() {
    activeUserId = 'account-a';
    adapter = _RecordingFileAdapter();
  });

  FullPersonalDataExportServiceImpl buildService({
    List<PersonalDataExportModule>? modules,
    PersonalDataBackupEncoder encoder = const PersonalDataBackupEncoder(),
  }) {
    return FullPersonalDataExportServiceImpl(
      registry: PersonalDataExportModuleRegistry(
        modules ?? [_StaticModule('profile', 'account-a-data')],
      ),
      fileExportAdapter: adapter,
      dateTimeService: DateTimeService(
        now: () => DateTime.utc(2026, 8, 5, 1, 2, 3),
      ),
      activeUserId: () => activeUserId,
      readTransaction: <T>(action) => action(),
      appVersion: '1.0.0+1',
      databaseSchemaVersion: 11,
      encoder: encoder,
    );
  }

  test('successful export writes one UTF-8 verified JSON file', () async {
    final result = await buildService(
      modules: [
        _StaticModule('profile', 'account-a-profile'),
        _StaticModule('plan', 'account-a-plan'),
      ],
    ).export();
    final request = adapter.requests.single;
    final decoded =
        jsonDecode(utf8.decode(request.bytes)) as Map<String, dynamic>;

    expect(result.disposition, FullPersonalDataExportDisposition.saved);
    expect(result.moduleCount, 2);
    expect(result.recordCount, 2);
    expect(request.fileName, 'rebirth-personal-data-backup-2026-08-05.json');
    expect(request.mimeType, 'application/json');
    expect(decoded['payload_sha256'], hasLength(64));
    expect(decoded['data'].toString(), contains('account-a-profile'));
  });

  test(
    'account switch before save aborts without opening file picker',
    () async {
      var boundaryChecks = 0;
      final service = FullPersonalDataExportServiceImpl(
        registry: PersonalDataExportModuleRegistry([
          _CallbackModule('profile', () async {
            activeUserId = 'account-b';
            return _snapshot('profile', 'account-a-data');
          }),
        ]),
        fileExportAdapter: adapter,
        dateTimeService: const DateTimeService(),
        activeUserId: () {
          boundaryChecks += 1;
          return activeUserId;
        },
        readTransaction: <T>(action) => action(),
        appVersion: 'test',
        databaseSchemaVersion: 11,
      );

      await expectLater(
        service.export(),
        throwsA(
          isA<FullPersonalDataExportException>().having(
            (error) => error.failure,
            'failure',
            FullPersonalDataExportFailure.accessDenied,
          ),
        ),
      );
      expect(boundaryChecks, greaterThanOrEqualTo(2));
      expect(adapter.requests, isEmpty);
    },
  );

  test('one module failure closes the whole backup', () async {
    final service = buildService(
      modules: [
        _StaticModule('profile', 'ok'),
        _CallbackModule('health', () => Future.error(StateError('failed'))),
      ],
    );

    await expectLater(
      service.export(),
      throwsA(
        isA<FullPersonalDataExportException>().having(
          (error) => error.failure,
          'failure',
          FullPersonalDataExportFailure.sourceUnavailable,
        ),
      ),
    );
    expect(adapter.requests, isEmpty);
  });

  test('integrity failure refuses to write the file', () async {
    await expectLater(
      buildService(encoder: const _FailingIntegrityEncoder()).export(),
      throwsA(
        isA<FullPersonalDataExportException>().having(
          (error) => error.failure,
          'failure',
          FullPersonalDataExportFailure.integrityCheckFailed,
        ),
      ),
    );
    expect(adapter.requests, isEmpty);
  });

  test('invalid canonical data refuses to open the file picker', () async {
    await expectLater(
      buildService(encoder: const _ThrowingEncoder()).export(),
      throwsA(
        isA<FullPersonalDataExportException>().having(
          (error) => error.failure,
          'failure',
          FullPersonalDataExportFailure.invalidData,
        ),
      ),
    );
    expect(adapter.requests, isEmpty);
  });

  test(
    'picker cancellation and storage failure are controlled and retryable',
    () async {
      adapter.disposition = FileExportDisposition.cancelled;
      final service = buildService();
      final cancelled = await service.export();
      expect(
        cancelled.disposition,
        FullPersonalDataExportDisposition.cancelled,
      );

      adapter.error = StateError(r'C:\private\backup.json');
      await expectLater(
        service.export(),
        throwsA(
          isA<FullPersonalDataExportException>().having(
            (error) => error.failure,
            'failure',
            FullPersonalDataExportFailure.storageUnavailable,
          ),
        ),
      );
      adapter.error = null;
      adapter.disposition = FileExportDisposition.saved;
      expect(
        (await service.export()).disposition,
        FullPersonalDataExportDisposition.saved,
      );
    },
  );

  test('registry rejects duplicate module IDs', () {
    expect(
      () => PersonalDataExportModuleRegistry([
        _StaticModule('profile', 'one'),
        _StaticModule('profile', 'two'),
      ]),
      throwsArgumentError,
    );
  });
}

PersonalDataModuleSnapshot _snapshot(String id, String value) {
  return PersonalDataModuleSnapshot(id: id, records: [_TextRecord(value)]);
}

final class _StaticModule implements PersonalDataExportModule {
  const _StaticModule(this.id, this.value);

  @override
  final String id;
  final String value;

  @override
  Future<PersonalDataModuleSnapshot> export(String localUserId) async {
    return _snapshot(id, value);
  }
}

final class _CallbackModule implements PersonalDataExportModule {
  const _CallbackModule(this.id, this.callback);

  @override
  final String id;
  final Future<PersonalDataModuleSnapshot> Function() callback;

  @override
  Future<PersonalDataModuleSnapshot> export(String localUserId) => callback();
}

final class _TextRecord implements PersonalDataBackupRecord {
  const _TextRecord(this.value);

  final String value;

  @override
  Map<String, Object?> toJson() => {'value': value};
}

final class _RecordingFileAdapter implements FileExportAdapter {
  final List<FileExportRequest> requests = [];
  FileExportDisposition disposition = FileExportDisposition.saved;
  Object? error;

  @override
  Future<FileExportDisposition> save(FileExportRequest request) async {
    if (error case final value?) throw value;
    requests.add(request);
    return disposition;
  }
}

final class _FailingIntegrityEncoder extends PersonalDataBackupEncoder {
  const _FailingIntegrityEncoder();

  @override
  bool verify(PersonalDataBackupDocument document) => false;
}

final class _ThrowingEncoder extends PersonalDataBackupEncoder {
  const _ThrowingEncoder();

  @override
  PersonalDataBackupDocument createDocument({
    required String exportedAt,
    required String appVersion,
    required int databaseSchemaVersion,
    required List<PersonalDataModuleSnapshot> modules,
  }) {
    throw const FormatException('invalid canonical data');
  }
}
