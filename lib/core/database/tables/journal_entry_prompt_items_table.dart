import 'package:drift/drift.dart';

import 'common_columns.dart';
import 'journal_entries_table.dart';

@DataClassName('JournalEntryPromptItemRow')
class JournalEntryPromptItems extends Table with UuidPrimaryKey {
  TextColumn get journalEntryId =>
      text().references(JournalEntries, #id, onDelete: KeyAction.cascade)();

  TextColumn get sourcePromptId => text().nullable()();

  TextColumn get sourcePromptStableKey => text().nullable()();

  IntColumn get sourcePromptVersion => integer()();

  TextColumn get promptSource => text()();

  TextColumn get questionTextSnapshot => text().withLength(min: 1, max: 500)();

  TextColumn get helperTextSnapshot => text().withLength(max: 500).nullable()();

  TextColumn get responseKind =>
      text().withDefault(const Constant('long_text'))();

  IntColumn get displayOrder => integer()();

  TextColumn get answerText => text().withLength(max: 20000).nullable()();

  IntColumn get createdAt => integer().clientDefault(utcNowMilliseconds)();

  IntColumn get updatedAt => integer().clientDefault(utcNowMilliseconds)();

  @override
  List<String> get customConstraints => const [
    'CHECK (source_prompt_version >= 1)',
    "CHECK (prompt_source IN ('system', 'user', 'future_ai'))",
    "CHECK (response_kind = 'long_text')",
    'CHECK (display_order >= 0)',
    'CHECK (length(trim(question_text_snapshot)) > 0)',
    'CHECK (answer_text IS NULL OR length(trim(answer_text)) > 0)',
    'CHECK (created_at >= 0)',
    'CHECK (updated_at >= 0)',
  ];
}
