import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/features/health/domain/health_save_data.dart';

import 'health_controller.dart';
import 'health_view_state.dart';
import 'widgets/health_form.dart';
import 'widgets/health_history_list.dart';
import 'widgets/health_summary_cards.dart';

class HealthPage extends ConsumerWidget {
  const HealthPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(healthControllerProvider);

    return state.when(
      loading: () => const Center(
        key: ValueKey('healthLoadingState'),
        child: CircularProgressIndicator(),
      ),
      error: (error, stackTrace) => Center(
        key: const ValueKey('healthErrorState'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('健康记录暂时无法加载'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const ValueKey('retryHealthButton'),
              onPressed: () => ref
                  .read(healthControllerProvider.notifier)
                  .reload(),
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
      data: (value) => _HealthContent(
        state: value,
        onSave: (data) => ref
            .read(healthControllerProvider.notifier)
            .saveToday(data),
      ),
    );
  }
}

class _HealthContent extends StatelessWidget {
  const _HealthContent({required this.state, required this.onSave});

  final HealthViewState state;
  final Future<void> Function(HealthSaveData data) onSave;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('healthDataState'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Health', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text(
                  '记录身体状态与恢复质量',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),
                HealthForm(
                  entry: state.today,
                  isSaving: state.isSaving,
                  onSave: onSave,
                ),
                const SizedBox(height: 36),
                Text('近 7 日摘要', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                HealthSummaryCards(summary: state.summary),
                const SizedBox(height: 36),
                Text('近 30 日历史', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                HealthHistoryList(entries: state.recentEntries),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
