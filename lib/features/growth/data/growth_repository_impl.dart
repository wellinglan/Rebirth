import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/growth/application/growth_projection_engine.dart';
import 'package:rebirth/features/growth/domain/growth_aggregator.dart';
import 'package:rebirth/features/growth/domain/growth_period.dart';
import 'package:rebirth/features/growth/domain/growth_projection_context.dart';
import 'package:rebirth/features/growth/domain/growth_repository.dart';
import 'package:rebirth/features/growth/domain/growth_snapshot.dart';
import 'package:rebirth/features/personal_data/application/personal_data_aggregation_engine.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_capability.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_query.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_time_range.dart';

final class GrowthRepositoryImpl implements GrowthRepository {
  const GrowthRepositoryImpl({
    required this.aggregationEngine,
    required this.projectionEngine,
    required this.dateTimeService,
    this.aggregator = const GrowthAggregator(),
  });

  final PersonalDataAggregationEngine aggregationEngine;
  final GrowthProjectionEngine projectionEngine;
  final DateTimeService dateTimeService;
  final GrowthAggregator aggregator;

  @override
  Future<GrowthSnapshot> loadRecent(GrowthPeriod period) async {
    final clock = dateTimeService.currentSnapshot();
    final dateRange = dateTimeService.recentLocalDateRange(
      period.days,
      endingAt: clock.now,
    );
    final timeRange = PersonalDataTimeRange.forSystemLocalDateRange(
      startLocalDate: dateRange.first,
      endLocalDateInclusive: dateRange.last,
    );
    final query = PersonalDataQuery(
      timeRange: timeRange,
      localTimeContext: PersonalDataLocalTimeContext(
        timezoneOffsetMinutes: clock.timezoneOffsetMinutes,
        timezoneId: 'device-local',
      ),
      requestedAtUtc: DateTime.fromMillisecondsSinceEpoch(
        clock.utcMilliseconds,
        isUtc: true,
      ),
      purpose: PersonalDataAggregationPurpose.localTimeline,
      requestedCapabilities: {
        PersonalDataCapability.dailyState,
        PersonalDataCapability.reflection,
        PersonalDataCapability.wellbeingMetrics,
      },
      maxItemsPerProvider: period.days,
    );
    final aggregation = await aggregationEngine.aggregate(query);
    final context = GrowthProjectionContext(
      period: period,
      timeRange: timeRange,
      expectedLocalDates: dateRange,
      generatedAtUtc: query.requestedAtUtc,
    );
    final projection = projectionEngine.project(aggregation, context);
    return aggregator.aggregate(
      period: period,
      dateRange: dateRange,
      projection: projection,
    );
  }
}
