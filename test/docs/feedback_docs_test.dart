import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('module feedback files exist and retain the requested topics', () {
    final readme = File('docs/backlog/feedback/README.md');
    final today = File('docs/backlog/feedback/01_today_feedback.md');
    final journal = File('docs/backlog/feedback/02_journal_feedback.md');
    final plan = File('docs/backlog/feedback/03_plan_feedback.md');
    final legacy = File('docs/backlog/01_today_journal_usage_feedback.md');

    for (final file in [readme, today, journal, plan, legacy]) {
      expect(file.existsSync(), isTrue, reason: '${file.path} should exist');
    }

    expect(readme.readAsStringSync(), contains('独立的 feedback 文件'));
    expect(today.readAsStringSync(), contains('过了一天仍显示“草稿”'));
    expect(journal.readAsStringSync(), contains('# Journal Feedback'));
    final planText = plan.readAsStringSync();
    expect(planText, contains('日期输入不友好'));
    expect(planText, contains('custom / 自定义'));
    expect(planText, contains('目标日期应根据目标层级自动计算'));
    expect(planText, contains('优先级'));
    expect(
      legacy.readAsStringSync(),
      contains('后续以 `docs/backlog/feedback/` 下的模块级反馈文件为准'),
    );
  });
}
