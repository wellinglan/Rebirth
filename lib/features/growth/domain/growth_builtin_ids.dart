import 'growth_identifier.dart';

abstract final class GrowthDimensions {
  static final focus = GrowthDimensionId('growth.focus');
  static final recovery = GrowthDimensionId('growth.recovery');
  static final subjectiveState = GrowthDimensionId('growth.subjective_state');
  static final reflection = GrowthDimensionId('growth.reflection');
}

abstract final class GrowthMetrics {
  static final researchDuration = GrowthMetricId(
    'growth.focus.research_duration',
  );
  static final learningDuration = GrowthMetricId(
    'growth.focus.learning_duration',
  );
  static final sleepDuration = GrowthMetricId('growth.recovery.sleep_duration');
  static final exerciseDuration = GrowthMetricId(
    'growth.recovery.exercise_duration',
  );
  static final moodScore = GrowthMetricId('growth.subjective_state.mood_score');
  static final energyScore = GrowthMetricId(
    'growth.subjective_state.energy_score',
  );
  static final reflectionStatus = GrowthMetricId(
    'growth.reflection.entry_status',
  );
}
