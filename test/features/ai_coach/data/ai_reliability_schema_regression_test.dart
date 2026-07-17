import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart';

void main() {
  test(
    'Sprint 8E keeps Flutter schema version 3 without a binding table',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      expect(database.schemaVersion, 3);
      final tables = await database
          .customSelect("SELECT name FROM sqlite_master WHERE type='table'")
          .get();
      expect(
        tables.map((row) => row.read<String>('name')),
        isNot(contains('ai_generation_request_bindings')),
      );
    },
  );
}
