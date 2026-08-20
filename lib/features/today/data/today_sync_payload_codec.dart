import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_payload_codec.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_exception.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';
import 'package:rebirth/features/today/domain/today_entry.dart';
import 'package:rebirth/features/today/domain/today_sync_payload.dart';

final class TodaySyncPayloadCodec implements SyncConflictPayloadCodec {
  const TodaySyncPayloadCodec([
    this._dateTimeService = const DateTimeService(),
  ]);

  static final _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  final DateTimeService _dateTimeService;

  @override
  SyncEntityType get entityType => SyncEntityType.today;

  @override
  Map<String, Object?> encode(SyncEntityPayload payload) {
    if (payload is! TodaySyncPayload) {
      throw const SyncException('Today 同步 payload 类型无效。');
    }
    validate(payload);
    return SplayTreeMap<String, Object?>.of({
      'created_at': payload.createdAt,
      'daily_note': payload.dailyNote,
      'energy_description': payload.energyDescription,
      'energy_score': payload.energyScore,
      'learning_minutes': payload.learningMinutes,
      'learning_description': payload.learningDescription,
      'mood_score': payload.moodScore,
      'mood_description': payload.moodDescription,
      'priority_1': payload.priority1,
      'priority_1_completed': payload.priority1Completed,
      'priority_1_goal_id': payload.priority1GoalId,
      'priority_2': payload.priority2,
      'priority_2_completed': payload.priority2Completed,
      'priority_2_goal_id': payload.priority2GoalId,
      'priority_3': payload.priority3,
      'priority_3_completed': payload.priority3Completed,
      'priority_3_goal_id': payload.priority3GoalId,
      'record_date': payload.recordDate,
      'record_status': payload.status.name,
      'research_minutes': payload.researchMinutes,
      'research_description': payload.researchDescription,
      'timezone_offset_minutes': payload.timezoneOffsetMinutes,
      'wellbeing_score_scale': payload.wellbeingScoreScale,
    });
  }

  @override
  TodaySyncPayload decode({
    required String recordId,
    required Map<String, Object?> json,
  }) {
    if (!isUuid(recordId)) {
      throw const SyncException('云端 Today ID 不是合法 UUID。');
    }
    const legacyKeys = {
      'created_at',
      'daily_note',
      'energy_score',
      'learning_minutes',
      'mood_score',
      'priority_1',
      'priority_1_completed',
      'priority_1_goal_id',
      'priority_2',
      'priority_2_completed',
      'priority_2_goal_id',
      'priority_3',
      'priority_3_completed',
      'priority_3_goal_id',
      'record_date',
      'record_status',
      'research_minutes',
      'timezone_offset_minutes',
    };
    const currentKeys = {
      ...legacyKeys,
      'energy_description',
      'mood_description',
      'wellbeing_score_scale',
    };
    const narrativeKeys = {
      ...currentKeys,
      'learning_description',
      'research_description',
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
      throw const SyncException('云端 Today payload 字段集合无效。');
    }
    final statusValue = json['record_status'];
    final status = switch (statusValue) {
      'draft' => TodayRecordStatus.draft,
      'completed' => TodayRecordStatus.completed,
      _ => throw const SyncException('云端 Today 状态无效。'),
    };
    final payload = TodaySyncPayload(
      recordDate: _string(json, 'record_date'),
      timezoneOffsetMinutes: _int(json, 'timezone_offset_minutes'),
      priority1: _nullableString(json, 'priority_1'),
      priority1Completed: _bool(json, 'priority_1_completed'),
      priority1GoalId: _nullableString(json, 'priority_1_goal_id'),
      priority2: _nullableString(json, 'priority_2'),
      priority2Completed: _bool(json, 'priority_2_completed'),
      priority2GoalId: _nullableString(json, 'priority_2_goal_id'),
      priority3: _nullableString(json, 'priority_3'),
      priority3Completed: _bool(json, 'priority_3_completed'),
      priority3GoalId: _nullableString(json, 'priority_3_goal_id'),
      moodScore: _nullableInt(json, 'mood_score'),
      wellbeingScoreScale: isLegacy ? 5 : _int(json, 'wellbeing_score_scale'),
      moodDescription: isLegacy
          ? null
          : _nullableString(json, 'mood_description'),
      energyScore: _nullableInt(json, 'energy_score'),
      energyDescription: isLegacy
          ? null
          : _nullableString(json, 'energy_description'),
      researchMinutes: _nullableInt(json, 'research_minutes'),
      researchDescription: hasNarratives
          ? _nullableString(json, 'research_description')
          : null,
      learningMinutes: _nullableInt(json, 'learning_minutes'),
      learningDescription: hasNarratives
          ? _nullableString(json, 'learning_description')
          : null,
      dailyNote: _nullableString(json, 'daily_note'),
      status: status,
      createdAt: _int(json, 'created_at'),
    );
    validate(payload);
    return payload;
  }

