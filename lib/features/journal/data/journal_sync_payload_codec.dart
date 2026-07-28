import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/journal/domain/journal_entry.dart';
import 'package:rebirth/features/journal/domain/journal_sync_payload.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_payload_codec.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_exception.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';

final class JournalSyncPayloadCodec implements SyncConflictPayloadCodec {
  const JournalSyncPayloadCodec([
    this._dateTimeService = const DateTimeService(),
  ]);

  static final _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  final DateTimeService _dateTimeService;

  @override
  SyncEntityType get entityType => SyncEntityType.journal;

  @override
  Map<String, Object?> encode(SyncEntityPayload payload) {
    if (payload is! JournalSyncPayload) {
      throw const SyncException('Journal 同步 payload 类型无效。');
    }
    validate(payload);
    return SplayTreeMap<String, Object?>.of({
      'created_at': payload.createdAt,
      'emotion_source': payload.emotionSource,
      'entry_date': payload.entryDate,
      'entry_status': payload.status.name,
      'learning': payload.learning,
      'most_draining_event': payload.mostDrainingEvent,
      'most_important_accomplishment': payload.mostImportantAccomplishment,
      'timezone_offset_minutes': payload.timezoneOffsetMinutes,
      'tomorrow_adjustment': payload.tomorrowAdjustment,
    });
  }

  @override
  JournalSyncPayload decode({
    required String recordId,
    required Map<String, Object?> json,
  }) {
    if (!isUuid(recordId)) {
      throw const SyncException('云端 Journal ID 不是合法 UUID。');
    }
    const requiredKeys = {
      'created_at',
      'emotion_source',
      'entry_date',
      'entry_status',
      'learning',
      'most_draining_event',
      'most_important_accomplishment',
      'timezone_offset_minutes',
      'tomorrow_adjustment',
    };
    if (json.length != requiredKeys.length ||
        !json.keys.every(requiredKeys.contains)) {
      throw const SyncException('云端 Journal payload 字段集合无效。');
    }
    final status = switch (json['entry_status']) {
      'draft' => JournalEntryStatus.draft,
      'completed' => JournalEntryStatus.completed,
      _ => throw const SyncException('云端 Journal 状态无效。'),
    };
    final payload = JournalSyncPayload(
      entryDate: _string(json, 'entry_date'),
      timezoneOffsetMinutes: _int(json, 'timezone_offset_minutes'),
      mostImportantAccomplishment: _nullableString(
        json,
        'most_important_accomplishment',
      ),
      mostDrainingEvent: _nullableString(json, 'most_draining_event'),
      emotionSource: _nullableString(json, 'emotion_source'),
      learning: _nullableString(json, 'learning'),
      tomorrowAdjustment: _nullableString(json, 'tomorrow_adjustment'),
      status: status,
      createdAt: _int(json, 'created_at'),
    );
    validate(payload);
    return payload;
  }

  String canonicalJson(JournalSyncPayload payload) {
    return jsonEncode(encode(payload));
  }

  String fingerprint(JournalSyncPayload payload) {
    return sha256.convert(utf8.encode(canonicalJson(payload))).toString();
  }

  void validate(JournalSyncPayload payload) {
    if (!_dateTimeService.isValidLocalDateString(payload.entryDate) ||
        payload.timezoneOffsetMinutes < -840 ||
        payload.timezoneOffsetMinutes > 840 ||
        payload.createdAt < 0 ||
        !payload.hasContent) {
      throw const SyncException('Journal 日期、时区、内容或创建时间无效。');
    }
    for (final value in [
      payload.mostImportantAccomplishment,
      payload.mostDrainingEvent,
      payload.emotionSource,
      payload.learning,
      payload.tomorrowAdjustment,
    ]) {
      if (value != null && value.trim().isEmpty) {
        throw const SyncException('Journal 内容不能是空白文本。');
      }
    }
  }

  static bool isUuid(String value) => _uuidPattern.hasMatch(value);

  String _string(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String) {
      throw SyncException('云端 Journal 字段 $key 必须是字符串。');
    }
    return value;
  }

  String? _nullableString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value != null && value is! String) {
      throw SyncException('云端 Journal 字段 $key 必须是字符串或 null。');
    }
    return value as String?;
  }

  int _int(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! int) {
      throw SyncException('云端 Journal 字段 $key 必须是整数。');
    }
    return value;
  }
}
