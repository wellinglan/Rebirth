import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'today_controller.dart';

class TodayPage extends ConsumerWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayControllerProvider);

    return Center(
      child: today.when(
        loading: () => const CircularProgressIndicator(),
        error: (error, stackTrace) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('今日数据暂时无法加载'),
            const SizedBox(height: 12),
            IconButton(
              onPressed: () =>
                  ref.read(todayControllerProvider.notifier).reload(),
              tooltip: '重新加载',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        data: (entry) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              entry.recordDate,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text('今日记录已建立'),
          ],
        ),
      ),
    );
  }
}
