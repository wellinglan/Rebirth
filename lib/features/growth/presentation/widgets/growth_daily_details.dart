import 'package:flutter/material.dart';
import 'package:rebirth/core/theme/app_layout.dart';
import 'package:rebirth/core/theme/app_typography.dart';
import 'package:rebirth/features/growth/domain/growth_day_snapshot.dart';

import '../growth_formatters.dart';

class GrowthDailyDetails extends StatefulWidget {
  const GrowthDailyDetails({required this.days, super.key});

  final List<GrowthDaySnapshot> days;

  @override
  State<GrowthDailyDetails> createState() => _GrowthDailyDetailsState();
}

class _GrowthDailyDetailsState extends State<GrowthDailyDetails> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey('growthDailyDetails'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label: '每日数据明细',
            value: _isExpanded ? '已展开' : '已折叠',
            hint: _isExpanded ? '激活以折叠' : '激活以展开',
            button: true,
            expanded: _isExpanded,
            onTap: _toggle,
            container: true,
            child: ExcludeSemantics(
              child: ListTile(
                key: const ValueKey('growthDailyDetailsToggle'),
                title: const Text('每日数据明细'),
                subtitle: Text('${widget.days.length} 天的只读记录'),
                trailing: Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                ),
                onTap: _toggle,
              ),
            ),
          ),
          if (_isExpanded) ...[
            const Divider(),
            Padding(
              key: const ValueKey('growthDailyDetailsContent'),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                children: [
                  for (
                    var index = 0;
                    index < widget.days.length;
                    index += 1
                  ) ...[
                    GrowthDailyDetailRow(day: widget.days[index]),
                    if (index != widget.days.length - 1)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                        child: Divider(),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _toggle() {
    setState(() => _isExpanded = !_isExpanded);
  }
}

class GrowthDailyDetailRow extends StatelessWidget {
  const GrowthDailyDetailRow({required this.day, super.key});

  final GrowthDaySnapshot day;

  @override
  Widget build(BuildContext context) {
    final date = GrowthFormatters.fullDate(day.date);
    final metrics = <({String label, String value})>[
      (
        label: '科研',
        value: GrowthFormatters.detailDuration(day.researchMinutes),
      ),
      (
        label: '学习',
        value: GrowthFormatters.detailDuration(day.learningMinutes),
      ),
      (label: '睡眠', value: GrowthFormatters.detailDuration(day.sleepMinutes)),
      (
        label: '运动',
        value: GrowthFormatters.detailDuration(day.exerciseMinutes),
      ),
      (label: 'Mood', value: GrowthFormatters.detailScore(day.moodScore)),
      (label: 'Energy', value: GrowthFormatters.detailScore(day.energyScore)),
      (
        label: 'Journal',
        value: GrowthFormatters.journalStatus(
          recorded: day.journalRecorded,
          completed: day.journalCompleted,
        ),
      ),
    ];
    final semanticLabel = <String>[
      date,
      for (final metric in metrics) '${metric.label}：${metric.value}',
    ].join('；');

    return Semantics(
      key: ValueKey('growthDailyDetailSemantics_${day.date}'),
      label: semanticLabel,
      readOnly: true,
      container: true,
      excludeSemantics: true,
      child: Column(
        key: ValueKey('growthDailyDetail_${day.date}'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            date,
            style: AppTypography.numericStyle(
              Theme.of(context).textTheme.titleSmall!,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 560 ? 2 : 1;
              final width =
                  (constraints.maxWidth - AppSpacing.sm * (columns - 1)) /
                  columns;
              return Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xxs,
                children: [
                  for (final metric in metrics)
                    SizedBox(
                      width: width,
                      child: Text('${metric.label}：${metric.value}'),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
