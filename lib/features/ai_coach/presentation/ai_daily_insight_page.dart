import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rebirth/core/router/route_names.dart';
import 'package:rebirth/core/theme/app_layout.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_scope.dart';
import 'package:rebirth/features/ai_coach/domain/ai_input_contract.dart';

import 'ai_request_preview_controller.dart';
import 'ai_request_preview_view_state.dart';
import 'models/ai_insight_request_context.dart';
import 'widgets/ai_consent_gate.dart';
import 'widgets/ai_generation_section.dart';
import 'widgets/ai_journal_scope_dialog.dart';
import 'widgets/ai_request_preview.dart';
import 'widgets/ai_reusable_report_card.dart';
import 'widgets/ai_scope_selector.dart';

class AiDailyInsightPage extends ConsumerWidget {
  const AiDailyInsightPage({
    required this.targetDate,
    this.initialScopes = const {},
    super.key,
  });

  final String targetDate;
  final Set<AiDataScope> initialScopes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref
        .watch(dateTimeServiceProvider)
        .isValidLocalDateString(targetDate)) {
      return Scaffold(
        key: const ValueKey('invalidDailyInsightDatePage'),
        appBar: AppBar(title: const Text('每日洞察')),
        body: const SafeArea(child: Center(child: Text('目标日期无效，请返回后重新选择。'))),
      );
    }

    final requestContext = AiInsightRequestContext.daily(
      targetDate,
      initialScopes: initialScopes,
    );
    final preview = ref.watch(aiRequestPreviewControllerFamily(requestContext));
    return Scaffold(
      key: const ValueKey('aiDailyInsightPage'),
      appBar: AppBar(title: const Text('每日洞察')),
      body: SafeArea(
        child: preview.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
              key: ValueKey('dailyInsightLoading'),
              semanticsLabel: '正在读取 AI 数据授权状态',
            ),
          ),
          error: (error, stackTrace) => _DailyError(
            onRetry: () => ref
                .read(aiRequestPreviewControllerFamily(requestContext).notifier)
                .reloadAuthorization(),
          ),
          data: (state) =>
              _DailyContent(state: state, requestContext: requestContext),
        ),
      ),
    );
  }
}

class _DailyContent extends ConsumerWidget {
  const _DailyContent({required this.state, required this.requestContext});

  final AiRequestPreviewViewState state;
  final AiInsightRequestContext requestContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      key: const ValueKey('dailyInsightScrollView'),
      padding: AppLayout.pagePadding,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.wideContentWidth,
            ),
            child: state.authorization.enabled
                ? _AuthorizedDaily(state: state, requestContext: requestContext)
                : AiConsentGate(
                    onOpenSettings: () async {
                      await context.push(RoutePaths.settings);
                      if (!context.mounted) return;
                      await ref
                          .read(
                            aiRequestPreviewControllerFamily(
                              requestContext,
                            ).notifier,
                          )
                          .reloadAuthorization();
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _AuthorizedDaily extends ConsumerWidget {
  const _AuthorizedDaily({required this.state, required this.requestContext});

  final AiRequestPreviewViewState state;
  final AiInsightRequestContext requestContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(
      aiRequestPreviewControllerFamily(requestContext).notifier,
    );
    final preview = state.preview;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: '每日洞察，目标日期 ${requestContext.targetDate}',
          header: true,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('每日洞察', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text('目标日期：${requestContext.targetDate}'),
                  const Text('手动生成；不会自动调用 AI Provider。'),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        AiScopeSelector(
          selectedScopes: state.selectedScopes,
          allowedScopes: AiInputContract.supportedScopesFor(
            requestContext.reportType,
          ),
          isDaily: true,
          onChanged: (scope, selected) =>
              _toggleScope(context, notifier, scope, selected),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const ValueKey('buildDailyInsightPreviewButton'),
          onPressed: state.canBuild ? notifier.buildPreview : null,
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
            key: const ValueKey('dailyInsightPreviewError'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (preview != null) ...[
          const SizedBox(height: 24),
          AiRequestPreview(preview: preview),
          const SizedBox(height: 16),
          AiReusableReportCard(
            report: state.reusableCompletedReport,
            onOpenReport: (id) => context.push(RoutePaths.aiCoachReport(id)),
          ),
          if (preview.sourceCount == 0)
            const _NoDailySources()
          else if (state.reusableCompletedReport == null &&
              state.bundle != null)
            AiGenerationSection(
              bundle: state.bundle!,
              requestContext: requestContext,
            ),
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
    final confirmed = await showAiJournalScopeDialog(context, isDaily: true);
    if (!context.mounted) return;
    confirmed ? notifier.confirmJournalScope() : notifier.cancelJournalScope();
  }
}

class _NoDailySources extends StatelessWidget {
  const _NoDailySources();

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey('dailyInsightNoSources'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('这一天暂时没有可用于生成洞察的已保存记录。'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => context.go(RoutePaths.today),
                  child: const Text('返回 Today'),
                ),
                OutlinedButton(
                  onPressed: () => context.go(RoutePaths.health),
                  child: const Text('返回 Health'),
                ),
                OutlinedButton(
                  onPressed: () => context.go(RoutePaths.journal),
                  child: const Text('返回 Journal'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyError extends StatelessWidget {
  const _DailyError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('每日洞察暂时无法加载。'),
          const SizedBox(height: 12),
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
