import 'package:flutter/material.dart';
import 'package:rebirth/core/theme/app_layout.dart';
import 'package:rebirth/features/growth/domain/growth_dimension_projection.dart';
import 'package:rebirth/features/growth/domain/growth_projection.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_privacy.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_quality.dart';

class GrowthProjectionOverview extends StatelessWidget {
  const GrowthProjectionOverview({required this.projection, super.key});

  final GrowthProjection projection;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('growthProjectionOverview'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('数据覆盖与来源', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppLayout.cardGap),
        for (final dimension in projection.dimensions) ...[
          _DimensionSummary(dimension: dimension),
          const SizedBox(height: AppLayout.cardGap),
        ],
        for (final failure in projection.failures)
          Card(
            key: ValueKey(
              'growthDimensionFailure_${failure.dimensionId.value}',
            ),
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('部分成长维度暂不可用'),
              subtitle: Text(failure.message),
            ),
          ),
      ],
    );
  }
}

class _DimensionSummary extends StatelessWidget {
  const _DimensionSummary({required this.dimension});

  final GrowthDimensionProjection dimension;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final sources =
        dimension.metrics
            .expand((metric) => metric.sourceProviderIds)
            .map((provider) => _sourceLabel(provider.value))
            .toSet()
            .toList()
          ..sort();
    return Card(
      key: ValueKey(
        'growthDimension_${dimension.descriptor.dimensionId.value}',
      ),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    dimension.descriptor.displayName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  _sensitivityLabel(dimension.sensitivity),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              dimension.descriptor.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '覆盖 ${dimension.coverage.observedCount} / '
              '${dimension.coverage.expectedCount} 天 · '
              '缺失 ${dimension.coverage.missingCount} 天',
              key: ValueKey(
                'growthCoverage_${dimension.descriptor.dimensionId.value}',
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text('质量：${_qualityLabel(dimension.quality)}'),
            if (sources.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text('来源：${sources.join('、')}'),
            ],
          ],
        ),
      ),
    );
  }
}

String _sourceLabel(String providerId) {
  final segment = providerId.split('.').last;
  if (segment.isEmpty) return '本地数据';
  return '${segment[0].toUpperCase()}${segment.substring(1)}';
}

String _qualityLabel(PersonalDataQuality quality) => switch (quality.status) {
  PersonalDataQualityStatus.complete => '完整',
  PersonalDataQualityStatus.partial => '部分可用',
  PersonalDataQualityStatus.unavailable => '暂不可用',
  PersonalDataQualityStatus.unsupported => '暂不支持',
  PersonalDataQualityStatus.conflicted => '存在同步冲突',
  PersonalDataQualityStatus.stale => '可能已过期',
};

String _sensitivityLabel(PersonalDataSensitivity sensitivity) =>
    switch (sensitivity) {
      PersonalDataSensitivity.standardPrivate => '本地私密',
      PersonalDataSensitivity.sensitive => '敏感',
      PersonalDataSensitivity.highlySensitive => '高度敏感',
    };
