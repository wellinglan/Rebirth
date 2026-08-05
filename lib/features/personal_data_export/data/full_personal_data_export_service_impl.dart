import 'dart:convert';
import 'dart:typed_data';

import 'package:rebirth/core/files/file_export.dart';
import 'package:rebirth/core/utils/date_time_service.dart';

import '../domain/full_personal_data_export.dart';
import '../domain/personal_data_backup.dart';
import '../domain/personal_data_backup_repository.dart';
import '../domain/personal_data_export_module.dart';
import 'personal_data_backup_encoder.dart';

typedef ActivePersonalDataExportUserReader = String? Function();
typedef PersonalDataReadTransaction =
    Future<T> Function<T>(Future<T> Function() action);

final class FullPersonalDataExportServiceImpl
    implements FullPersonalDataExportService {
  const FullPersonalDataExportServiceImpl({
    required this.registry,
    required this.fileExportAdapter,
    required this.dateTimeService,
    required this.activeUserId,
    required this.readTransaction,
    required this.appVersion,
    required this.databaseSchemaVersion,
    this.encoder = const PersonalDataBackupEncoder(),
  });

  final PersonalDataExportModuleRegistry registry;
  final FileExportAdapter fileExportAdapter;
  final DateTimeService dateTimeService;
  final ActivePersonalDataExportUserReader activeUserId;
  final PersonalDataReadTransaction readTransaction;
  final String appVersion;
  final int databaseSchemaVersion;
  final PersonalDataBackupEncoder encoder;

  @override
  Future<FullPersonalDataExportResult> export() async {
    final expectedUserId = _requireActiveUser();
    late final List<PersonalDataModuleSnapshot> snapshots;
    try {
      snapshots = await readTransaction(
        () => registry.exportAll(
          expectedUserId,
          checkBoundary: () => _requireSameActiveUser(expectedUserId),
        ),
      );
    } on FullPersonalDataExportException {
      rethrow;
    } on PersonalDataBackupSourceException {
      throw const FullPersonalDataExportException(
        FullPersonalDataExportFailure.sourceUnavailable,
      );
    } catch (_) {
      throw const FullPersonalDataExportException(
        FullPersonalDataExportFailure.sourceUnavailable,
      );
    }

    final snapshot = dateTimeService.currentSnapshot();
    late final PersonalDataBackupDocument document;
    late final bool integrityVerified;
    try {
      document = encoder.createDocument(
        exportedAt: _utcIso(snapshot.utcMilliseconds),
        appVersion: appVersion,
        databaseSchemaVersion: databaseSchemaVersion,
        modules: snapshots,
      );
      integrityVerified = encoder.verify(document);
    } catch (_) {
      throw const FullPersonalDataExportException(
        FullPersonalDataExportFailure.invalidData,
      );
    }
    if (!integrityVerified) {
      throw const FullPersonalDataExportException(
        FullPersonalDataExportFailure.integrityCheckFailed,
      );
    }

    late final String content;
    try {
      content = encoder.encode(document);
    } catch (_) {
      throw const FullPersonalDataExportException(
        FullPersonalDataExportFailure.invalidData,
      );
    }
    _requireSameActiveUser(expectedUserId);

    late final FileExportDisposition disposition;
    try {
      disposition = await fileExportAdapter.save(
        FileExportRequest(
          dialogTitle: '保存完整个人数据备份',
          fileName:
              'rebirth-personal-data-backup-${snapshot.localDateString}.json',
          extension: 'json',
          mimeType: 'application/json',
          bytes: Uint8List.fromList(utf8.encode(content)),
        ),
      );
    } catch (_) {
      throw const FullPersonalDataExportException(
        FullPersonalDataExportFailure.storageUnavailable,
      );
    }

    return FullPersonalDataExportResult(
      disposition: disposition == FileExportDisposition.saved
          ? FullPersonalDataExportDisposition.saved
          : FullPersonalDataExportDisposition.cancelled,
      moduleCount: document.modules.length,
      recordCount: document.totalRecordCount,
    );
  }

  String _requireActiveUser() {
    final value = activeUserId()?.trim();
    if (value == null || value.isEmpty) {
      throw const FullPersonalDataExportException(
        FullPersonalDataExportFailure.accessDenied,
      );
    }
    return value;
  }

  void _requireSameActiveUser(String expectedUserId) {
    if (_requireActiveUser() != expectedUserId) {
      throw const FullPersonalDataExportException(
        FullPersonalDataExportFailure.accessDenied,
      );
    }
  }

  String _utcIso(int milliseconds) => DateTime.fromMillisecondsSinceEpoch(
    milliseconds,
    isUtc: true,
  ).toIso8601String();
}
