import 'package:flutter/material.dart';
import 'package:rebirth/core/theme/app_layout.dart';

import '../../domain/personal_data_contribution.dart';
import '../../domain/personal_data_fact.dart';
import '../../domain/personal_data_item.dart';
import '../../domain/personal_data_privacy.dart';
import '../../domain/personal_data_provider_descriptor.dart';
import '../../domain/personal_data_quality.dart';
import 'personal_data_value_text.dart';

class PersonalDataContributionSection extends StatelessWidget {
  const PersonalDataContributionSection({
    required this.contribution,
    required this.descriptor,
    super.key,
  });

  final PersonalDataContribution contribution;
  final PersonalDataProviderDescriptor? descriptor;

  @override
  Widget build(BuildContext context) {
    final isHighlySensitive =
        contribution.sensitivity == PersonalDataSensitivity.highlySensitive;
    final itemContent = contribution.items.isEmpty
        ? const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Text('所选日期暂无记录'),
          )
        : Column(
            children: [
              for (
                var index = 0;
                index < contribution.items.length;
                index++
              ) ...[
                if (index > 0) const Divider(height: 1),
                _PersonalDataItemView(item: contribution.items[index]),
              ],
            ],
          );

    return Card(
      key: ValueKey('personalDataSource_${contribution.providerId.value}'),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: _SourceHeader(
              title: descriptor?.displayName ?? '其他本地来源',
              description: descriptor?.description ?? '本地个人数据来源',
              sensitivity: contribution.sensitivity,
              quality: contribution.quality,
            ),
          ),
          if (contribution.summaryFacts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: _FactWrap(facts: contribution.summaryFacts),
            ),
          if (isHighlySensitive)
            ExpansionTile(
              key: ValueKey(
                'sensitiveSourceExpansion_${contribution.providerId.value}',
              ),
              initiallyExpanded: false,
              title: const Text('查看本地敏感指标'),
              subtitle: const Text('内容仅在当前设备显示'),
              children: [itemContent],
            )
          else
            itemContent,
        ],
      ),
    );
  }
}

class _SourceHeader extends StatelessWidget {
  const _SourceHeader({
    required this.title,
    required this.description,
    required this.sensitivity,
    required this.quality,
  });

  final String title;
  final String description;
  final PersonalDataSensitivity sensitivity;
  final PersonalDataQuality quality;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label:
          '$title，${sensitivity.displayLabel}，${_qualityLabel(quality.status)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xxs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              _StatusLabel(
                icon: Icons.lock_outline,
                label: sensitivity.displayLabel,
              ),
              if (!quality.isComplete)
                _StatusLabel(
                  icon: Icons.info_outline,
                  label: _qualityLabel(quality.status),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: AppSpacing.xxs),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _PersonalDataItemView extends StatelessWidget {
  const _PersonalDataItemView({required this.item});

  final PersonalDataItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xxs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(item.title, style: Theme.of(context).textTheme.titleSmall),
              if (item.quality.status == PersonalDataQualityStatus.conflicted)
                const _StatusLabel(
                  icon: Icons.sync_problem_outlined,
                  label: '存在同步冲突',
                ),
            ],
          ),
          if (item.localDate != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              item.localDate!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (item.facts.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _FactWrap(facts: item.facts),
          ],
        ],
      ),
    );
  }
}

class _FactWrap extends StatelessWidget {
  const _FactWrap({required this.facts});

  final List<PersonalDataFact> facts;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final fact in facts)
          Container(
            constraints: const BoxConstraints(minWidth: 108, maxWidth: 260),
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              border: Border.all(color: colors.outlineVariant),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fact.label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                PersonalDataValueText(
                  value: fact.value,
                  unit: fact.unit,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

String _qualityLabel(PersonalDataQualityStatus status) => switch (status) {
  PersonalDataQualityStatus.complete => '完整',
  PersonalDataQualityStatus.partial => '部分可用',
  PersonalDataQualityStatus.unavailable => '暂不可用',
  PersonalDataQualityStatus.unsupported => '不支持',
  PersonalDataQualityStatus.conflicted => '存在冲突',
  PersonalDataQualityStatus.stale => '可能过期',
};
