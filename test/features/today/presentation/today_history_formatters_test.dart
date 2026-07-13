import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/today/presentation/widgets/today_history_formatters.dart';

void main() {
  test('formats nullable minute durations for read-only history', () {
    expect(formatDurationMinutes(null), '未填写');
    expect(formatDurationMinutes(0), '0分钟');
    expect(formatDurationMinutes(30), '30分钟');
    expect(formatDurationMinutes(60), '1小时');
    expect(formatDurationMinutes(90), '1小时30分钟');
  });
}
