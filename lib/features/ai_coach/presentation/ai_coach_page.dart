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
import 'widgets/ai_report_history_tab.dart';
import 'widgets/ai_request_preview.dart';
import 'widgets/ai_reusable_report_card.dart';
import 'widgets/ai_scope_selector.dart';

class AiCoachPage extends StatelessWidget {
  const AiCoachPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        key: const ValueKey('aiCoachPage'),
        appBar: AppBar(
          title: const Text('AI Coach'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '请求预览'),
              Tab(text: '本地报告'),
            ],
          ),
        ),
        body: const SafeArea(
          child: Column(
            children: [
              _PageIntroduction(),
              Expanded(
                child: TabBarView(
                  children: [_RequestPreviewTab(), AiReportHistoryTab()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageIntroduction extends StatelessWidget {
  const _PageIntroduction();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.wideContentWidth,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '在发送任何数据之前，先确认会使用哪些本地记录。',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                '预览只在本机准备；只有最终确认后，才会通过 Rebirth Server 请求生成。',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestPreviewTab extends ConsumerWidget {
  const _RequestPreviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previewState = ref.watch(aiRequestPreviewControllerProvider);
    return previewState.when(
      loading: () => const Center(
        child: CircularProgressIndicator(key: ValueKey('aiPreviewLoading')),
      ),
      error: (error, stackTrace) => _PreviewAuthorizationError(
        onRetry: () => ref
            .read(aiRequestPreviewControllerProvider.notifier)
            .reloadAuthorization(),
      ),
      data: (state) => _PreviewContent(state: state),
    );
  }
}

class _PreviewContent extends ConsumerWidget {
  const _PreviewContent({required this.state});

  final AiRequestPreviewViewState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      key: const ValueKey('aiPreviewScrollView'),
      padding: AppLayout.pagePadding,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.wideContentWidth,
            ),
            child: state.authorization.enabled
                ? _AuthorizedPreview(state: state)
                : AiConsentGate(
                    onOpenSettings: () => _openSettings(context, ref),
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _openSettings(BuildContext context, WidgetRef ref) async {
    await context.push(RoutePaths.settings);
    if (!context.mounted) return;
    await ref
        .read(aiRequestPreviewControllerProvider.notifier)
        .reloadAuthorization();
  }
}

class _AuthorizedPreview extends ConsumerWidget {
  const _AuthorizedPreview({required this.state});

  final AiRequestPreviewViewState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('每周回顾', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text('${state.periodStartDate} 至 ${state.periodEndDate}'),
                Text('Prompt Version：${state.promptVersion}'),
                const SizedBox(height: 6),
                const Text('周期固定为包含今天的最近 7 个本地自然日。'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        AiScopeSelector(
          selectedScopes: state.selectedScopes,
          onChanged: (scope, selected) =>
              _toggleScope(context, ref, scope, selected),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const ValueKey('buildAiPreviewButton'),
          onPressed: state.canBuild
              ? () => ref
                    .read(aiRequestPreviewControllerProvider.notifier)
                    .buildPreview()
              : null,
          icon: state.isBuilding
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.visibility_outlined),
          label: Text(state.isBuilding ? '准备预览中...' : '生成本地预览'),
        ),
        if (state.selectedScopes.isEmpty) ...[
          const SizedBox(height: 6),
          const Text('请至少选择一个数据范围。'),
        ],
        if (state.buildError case final message?) ...[
          const SizedBox(height: 8),
          Text(
            message,
            key: const ValueKey('aiPreviewBuildError'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (state.preview case final preview?) ...[
          const SizedBox(height: 24),
          AiRequestPreview(preview: preview),
          const SizedBox(height: 16),
          AiReusableReportCard(
            report: state.reusableCompletedReport,
            onOpenReport: (id) => context.push(RoutePaths.aiCoachReport(id)),
          ),
          if (state.reusableCompletedReport == null && state.bundle != null) ...[
            const SizedBox(height: 16),
            AiGenerationSection(bundle: state.bundle!),
          ],
        ],
      ],
    );
  }

  Future<void> _toggleScope(
    BuildContext context,
    WidgetRef ref,
    AiDataScope scope,
    bool selected,
  ) async {
    final notifier = ref.read(aiRequestPreviewControllerProvider.notifier);
    final result = notifier.toggleScope(scope, selected: selected);
    if (result != AiScopeToggleResult.journalConfirmationRequired) return;
    final confirmed = await showAiJournalScopeDialog(context);
    if (!context.mounted) return;
    confirmed ? notifier.confirmJournalScope() : notifier.cancelJournalScope();
  }
}

class _PreviewAuthorizationError extends StatelessWidget {
  const _PreviewAuthorizationError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('aiPreviewAuthorizationError'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('AI 数据授权状态暂时无法读取。'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey('retryAiPreviewAuthorizationButton'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
