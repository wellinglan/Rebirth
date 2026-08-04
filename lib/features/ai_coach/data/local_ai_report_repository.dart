import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:rebirth/core/database/app_database.dart' as db;
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/ai_coach/domain/ai_coach_exception.dart';
import 'package:rebirth/features/ai_coach/domain/ai_coach_input_bundle.dart';
import 'package:rebirth/features/ai_coach/domain/ai_consent_repository.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_scope.dart';
import 'package:rebirth/features/ai_coach/domain/ai_generation_mode.dart';
import 'package:rebirth/features/ai_coach/domain/ai_input_source_ref.dart';
import 'package:rebirth/features/ai_coach/domain/ai_input_contract.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report.dart' as domain;
import 'package:rebirth/features/ai_coach/domain/ai_report_lifecycle.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_metadata.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_repository.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_status.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_type.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_version.dart';
import 'package:rebirth/features/ai_coach/domain/canonical_json_encoder.dart';
import 'package:uuid/uuid.dart';

final class LocalAiReportRepository implements AiReportRepository {
  LocalAiReportRepository({
    required this.database,
    required this.dateTimeService,
    required this.consentRepository,
    required this.canonicalJsonEncoder,
    String Function()? idFactory,
  }) : idFactory = idFactory ?? const Uuid().v4;

  final db.AppDatabase database;
  final DateTimeService dateTimeService;
  final AiConsentRepository consentRepository;
  final CanonicalJsonEncoder canonicalJsonEncoder;
  final String Function() idFactory;

  @override
  Future<domain.AiReport> createDraft({
    required AiReportType reportType,
    required String title,
    required String periodStartDate,
    required String periodEndDate,
    String generationSource = 'fake',
    AiReportSensitivity sensitivity = AiReportSensitivity.high,
  }) async {
    final normalizedTitle = title.trim();
    final normalizedSource = generationSource.trim();
    if (normalizedTitle.isEmpty ||
        normalizedSource.isEmpty ||
        !dateTimeService.isValidLocalDateString(periodStartDate) ||
        !dateTimeService.isValidLocalDateString(periodEndDate) ||
        periodEndDate.compareTo(periodStartDate) < 0) {
      throw const InvalidAiInputException('Invalid AI report draft.');
    }
    final bootstrap = await database.bootstrapDao.bootstrap();
    final now = dateTimeService.currentSnapshot().utcMilliseconds;
    final reportId = idFactory();
    await database
        .into(database.aiReports)
        .insert(
          db.AiReportsCompanion.insert(
            id: Value(reportId),
            userId: bootstrap.activeUserId,
            reportType: reportType.databaseValue,
            title: Value(normalizedTitle),
            periodStartDate: periodStartDate,
            periodEndDate: periodEndDate,
            inputHash: 'report-foundation:$reportId',
            promptVersion: 'report-foundation-v1',
            generationMode: const Value('manual'),
            reportStatus: const Value('draft'),
            generationSource: Value(normalizedSource),
            sensitivity: Value(sensitivity.databaseValue),
            quality: const Value('unknown'),
            requestedAt: now,
            createdAt: Value(now),
            updatedAt: Value(now),
            syncStatus: const Value('local_only'),
          ),
        );
    return _toDomain(await _getActiveRow(reportId, bootstrap.activeUserId));
  }

  @override
  Future<domain.AiReport> beginGeneration(String reportId) async {
    final bootstrap = await database.bootstrapDao.bootstrap();
    final now = dateTimeService.currentSnapshot().utcMilliseconds;
    return database.transaction(() async {
      final existing = await _getActiveRow(reportId, bootstrap.activeUserId);
      final current = AiReportStatus.fromDatabaseValue(existing.reportStatus);
      AiReportLifecycle.requireTransition(current, AiReportStatus.generating);
      await (database.update(
        database.aiReports,
      )..where((row) => row.id.equals(reportId))).write(
        db.AiReportsCompanion(
          reportStatus: const Value('generating'),
          errorCode: const Value(null),
          generatedAt: const Value(null),
          updatedAt: Value(now),
        ),
      );
      return _toDomain(await _getActiveRow(reportId, bootstrap.activeUserId));
    });
  }

