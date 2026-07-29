import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/growth/application/growth_projection_providers.dart';
import 'package:rebirth/features/growth/domain/growth_repository.dart';
import 'package:rebirth/features/personal_data/application/personal_data_providers.dart';

import 'growth_repository_impl.dart';

final growthRepositoryProvider = Provider<GrowthRepository>((ref) {
  return GrowthRepositoryImpl(
    aggregationEngine: ref.watch(personalDataAggregationEngineProvider),
    projectionEngine: ref.watch(growthProjectionEngineProvider),
    dateTimeService: ref.watch(dateTimeServiceProvider),
  );
});
