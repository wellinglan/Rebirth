import 'package:drift/drift.dart';

import 'ai_reports_table.dart';
import 'common_columns.dart';

@DataClassName('AiReportVersionRow')
class AiReportVersions extends Table with UuidPrimaryKey, TimestampColumns {
  TextColumn get reportId =>
      text().references(AiReports, #id, onDelete: KeyAction.restrict)();

  IntColumn get version => integer()();

  TextColumn get status => text()();

  TextColumn get generationSource => text()();

  TextColumn get modelMetadataJson => text().nullable()();

  TextColumn get content => text().nullable()();

  TextColumn get sensitivity => text()();

  TextColumn get quality => text()();

  TextColumn get errorCode => text().nullable()();

  IntColumn get completedAt => integer().nullable()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {reportId, version},
  ];

  @override
  List<String> get customConstraints => const [
    'CHECK (version > 0)',
    "CHECK (status IN ('completed', 'failed'))",
    'CHECK (length(trim(generation_source)) > 0)',
    "CHECK (status != 'completed' OR (content IS NOT NULL AND length(trim(content)) > 0))",
    "CHECK (status != 'failed' OR (error_code IS NOT NULL AND length(trim(error_code)) > 0))",
    "CHECK (sensitivity IN ('standard', 'high', 'restricted'))",
    "CHECK (quality IN ('unknown', 'unreviewed', 'validated'))",
    'CHECK (created_at >= 0)',
    'CHECK (updated_at >= created_at)',
    'CHECK (completed_at IS NULL OR completed_at >= created_at)',
  ];
}
