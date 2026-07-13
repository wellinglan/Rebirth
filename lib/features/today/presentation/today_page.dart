import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rebirth/core/router/route_names.dart';
import 'package:rebirth/features/today/domain/today_save_data.dart';

import 'today_controller.dart';
import 'today_history_controller.dart';
import 'widgets/today_form.dart';

class TodayPage extends ConsumerWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayControllerProvider);

    return SafeArea(
      child: today.when(
        loading: () => const Center(
          child: CircularProgressIndicator(key: ValueKey('todayLoadingState')),
        ),
        error: (error, stackTrace) => Center(
          child: Column(
            key: const ValueKey('todayErrorState'),
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
        ),
        data: (entry) => TodayForm(
          entry: entry,
          onSave: (data) => _save(context, ref, data),
          onOpenHistory: () => context.push(RoutePaths.todayHistory),
        ),
      ),
    );
  }

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    TodaySaveData data,
  ) async {
    await ref.read(todayControllerProvider.notifier).saveToday(data);
    if (!context.mounted || ref.read(todayControllerProvider).hasError) {
      return;
    }
    ref.invalidate(todayHistoryControllerProvider);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('今日记录已保存')));
  }
}
