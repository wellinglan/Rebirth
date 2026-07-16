enum GrowthChartMetric { research, learning, sleep, exercise, mood, energy }

final class GrowthChartPoint {
  const GrowthChartPoint({
    required this.index,
    required this.date,
    required this.value,
  });

  final int index;
  final String date;
  final int? value;
}

final class GrowthChartSeries {
  GrowthChartSeries({
    required this.metric,
    required this.label,
    required List<GrowthChartPoint> points,
  }) : points = List<GrowthChartPoint>.unmodifiable(points);

  final GrowthChartMetric metric;
  final String label;
  final List<GrowthChartPoint> points;

  bool get hasRecordedValues => points.any((point) => point.value != null);
  int get recordedPointCount =>
      points.where((point) => point.value != null).length;
  int get total => points.fold(0, (sum, point) => sum + (point.value ?? 0));
  double? get average =>
      recordedPointCount == 0 ? null : total / recordedPointCount;
}

enum GrowthJournalDayStatus { missing, recordedDraft, completed }

final class GrowthJournalDay {
  const GrowthJournalDay({required this.date, required this.status});

  final String date;
  final GrowthJournalDayStatus status;
}

final class GrowthPresentationData {
  GrowthPresentationData({
    required this.research,
    required this.learning,
    required this.sleep,
    required this.exercise,
    required this.mood,
    required this.energy,
    required List<GrowthJournalDay> journalDays,
  }) : journalDays = List<GrowthJournalDay>.unmodifiable(journalDays);

  final GrowthChartSeries research;
  final GrowthChartSeries learning;
  final GrowthChartSeries sleep;
  final GrowthChartSeries exercise;
  final GrowthChartSeries mood;
  final GrowthChartSeries energy;
  final List<GrowthJournalDay> journalDays;
}
