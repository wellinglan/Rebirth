import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rebirth/core/router/route_names.dart';
import 'package:rebirth/core/theme/app_layout.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_status.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_type.dart';
import 'package:rebirth/features/ai_coach/domain/ai_usage_snapshot.dart';

import 'ai_report_history_controller.dart';
import 'ai_report_history_view_state.dart';
import 'ai_request_preview_controller.dart';
import 'ai_request_preview_view_state.dart';
import 'ai_usage_controller.dart';
import 'models/ai_coach_home_models.dart';
import 'models/ai_report_presentation_models.dart';
import 'widgets/ai_coach_home_sections.dart';
import 'widgets/ai_consent_gate.dart';

class AiCoachPage extends ConsumerWidget {
  const AiCoachPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekly = ref.watch(aiRequestPreviewControllerProvider);
    final usage = ref.watch(aiUsageControllerProvider);
    final history = ref.watch(aiReportHistoryControllerProvider);
    return SafeArea(
      key: const ValueKey('aiCoachPage'),
      child: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ListView(
          key: const ValueKey('aiCoachHomeScrollView'),
          physics: const AlwaysScrollableScrollPhysics(),
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
                    Text(
                      '今天想从哪里开始？',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Text('从已有记录中选择一次洞察，生成前由你确认本次使用的数据。'),
                    const SizedBox(height: AppSpacing.lg),
                    AiCoachAvailabilityPanel(
                      loading: usage.isLoading,
                      usage: usage.asData?.value,
                      onRetry: () => ref
                          .read(aiUsageControllerProvider.notifier)
                          .refresh(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    weekly.when(
                      loading: () => const Center(
                        key: ValueKey('aiCoachTasksLoading'),
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.lg),
                          child: CircularProgressIndicator(
                            semanticsLabel: '正在准备 AI 教练',
                          ),
                        ),
                      ),
                      error: (_, _) => _TaskLoadError(
                        onRetry: () => ref
                            .read(aiRequestPreviewControllerProvider.notifier)
                            .reloadAuthorization(),
                      ),
                      data: (state) => _TaskSection(
                        state: state,
                        usage: usage.asData?.value,
                        history: history.asData?.value,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    history.when(
                      loading: () => AiCoachRecentReportsState(
                        loading: true,
                        onRetry: () {},
                      ),
                      error: (_, _) => AiCoachRecentReportsState(
                        loading: false,
                        onRetry: () => ref
                            .read(aiReportHistoryControllerProvider.notifier)
                            .reload(),
                      ),
                      data: (state) => AiCoachRecentReports(
                        reports: state.reports,
                        onOpenReport: (id) =>
                            context.push(RoutePaths.aiReportsDetail(id)),
                        onOpenAll: () => context.push(RoutePaths.aiReports),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refresh(WidgetRef ref) async {
    await Future.wait([
      ref.read(aiUsageControllerProvider.notifier).refresh(),
      ref.read(aiReportHistoryControllerProvider.notifier).reload(),
      ref
          .read(aiRequestPreviewControllerProvider.notifier)
          .reloadAuthorization(),
    ]);
  }
}

class _TaskSection extends ConsumerWidget {
  const _TaskSection({
    required this.state,
    required this.usage,
    required this.history,
  });

  final AiRequestPreviewViewState state;
  final AiUsageSnapshot? usage;
  final AiReportHistoryViewState? history;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref
        .read(dateTimeServiceProvider)
        .currentSnapshot()
        .localDateString;
    final reports = history?.reports ?? const <AiReportListItemModel>[];
    final dailyReport = _bestReport(
      reports,
      type: AiReportType.dailyInsight,
      startDate: today,
      endDate: today,
    );
    final weeklyReport = _bestReport(
      reports,
      type: AiReportType.weeklyReport,
      startDate: state.periodStartDate,
      endDate: state.periodEndDate,
    );
    final generationAvailable =
        usage?.availability != AiUsageAvailability.disabled &&
        usage?.availability != AiUsageAvailability.limitReached;
    final dailyTask = _taskFor(
      id: 'daily',
      title: '今日洞察',
      periodLabel: today,
      report: dailyReport,
      authorizationEnabled: state.authorization.enabled,
      generationAvailable: generationAvailable,
    );
    final weeklyTask = _taskFor(
      id: 'weekly',
      title: '每周回顾',
      periodLabel: '${state.periodStartDate} 至 ${state.periodEndDate}',
      report: weeklyReport,
      authorizationEnabled: state.authorization.enabled,
      generationAvailable: generationAvailable,
    );
    return Column(
      key: const ValueKey('aiCoachTaskSection'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!state.authorization.enabled) ...[
          AiConsentGate(onOpenSettings: () => _openConsent(context, ref)),
          const SizedBox(height: AppSpacing.md),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final sideBySide = constraints.maxWidth >= 680;
            final cards = [
              AiCoachTaskCard(
                task: dailyTask,
                onPressed: () => _openTask(context, ref, dailyTask, today),
              ),
              AiCoachTaskCard(
                task: weeklyTask,
                onPressed: () => _openTask(context, ref, weeklyTask, today),
              ),
            ];
            if (!sideBySide) {
              return Column(
                children: [
                  cards.first,
                  const SizedBox(height: AppSpacing.sm),
                  cards.last,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: cards.first),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: cards.last),
              ],
            );
          },
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

  Future<void> _openTask(
    BuildContext context,
    WidgetRef ref,
    AiCoachTaskCardModel task,
    String today,
  ) async {
    if (task.reportId case final id?) {
      await context.push(RoutePaths.aiReportsDetail(id));
      if (context.mounted) await _refreshHome(ref);
      return;
    }
    if (!state.authorization.enabled) {
      await _openConsent(context, ref);
      return;
    }
    await context.push(
      task.id == 'daily'
          ? RoutePaths.aiCoachDaily(today)
          : RoutePaths.aiCoachWeekly,
    );
    if (context.mounted) await _refreshHome(ref);
  }

  Future<void> _refreshHome(WidgetRef ref) async {
    await Future.wait([
      ref.read(aiUsageControllerProvider.notifier).refresh(),
      ref.read(aiReportHistoryControllerProvider.notifier).reload(),
    ]);
  }

  AiReportListItemModel? _bestReport(
    List<AiReportListItemModel> reports, {
    required AiReportType type,
    required String startDate,
    required String endDate,
  }) {
    final matching = reports
        .where(
          (report) =>
              report.reportType == type &&
              report.periodStartDate == startDate &&
              report.periodEndDate == endDate,
        )
        .toList(growable: false);
    for (final statuses in const [
      [AiReportStatus.completed, AiReportStatus.archived],
      [AiReportStatus.pending, AiReportStatus.generating],
      [AiReportStatus.failed],
    ]) {
      for (final report in matching) {
        if (statuses.contains(report.status)) return report;
      }
    }
    return null;
  }

  AiCoachTaskCardModel _taskFor({
    required String id,
    required String title,
    required String periodLabel,
    required AiReportListItemModel? report,
    required bool authorizationEnabled,
    required bool generationAvailable,
  }) {
    final isDaily = id == 'daily';
    final generateLabel = isDaily ? '生成今日洞察' : '生成每周回顾';
    if (report != null &&
        (report.status == AiReportStatus.completed ||
            report.status == AiReportStatus.archived)) {
      return AiCoachTaskCardModel(
        id: id,
        title: title,
        periodLabel: periodLabel,
        message: report.status == AiReportStatus.archived
            ? '这份报告已归档，正文和历史仍可查看。'
            : '已有报告，可以直接继续查看。',
        actionLabel: isDaily ? '查看今日洞察' : '查看本周报告',
        iconName: id,
        actionEnabled: true,
        reportId: report.id,
        reportStatus: report.status,
      );
    }
    if (report != null &&
        (report.status == AiReportStatus.pending ||
            report.status == AiReportStatus.generating)) {
      return AiCoachTaskCardModel(
        id: id,
        title: title,
        periodLabel: periodLabel,
        message: '上次生成仍在处理中，可以继续检查结果。',
        actionLabel: '继续查看生成结果',
        iconName: id,
        actionEnabled: true,
        reportId: report.id,
        reportStatus: report.status,
      );
    }
    final actionLabel = !authorizationEnabled
        ? '设置 AI 授权'
        : generationAvailable
        ? generateLabel
        : usage?.availability == AiUsageAvailability.limitReached
        ? '今天的次数已用完'
        : 'AI 暂不可用';
    return AiCoachTaskCardModel(
      id: id,
      title: title,
      periodLabel: periodLabel,
      message: report?.status == AiReportStatus.failed
          ? '上次未能完成，可以重新选择数据后再试。'
          : '进入后选择本次允许使用的数据，系统会检查是否有足够记录。',
      actionLabel: actionLabel,
      iconName: id,
      actionEnabled: !authorizationEnabled || generationAvailable,
      reportStatus: report?.status,
    );
  }
}

class _TaskLoadError extends StatelessWidget {
  const _TaskLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('aiCoachTasksError'),
      child: Column(
        children: [
          const Text('AI 授权状态暂时无法读取。'),
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