  String canonicalJson(TodaySyncPayload payload) {
    return jsonEncode(encode(payload));
  }

  String fingerprint(TodaySyncPayload payload) {
    return sha256.convert(utf8.encode(canonicalJson(payload))).toString();
  }

  void validate(TodaySyncPayload payload) {
    if (!_dateTimeService.isValidLocalDateString(payload.recordDate) ||
        payload.timezoneOffsetMinutes < -840 ||
        payload.timezoneOffsetMinutes > 840 ||
        payload.createdAt < 0) {
      throw const SyncException('Today 日期、时区或创建时间无效。');
    }
    _validatePriority(
      payload.priority1,
      payload.priority1Completed,
      payload.priority1GoalId,
    );
    _validatePriority(
      payload.priority2,
      payload.priority2Completed,
      payload.priority2GoalId,
    );
    _validatePriority(
      payload.priority3,
      payload.priority3Completed,
      payload.priority3GoalId,
    );
    if (payload.wellbeingScoreScale != 5 && payload.wellbeingScoreScale != 10) {
      throw const SyncException('Today 评分量表必须为 5 或 10。');
    }
    for (final score in [payload.moodScore, payload.energyScore]) {
      if (score != null && (score < 1 || score > payload.wellbeingScoreScale)) {
        throw const SyncException('Today 评分超出量表范围。');
      }
    }
    for (final description in [
      payload.moodDescription,
      payload.energyDescription,
      payload.researchDescription,
      payload.learningDescription,
    ]) {
      if (description != null &&
          (description.trim().isEmpty || description.length > 80)) {
        throw const SyncException('Today 指标描述必须为 1 到 80 字。');
      }
    }
    for (final minutes in [payload.researchMinutes, payload.learningMinutes]) {
      if (minutes != null && minutes < 0) {
        throw const SyncException('Today 时长必须为空或非负整数。');
      }
    }
  }

  void _validatePriority(String? text, bool completed, String? goalId) {
    if (text != null && text.trim().isEmpty) {
      throw const SyncException('Today priority 不能是空白文本。');
    }
    if (text == null && (completed || goalId != null)) {
      throw const SyncException('空 Today priority 不能完成或关联目标。');
    }
    if (goalId != null && !isUuid(goalId)) {
      throw const SyncException('Today priority Goal ID 无效。');
    }
  }

  static bool isUuid(String value) => _uuidPattern.hasMatch(value);

  String _string(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String) {
      throw SyncException('云端 Today 字段 $key 必须是字符串。');
    }
    return value;
  }

  String? _nullableString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value != null && value is! String) {
      throw SyncException('云端 Today 字段 $key 必须是字符串或 null。');
    }
    return value as String?;
  }

  int _int(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! int) {
      throw SyncException('云端 Today 字段 $key 必须是整数。');
    }
    return value;
  }

  int? _nullableInt(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value != null && value is! int) {
      throw SyncException('云端 Today 字段 $key 必须是整数或 null。');
    }
    return value as int?;
  }

  bool _bool(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! bool) {
      throw SyncException('云端 Today 字段 $key 必须是布尔值。');
    }
    return value;
  }
}
