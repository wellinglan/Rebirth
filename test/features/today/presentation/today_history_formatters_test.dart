import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/today/domain/today_entry.dart';
import 'package:rebirth/features/today/presentation/widgets/today_history_formatters.dart';

void main() {
  test(
    'history status is derived from content and date, not database status',
    () {
      expect(
        todayHistoryStatusLabel(
          entry: _entry(date: '2026-07-13', note: '有内容'),
          today: '2026-07-14',
        ),
        '已记录',
      );
      expect(
        todayHistoryStatusLabel(
          entry: _entry(date: '2026-07-14', note: '有内容'),
          today: '2026-07-14',
        ),
        '今日记录',
      );
      expect(
        todayHistoryStatusLabel(
          entry: _entry(date: '2026-07-13'),
          today: '2026-07-14',
        ),
        '空记录',
      );
    },
  );
}

TodayEntry _entry({required String date, String? note}) => TodayEntry(
  id: date,
  userId: 'user',
  recordDate: date,
  timezoneOffsetMinutes: 480,
  priorities: const [TodayPriority(), TodayPriority(), TodayPriority()],
  moodScore: null,
  energyScore: null,
  researchMinutes: null,
  learningMinutes: null,
  dailyNote: note,
  status: TodayRecordStatus.draft,
  createdAt: 1,
  updatedAt: 1,
  health: null,
);
