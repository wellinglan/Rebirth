import 'package:flutter/material.dart';
import 'package:rebirth/features/growth/domain/growth_period.dart';

class GrowthPeriodSelector extends StatelessWidget {
  const GrowthPeriodSelector({
    required this.period,
    required this.onChanged,
    super.key,
  });

  final GrowthPeriod period;
  final ValueChanged<GrowthPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '成长趋势周期选择',
      container: true,
      child: SegmentedButton<GrowthPeriod>(
        key: const ValueKey('growthPeriodSelector'),
        showSelectedIcon: false,
        segments: [
          ButtonSegment(
            value: GrowthPeriod.sevenDays,
            label: Semantics(
              label: '近 7 天趋势',
              selected: period == GrowthPeriod.sevenDays,
              container: true,
              excludeSemantics: true,
              child: const Text(
                '近 7 天',
                key: ValueKey('growthPeriodSevenDays'),
              ),
            ),
          ),
          ButtonSegment(
            value: GrowthPeriod.thirtyDays,
            label: Semantics(
              label: '近 30 天趋势',
              selected: period == GrowthPeriod.thirtyDays,
              container: true,
              excludeSemantics: true,
              child: const Text(
                '近 30 天',
                key: ValueKey('growthPeriodThirtyDays'),
              ),
            ),
          ),
        ],
        selected: {period},
        onSelectionChanged: (selection) => onChanged(selection.single),
      ),
    );
  }
}
