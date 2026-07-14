import 'package:rebirth/features/health/domain/health_entry.dart';
import 'package:rebirth/features/health/domain/health_summary.dart';

final class HealthViewState {
  const HealthViewState({
    required this.today,
    required this.recentEntries,
    required this.summary,
    this.isSaving = false,
  });

  final HealthEntry today;
  final List<HealthEntry> recentEntries;
  final HealthSummary summary;
  final bool isSaving;

  HealthViewState copyWith({
    HealthEntry? today,
    List<HealthEntry>? recentEntries,
    HealthSummary? summary,
    bool? isSaving,
  }) {
    return HealthViewState(
      today: today ?? this.today,
      recentEntries: recentEntries ?? this.recentEntries,
      summary: summary ?? this.summary,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}
