import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

QueryExecutor openDatabaseConnection() {
  return LazyDatabase(() async {
    final supportDirectory = await getApplicationSupportDirectory();
    final databaseDirectory = Directory(
      p.join(supportDirectory.path, 'Rebirth'),
    );
    await databaseDirectory.create(recursive: true);

    final databaseFile = File(p.join(databaseDirectory.path, 'rebirth.sqlite'));
    return NativeDatabase.createInBackground(databaseFile);
  });
}
