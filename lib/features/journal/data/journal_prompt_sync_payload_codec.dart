import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:rebirth/core/journal/journal_prompt_catalog.dart';
import 'package:rebirth/features/journal/domain/journal_prompt.dart';
import 'package:rebirth/features/journal/domain/journal_prompt_sync_payload.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_payload_codec.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_exception.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';

final class JournalPromptSyncPayloadCodec implements SyncConflictPayloadCodec {
  const JournalPromptSyncPayloadCodec();

  static final _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  @override
  SyncEntityType get entityType => SyncEntityType.journalPromptConfiguration;

  @override
  Map<String, Object?> encode(SyncEntityPayload payload) {
    if (payload is! JournalPromptConfigurationSyncPayload) {
      throw const SyncException('Journal 问题配置 payload 类型无效。');
    }
    validate(payload);
    return SplayTreeMap<String, Object?>.of({
      'configuration_version': payload.configurationVersion,
      'created_at': payload.createdAt,
      'logical_key': payload.logicalKey,
      'payload_schema_version':
          JournalPromptConfigurationSyncPayload.payloadSchemaVersion,
      'prompts': [
        for (final prompt in payload.prompts)
          SplayTreeMap<String, Object?>.of({
            'created_at': prompt.createdAt,
            'deleted_at': prompt.deletedAt,
            'display_order': prompt.displayOrder,
            'helper_text': prompt.helperText,
            'id': prompt.id,
            'is_enabled': prompt.isEnabled,
            'prompt_version': prompt.promptVersion,
            'question_text': prompt.questionText,
            'response_kind': prompt.responseKind.wireName,
            'source': prompt.source.wireName,
            'stable_key': prompt.stableKey,
            'updated_at': prompt.updatedAt,
          }),
      ],
    });
  }

  @override
  JournalPromptConfigurationSyncPayload decode({
    required String recordId,
    required Map<String, Object?> json,
  }) {
    if (!isUuid(recordId)) {
      throw const SyncException('云端 Journal 问题配置 ID 无效。');
    }
    const keys = {
      'configuration_version',
      'created_at',
      'logical_key',
      'payload_schema_version',
      'prompts',
    };
    if (json.length != keys.length || !json.keys.every(keys.contains)) {
      throw const SyncException('云端 Journal 问题配置字段集合无效。');
    }
    if (_int(json, 'payload_schema_version') !=
        JournalPromptConfigurationSyncPayload.payloadSchemaVersion) {
      throw const SyncException('云端 Journal 问题配置版本不受支持。');
    }
    final rawPrompts = json['prompts'];
    if (rawPrompts is! List<Object?>) {
      throw const SyncException('云端 Journal 问题列表无效。');
    }
    final payload = JournalPromptConfigurationSyncPayload(
      logicalKey: _string(json, 'logical_key'),
      configurationVersion: _int(json, 'configuration_version'),
      createdAt: _int(json, 'created_at'),
      prompts: [
        for (final raw in rawPrompts)
          _decodePrompt(
            recordId,
            raw is Map<String, Object?>
                ? raw
                : throw const SyncException('云端 Journal 问题无效。'),
          ),
      ],
    );
    validate(payload);
    return payload;
  }

  void validate(JournalPromptConfigurationSyncPayload payload) {
    if (payload.logicalKey != 'default' ||
        payload.configurationVersion < 1 ||
        payload.createdAt < 0 ||
        payload.prompts.isEmpty ||
        payload.prompts.length > JournalPromptLimits.totalPromptCount) {
      throw const SyncException('Journal 问题配置元数据无效。');
    }
    final ids = <String>{};
    final systemKeys = <String>{};
    var enabledCount = 0;
    for (final prompt in payload.prompts) {
      try {
        validatePromptDefinition(prompt);
      } on JournalPromptValidationException {
        throw const SyncException('Journal 问题定义无效。');
      }
      if (!isUuid(prompt.id) ||
          !ids.add(prompt.id) ||
          prompt.createdAt < 0 ||
          prompt.updatedAt < 0) {
        throw const SyncException('Journal 问题定义元数据无效。');
      }
      if (prompt.stableKey case final key?) {
        if (!systemKeys.add(key)) {
          throw const SyncException('Journal 系统问题 stableKey 重复。');
        }
      }
      if (!prompt.isDeleted && prompt.isEnabled) enabledCount += 1;
    }
    if (enabledCount < 1 ||
        enabledCount > JournalPromptLimits.enabledPromptCount) {
      throw const SyncException('Journal 启用问题数量无效。');
    }
  }

