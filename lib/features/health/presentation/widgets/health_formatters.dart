String formatHealthDuration(int? totalMinutes) {
  if (totalMinutes == null) {
    return '未填写';
  }
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours == 0) {
    return '$minutes分钟';
  }
  if (minutes == 0) {
    return '$hours小时';
  }
  return '$hours小时$minutes分钟';
}

String formatHealthWeight(double? weightKg) {
  if (weightKg == null) {
    return '未填写';
  }
  final value = weightKg == weightKg.roundToDouble()
      ? weightKg.toStringAsFixed(0)
      : weightKg.toStringAsFixed(1);
  return '$value kg';
}
