import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/growth/domain/growth_repository.dart';
import 'package:rebirth/features/health/data/health_repository_provider.dart';
import 'package:rebirth/features/journal/data/journal_repository_provider.dart';
import 'package:rebirth/features/today/data/today_repository_provider.dart';

import 'growth_repository_impl.dart';

final growthRepositoryProvider = Provider<GrowthRepository>((ref) {
  return GrowthRepositoryImpl(
    todayRepository: ref.watch(todayRepositoryProvider),
    healthRepository: ref.watch(healthRepositoryProvider),
    journalRepository: ref.watch(journalRepositoryProvider),
    dateTimeService: ref.watch(dateTimeServiceProvider),
  );
});
