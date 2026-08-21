import 'package:drift/drift.dart';

import 'ai_chat_threads_table.dart';
import 'common_columns.dart';
import 'user_profiles_table.dart';

@DataClassName('AiChatMessageRow')
class AiChatMessages extends Table with UuidPrimaryKey, TimestampColumns {
  TextColumn get threadId =>
      text().references(AiChatThreads, #id, onDelete: KeyAction.cascade)();

  TextColumn get userId =>
      text().references(UserProfiles, #id, onDelete: KeyAction.restrict)();

  TextColumn get role => text()();

  IntColumn get sequence => integer()();

  TextColumn get content => text().withDefault(const Constant(''))();

  TextColumn get requestId => text().nullable()();

  TextColumn get status => text()();

  TextColumn get promptVersion => text().nullable()();

  TextColumn get safetyCategory => text().nullable()();

  TextColumn get errorCode => text().nullable()();

  @override
  List<String> get customConstraints => const [
    "CHECK (role IN ('user', 'assistant'))",
    'CHECK (sequence >= 0)',
    "CHECK (status IN ('pending', 'completed', 'failed', 'outcome_unknown'))",
    "CHECK (role = 'assistant' OR status = 'completed')",
    "CHECK (role = 'user' OR request_id IS NOT NULL)",
    "CHECK (role = 'user' OR prompt_version IS NOT NULL)",
    "CHECK (status != 'completed' OR length(trim(content)) > 0)",
    "CHECK (safety_category IS NULL OR safety_category IN ('normal', 'caution', 'high_risk'))",
    'CHECK (created_at >= 0)',
    'CHECK (updated_at >= created_at)',
  ];
}
