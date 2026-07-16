import 'ai_coach_exception.dart';
import 'ai_data_selection.dart';
import 'ai_input_source_ref.dart';
import 'ai_report_type.dart';

final class AiCoachInputBundle {
  AiCoachInputBundle({
    required this.reportType,
    required this.promptVersion,
    required this.periodStartDate,
    required this.periodEndDate,
    required this.selection,
    required List<AiInputSourceRef> sources,
    required Map<String, Object?> canonicalPayload,
    required this.canonicalJson,
    required this.inputHash,
  }) : sources = List<AiInputSourceRef>.unmodifiable(sources),
       canonicalPayload = _freezeMap(canonicalPayload) {
    if (promptVersion.trim().isEmpty || canonicalJson.isEmpty) {
      throw const InvalidAiInputException();
    }
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(inputHash)) {
      throw const InvalidAiInputException('Invalid AI input hash.');
    }
    if (periodStartDate.compareTo(periodEndDate) > 0) {
      throw const InvalidAiInputException('Invalid AI report period.');
    }
  }

  final AiReportType reportType;
  final String promptVersion;
  final String periodStartDate;
  final String periodEndDate;
  final AiDataSelection selection;
  final List<AiInputSourceRef> sources;
  final Map<String, Object?> canonicalPayload;
  final String canonicalJson;
  final String inputHash;
}

Map<String, Object?> _freezeMap(Map<String, Object?> value) {
  return Map<String, Object?>.unmodifiable(
    value.map((key, item) => MapEntry(key, _freezeValue(item))),
  );
}

Object? _freezeValue(Object? value) {
  if (value is Map<String, Object?>) return _freezeMap(value);
  if (value is List<Object?>) {
    return List<Object?>.unmodifiable(value.map(_freezeValue));
  }
  return value;
}
