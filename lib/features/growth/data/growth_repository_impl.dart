import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/growth/domain/growth_aggregator.dart';
import 'package:rebirth/features/growth/domain/growth_period.dart';
import 'package:rebirth/features/growth/domain/growth_repository.dart';
import 'package:rebirth/features/growth/domain/growth_snapshot.dart';
import 'package:rebirth/features/health/domain/health_entry.dart';
import 'package:rebirth/features/health/domain/health_repository.dart';
import 'package:rebirth/features/journal/domain/journal_entry.dart';
import 'package:rebirth/features/journal/domain/journal_repository.dart';
import 'package:rebirth/features/today/domain/today_entry.dart';
import 'package:rebirth/features/today/domain/today_repository.dart';

final class GrowthRepositoryImpl implements GrowthRepository {
  const GrowthRepositoryImpl({
    required this.todayRepository,
    required this.healthRepository,
    required this.journalRepository,
    required this.dateTimeService,
    this.aggregator = const GrowthAggregator(),
  });

  final TodayRepository todayRepository;
  final HealthRepository healthRepository;
  final JournalRepository journalRepository;
  final DateTimeService dateTimeService;
  final GrowthAggregator aggregator;

  @override
  Future<GrowthSnapshot> loadRecent(GrowthPeriod period) async {
    final now = dateTimeService.currentSnapshot().now;
    final dateRange = dateTimeService.recentLocalDateRange(
      period.days,
      endingAt: now,
    );
    final startDate = dateRange.first;
    final endDate = dateRange.last;

    late List<TodayEntry> todayEntries;
    late List<HealthEntry> healthEntries;
    late List<JournalEntry> journalEntries;

    await Future.wait<void>([
      todayRepository
          .listByDateRange(startDate: startDate, endDate: endDate)
          .then<void>((entries) {
            todayEntries = entries;
          }),
      healthRepository
          .listByDateRange(startDate: startDate, endDate: endDate)
          .then<void>((entries) {
            healthEntries = entries;
          }),
      journalRepository
          .listByDateRange(startDate: startDate, endDate: endDate)
          .then<void>((entries) {
            journalEntries = entries;
          }),
    ]);

    return aggregator.aggregate(
      period: period,
      dateRange: dateRange,
      todayEntries: todayEntries,
      healthEntries: healthEntries,
      journalEntries: journalEntries,
    );
  }
}
