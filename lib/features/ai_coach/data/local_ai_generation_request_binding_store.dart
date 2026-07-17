import 'dart:async';
import 'dart:convert';

import 'package:rebirth/core/config/server_endpoint_validator.dart';
import 'package:rebirth/features/ai_coach/domain/ai_generation_request_binding.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class LocalAiGenerationRequestBindingStore
    implements AiGenerationRequestBindingStore {
  LocalAiGenerationRequestBindingStore({
    Future<SharedPreferences> Function()? loadPreferences,
    this.endpointValidator = const ServerEndpointValidator(),
  }) : _loadPreferences = loadPreferences ?? SharedPreferences.getInstance;

  static const legacyV1Key = 'rebirth.ai.generation_request_bindings.v1';
  static const v2KeyPrefix = 'rebirth.ai.generation_request_binding.v2.';
  static const migrationMarkerKey =
      'rebirth.ai.generation_request_bindings.v2.migrated';

  static Future<void> _operationTail = Future<void>.value();

  final Future<SharedPreferences> Function() _loadPreferences;
  final ServerEndpointValidator endpointValidator;

  @override
  Future<void> save(AiGenerationRequestBinding binding) {
    return _serialized(() async {
      final preferences = await _loadPreferences();
      await _ensureV2(preferences);
      final saved = await preferences.setString(
        _itemKey(binding.localReportId),
        jsonEncode(_encode(binding)),
      );
      if (!saved) {
        throw StateError('AI request binding could not be saved.');
      }
    });
  }

  @override
  Future<AiGenerationRequestBinding?> read(String localReportId) {
    return _serialized(() async {
      final preferences = await _loadPreferences();
      await _ensureV2(preferences);
      return _decodeItem(preferences.getString(_itemKey(localReportId)));
    });
  }

  @override
  Future<List<AiGenerationRequestBinding>> readAll() {
    return _serialized(() async {
      final preferences = await _loadPreferences();
      await _ensureV2(preferences);
      final result = <AiGenerationRequestBinding>[];
      final keys =
          preferences
              .getKeys()
              .where((key) => key.startsWith(v2KeyPrefix))
              .toList(growable: false)
            ..sort();
      for (final key in keys) {
        final binding = _decodeItem(preferences.getString(key));
        if (binding != null) result.add(binding);
      }
      return List.unmodifiable(result);
    });
  }

  @override
  Future<void> delete(String localReportId) {
    return _serialized(() async {
      final preferences = await _loadPreferences();
      await _ensureV2(preferences);
      final key = _itemKey(localReportId);
      if (!preferences.containsKey(key)) return;
      if (!await preferences.remove(key)) {
        throw StateError('AI request binding could not be deleted.');
      }
    });
  }

  Future<void> _ensureV2(SharedPreferences preferences) async {
    if (preferences.getBool(migrationMarkerKey) == true) return;
    final encoded = preferences.getString(legacyV1Key);
    if (encoded != null) {
      final legacy = _decodeLegacyMap(encoded);
      for (final entry in legacy.entries) {
        if (entry.value is! Map) {
          throw StateError('Legacy AI request bindings are invalid.');
        }
        final binding = _decode(Map<String, Object?>.from(entry.value as Map));
        if (binding.localReportId != entry.key) {
          throw StateError('Legacy AI request bindings are invalid.');
        }
        final key = _itemKey(entry.key);
        if (preferences.containsKey(key)) continue;
        final saved = await preferences.setString(
          key,
          jsonEncode(_encode(binding)),
        );
        if (!saved) {
          throw StateError('AI request binding migration could not be saved.');
        }
      }
    }
    if (!await preferences.setBool(migrationMarkerKey, true)) {
      throw StateError('AI request binding migration could not be completed.');
    }
    if (encoded != null && !await preferences.remove(legacyV1Key)) {
      throw StateError('Legacy AI request bindings could not be removed.');
    }
  }

  Map<String, Object?> _decodeLegacyMap(String encoded) {
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) {
        throw StateError('Legacy AI request bindings are invalid.');
      }
      return Map<String, Object?>.from(decoded);
    } on FormatException {
      throw StateError('Legacy AI request bindings are invalid.');
    }
  }

  AiGenerationRequestBinding? _decodeItem(String? encoded) {
    if (encoded == null) return null;
    try {
      final value = jsonDecode(encoded);
      if (value is! Map) return null;
      return _decode(Map<String, Object?>.from(value));
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Map<String, Object?> _encode(AiGenerationRequestBinding binding) => {
    'local_report_id': binding.localReportId,
    'request_id': binding.requestId,
    'normalized_endpoint': endpointValidator.normalize(
      binding.normalizedEndpoint,
    ),
    'cloud_user_id': binding.cloudUserId,
    'input_hash': binding.inputHash,
    'report_type': binding.reportType,
    'prompt_version': binding.promptVersion,
    'created_at': binding.createdAt,
  };

  AiGenerationRequestBinding _decode(Map<String, Object?> json) {
    final binding = AiGenerationRequestBinding(
      localReportId: json['local_report_id'] as String,
      requestId: json['request_id'] as String,
      normalizedEndpoint: endpointValidator.normalize(
        json['normalized_endpoint'] as String,
      ),
      cloudUserId: json['cloud_user_id'] as String,
      inputHash: json['input_hash'] as String,
      reportType: json['report_type'] as String,
      promptVersion: json['prompt_version'] as String,
      createdAt: json['created_at'] as int,
    );
    if (binding.localReportId.isEmpty ||
        binding.requestId.isEmpty ||
        binding.cloudUserId.isEmpty ||
        binding.inputHash.length != 64) {
      throw const FormatException('Invalid AI request binding.');
    }
    return binding;
  }

  String _itemKey(String localReportId) {
    final encodedId = base64Url
        .encode(utf8.encode(localReportId))
        .replaceAll('=', '');
    return '$v2KeyPrefix$encodedId';
  }

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final next = _operationTail.then(
      (_) => operation(),
      onError: (_, _) => operation(),
    );
    _operationTail = next.then<void>((_) {}, onError: (_, _) {});
    return next;
  }
}
