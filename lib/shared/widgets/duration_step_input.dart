import 'package:flutter/material.dart';

import 'quick_increment_control.dart';

class DurationStepInput extends StatelessWidget {
  const DurationStepInput({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
    super.key,
    this.selectedStep = 15,
    this.onStepChanged,
    this.stepOptions = const [15, 30, 60],
  });

  final String label;
  final IconData icon;
  final int? value;
  final ValueChanged<int?> onChanged;
  final int selectedStep;
  final ValueChanged<int>? onStepChanged;
  final List<int> stepOptions;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icon, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              QuickIncrementControl(
                value: value,
                stepOptions: stepOptions,
                selectedStep: selectedStep,
                unit: '分钟',
                minimumValue: 0,
                label: label,
                valueFormatter: formatDurationMinutes,
                onChanged: onChanged,
                onStepChanged: onStepChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String formatDurationMinutes(int? value) {
  if (value == null) return '未记录';
  final hours = value ~/ 60;
  final minutes = value % 60;
  if (hours == 0) return '$minutes 分钟';
  if (minutes == 0) return '$hours 小时';
  return '$hours 小时 $minutes 分钟';
}
