import 'package:flutter/material.dart';
import 'package:rebirth/core/theme/app_layout.dart';

class GrowthEmptyState extends StatelessWidget {
  const GrowthEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey('growthEmptyState'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            Icon(
              Icons.insights_outlined,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              '这一周期还没有足够的记录。随着 Today、Health 和 Journal 数据逐渐积累，你会在这里看见变化。',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
