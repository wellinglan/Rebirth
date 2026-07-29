import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/theme/app_layout.dart';

import '../application/personal_data_aggregation_controller.dart';
import '../application/personal_data_providers.dart';
import '../domain/personal_data_aggregation_result.dart';
import '../domain/personal_data_provider_failure.dart';
import 'personal_data_overview_state.dart';
import 'widgets/personal_data_contribution_section.dart';

class PersonalDataOverviewPage extends ConsumerWidget {
  const PersonalDataOverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(personalDataAggregationControllerProvider);
    return Scaffold(
      key: const ValueKey('personalDataOverviewPage'),
      appBar: AppBar(title: const Text('个人数据概览')),
      body: SafeArea(
        child: state.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
              key: ValueKey('personalDataLoadingState'),
            ),
          ),
          error: (_, _) => _InitialError(
            onRetry: () =>
                ref.invalidate(personalDataAggregationControllerProvider),
          ),
          data: (value) => _OverviewContent(state: value),
        ),
      ),
    );
  }
}

class _OverviewContent extends ConsumerWidget {
  const _OverviewContent({required this.state});

  final PersonalDataOverviewState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(
      personalDataAggregationControllerProvider.notifier,
    );
    final registry = ref.watch(personalDataProviderRegistryProvider);
    final result = state.result;
    return ListView(
      key: const ValueKey('personalDataOverviewContent'),
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
                _DateToolbar(
                  selectedDate: state.selectedDate,
                  isToday: state.isToday,
                  isBusy: state.isRefreshing,
                  onPrevious: controller.previousDay,
                  onNext: controller.nextDay,
                  onToday: controller.goToToday,
                  onRefresh: controller.refresh,
                ),
                const SizedBox(height: AppSpacing.md),
                const _LocalOnlyNotice(),
                if (state.isRefreshing) ...[
                  const SizedBox(height: AppSpacing.sm),
                  const LinearProgressIndicator(
                    key: ValueKey('personalDataRefreshingIndicator'),
                  ),
                ],
                if (state.errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _RefreshError(
                    message: state.errorMessage!,
                    onRetry: controller.refresh,
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                if (result == null && state.errorMessage == null)
                  const Center(child: CircularProgressIndicator())
                else if (result != null) ...[
                  if (result.failures.isNotEmpty) ...[
                    _PartialNotice(failureCount: result.failures.length),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  if (_hasNoRecords(result))
                    const _EmptyOverview()
                  else
                    for (final contribution in result.contributions) ...[
                      PersonalDataContributionSection(
                        contribution: contribution,
                        descriptor: registry
                            .providerById(contribution.providerId)
                            ?.descriptor,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  for (final failure in result.failures) ...[
                    _ProviderFailureView(
                      failure: failure,
                      displayName: registry
                          .providerById(failure.providerId)
                          ?.descriptor
                          .displayName,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DateToolbar extends StatelessWidget {
  const _DateToolbar({
    required this.selectedDate,
    required this.isToday,
    required this.isBusy,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
    required this.onRefresh,
  });

  final String selectedDate;
  final bool isToday;
  final bool isBusy;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '当前选择日期 $selectedDate',
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          IconButton(
            key: const ValueKey('personalDataPreviousDateButton'),
            tooltip: '前一天',
            onPressed: isBusy ? null : onPrevious,
            icon: const Icon(Icons.chevron_left),
          ),
          Text(
            selectedDate,
            key: const ValueKey('personalDataSelectedDate'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          IconButton(
            key: const ValueKey('personalDataNextDateButton'),
            tooltip: '后一天',
            onPressed: isBusy ? null : onNext,
            icon: const Icon(Icons.chevron_right),
          ),
          OutlinedButton.icon(
            key: const ValueKey('personalDataTodayButton'),
            onPressed: isBusy || isToday ? null : onToday,
            icon: const Icon(Icons.today_outlined),
            label: const Text('今天'),
          ),
          IconButton(
            key: const ValueKey('personalDataRefreshButton'),
            tooltip: '刷新本地概览',
            onPressed: isBusy ? null : onRefresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}

class _LocalOnlyNotice extends StatelessWidget {
  const _LocalOnlyNotice();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: '仅汇总当前账号的本地数据，不进行云同步或 AI 分析',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: const Padding(
          padding: EdgeInsets.all(AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.phonelink_lock_outlined),
              SizedBox(width: AppSpacing.xs),
              Expanded(child: Text('仅汇总当前账号的本地数据，不进行云同步或 AI 分析。')),
            ],
          ),
        ),
      ),
    );
  }
}

class _PartialNotice extends StatelessWidget {
  const _PartialNotice({required this.failureCount});

  final int failureCount;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Text('有 $failureCount 个本地数据来源暂不可用，其余结果仍可查看。'),
    );
  }
}

class _ProviderFailureView extends StatelessWidget {
  const _ProviderFailureView({
    required this.failure,
    required this.displayName,
  });

  final PersonalDataProviderFailure failure;
  final String? displayName;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: ValueKey('personalDataFailure_${failure.providerId.value}'),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: ListTile(
        leading: const Icon(Icons.info_outline),
        title: Text(displayName ?? '其他本地来源'),
        subtitle: Text(failure.message),
      ),
    );
  }
}

class _RefreshError extends StatelessWidget {
  const _RefreshError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey('personalDataRefreshError'),
      children: [
        Expanded(child: Text(message)),
        IconButton(
          tooltip: '重新汇总本地数据',
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }
}

class _EmptyOverview extends StatelessWidget {
  const _EmptyOverview();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      key: ValueKey('personalDataEmptyState'),
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 40),
          SizedBox(height: AppSpacing.sm),
          Text('所选日期暂无个人数据记录'),
        ],
      ),
    );
  }
}

class _InitialError extends StatelessWidget {
  const _InitialError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('personalDataErrorState'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('本地个人数据暂时无法加载'),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }
}

bool _hasNoRecords(PersonalDataAggregationResult result) {
  return result.contributions.every(
    (contribution) => contribution.items.isEmpty,
  );
}
