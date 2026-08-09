import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rebirth/core/router/route_names.dart';
import 'package:rebirth/core/theme/app_layout.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_scope.dart';

import 'ai_request_preview_controller.dart';
import 'ai_request_preview_view_state.dart';
import 'widgets/ai_consent_gate.dart';
import 'widgets/ai_generation_section.dart';
import 'widgets/ai_journal_scope_dialog.dart';
import 'widgets/ai_request_preview.dart';
import 'widgets/ai_reusable_report_card.dart';
import 'widgets/ai_scope_selector.dart';

class AiWeeklyReportPage extends ConsumerWidget {
  const AiWeeklyReportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(aiRequestPreviewControllerProvider);
    return Scaffold(
      key: const ValueKey('aiWeeklyReportPage'),
      appBar: AppBar(title: const Text('每周回顾')),
      body: SafeArea(
        child: preview.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
              key: ValueKey('aiWeeklyLoading'),
              semanticsLabel: '正在读取 AI 数据授权状态',
            ),
          ),
          error: (_, _) => _WeeklyError(
            onRetry: () => ref
                .read(aiRequestPreviewControllerProvider.notifier)
                .reloadAuthorization(),
          ),
          data: (state) => _WeeklyContent(state: state),
        ),
      ),
    );
  }
}

class _WeeklyContent extends ConsumerWidget {
  const _WeeklyContent({required this.state});

  final AiRequestPreviewViewState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      key: const ValueKey('aiWeeklyScrollView'),
      padding: AppLayout.pagePadding,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.wideContentWidth,
            ),
            child: state.authorization.enabled
                ? _AuthorizedWeekly(state: state)
                : AiConsentGate(
                    onOpenSettings: () => _openConsent(context, ref),
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _openConsent(BuildContext context, WidgetRef ref) async {
    await context.push(RoutePaths.settingsAiConsent);
    if (!context.mounted) return;
    await ref
        .read(aiRequestPreviewControllerProvider.notifier)
        .reloadAuthorization();
  }
}

class _AuthorizedWeekly extends ConsumerWidget {
  const _AuthorizedWeekly({required this.state});

  final AiRequestPreviewViewState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(aiRequestPreviewControllerProvider.notifier);
    final preview = state.preview;
    final growthSelected = state.selectedScopes.contains(
      AiDataScope.growthSummary,
    );
    final hasGeneratableData =
        preview != null && (preview.sourceCount > 0 || growthSelected);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: '每周回顾，日期范围 ${state.periodStartDate} 至 ${state.periodEndDate}',
          header: true,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('最近七天', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Text('${state.periodStartDate} 至 ${state.periodEndDate}'),
                  const SizedBox(height: AppSpacing.xs),
                  const Text('选择本次允许使用的数据后，再确认是否生成。'),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AiScopeSelector(
          selectedScopes: state.selectedScopes,
          onChanged: (scope, selected) =>
              _toggleScope(context, notifier, scope, selected),
        ),
        const SizedBox(height: AppSpacing.sm),
        FilledButton.icon(
          key: const ValueKey('buildAiPreviewButton'),
          onPressed: state.canBuild ? notifier.buildPreview : null,
          icon: state.isBuilding
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.visibility_outlined),
          label: Text(state.isBuilding ? '正在准备...' : '查看本次使用的数据'),
        ),
        if (state.selectedScopes.isEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          const Text('请至少选择一种数据。'),
        ],
        if (state.buildError case final message?) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            key: const ValueKey('aiPreviewBuildError'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (preview != null) ...[
          const SizedBox(height: AppSpacing.xl),
          AiRequestPreview(preview: preview),
          const SizedBox(height: AppSpacing.md),
          AiReusableReportCard(
            report: state.reusableCompletedReport,
            onOpenReport: (id) => context.push(RoutePaths.aiReportsDetail(id)),
          ),
          if (state.reusableCompletedReport == null &&
              state.bundle != null) ...[
            const SizedBox(height: AppSpacing.md),
            if (hasGeneratableData)
              AiGenerationSection(bundle: state.bundle!)
            else
              const _NoWeeklySources(),
          ],
        ],
      ],
    );
  }

  Future<void> _toggleScope(
    BuildContext context,
    AiRequestPreviewController notifier,
    AiDataScope scope,
    bool selected,
  ) async {
    final result = notifier.toggleScope(scope, selected: selected);
    if (result != AiScopeToggleResult.journalConfirmationRequired) return;
    final confirmed = await showAiJournalScopeDialog(context);
    if (!context.mounted) return;
    confirmed ? notifier.confirmJournalScope() : notifier.cancelJournalScope();
  }
}

class _NoWeeklySources extends StatelessWidget {
  const _NoWeeklySources();

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey('weeklyReportNoSources'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('最近七天还没有足够的已保存记录。'),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                OutlinedButton(
                  onPressed: () => context.go(RoutePaths.today),
                  child: const Text('去记录今天'),
                ),
                OutlinedButton(
                  onPressed: () => context.go(RoutePaths.journal),
                  child: const Text('写今日复盘'),
                ),
                OutlinedButton(
                  onPressed: () => context.go(RoutePaths.health),
                  child: const Text('补充健康记录'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyError extends StatelessWidget {
  const _WeeklyError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('aiWeeklyError'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('每周回顾暂时无法加载。'),
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
