import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/database/database_provider.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/journal/domain/journal_repository.dart';

import 'journal_repository_impl.dart';

final journalRepositoryProvider = Provider<JournalRepository>((ref) {
  return JournalRepositoryImpl(
    database: ref.watch(appDatabaseProvider),
    dateTimeService: ref.watch(dateTimeServiceProvider),
  );
});
