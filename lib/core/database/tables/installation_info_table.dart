import 'package:drift/drift.dart';

@DataClassName('InstallationInfoRow')
class InstallationInfo extends Table {
  @override
  String get tableName => 'installation_info';

  IntColumn get singletonId => integer().withDefault(const Constant(1))();

  TextColumn get installationId =>
      text().withLength(min: 36, max: 36).unique()();

  IntColumn get createdAt => integer()();

  TextColumn get platform => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {singletonId};

  @override
  List<String> get customConstraints => const [
    'CHECK (singleton_id = 1)',
    'CHECK (created_at >= 0)',
    'CHECK (platform IS NULL OR length(trim(platform)) > 0)',
  ];
}
