import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/database/database_provider.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/journal/domain/journal_prompt_repository.dart';

import 'journal_prompt_repository_impl.dart';

final journalPromptRepositoryProvider = Provider<JournalPromptRepository>((
  ref,
) {
  return JournalPromptRepositoryImpl(
    database: ref.watch(appDatabaseProvider),
    dateTimeService: ref.watch(dateTimeServiceProvider),
  );
});
