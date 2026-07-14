import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('module feedback files exist and retain the requested topics', () {
    final readme = File('docs/backlog/feedback/README.md');
    final today = File('docs/backlog/feedback/01_today_feedback.md');
    final journal = File('docs/backlog/feedback/02_journal_feedback.md');
    final plan = File('docs/backlog/feedback/03_plan_feedback.md');
    final health = File('docs/backlog/feedback/04_health_feedback.md');
    final legacy = File('docs/backlog/01_today_journal_usage_feedback.md');

    for (final file in [readme, today, journal, plan, health, legacy]) {
      expect(file.existsSync(), isTrue, reason: '${file.path} should exist');
    }

    expect(readme.readAsStringSync(), contains('独立的 feedback 文件'));
    final todayText = today.readAsStringSync();
    expect(todayText, contains('过了一天仍显示“草稿”'));
    expect(todayText, contains('Today 与 Health 数据同步延迟'));
    expect(todayText, contains('Today 历史记录包含今天'));
    expect(todayText, contains('Sprint UI-1B 实现'));
    final journalText = journal.readAsStringSync();
    expect(journalText, contains('# Journal Feedback'));
    expect(journalText, contains('Journal 历史详情问答层级不清晰'));
    final planText = plan.readAsStringSync();
    expect(planText, contains('日期输入不友好'));
    expect(planText, contains('custom / 自定义'));
    expect(planText, contains('目标日期应根据目标层级自动计算'));
    expect(planText, contains('优先级'));
    expect(planText, contains('缺少删除计划功能'));
    expect(planText, contains('手动状态设置不符合使用直觉'));
    expect(planText, contains('日期选择组件响应延迟明显'));
    expect(planText, contains('缺少归档功能'));
    expect(planText, contains('缺少分类、筛选、排序能力'));
    final healthText = health.readAsStringSync();
    expect(healthText, contains('# Health Feedback'));
    expect(healthText, contains('Health 与 Today 数据同步延迟'));
    expect(healthText, contains('Health 历史记录包含今天'));
    expect(
      legacy.readAsStringSync(),
      contains('后续以 `docs/backlog/feedback/` 下的模块级反馈文件为准'),
    );
  });
}
