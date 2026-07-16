import 'dart:convert';
import 'dart:collection';

import 'package:rebirth/features/ai_coach/domain/ai_coach_exception.dart';
import 'package:rebirth/features/ai_coach/domain/canonical_json_encoder.dart';

final class CanonicalJsonEncoderImpl implements CanonicalJsonEncoder {
  const CanonicalJsonEncoderImpl();

  @override
  String encode(Object? value) => jsonEncode(_canonicalize(value));

  Object? _canonicalize(Object? value) {
    if (value == null || value is String || value is bool || value is int) {
      return value;
    }
    if (value is double) {
      if (!value.isFinite) {
        throw const InvalidAiInputException(
          'Non-finite numbers are not valid canonical JSON.',
        );
      }
      return value;
    }
    if (value is List) {
      return value.map(_canonicalize).toList(growable: false);
    }
    if (value is Map) {
      if (value.keys.any((key) => key is! String)) {
        throw const InvalidAiInputException(
          'Canonical JSON object keys must be strings.',
        );
      }
      final sorted = SplayTreeMap<String, Object?>();
      for (final entry in value.entries) {
        sorted[entry.key as String] = _canonicalize(entry.value);
      }
      return sorted;
    }
    throw const InvalidAiInputException(
      'Unsupported value in canonical JSON contract.',
    );
  }
}
