import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/growth/domain/growth_period.dart';
import 'package:rebirth/features/growth/presentation/growth_formatters.dart';

void main() {
  test('formats missing and minute durations without meaningless decimals', () {
    expect(GrowthFormatters.duration(null), '暂无数据');
    expect(GrowthFormatters.duration(0), '0 分钟');
    expect(GrowthFormatters.duration(59), '59 分钟');
    expect(GrowthFormatters.duration(60), '1 小时');
    expect(GrowthFormatters.duration(65), '1 小时 5 分钟');
  });

  test('formats score to one decimal place', () {
    expect(GrowthFormatters.score(null), '暂无数据');
    expect(GrowthFormatters.score(3.75), '3.8 / 5');
  });

  test('formats same-month, cross-month, and cross-year date ranges', () {
    expect(
      GrowthFormatters.dateRange('2026-07-10', '2026-07-16'),
      '7月10日 — 7月16日',
    );
    expect(
      GrowthFormatters.dateRange('2026-06-17', '2026-07-16'),
      '6月17日 — 7月16日',
    );
    expect(
      GrowthFormatters.dateRange('2025-12-20', '2026-01-18'),
      '2025年12月20日 — 2026年1月18日',
    );
  });

  test('thirty-day labels are sparse while first and last remain visible', () {
    final visible = List<int>.generate(30, (index) => index)
        .where(
          (index) => GrowthFormatters.showAxisLabel(
            index: index,
            pointCount: 30,
            period: GrowthPeriod.thirtyDays,
          ),
        )
        .toList();

    expect(visible, [0, 6, 12, 18, 24, 29]);
    expect(
      GrowthFormatters.showAxisLabel(
        index: 3,
        pointCount: 7,
        period: GrowthPeriod.sevenDays,
      ),
      isTrue,
    );
  });

  test('invalid date remains diagnosable', () {
    expect(
      () => GrowthFormatters.dateRange('2026-02-30', '2026-03-01'),
      throwsFormatException,
    );
  });
}
