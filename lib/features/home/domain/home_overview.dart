import '../../health/domain/health_entry.dart';
import '../../today/domain/today_entry.dart';

final class HomeOverview {
  const HomeOverview({
    required this.recordDate,
    required this.today,
    required this.health,
    this.todayError,
    this.healthError,
  });

  final String recordDate;
  final TodayEntry? today;
  final HealthEntry? health;
  final Object? todayError;
  final Object? healthError;

  bool get hasPartialFailure => todayError != null || healthError != null;
  bool get hasData => today != null || health != null;
}
