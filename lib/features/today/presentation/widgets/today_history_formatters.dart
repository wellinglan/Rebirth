String formatDurationMinutes(int? minutes) {
  if (minutes == null) {
    return '未填写';
  }
  if (minutes == 0) {
    return '0分钟';
  }

  final hours = minutes ~/ 60;
  final minutePart = minutes % 60;
  if (hours == 0) {
    return '$minutePart分钟';
  }
  if (minutePart == 0) {
    return '$hours小时';
  }
  return '$hours小时$minutePart分钟';
}
