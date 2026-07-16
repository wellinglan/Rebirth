import 'package:rebirth/features/growth/domain/growth_period.dart';
import 'package:rebirth/features/growth/domain/growth_snapshot.dart';

final class GrowthViewState {
  const GrowthViewState({
    required this.period,
    required this.snapshot,
    this.isRefreshing = false,
    this.refreshFailed = false,
  });

  final GrowthPeriod period;
  final GrowthSnapshot snapshot;
  final bool isRefreshing;
  final bool refreshFailed;

  bool get isCompletelyEmpty =>
      snapshot.researchSummary.recordedDayCount == 0 &&
      snapshot.learningSummary.recordedDayCount == 0 &&
      snapshot.exerciseSummary.recordedDayCount == 0 &&
      snapshot.sleepSummary.recordedDayCount == 0 &&
      snapshot.moodSummary.recordedDayCount == 0 &&
      snapshot.energySummary.recordedDayCount == 0 &&
      snapshot.journalRecordedDays == 0;

  GrowthViewState copyWith({
    GrowthPeriod? period,
    GrowthSnapshot? snapshot,
    bool? isRefreshing,
    bool? refreshFailed,
  }) {
    return GrowthViewState(
      period: period ?? this.period,
      snapshot: snapshot ?? this.snapshot,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      refreshFailed: refreshFailed ?? this.refreshFailed,
    );
  }
}