  @override
  Future<domain.AiReport> completeVersion({
    required String reportId,
    required String content,
    required String generationSource,
    String? modelMetadataJson,
    AiReportSensitivity sensitivity = AiReportSensitivity.high,
    AiReportQuality quality = AiReportQuality.unreviewed,
  }) async {
    final normalizedContent = content.trim();
    final normalizedSource = generationSource.trim();
    if (normalizedContent.isEmpty || normalizedSource.isEmpty) {
      throw const InvalidAiInputException(
        'Completed AI report content must not be empty.',
      );
    }
    final bootstrap = await database.bootstrapDao.bootstrap();
    final now = dateTimeService.currentSnapshot().utcMilliseconds;
    return database.transaction(() async {
      final existing = await _getActiveRow(reportId, bootstrap.activeUserId);
      final current = AiReportStatus.fromDatabaseValue(existing.reportStatus);
      AiReportLifecycle.requireTransition(current, AiReportStatus.completed);
      final version = await _insertVersion(
        report: existing,
        status: AiReportStatus.completed,
        generationSource: normalizedSource,
        modelMetadataJson: _trimToNull(modelMetadataJson),
        content: normalizedContent,
        sensitivity: sensitivity,
        quality: quality,
        errorCode: null,
        now: now,
      );
      await (database.update(
        database.aiReports,
      )..where((row) => row.id.equals(reportId))).write(
        db.AiReportsCompanion(
          reportStatus: const Value('completed'),
          generationSource: Value(normalizedSource),
          sensitivity: Value(sensitivity.databaseValue),
          quality: Value(quality.databaseValue),
          currentVersion: Value(version),
          reportContent: Value(normalizedContent),
          errorCode: const Value(null),
          generatedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      return _toDomain(
        await _getActiveRow(reportId, bootstrap.activeUserId),
        versions: await _listVersionsFor(reportId),
      );
    });
  }

  @override
  Future<domain.AiReport> failVersion({
    required String reportId,
    required String errorCode,
    required String generationSource,
  }) async {
    final normalizedSource = generationSource.trim();
    if (!AiReportFailureCode.isSupported(errorCode) ||
        normalizedSource.isEmpty) {
      throw const InvalidAiInputException('Invalid AI report failure.');
    }
    final bootstrap = await database.bootstrapDao.bootstrap();
    final now = dateTimeService.currentSnapshot().utcMilliseconds;
    return database.transaction(() async {
      final existing = await _getActiveRow(reportId, bootstrap.activeUserId);
      final current = AiReportStatus.fromDatabaseValue(existing.reportStatus);
      AiReportLifecycle.requireTransition(current, AiReportStatus.failed);
      final version = await _insertVersion(
        report: existing,
        status: AiReportStatus.failed,
        generationSource: normalizedSource,
        content: null,
        sensitivity: AiReportSensitivity.fromDatabaseValue(
          existing.sensitivity,
        ),
        quality: AiReportQuality.unknown,
        errorCode: errorCode.trim(),
        now: now,
      );
      await (database.update(
        database.aiReports,
      )..where((row) => row.id.equals(reportId))).write(
        db.AiReportsCompanion(
          reportStatus: const Value('failed'),
          generationSource: Value(normalizedSource),
          quality: const Value('unknown'),
          currentVersion: Value(version),
          errorCode: Value(errorCode.trim()),
          updatedAt: Value(now),
        ),
      );
      return _toDomain(
        await _getActiveRow(reportId, bootstrap.activeUserId),
        versions: await _listVersionsFor(reportId),
      );
    });
  }

  @override
  Future<domain.AiReport> archive(String reportId) async {
    final bootstrap = await database.bootstrapDao.bootstrap();
    final now = dateTimeService.currentSnapshot().utcMilliseconds;
    return database.transaction(() async {
      final existing = await _getActiveRow(reportId, bootstrap.activeUserId);
      final current = AiReportStatus.fromDatabaseValue(existing.reportStatus);
      AiReportLifecycle.requireTransition(current, AiReportStatus.archived);
      await (database.update(
        database.aiReports,
      )..where((row) => row.id.equals(reportId))).write(
        db.AiReportsCompanion(
          reportStatus: const Value('archived'),
          updatedAt: Value(now),
        ),
      );
      return _toDomain(
        await _getActiveRow(reportId, bootstrap.activeUserId),
        versions: await _listVersionsFor(reportId),
      );
    });
  }

  @override
  Future<List<AiReportVersion>> listVersions(String reportId) async {
    final bootstrap = await database.bootstrapDao.bootstrap();
    await _getActiveRow(reportId, bootstrap.activeUserId);
    return _listVersionsFor(reportId);
  }

  @override
  Future<domain.AiReport> createPending({
    required AiCoachInputBundle input,
  }) async {
    final authorization = await consentRepository.read();
    if (!authorization.enabled) throw const AiConsentRequiredException();
    if (!AiInputContract.isSupportedReportType(input.reportType)) {
      throw UnsupportedAiReportTypeException(input.reportType.databaseValue);
    }
    final expectedPrompt = AiInputContract.promptVersionFor(input.reportType);
    final isDaily = input.reportType == AiReportType.dailyInsight;
    if (!dateTimeService.isValidLocalDateString(input.periodStartDate) ||
        !dateTimeService.isValidLocalDateString(input.periodEndDate) ||
        input.promptVersion != expectedPrompt ||
        (isDaily && input.periodStartDate != input.periodEndDate) ||
        (!isDaily &&
            dateTimeService
                    .recentLocalDateRange(
                      AiInputContract.weeklyPeriodDays,
                      endingAt: DateTime.parse(input.periodEndDate),
                    )
                    .first !=
                input.periodStartDate)) {
      throw const InvalidAiInputException('Invalid AI report contract.');
    }

    final bootstrap = await database.bootstrapDao.bootstrap();
    final now = dateTimeService.currentSnapshot().utcMilliseconds;
    final reportId = idFactory();
    final scopes =
        input.selection.scopes
            .map((scope) => scope.contractValue)
            .toList(growable: false)
          ..sort();
    final inputSourcesJson = canonicalJsonEncoder.encode({
      'input_schema_version': AiInputContract.schemaVersion,
      'metadata_version': 1,
      'scopes': scopes,
      'sources': input.sources
          .map((source) => source.toCanonicalMap())
          .toList(growable: false),
    });
    await database
        .into(database.aiReports)
        .insert(
          db.AiReportsCompanion.insert(
            id: Value(reportId),
            userId: bootstrap.activeUserId,
            reportType: input.reportType.databaseValue,
            title: Value(_defaultTitle(input.reportType)),
            periodStartDate: input.periodStartDate,
            periodEndDate: input.periodEndDate,
            inputSourcesJson: Value(inputSourcesJson),
            inputHash: input.inputHash,
            inputSnapshotJson: input.selection.persistInputSnapshot
                ? Value(input.canonicalJson)
                : const Value(null),
            promptVersion: input.promptVersion,
            generationMode: const Value('manual'),
            reportStatus: const Value('pending'),
            generationSource: const Value('remote_ai'),
            sensitivity: const Value('high'),
            quality: const Value('unknown'),
            requestedAt: now,
            createdAt: Value(now),
            updatedAt: Value(now),
            syncStatus: const Value('local_only'),
          ),
        );
    final row = await _getActiveRow(reportId, bootstrap.activeUserId);
    return _toDomain(row);
  }

  @override
  Future<domain.AiReport> markCompleted({
    required String reportId,
    required String reportContent,
    String? structuredOutputJson,
    String? provider,
    String? model,
  }) async {
    final metadata = <String, String>{};
    if (_trimToNull(provider) case final value?) metadata['provider'] = value;
    if (_trimToNull(model) case final value?) metadata['model'] = value;
    final result = await completeVersion(
      reportId: reportId,
      content: reportContent,
      generationSource: 'remote_ai',
      modelMetadataJson: jsonEncode(metadata),
    );
    final bootstrap = await database.bootstrapDao.bootstrap();
    await (database.update(database.aiReports)..where(
          (row) =>
              row.id.equals(reportId) &
              row.userId.equals(bootstrap.activeUserId),
        ))
        .write(
          db.AiReportsCompanion(
            structuredOutputJson: Value(_trimToNull(structuredOutputJson)),
            provider: Value(_trimToNull(provider)),
            model: Value(_trimToNull(model)),
          ),
        );
    return _toDomain(
      await _getActiveRow(reportId, bootstrap.activeUserId),
      versions: result.versions,
    );
  }

  @override
  Future<domain.AiReport> markFailed({
    required String reportId,
    required String errorCode,
  }) async {
    if (!AiReportFailureCode.isSupported(errorCode)) {
      throw const InvalidAiInputException(
        'AI report failure code is not supported.',
      );
    }
    return failVersion(
      reportId: reportId,
      errorCode: errorCode,
      generationSource: 'remote_ai',
    );
  }

  @override
  Future<domain.AiReport?> findReusableCompleted({
    required AiReportType reportType,
    required String periodStartDate,
    required String periodEndDate,
    required String promptVersion,
    required String inputHash,
  }) async {
    final bootstrap = await database.bootstrapDao.bootstrap();
    final query = database.select(database.aiReports)
      ..where(
        (row) =>
            row.userId.equals(bootstrap.activeUserId) &
            row.reportType.equals(reportType.databaseValue) &
            row.periodStartDate.equals(periodStartDate) &
            row.periodEndDate.equals(periodEndDate) &
            row.promptVersion.equals(promptVersion) &
            row.inputHash.equals(inputHash) &
            row.reportStatus.equals('completed') &
            row.deletedAt.isNull(),
      )
      ..orderBy([
        (row) => OrderingTerm.desc(row.generatedAt),
        (row) => OrderingTerm.desc(row.requestedAt),
      ])
      ..limit(1);
    final result = await query.getSingleOrNull();
    return result == null ? null : _toDomain(result);
  }

  @override
  Future<domain.AiReport?> getById(String id) async {
    final bootstrap = await database.bootstrapDao.bootstrap();
    final row =
        await (database.select(database.aiReports)..where(
              (row) =>
                  row.id.equals(id) &
                  row.userId.equals(bootstrap.activeUserId) &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<List<domain.AiReport>> listRecent({int limit = 20}) async {
    if (limit <= 0) return const [];
    final bootstrap = await database.bootstrapDao.bootstrap();
    final rows =
        await (database.select(database.aiReports)
              ..where(
                (row) =>
                    row.userId.equals(bootstrap.activeUserId) &
                    row.deletedAt.isNull(),
              )
              ..orderBy([(row) => OrderingTerm.desc(row.requestedAt)])
              ..limit(limit))
            .get();
    return rows.map(_toDomain).toList(growable: false);
  }

  @override
  Future<List<domain.AiReport>> listPending() async {
    final bootstrap = await database.bootstrapDao.bootstrap();
    final rows =
        await (database.select(database.aiReports)
              ..where(
                (row) =>
                    row.userId.equals(bootstrap.activeUserId) &
                    row.reportStatus.equals('pending') &
                    row.deletedAt.isNull(),
              )
              ..orderBy([(row) => OrderingTerm.asc(row.requestedAt)]))
            .get();
    return rows.map(_toDomain).toList(growable: false);
  }

  @override
  Future<void> softDelete(String id) async {
    final bootstrap = await database.bootstrapDao.bootstrap();
    final now = dateTimeService.currentSnapshot().utcMilliseconds;
    await _getActiveRow(id, bootstrap.activeUserId);
    await (database.update(database.aiReports)..where(
          (row) =>
              row.id.equals(id) &
              row.userId.equals(bootstrap.activeUserId) &
              row.deletedAt.isNull(),
        ))
        .write(
          db.AiReportsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
        );
  }

  Future<db.AiReport> _getActiveRow(String id, String userId) async {
    final row =
        await (database.select(database.aiReports)..where(
              (row) =>
                  row.id.equals(id) &
                  row.userId.equals(userId) &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (row == null) throw AiReportNotFoundException(id);
    return row;
  }

  domain.AiReport _toDomain(
    db.AiReport row, {
    List<AiReportVersion> versions = const [],
  }) {
    final metadata = _decodeInputMetadata(row.inputSourcesJson);
    return domain.AiReport(
      id: row.id,
      userId: row.userId,
      reportType: AiReportType.fromDatabaseValue(row.reportType),
      periodStartDate: row.periodStartDate,
      periodEndDate: row.periodEndDate,
      inputSources: metadata.sources,
      selectedScopes: metadata.selectedScopes,
      inputMetadataVersion: metadata.metadataVersion,
      inputSchemaVersion: metadata.inputSchemaVersion,
      inputHash: row.inputHash,
      promptVersion: row.promptVersion,
      provider: row.provider,
      model: row.model,
      generationMode: AiGenerationMode.fromDatabaseValue(row.generationMode),
      status: AiReportStatus.fromDatabaseValue(row.reportStatus),
      reportContent: row.reportContent,
      structuredOutputJson: row.structuredOutputJson,
      hasInputSnapshot: row.inputSnapshotJson != null,
      errorCode: row.errorCode,
      requestedAt: row.requestedAt,
      generatedAt: row.generatedAt,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      title: row.title,
      generationSource: row.generationSource,
      sensitivity: AiReportSensitivity.fromDatabaseValue(row.sensitivity),
      quality: AiReportQuality.fromDatabaseValue(row.quality),
      currentVersion: row.currentVersion,
      versions: versions,
    );
  }

  Future<int> _insertVersion({
    required db.AiReport report,
    required AiReportStatus status,
    required String generationSource,
    String? modelMetadataJson,
    required String? content,
    required AiReportSensitivity sensitivity,
    required AiReportQuality quality,
    required String? errorCode,
    required int now,
  }) async {
    final nextRow = await database
        .customSelect(
          'SELECT COALESCE(MAX(version), 0) + 1 AS next_version '
          'FROM ai_report_versions WHERE report_id = ?',
          variables: [Variable.withString(report.id)],
        )
        .getSingle();
    final version = nextRow.read<int>('next_version');
    await database
        .into(database.aiReportVersions)
        .insert(
          db.AiReportVersionsCompanion.insert(
            id: Value(idFactory()),
            reportId: report.id,
            version: version,
            status: status.databaseValue,
            generationSource: generationSource,
            modelMetadataJson: Value(modelMetadataJson),
            content: Value(content),
            sensitivity: sensitivity.databaseValue,
            quality: quality.databaseValue,
            errorCode: Value(errorCode),
            completedAt: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return version;
  }

  Future<List<AiReportVersion>> _listVersionsFor(String reportId) async {
    final rows =
        await (database.select(database.aiReportVersions)
              ..where((row) => row.reportId.equals(reportId))
              ..orderBy([(row) => OrderingTerm.desc(row.version)]))
            .get();
    return rows
        .map(
          (row) => AiReportVersion(
            id: row.id,
            reportId: row.reportId,
            version: row.version,
            status: AiReportStatus.fromDatabaseValue(row.status),
            generationSource: row.generationSource,
            modelMetadataJson: row.modelMetadataJson,
            content: row.content,
            sensitivity: AiReportSensitivity.fromDatabaseValue(row.sensitivity),
            quality: AiReportQuality.fromDatabaseValue(row.quality),
            errorCode: row.errorCode,
            createdAt: row.createdAt,
            completedAt: row.completedAt,
          ),
        )
        .toList(growable: false);
  }

  String _defaultTitle(AiReportType type) => switch (type) {
    AiReportType.dailyInsight => '每日洞察',
    AiReportType.weeklyReport => '每周回顾',
    AiReportType.monthlyReflection => '月度复盘',
    AiReportType.tomorrowSuggestion => '明日建议',
    AiReportType.trendExplanation => '趋势说明',
  };

  _StoredInputMetadata _decodeInputMetadata(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is List) {
        return _StoredInputMetadata(sources: _decodeSources(decoded));
      }
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      final metadataVersion = decoded['metadata_version'];
      final inputSchemaVersion = decoded['input_schema_version'];
      final rawScopes = decoded['scopes'];
      final rawSources = decoded['sources'];
      if (metadataVersion is! int ||
          inputSchemaVersion is! int ||
          rawScopes is! List ||
          rawSources is! List) {
        throw const FormatException();
      }
      final selectedScopes = rawScopes.map((value) {
        if (value is! String) throw const FormatException();
        return AiDataScope.values.firstWhere(
          (scope) => scope.contractValue == value,
          orElse: () => throw const FormatException(),
        );
      }).toSet();
      return _StoredInputMetadata(
        sources: _decodeSources(rawSources),
        selectedScopes: selectedScopes,
        metadataVersion: metadataVersion,
        inputSchemaVersion: inputSchemaVersion,
      );
    } catch (_) {
      throw const InvalidAiInputException(
        'Stored AI source references are invalid.',
      );
    }
  }

  List<AiInputSourceRef> _decodeSources(List<dynamic> values) {
    return values
        .map((item) {
          if (item is! Map<String, dynamic>) throw const FormatException();
          final table = item['table'];
          final id = item['id'];
          final updatedAt = item['updated_at'];
          if (table is! String || id is! String || updatedAt is! int) {
            throw const FormatException();
          }
          return AiInputSourceRef(table: table, id: id, updatedAt: updatedAt);
        })
        .toList(growable: false);
  }

  String? _trimToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

final class _StoredInputMetadata {
  const _StoredInputMetadata({
    required this.sources,
    this.selectedScopes,
    this.metadataVersion,
    this.inputSchemaVersion,
  });

  final List<AiInputSourceRef> sources;
  final Set<AiDataScope>? selectedScopes;
  final int? metadataVersion;
  final int? inputSchemaVersion;
}
