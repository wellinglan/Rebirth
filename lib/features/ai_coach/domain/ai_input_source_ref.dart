import 'ai_coach_exception.dart';

final class AiInputSourceRef {
  AiInputSourceRef({
    required this.table,
    required this.id,
    required this.updatedAt,
  }) {
    if (!_supportedTables.contains(table)) {
      throw InvalidAiInputException('Unsupported AI source table "$table".');
    }
    if (id.trim().isEmpty || updatedAt < 0) {
      throw const InvalidAiInputException('Invalid AI source reference.');
    }
  }

  static const supportedTables = <String>{
    'today_records',
    'health_records',
    'journal_entries',
    'goals',
  };

  static const _supportedTables = supportedTables;

  final String table;
  final String id;
  final int updatedAt;

  Map<String, Object> toCanonicalMap() => {
    'id': id,
    'table': table,
    'updated_at': updatedAt,
  };

  @override
  bool operator ==(Object other) {
    return other is AiInputSourceRef &&
        other.table == table &&
        other.id == id &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(table, id, updatedAt);
}
