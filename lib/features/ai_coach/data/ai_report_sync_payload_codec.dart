import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_metadata.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_status.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_sync_payload.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_type.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_payload_codec.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_exception.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';

final class AiReportSyncPayloadCodec implements SyncConflictPayloadCodec {
  const AiReportSyncPayloadCodec([
    this._dateTimeService = const DateTimeService(),
  ]);

  static final _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );
  static const _synchronizedStatuses = {
    AiReportStatus.completed,
    AiReportStatus.failed,
    AiReportStatus.archived,
  };

  final DateTimeService _dateTimeService;

  @override
  SyncEntityType get entityType => SyncEntityType.aiReport;

  @override
  Map<String, Object?> encode(SyncEntityPayload payload) {
    if (payload is! AiReportSyncPayload) {
      throw const SyncException('AI 报告同步 payload 类型无效。');
    }
    validate(payload);
    return SplayTreeMap<String, Object?>.of({
      'created_at': payload.createdAt,
      'current_version': payload.currentVersion,
      'generation_source': payload.generationSource,
      'period_end_date': payload.periodEndDate,
      'period_start_date': payload.periodStartDate,
      'quality': payload.quality.databaseValue,
      'report_status': payload.status.databaseValue,
      'report_type': payload.reportType.databaseValue,
      'sensitivity': payload.sensitivity.databaseValue,
      'title': payload.title,
      'versions': payload.versions.map(_encodeVersion).toList(growable: false),
    });
  }

  @override
  AiReportSyncPayload decode({
    required String recordId,
    required Map<String, Object?> json,
  }) {
    if (!isUuid(recordId)) {
      throw const SyncException('云端 AI 报告 ID 不是合法 UUID。');
    }
    const requiredKeys = {
      'created_at',
      'current_version',
      'generation_source',
      'period_end_date',
      'period_start_date',
      'quality',
      'report_status',
      'report_type',
      'sensitivity',
      'title',
      'versions',
    };
    if (json.length != requiredKeys.length ||
        !json.keys.every(requiredKeys.contains)) {
      throw const SyncException('云端 AI 报告 payload 字段集合无效。');
    }
    final rawVersions = json['versions'];
    if (rawVersions is! List) {
      throw const SyncException('云端 AI 报告版本列表无效。');
    }
    final payload = AiReportSyncPayload(
      reportType: AiReportType.fromDatabaseValue(_string(json, 'report_type')),
      title: _string(json, 'title'),
      periodStartDate: _string(json, 'period_start_date'),
      periodEndDate: _string(json, 'period_end_date'),
      status: AiReportStatus.fromDatabaseValue(_string(json, 'report_status')),
      createdAt: _int(json, 'created_at'),
      generationSource: _string(json, 'generation_source'),
      sensitivity: AiReportSensitivity.fromDatabaseValue(
        _string(json, 'sensitivity'),
      ),
      quality: AiReportQuality.fromDatabaseValue(_string(json, 'quality')),
      currentVersion: _int(json, 'current_version'),
      versions: rawVersions
          .map((item) {
            if (item is! Map) {
              throw const SyncException('云端 AI 报告版本字段无效。');
            }
            return _decodeVersion(Map<String, Object?>.from(item));
          })
          .toList(growable: false),
    );
    validate(payload);
    return payload;
  }

  String canonicalJson(AiReportSyncPayload payload) =>
      jsonEncode(encode(payload));

  String fingerprint(AiReportSyncPayload payload) =>
      sha256.convert(utf8.encode(canonicalJson(payload))).toString();

  void validate(AiReportSyncPayload payload) {
    if (!_synchronizedStatuses.contains(payload.status) ||
        payload.title.trim().isEmpty ||
        payload.title.length > 200 ||
        payload.generationSource.trim().isEmpty ||
        payload.generationSource.length > 80 ||
        payload.createdAt < 0 ||
        payload.currentVersion < 1 ||
        !_dateTimeService.isValidLocalDateString(payload.periodStartDate) ||
        !_dateTimeService.isValidLocalDateString(payload.periodEndDate) ||
        payload.periodEndDate.compareTo(payload.periodStartDate) < 0 ||
        payload.versions.isEmpty ||
        payload.versions.length > 100) {
      throw const SyncException('AI 报告同步字段无效。');
    }
    final numbers = <int>{};
    final ids = <String>{};
    for (final version in payload.versions) {
      if (!ids.add(version.id) || !numbers.add(version.version)) {
        throw const SyncException('AI 报告版本身份或序号重复。');
      }
      _validateVersion(version);
    }
    if (!numbers.contains(payload.currentVersion)) {
      throw const SyncException('AI 报告当前版本不存在。');
    }
  }

  Map<String, Object?> _encodeVersion(AiReportVersionSyncPayload version) {
    return SplayTreeMap<String, Object?>.of({
      'completed_at': version.completedAt,
      'content': version.content,
      'created_at': version.createdAt,
      'error_code': version.errorCode,
      'generation_source': version.generationSource,
      'id': version.id,
      'quality': version.quality.databaseValue,
      'sensitivity': version.sensitivity.databaseValue,
      'status': version.status.databaseValue,
      'version': version.version,
    });
  }

  AiReportVersionSyncPayload _decodeVersion(Map<String, Object?> json) {
    const keys = {
      'completed_at',
      'content',
      'created_at',
      'error_code',
      'generation_source',
      'id',
      'quality',
      'sensitivity',
      'status',
      'version',
    };
    if (json.length != keys.length || !json.keys.every(keys.contains)) {
      throw const SyncException('云端 AI 报告版本字段集合无效。');
    }
    return AiReportVersionSyncPayload(
      id: _string(json, 'id'),
      version: _int(json, 'version'),
      status: AiReportStatus.fromDatabaseValue(_string(json, 'status')),
      generationSource: _string(json, 'generation_source'),
      content: _nullableString(json, 'content'),
      sensitivity: AiReportSensitivity.fromDatabaseValue(
        _string(json, 'sensitivity'),
      ),
      quality: AiReportQuality.fromDatabaseValue(_string(json, 'quality')),
      errorCode: _nullableString(json, 'error_code'),
      createdAt: _int(json, 'created_at'),
      completedAt: _nullableInt(json, 'completed_at'),
    );
  }

  void _validateVersion(AiReportVersionSyncPayload version) {
    if (!isUuid(version.id) ||
        version.version < 1 ||
        (version.status != AiReportStatus.completed &&
            version.status != AiReportStatus.failed) ||
        version.generationSource.trim().isEmpty ||
        version.generationSource.length > 80 ||
        version.createdAt < 0 ||
        (version.completedAt != null &&
            version.completedAt! < version.createdAt) ||
        (version.content != null && version.content!.length > 100000) ||
        (version.errorCode != null && version.errorCode!.length > 80) ||
        (version.status == AiReportStatus.completed &&
            (version.content == null || version.content!.trim().isEmpty)) ||
        (version.status == AiReportStatus.failed &&
            (version.errorCode == null || version.errorCode!.trim().isEmpty))) {
      throw const SyncException('AI 报告不可变版本字段无效。');
    }
  }

  static bool isUuid(String value) => _uuidPattern.hasMatch(value);

  String _string(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String) throw SyncException('云端 AI 报告字段 $key 必须是字符串。');
    return value;
  }

  String? _nullableString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value != null && value is! String) {
      throw SyncException('云端 AI 报告字段 $key 必须是字符串或 null。');
    }
    return value as String?;
  }

  int _int(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! int) throw SyncException('云端 AI 报告字段 $key 必须是整数。');
    return value;
  }

  int? _nullableInt(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value != null && value is! int) {
      throw SyncException('云端 AI 报告字段 $key 必须是整数或 null。');
    }
    return value as int?;
  }
}
