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
          onDelete: () => _confirmDelete(context, ref),
          onOpenHistory: () => context.push(RoutePaths.todayHistory),
          onOpenDailyInsight: () =>
              context.push(RoutePaths.aiCoachDaily(entry.recordDate)),
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

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            key: const ValueKey('deleteTodayConfirmationDialog'),
            title: const Text('删除今日记录？'),
            content: const SingleChildScrollView(
              child: Text(
                '只会删除 Today 记录，同日 Health 数据会保留。'
                '删除将在你下次手动同步 Today 后传到其他设备；取消不会修改数据。',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                key: const ValueKey('confirmDeleteTodayButton'),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('确认删除'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) return;
    try {
      await ref.read(todayControllerProvider.notifier).deleteToday();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Today 记录已删除，同日 Health 已保留')),
        );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('删除失败，记录内容已保留，请稍后重试')));
    }
  }
}
