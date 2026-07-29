import 'personal_data_identifier.dart';

final class PersonalDataCapability
    implements Comparable<PersonalDataCapability> {
  PersonalDataCapability(String id) : id = PersonalDataFactKey(id);

  final PersonalDataFactKey id;

  String get value => id.value;

  static final identity = PersonalDataCapability('core.identity');
  static final timeline = PersonalDataCapability('core.timeline');
  static final dailySummary = PersonalDataCapability('core.daily_summary');
  static final goalTracking = PersonalDataCapability('plan.goal_tracking');
  static final dailyState = PersonalDataCapability('today.daily_state');
  static final reflection = PersonalDataCapability('journal.reflection');
  static final wellbeingMetrics = PersonalDataCapability(
    'health.wellbeing_metrics',
  );

  @override
  int compareTo(PersonalDataCapability other) => id.compareTo(other.id);

  @override
  bool operator ==(Object other) =>
      other is PersonalDataCapability && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => value;
}
