import 'package:flutter/material.dart';
import 'package:rebirth/core/theme/app_layout.dart';

class GrowthErrorState extends StatelessWidget {
  const GrowthErrorState({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('growthErrorState'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('成长趋势暂时无法加载'),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            key: const ValueKey('retryGrowthButton'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
