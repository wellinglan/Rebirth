import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_time_service_provider.dart';
import '../../account/presentation/app_auth_controller.dart';
import '../../health/data/health_repository_provider.dart';
import '../../health/domain/health_entry.dart';
import '../../today/data/today_repository_provider.dart';
import '../../today/domain/today_entry.dart';
import '../../../shared/state/health_record_revision_provider.dart';
import '../domain/home_overview.dart';

final homeOverviewProvider = FutureProvider.autoDispose<HomeOverview>((
  ref,
) async {
  ref.watch(appAuthStateProvider);
  ref.watch(healthRecordRevisionProvider);
  final recordDate = ref
      .read(dateTimeServiceProvider)
      .currentSnapshot()
      .localDateString;

  final todayFuture = ref
      .read(todayRepositoryProvider)
      .getByDate(recordDate)
      .then<(Object?, Object?)>((value) => (value, null))
      .catchError((Object error) => (null, error));
  final healthFuture = ref
      .read(healthRepositoryProvider)
      .getByDate(recordDate)
      .then<(Object?, Object?)>((value) => (value, null))
      .catchError((Object error) => (null, error));
  final results = await Future.wait([todayFuture, healthFuture]);

  return HomeOverview(
    recordDate: recordDate,
    today: results[0].$1 as TodayEntry?,
    todayError: results[0].$2,
    health: results[1].$1 as HealthEntry?,
    healthError: results[1].$2,
  );
});
