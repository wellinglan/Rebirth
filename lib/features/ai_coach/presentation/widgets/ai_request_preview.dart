import 'package:flutter/material.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_scope.dart';

import '../ai_coach_formatters.dart';
import '../models/ai_request_preview_model.dart';
import '../models/ai_scope_option_model.dart';

class AiRequestPreview extends StatelessWidget {
  const AiRequestPreview({required this.preview, super.key});

  final AiRequestPreviewModel preview;

  @override
  Widget build(BuildContext context) {
    final isDaily = preview.periodStartDate == preview.periodEndDate;
    return Column(
      key: const ValueKey('aiRequestPreview'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          key: ValueKey('aiRequestPreviewLiveRegion'),
          container: true,
          liveRegion: true,
          label: '本地 AI 输入预览已更新',
          child: SizedBox.shrink(),
        ),
        Text('本地输入预览', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('以下内容只在本机显示，不会发送给服务器或 AI 模型。'),
        const SizedBox(height: 12),
        _MetadataCard(preview: preview),
        if (preview.growth case final growth?) ...[
          const SizedBox(height: 16),
          _GrowthPreview(growth: growth),
        ],
        if (preview.scopes.contains(AiDataScope.todayMetrics)) ...[
          const SizedBox(height: 16),
          _TodayPreview(days: preview.todayDays, isDaily: isDaily),
        ],
        if (preview.scopes.contains(AiDataScope.healthMetrics)) ...[
          const SizedBox(height: 16),
          _HealthPreview(days: preview.healthDays, isDaily: isDaily),
        ],
        if (preview.scopes.contains(AiDataScope.journalReflections)) ...[
          const SizedBox(height: 16),
          _JournalPreview(days: preview.journalDays, isDaily: isDaily),
        ],
      ],
    );
  }
}

class _MetadataCard extends StatelessWidget {
  const _MetadataCard({required this.preview});