  String canonicalJson(JournalPromptConfigurationSyncPayload payload) {
    return jsonEncode(encode(payload));
  }

  String semanticFingerprint(JournalPromptConfigurationSyncPayload payload) {
    final semantic = <String, Object?>{
      'logical_key': payload.logicalKey,
      'prompts': [
        for (final prompt in payload.prompts)
          {
            'deleted': prompt.isDeleted,
            'display_order': prompt.displayOrder,
            'helper_text': prompt.helperText,
            'is_enabled': prompt.isEnabled,
            'prompt_version': prompt.promptVersion,
            'question_text': prompt.questionText,
            'response_kind': prompt.responseKind.wireName,
            'source': prompt.source.wireName,
            'stable_key': prompt.stableKey,
          },
      ],
    };
    return sha256.convert(utf8.encode(jsonEncode(semantic))).toString();
  }

  static bool isUuid(String value) => _uuidPattern.hasMatch(value);

  JournalPromptDefinition _decodePrompt(
    String configurationId,
    Map<String, Object?> json,
  ) {
    const keys = {
      'created_at',
      'deleted_at',
      'display_order',
      'helper_text',
      'id',
      'is_enabled',
      'prompt_version',
      'question_text',
      'response_kind',
      'source',
      'stable_key',
      'updated_at',
    };
    if (json.length != keys.length || !json.keys.every(keys.contains)) {
      throw const SyncException('云端 Journal 问题字段集合无效。');
    }
    return JournalPromptDefinition(
      id: _string(json, 'id'),
      configurationId: configurationId,
      stableKey: _nullableString(json, 'stable_key'),
      source: _source(_string(json, 'source')),
      questionText: _string(json, 'question_text'),
      helperText: _nullableString(json, 'helper_text'),
      responseKind: _kind(_string(json, 'response_kind')),
      displayOrder: _int(json, 'display_order'),
      isEnabled: _bool(json, 'is_enabled'),
      promptVersion: _int(json, 'prompt_version'),
      createdAt: _int(json, 'created_at'),
      updatedAt: _int(json, 'updated_at'),
      deletedAt: _nullableInt(json, 'deleted_at'),
    );
  }

  JournalPromptSource _source(String value) {
    try {
      return JournalPromptSource.fromWireName(value);
    } on ArgumentError {
      throw const SyncException('云端 Journal 问题来源无效。');
    }
  }

  JournalResponseKind _kind(String value) {
    try {
      return JournalResponseKind.fromWireName(value);
    } on ArgumentError {
      throw const SyncException('云端 Journal 回答类型无效。');
    }
  }

  String _string(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String) throw SyncException('字段 $key 必须是字符串。');
    return value;
  }

  String? _nullableString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value != null && value is! String) {
      throw SyncException('字段 $key 必须是字符串或 null。');
    }
    return value as String?;
  }

  int _int(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! int) throw SyncException('字段 $key 必须是整数。');
    return value;
  }

  int? _nullableInt(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value != null && value is! int) {
      throw SyncException('字段 $key 必须是整数或 null。');
    }
    return value as int?;
  }

  bool _bool(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! bool) throw SyncException('字段 $key 必须是布尔值。');
    return value;
  }
}
