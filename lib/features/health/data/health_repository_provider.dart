import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/database/database_provider.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/health/domain/health_repository.dart';

import 'health_repository_impl.dart';

final healthRepositoryProvider = Provider<HealthRepository>((ref) {
  return HealthRepositoryImpl(
    database: ref.watch(appDatabaseProvider),
    dateTimeService: ref.watch(dateTimeServiceProvider),
  );
});
