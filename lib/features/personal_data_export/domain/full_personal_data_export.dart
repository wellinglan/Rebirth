abstract interface class FullPersonalDataExportService {
  Future<FullPersonalDataExportResult> export();
}

enum FullPersonalDataExportDisposition { saved, cancelled }

final class FullPersonalDataExportResult {
  const FullPersonalDataExportResult({
    required this.disposition,
    required this.moduleCount,
    required this.recordCount,
  });

  final FullPersonalDataExportDisposition disposition;
  final int moduleCount;
  final int recordCount;
}

enum FullPersonalDataExportFailure {
  accessDenied,
  sourceUnavailable,
  invalidData,
  integrityCheckFailed,
  storageUnavailable,
}

final class FullPersonalDataExportException implements Exception {
  const FullPersonalDataExportException(this.failure);

  final FullPersonalDataExportFailure failure;
}
