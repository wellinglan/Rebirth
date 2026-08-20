import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/health/domain/health_sync_payload.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_payload_codec.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_exception.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';

final class HealthSyncPayloadCodec implements SyncConflictPayloadCodec {
  const HealthSyncPayloadCodec([
    this._dateTimeService = const DateTimeService(),
  ]);

  static final _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  static const _dataSources = {'manual', 'health_connect', 'apple_health'};

  final DateTimeService _dateTimeService;

  @override
  SyncEntityType get entityType => SyncEntityType.health;

  @override
  Map<String, Object?> encode(SyncEntityPayload payload) {
    if (payload is! HealthSyncPayload) {
      throw const SyncException('Health 同步 payload 类型无效。');
    }
    validate(payload);
    return SplayTreeMap<String, Object?>.of({
      'created_at': payload.createdAt,
      'data_source': payload.dataSource,
      'exercise_duration_minutes': payload.exerciseDurationMinutes,
      'exercise_description': payload.exerciseDescription,
      'exercise_type': payload.exerciseType,
      'note': payload.note,
      'physical_state_score': payload.physicalStateScore,
      'physical_state_score_scale': payload.physicalStateScoreScale,
      'physical_state_description': payload.physicalStateDescription,
      'record_date': payload.recordDate,
      'sleep_duration_minutes': payload.sleepDurationMinutes,
      'sleep_description': payload.sleepDescription,
      'source_record_id': payload.sourceRecordId,
      'timezone_offset_minutes': payload.timezoneOffsetMinutes,
      'water_intake_ml': payload.waterIntakeMl,
      'water_description': payload.waterDescription,
      'weight_kg': payload.weightKg,
      'weight_description': payload.weightDescription,
    });
  }

  @override
  HealthSyncPayload decode({
    required String recordId,
    required Map<String, Object?> json,
  }) {
    if (!isUuid(recordId)) {
      throw const SyncException('云端 Health ID 不是合法 UUID。');
    }
    const legacyKeys = {
      'created_at',
      'data_source',
      'exercise_duration_minutes',
      'exercise_type',
      'note',
      'physical_state_score',
      'record_date',
      'sleep_duration_minutes',
      'source_record_id',
      'timezone_offset_minutes',
      'water_intake_ml',
      'weight_kg',
    };
    const currentKeys = {
      ...legacyKeys,
      'physical_state_description',
      'physical_state_score_scale',
    };
    const narrativeKeys = {
      ...currentKeys,
      'exercise_description',
      'sleep_description',
      'water_description',
      'weight_description',
    };
    final isLegacy =
        json.length == legacyKeys.length &&
        json.keys.every(legacyKeys.contains);
    final isCurrent =
        json.length == currentKeys.length &&
        json.keys.every(currentKeys.contains);
    final hasNarratives =
        json.length == narrativeKeys.length &&
        json.keys.every(narrativeKeys.contains);
    if (!isLegacy && !isCurrent && !hasNarratives) {
      throw const SyncException('云端 Health payload 字段集合无效。');
    }
    final payload = HealthSyncPayload(
      recordDate: _string(json, 'record_date'),
      timezoneOffsetMinutes: _int(json, 'timezone_offset_minutes'),
      sleepDurationMinutes: _nullableInt(json, 'sleep_duration_minutes'),
      sleepDescription: hasNarratives
          ? _nullableString(json, 'sleep_description')
          : null,
      weightKg: _nullableDouble(json, 'weight_kg'),
      weightDescription: hasNarratives
          ? _nullableString(json, 'weight_description')
          : null,
      waterIntakeMl: _nullableInt(json, 'water_intake_ml'),
      waterDescription: hasNarratives
          ? _nullableString(json, 'water_description')
          : null,
      exerciseType: _nullableString(json, 'exercise_type'),
      exerciseDurationMinutes: _nullableInt(json, 'exercise_duration_minutes'),
      exerciseDescription: hasNarratives
          ? _nullableString(json, 'exercise_description')
          : null,
      physicalStateScore: _nullableInt(json, 'physical_state_score'),
      physicalStateScoreScale: isLegacy
          ? 5
          : _int(json, 'physical_state_score_scale'),
      physicalStateDescription: isLegacy
          ? null
          : _nullableString(json, 'physical_state_description'),
      note: _nullableString(json, 'note'),
      dataSource: _string(json, 'data_source'),
      sourceRecordId: _nullableString(json, 'source_record_id'),
      createdAt: _int(json, 'created_at'),
    );
    validate(payload);
    return payload;
  }

  String canonicalJson(HealthSyncPayload payload) {
    return jsonEncode(encode(payload));
  }

  String fingerprint(HealthSyncPayload payload) {
    return sha256.convert(utf8.encode(canonicalJson(payload))).toString();
  }

  void validate(HealthSyncPayload payload) {
    if (!_dateTimeService.isValidLocalDateString(payload.recordDate) ||
        payload.timezoneOffsetMinutes < -840 ||
        payload.timezoneOffsetMinutes > 840 ||
        payload.createdAt < 0 ||
        !_dataSources.contains(payload.dataSource) ||
        !_isNonNegative(payload.sleepDurationMinutes) ||
        !_isNonNegative(payload.waterIntakeMl) ||
        !_isNonNegative(payload.exerciseDurationMinutes) ||
        (payload.weightKg != null && payload.weightKg! <= 0) ||
        (payload.physicalStateScoreScale != 5 &&
            payload.physicalStateScoreScale != 10) ||
        (payload.physicalStateScore != null &&
            (payload.physicalStateScore! < 1 ||
                payload.physicalStateScore! >
                    payload.physicalStateScoreScale))) {
      throw const SyncException('Health 日期、时区、指标、来源或创建时间无效。');
    }
    for (final value in [
      payload.exerciseType,
      payload.note,
      payload.sourceRecordId,
      payload.physicalStateDescription,
      payload.sleepDescription,
      payload.weightDescription,
      payload.waterDescription,
      payload.exerciseDescription,
    ]) {
      if (value != null && value.trim().isEmpty) {
        throw const SyncException('Health 文本字段不能是空白文本。');
      }
    }
    for (final description in [
      payload.physicalStateDescription,
      payload.sleepDescription,
      payload.weightDescription,
      payload.waterDescription,
      payload.exerciseDescription,
    ]) {
      if (description != null && description.length > 80) {
        throw const SyncException('Health 指标描述不得超过 80 字。');
      }
    }
  }

  static bool isUuid(String value) => _uuidPattern.hasMatch(value);

  static bool _isNonNegative(int? value) => value == null || value >= 0;

  String _string(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String) {
      throw SyncException('云端 Health 字段 $key 必须是字符串。');
    }
    return value;
  }

  String? _nullableString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value != null && value is! String) {
      throw SyncException('云端 Health 字段 $key 必须是字符串或 null。');
    }
    return value as String?;
  }

  int _int(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! int) {
      throw SyncException('云端 Health 字段 $key 必须是整数。');
    }
    return value;
  }

  int? _nullableInt(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value != null && value is! int) {
      throw SyncException('云端 Health 字段 $key 必须是整数或 null。');
    }
    return value as int?;
  }

  double? _nullableDouble(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is! num) {
      throw SyncException('云端 Health 字段 $key 必须是数字或 null。');
    }
    return value.toDouble();
  }
}
