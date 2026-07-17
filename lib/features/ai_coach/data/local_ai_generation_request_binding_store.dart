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

  static const _key = 'rebirth.ai.generation_request_bindings.v1';

  final Future<SharedPreferences> Function() _loadPreferences;
  final ServerEndpointValidator endpointValidator;

  @override
  Future<void> save(AiGenerationRequestBinding binding) async {
    final all = await _readMap();
    all[binding.localReportId] = {
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
    final preferences = await _loadPreferences();
    if (!await preferences.setString(_key, jsonEncode(all))) {
      throw StateError('AI request binding could not be saved.');
    }
  }

  @override
  Future<AiGenerationRequestBinding?> read(String localReportId) async {
    final value = (await _readMap())[localReportId];
    if (value is! Map) return null;
    try {
      return _decode(Map<String, Object?>.from(value));
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  @override
  Future<List<AiGenerationRequestBinding>> readAll() async {
    final result = <AiGenerationRequestBinding>[];
    for (final value in (await _readMap()).values) {
      if (value is! Map) continue;
      try {
        result.add(_decode(Map<String, Object?>.from(value)));
      } on FormatException {
        continue;
      } on TypeError {
        continue;
      }
    }
    return List.unmodifiable(result);
  }

  @override
  Future<void> delete(String localReportId) async {
    final all = await _readMap();
    if (all.remove(localReportId) == null) return;
    final preferences = await _loadPreferences();
    if (!await preferences.setString(_key, jsonEncode(all))) {
      throw StateError('AI request binding could not be deleted.');
    }
  }

  Future<Map<String, Object?>> _readMap() async {
    final preferences = await _loadPreferences();
    final encoded = preferences.getString(_key);
    if (encoded == null) return {};
    try {
      final decoded = jsonDecode(encoded);
      return decoded is Map ? Map<String, Object?>.from(decoded) : {};
    } on FormatException {
      return {};
    }
  }

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
}
