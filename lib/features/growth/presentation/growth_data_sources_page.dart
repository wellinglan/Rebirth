import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/theme/app_layout.dart';

import 'growth_controller.dart';
import 'growth_formatters.dart';
import 'widgets/growth_projection_overview.dart';

class GrowthDataSourcesPage extends ConsumerWidget {
  const GrowthDataSourcesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(growthControllerProvider);

    return SafeArea(
      key: const ValueKey('growthDataSourcesPage'),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
            child: Row(
              children: [
                IconButton(
                  key: const ValueKey('growthDataSourcesBackButton'),
                  onPressed: () => Navigator.of(context).maybePop(),
                  tooltip: '返回成长趋势',
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: AppSpacing.xxs),
                Expanded(
                  child: Text(
                    '数据说明',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: state.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  key: ValueKey('growthDataSourcesLoading'),
                ),
              ),
              error: (error, stackTrace) => _DataSourcesError(
                onRetry: () =>
                    ref.read(growthControllerProvider.notifier).reload(),
              ),
              data: (value) => LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: AppLayout.pagePaddingFor(constraints.maxWidth),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: AppLayout.wideContentWidth,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Semantics(
                            label:
                                '当前周期，${GrowthFormatters.periodLabel(value.period)}，'
                                '日期范围，${GrowthFormatters.dateRange(value.snapshot.startDate, value.snapshot.endDate)}',
                            container: true,
                            excludeSemantics: true,
                            child: Text(
                              '${GrowthFormatters.periodLabel(value.period)} · '
                              '${GrowthFormatters.dateRange(value.snapshot.startDate, value.snapshot.endDate)}',
                              key: const ValueKey(
                                'growthDataSourcesPeriodSummary',
                              ),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                          const SizedBox(height: AppLayout.sectionGap),
                          if (value.snapshot.projection case final projection?)
                            GrowthProjectionOverview(projection: projection)
                          else
                            const _NoProjectionData(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoProjectionData extends StatelessWidget {
  const _NoProjectionData();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '当前周期的数据覆盖与来源暂不可用',
      container: true,
      excludeSemantics: true,
      child: const Text(
        '当前周期的数据覆盖与来源暂不可用。',
        key: ValueKey('growthDataSourcesUnavailable'),
      ),
    );
  }
}

class _DataSourcesError extends StatelessWidget {
  const _DataSourcesError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        key: const ValueKey('growthDataSourcesError'),
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('数据说明暂时无法加载'),
          const SizedBox(height: AppSpacing.sm),
          IconButton(
            onPressed: onRetry,
            tooltip: '重新加载数据说明',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}
