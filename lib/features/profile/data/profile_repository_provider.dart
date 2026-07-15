import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/database/database_provider.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/profile/domain/profile_repository.dart';

import 'profile_repository_impl.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepositoryImpl(
    database: ref.watch(appDatabaseProvider),
    dateTimeService: ref.watch(dateTimeServiceProvider),
  );
});
