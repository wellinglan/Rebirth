import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import 'daos/bootstrap_dao.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final appBootstrapProvider = FutureProvider<DatabaseBootstrapResult>((ref) {
  return ref.watch(appDatabaseProvider).bootstrapDao.bootstrap();
});