  final AiRequestPreviewModel preview;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ValueLine(label: '报告类型', value: preview.reportTypeLabel),
            _ValueLine(
              label: preview.periodStartDate == preview.periodEndDate
                  ? '目标日期'
                  : '日期范围',
              value: preview.periodStartDate == preview.periodEndDate
                  ? preview.periodStartDate
                  : '${preview.periodStartDate} 至 ${preview.periodEndDate}',
            ),
            _ValueLine(label: 'Prompt Version', value: preview.promptVersion),
            _ValueLine(label: 'Input Hash', value: preview.shortInputHash),
            _ValueLine(label: '来源记录', value: '${preview.sourceCount} 条'),
            const SizedBox(height: 8),
            Text('已选择范围', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: preview.scopes
                  .map(
                    (scope) =>
                        Chip(label: Text(AiScopeCatalog.titleFor(scope))),
                  )
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _GrowthPreview extends StatelessWidget {
  const _GrowthPreview({required this.growth});

  final AiGrowthPreviewModel growth;

  @override
  Widget build(BuildContext context) {
    return _PreviewSection(
      title: '成长趋势汇总',
      child: Column(
        children: [
          _ValueLine(
            label: '科研总时长',
            value: AiCoachFormatters.minutes(growth.researchTotalMinutes),
          ),
          _ValueLine(
            label: '学习总时长',
            value: AiCoachFormatters.minutes(growth.learningTotalMinutes),
          ),
          _ValueLine(
            label: '运动总时长',
            value: AiCoachFormatters.minutes(growth.exerciseTotalMinutes),
          ),
          _ValueLine(
            label: '平均睡眠',
            value: AiCoachFormatters.averageMinutes(growth.averageSleepMinutes),
          ),
          _ValueLine(
            label: '平均 Mood',
            value: AiCoachFormatters.score(growth.averageMood),
          ),
          _ValueLine(
            label: '平均 Energy',
            value: AiCoachFormatters.score(growth.averageEnergy),
          ),
          _ValueLine(
            label: 'Journal',
            value:
                '${growth.journalRecordedDays} 天记录 / ${growth.journalCompletedDays} 天完成',
          ),
        ],
      ),
    );
  }
}

class _TodayPreview extends StatelessWidget {
  const _TodayPreview({required this.days, required this.isDaily});

  final List<AiTodayDayPreviewModel> days;
  final bool isDaily;

  @override
  Widget build(BuildContext context) {
    return _DatedPreviewSection(
      title: '每日状态指标',
      boundary: 'Daily Note 未包含；Priority 文本未包含。',
      emptyMessage: isDaily ? '当天没有已保存的 Today 记录。' : '最近 7 天没有可预览的 Today 记录。',
      children: days
          .map((day) {
            return _DayCard(
              date: day.date,
              children: [
                _ValueLine(
                  label: '科研',
                  value: AiCoachFormatters.minutes(day.researchMinutes),
                ),
                _ValueLine(
                  label: '学习',
                  value: AiCoachFormatters.minutes(day.learningMinutes),
                ),
                _ValueLine(
                  label: 'Mood',
                  value: AiCoachFormatters.score(day.moodScore),
                ),
                _ValueLine(
                  label: 'Energy',
                  value: AiCoachFormatters.score(day.energyScore),
                ),
                _ValueLine(
                  label: 'Priority',
                  value:
                      '${day.populatedPriorityCount} 项填写 / ${day.completedPriorityCount} 项完成',
                ),
                _ValueLine(label: '状态', value: day.statusLabel),
              ],
            );
          })
          .toList(growable: false),
    );
  }
}

class _HealthPreview extends StatelessWidget {
  const _HealthPreview({required this.days, required this.isDaily});

  final List<AiHealthDayPreviewModel> days;
  final bool isDaily;

  @override
  Widget build(BuildContext context) {
    return _DatedPreviewSection(
      title: '健康指标',
      boundary: 'Health Note 未包含；外部来源标识未包含。',
      emptyMessage: isDaily ? '当天没有已保存的 Health 记录。' : '最近 7 天没有可预览的 Health 记录。',
      children: days
          .map((day) {
            return _DayCard(
              date: day.date,
              children: [
                _ValueLine(
                  label: '睡眠',
                  value: AiCoachFormatters.minutes(day.sleepDurationMinutes),
                ),
                _ValueLine(
                  label: '运动',
                  value: AiCoachFormatters.minutes(day.exerciseDurationMinutes),
                ),
                _ValueLine(
                  label: '饮水',
                  value: day.waterIntakeMl == null
                      ? '未记录'
                      : '${day.waterIntakeMl} ml',
                ),
                _ValueLine(
                  label: '体重',
                  value: day.weightKg == null ? '未记录' : '${day.weightKg} kg',
                ),
                _ValueLine(
                  label: '身体评分',
                  value: AiCoachFormatters.score(day.physicalStateScore),
                ),
              ],
            );
          })
          .toList(growable: false),
    );
  }
}

class _JournalPreview extends StatelessWidget {
  const _JournalPreview({required this.days, required this.isDaily});

  final List<AiJournalDayPreviewModel> days;
  final bool isDaily;

  @override
  Widget build(BuildContext context) {
    return _DatedPreviewSection(
      title: 'Journal 复盘内容',
      boundary: '以下结构化回答仅在本机显示，不会被摘要、改写或分析。',
      emptyMessage: isDaily
          ? '当天没有已保存的 Journal 记录。'
          : '最近 7 天没有可预览的 Journal 内容。',
      children: days
          .map((day) {
            return _DayCard(
              date: day.date,
              children: [
                _ValueLine(label: '状态', value: day.statusLabel),
                _TextAnswer(
                  label: '最重要的完成',
                  value: day.mostImportantAccomplishment,
                ),
                _TextAnswer(label: '最消耗的事情', value: day.mostDrainingEvent),
                _TextAnswer(label: '情绪来源', value: day.emotionSource),
                _TextAnswer(label: '学到了什么', value: day.learning),
                _TextAnswer(label: '明日调整', value: day.tomorrowAdjustment),
              ],
            );
          })
          .toList(growable: false),
    );
  }
}

class _PreviewSection extends StatelessWidget {
  const _PreviewSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Card(
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ],
    );
  }
}

class _DatedPreviewSection extends StatelessWidget {
  const _DatedPreviewSection({
    required this.title,
    required this.boundary,
    required this.emptyMessage,
    required this.children,
  });

  final String title;
  final String boundary;
  final String emptyMessage;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(boundary),
        const SizedBox(height: 8),
        if (children.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(emptyMessage),
            ),
          )
        else
          ...children.expand((child) => [child, const SizedBox(height: 8)]),
      ],
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.date, required this.children});

  final String date;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(date, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ValueLine extends StatelessWidget {
  const _ValueLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 360) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 2),
                Text(value),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 124, child: Text(label)),
              Expanded(child: Text(value)),
            ],
          );
        },
      ),
    );
  }
}

class _TextAnswer extends StatelessWidget {
  const _TextAnswer({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 3),
          Text(AiCoachFormatters.nullableText(value)),
        ],
      ),
    );
  }
}
