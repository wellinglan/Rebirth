import 'package:drift/drift.dart';

import 'common_columns.dart';
import 'user_profiles_table.dart';

@DataClassName('AiChatThreadRow')
class AiChatThreads extends Table with UuidPrimaryKey, TimestampColumns {
  TextColumn get userId =>
      text().references(UserProfiles, #id, onDelete: KeyAction.restrict)();

  TextColumn get title => text().withLength(min: 1, max: 120)();

  IntColumn get archivedAt => integer().nullable()();

  @override
  List<String> get customConstraints => const [
    'CHECK (length(trim(title)) > 0)',
    'CHECK (created_at >= 0)',
    'CHECK (updated_at >= created_at)',
    'CHECK (archived_at IS NULL OR archived_at >= created_at)',
  ];
}
