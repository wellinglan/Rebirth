import 'package:flutter/material.dart';
import 'package:rebirth/core/theme/app_layout.dart';

class GrowthPage extends StatelessWidget {
  const GrowthPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Growth', style: textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text('看见缓慢而真实的变化。', style: textTheme.bodyMedium),
        ],
      ),
    );
  }
}
