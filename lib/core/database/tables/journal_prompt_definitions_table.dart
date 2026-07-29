import 'package:drift/drift.dart';

import 'common_columns.dart';
import 'journal_prompt_configurations_table.dart';

@DataClassName('JournalPromptDefinitionRow')
class JournalPromptDefinitions extends Table
    with UuidPrimaryKey, SoftDeleteColumn {
  TextColumn get configurationId => text().references(
    JournalPromptConfigurations,
    #id,
    onDelete: KeyAction.restrict,
  )();

  TextColumn get stableKey => text().nullable()();

  TextColumn get promptSource => text()();

  TextColumn get questionText => text().withLength(min: 1, max: 500)();

  TextColumn get helperText => text().withLength(max: 500).nullable()();

  TextColumn get responseKind =>
      text().withDefault(const Constant('long_text'))();

  IntColumn get displayOrder => integer()();

  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();

  IntColumn get promptVersion => integer().withDefault(const Constant(1))();

  IntColumn get createdAt => integer().clientDefault(utcNowMilliseconds)();

  IntColumn get updatedAt => integer().clientDefault(utcNowMilliseconds)();

  @override
  List<String> get customConstraints => const [
    "CHECK (prompt_source IN ('system', 'user', 'future_ai'))",
    "CHECK (response_kind = 'long_text')",
    'CHECK (display_order >= 0)',
    'CHECK (prompt_version >= 1)',
    'CHECK (length(trim(question_text)) > 0)',
    "CHECK ((prompt_source = 'system' AND stable_key IS NOT NULL "
        "AND length(trim(stable_key)) > 0) OR "
        "(prompt_source != 'system' AND stable_key IS NULL))",
    'CHECK (deleted_at IS NULL OR deleted_at >= 0)',
    'CHECK (deleted_at IS NULL OR is_enabled = 0)',
    'CHECK (created_at >= 0)',
    'CHECK (updated_at >= 0)',
  ];
}
