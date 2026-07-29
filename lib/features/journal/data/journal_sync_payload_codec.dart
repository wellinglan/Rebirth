import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:rebirth/core/journal/journal_prompt_catalog.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/core/utils/deterministic_uuid.dart';
import 'package:rebirth/features/journal/domain/journal_entry.dart';
import 'package:rebirth/features/journal/domain/journal_entry_prompt_item.dart';
import 'package:rebirth/features/journal/domain/journal_prompt.dart';
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

  static const _v1Keys = {
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
  static const _v2Keys = {
    'created_at',
    'entry_date',
    'entry_status',
    'journal_payload_schema_version',
    'prompt_items',
    'timezone_offset_minutes',
  };

  final DateTimeService _dateTimeService;

  @override
  SyncEntityType get entityType => SyncEntityType.journal;

  @override
  Map<String, Object?> encode(SyncEntityPayload payload) {
    if (payload is! JournalSyncPayload) {
      throw const SyncException('Journal 同步 payload 类型无效。');
    }
    validate(payload);
    if (payload.schemaVersion == 1) return _encodeV1(payload);
    return SplayTreeMap<String, Object?>.of({
      'created_at': payload.createdAt,
      'entry_date': payload.entryDate,
      'entry_status': payload.status.name,
      'journal_payload_schema_version': 2,
      'prompt_items': [
        for (final item in payload.promptItems)
          SplayTreeMap<String, Object?>.of({
            'answer_text': item.answerText,
            'created_at': item.createdAt,
            'display_order': item.displayOrder,
            'helper_text_snapshot': item.helperTextSnapshot,
            'id': item.id,
            'prompt_source': item.promptSource.wireName,
            'question_text_snapshot': item.questionTextSnapshot,
            'response_kind': item.responseKind.wireName,
            'source_prompt_id': item.sourcePromptId,
            'source_prompt_stable_key': item.sourcePromptStableKey,
            'source_prompt_version': item.sourcePromptVersion,
            'updated_at': item.updatedAt,
          }),
      ],
      'timezone_offset_minutes': payload.timezoneOffsetMinutes,
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
    final keys = json.keys.toSet();
    if (keys.length == _v1Keys.length && keys.containsAll(_v1Keys)) {
      return _decodeV1(recordId, json);
    }
    if (keys.length != _v2Keys.length || !keys.containsAll(_v2Keys)) {
      throw const SyncException('云端 Journal payload 字段集合无效。');
    }
    if (_int(json, 'journal_payload_schema_version') != 2) {
      throw const SyncException('云端 Journal payload 版本不受支持。');
    }
    final rawItems = json['prompt_items'];
    if (rawItems is! List<Object?>) {
      throw const SyncException('云端 Journal 问题快照必须是列表。');
    }
    final payload = JournalSyncPayload(
      entryDate: _string(json, 'entry_date'),
      timezoneOffsetMinutes: _int(json, 'timezone_offset_minutes'),
      status: _status(json['entry_status']),
      createdAt: _int(json, 'created_at'),
      promptItems: [
        for (final raw in rawItems)
          _decodeItem(
            raw is Map<String, Object?>
                ? raw
                : throw const SyncException('云端 Journal 问题快照无效。'),
          ),
      ],
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
    if (payload.schemaVersion == 2) {
      try {
        validateJournalPromptItems(payload.promptItems);
      } on JournalPromptItemValidationException {
        throw const SyncException('Journal 问题快照无效。');
      }
      for (final item in payload.promptItems) {
        if (!isUuid(item.id) ||
            (item.sourcePromptId != null && !isUuid(item.sourcePromptId!)) ||
            item.createdAt < 0 ||
            item.updatedAt < 0) {
          throw const SyncException('Journal 问题快照元数据无效。');
        }
      }
      return;
    }
    for (final value in [
      payload.mostImportantAccomplishment,
      payload.mostDrainingEvent,
      payload.emotionSource,
      payload.learning,
      payload.tomorrowAdjustment,
    ]) {
      if (value != null &&
          (value.trim().isEmpty ||
              value.length > JournalPromptLimits.answerTextLength)) {
        throw const SyncException('Journal 内容无效。');
      }
    }
  }

  static bool isUuid(String value) => _uuidPattern.hasMatch(value);

  Map<String, Object?> _encodeV1(JournalSyncPayload payload) {
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

  JournalSyncPayload _decodeV1(String recordId, Map<String, Object?> json) {
    final createdAt = _int(json, 'created_at');
    final answers = <String, String?>{
      JournalPromptCatalog.accomplishmentKey: _nullableString(
        json,
        'most_important_accomplishment',
      ),
      JournalPromptCatalog.drainingEventKey: _nullableString(
        json,
        'most_draining_event',
      ),
      JournalPromptCatalog.emotionSourceKey: _nullableString(
        json,
        'emotion_source',
      ),
      JournalPromptCatalog.learningKey: _nullableString(json, 'learning'),
      JournalPromptCatalog.tomorrowAdjustmentKey: _nullableString(
        json,
        'tomorrow_adjustment',
      ),
    };
    final payload = JournalSyncPayload(
      entryDate: _string(json, 'entry_date'),
      timezoneOffsetMinutes: _int(json, 'timezone_offset_minutes'),
      status: _status(json['entry_status']),
      createdAt: createdAt,
      promptItems: [
        for (final prompt in JournalPromptCatalog.prompts)
          JournalEntryPromptItem(
            id: deterministicUuid(
              'journal-entry-prompt-item:$recordId:${prompt.stableKey}:1',
            ),
            sourcePromptId: null,
            sourcePromptStableKey: prompt.stableKey,
            sourcePromptVersion: 1,
            promptSource: JournalPromptSource.system,
            questionTextSnapshot: prompt.questionText,
            helperTextSnapshot: prompt.helperText,
            responseKind: JournalResponseKind.longText,
            displayOrder: prompt.displayOrder,
            answerText: answers[prompt.stableKey],
            createdAt: createdAt,
            updatedAt: createdAt,
          ),
      ],
    );
    validate(payload);
    return payload;
  }

  JournalEntryPromptItem _decodeItem(Map<String, Object?> json) {
    const keys = {
      'answer_text',
      'created_at',
      'display_order',
      'helper_text_snapshot',
      'id',
      'prompt_source',
      'question_text_snapshot',
      'response_kind',
      'source_prompt_id',
      'source_prompt_stable_key',
      'source_prompt_version',
      'updated_at',
    };
    if (json.length != keys.length || !json.keys.every(keys.contains)) {
      throw const SyncException('云端 Journal 问题快照字段集合无效。');
    }
    return JournalEntryPromptItem(
      id: _string(json, 'id'),
      sourcePromptId: _nullableString(json, 'source_prompt_id'),
      sourcePromptStableKey: _nullableString(json, 'source_prompt_stable_key'),
      sourcePromptVersion: _int(json, 'source_prompt_version'),
      promptSource: _promptSource(_string(json, 'prompt_source')),
      questionTextSnapshot: _string(json, 'question_text_snapshot'),
      helperTextSnapshot: _nullableString(json, 'helper_text_snapshot'),
      responseKind: _responseKind(_string(json, 'response_kind')),
      displayOrder: _int(json, 'display_order'),
      answerText: _nullableString(json, 'answer_text'),
      createdAt: _int(json, 'created_at'),
      updatedAt: _int(json, 'updated_at'),
    );
  }

  JournalEntryStatus _status(Object? value) => switch (value) {
    'draft' => JournalEntryStatus.draft,
    'completed' => JournalEntryStatus.completed,
    _ => throw const SyncException('云端 Journal 状态无效。'),
  };

  JournalPromptSource _promptSource(String value) {
    try {
      return JournalPromptSource.fromWireName(value);
    } on ArgumentError {
      throw const SyncException('云端 Journal 问题来源无效。');
    }
  }

  JournalResponseKind _responseKind(String value) {
    try {
      return JournalResponseKind.fromWireName(value);
    } on ArgumentError {
      throw const SyncException('云端 Journal 回答类型无效。');
    }
  }

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
