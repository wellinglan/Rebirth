import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/theme/app_layout.dart';
import 'package:rebirth/features/growth/domain/growth_period.dart';

import 'growth_controller.dart';
import 'growth_formatters.dart';
import 'growth_presentation_mapper.dart';
import 'growth_view_state.dart';
import 'widgets/exercise_trend_chart.dart';
import 'widgets/focus_trend_chart.dart';
import 'widgets/growth_daily_details.dart';
import 'widgets/growth_empty_state.dart';
import 'widgets/growth_error_state.dart';
import 'widgets/growth_period_selector.dart';
import 'widgets/growth_summary_grid.dart';
import 'widgets/journal_coverage_grid.dart';
import 'widgets/mood_energy_chart.dart';
import 'widgets/sleep_trend_chart.dart';

class GrowthPage extends ConsumerWidget {
  const GrowthPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(growthControllerProvider);

    return SafeArea(
      child: state.when(
        loading: () => const Center(
          key: ValueKey('growthLoadingState'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: AppSpacing.sm),
              Text('正在加载成长趋势'),
            ],
          ),
        ),
        error: (error, stackTrace) => GrowthErrorState(
          onRetry: () => ref.read(growthControllerProvider.notifier).reload(),
        ),
        data: (value) => _GrowthContent(
          state: value,
          onPeriodChanged: (period) =>
              ref.read(growthControllerProvider.notifier).selectPeriod(period),
          onReload: () => ref.read(growthControllerProvider.notifier).reload(),
        ),
      ),
    );
  }
}

class _GrowthContent extends StatelessWidget {
  const _GrowthContent({
    required this.state,
    required this.onPeriodChanged,
    required this.onReload,
  });

  final GrowthViewState state;
  final ValueChanged<GrowthPeriod> onPeriodChanged;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    final snapshot = state.snapshot;
    final presentation = const GrowthPresentationMapper().map(snapshot);

    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: ListView(
        key: const ValueKey('growthDataState'),
        padding: AppLayout.pagePadding,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppLayout.wideContentWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    key: const ValueKey('growthTitleSemantics'),
                    label: 'Growth 成长趋势',
                    header: true,
                    container: true,
                    excludeSemantics: true,
                    child: Text(
                      'Growth',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    '看见缓慢而真实的变化。',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(1),
                        child: GrowthPeriodSelector(
                          period: state.period,
                          onChanged: onPeriodChanged,
                        ),
                      ),
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(2),
                        child: _GrowthRefreshButton(
                          isRefreshing: state.isRefreshing,
                          onReload: onReload,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Semantics(
                    label:
                        '当前周期，${GrowthFormatters.periodLabel(state.period)}，'
                        '日期范围，${GrowthFormatters.dateRange(snapshot.startDate, snapshot.endDate)}',
                    container: true,
                    excludeSemantics: true,
                    child: Text(
                      GrowthFormatters.dateRange(
                        snapshot.startDate,
                        snapshot.endDate,
                      ),
                      key: const ValueKey('growthDateRange'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (state.isRefreshing) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Semantics(
                      label: '正在刷新成长趋势',
                      liveRegion: true,
                      container: true,
                      excludeSemantics: true,
                      child: const LinearProgressIndicator(
                        key: ValueKey('growthRefreshingIndicator'),
                      ),
                    ),
                  ],
                  if (state.refreshFailed) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _RefreshFailure(onRetry: onReload),
                  ],
                  const SizedBox(height: AppLayout.sectionGap),
                  if (state.isCompletelyEmpty)
                    const GrowthEmptyState()
                  else ...[
                    Text('周期概览', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: AppLayout.cardGap),
                    GrowthSummaryGrid(snapshot: snapshot),
                    const SizedBox(height: AppLayout.sectionGap),
                    FocusTrendChart(
                      research: presentation.research,
                      learning: presentation.learning,
                      period: snapshot.period,
                    ),
                    const SizedBox(height: AppLayout.sectionGap),
                    Text('身体恢复', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: AppLayout.cardGap),
                    _RecoveryCharts(
                      sleep: SleepTrendChart(
                        sleep: presentation.sleep,
                        period: snapshot.period,
                      ),
                      exercise: ExerciseTrendChart(
                        exercise: presentation.exercise,
                        period: snapshot.period,
                      ),
                    ),
                    const SizedBox(height: AppLayout.sectionGap),
                    MoodEnergyChart(
                      mood: presentation.mood,
                      energy: presentation.energy,
                      period: snapshot.period,
                    ),
                    const SizedBox(height: AppLayout.sectionGap),
                    JournalCoverageGrid(
                      days: presentation.journalDays,
                      recordedDays: snapshot.journalRecordedDays,
                      completedDays: snapshot.journalCompletedDays,
                    ),
                  ],
                  const SizedBox(height: AppLayout.sectionGap),
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(3),
                    child: GrowthDailyDetails(days: snapshot.days),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GrowthRefreshButton extends StatelessWidget {
  const _GrowthRefreshButton({
    required this.isRefreshing,
    required this.onReload,
  });

  final bool isRefreshing;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '刷新成长趋势',
      value: isRefreshing ? '正在刷新' : '可用',
      button: true,
      enabled: !isRefreshing,
      onTap: isRefreshing ? null : onReload,
      container: true,
      child: ExcludeSemantics(
        child: Tooltip(
          message: '刷新成长趋势',
          child: IconButton(
            key: const ValueKey('refreshGrowthButton'),
            onPressed: isRefreshing ? null : onReload,
            icon: isRefreshing
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ),
      ),
    );
  }
}

class _RecoveryCharts extends StatelessWidget {
  const _RecoveryCharts({required this.sleep, required this.exercise});

  final Widget sleep;
  final Widget exercise;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 680) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: sleep),
              const SizedBox(width: AppLayout.cardGap),
              Expanded(child: exercise),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            sleep,
            const SizedBox(height: AppLayout.cardGap),
            exercise,
          ],
        );
      },
    );
  }
}

class _RefreshFailure extends StatelessWidget {
  const _RefreshFailure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('growthRefreshError'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: colors.onErrorContainer),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Semantics(
              label: '刷新失败，已保留上次数据',
              liveRegion: true,
              container: true,
              excludeSemantics: true,
              child: Text(
                '刷新失败，已保留上次数据。',
                style: TextStyle(color: colors.onErrorContainer),
              ),
            ),
          ),
          IconButton(
            onPressed: onRetry,
            tooltip: '重新加载成长趋势',
            icon: const Icon(Icons.refresh),
            color: colors.onErrorContainer,
          ),
        ],
      ),
    );
  }
}
