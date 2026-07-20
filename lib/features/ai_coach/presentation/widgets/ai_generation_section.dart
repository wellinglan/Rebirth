import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rebirth/core/router/route_names.dart';
import 'package:rebirth/features/ai_coach/domain/ai_coach_input_bundle.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_status.dart';

import '../ai_manual_generation_controller.dart';
import '../ai_manual_generation_view_state.dart';
import '../models/ai_insight_request_context.dart';
import 'ai_generation_confirmation_dialog.dart';

class AiGenerationSection extends ConsumerWidget {
  const AiGenerationSection({
    required this.bundle,
    this.requestContext = const AiInsightRequestContext.weekly(),
    super.key,
  });

  final AiCoachInputBundle bundle;
  final AiInsightRequestContext requestContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final generation = ref.watch(
      aiManualGenerationControllerFamily(requestContext),
    );
    return Card(
      key: const ValueKey('aiGenerationSection'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: generation.when(
          loading: () => const Row(
            children: [
              SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Expanded(child: Text('正在读取服务器 AI 能力...')),
            ],
          ),
          error: (error, stackTrace) => _RetryMessage(
            message: '暂时无法读取服务器 AI 能力。',
            onRetry: () => ref
                .read(
                  aiManualGenerationControllerFamily(requestContext).notifier,
                )
                .reloadCapabilities(),
          ),
          data: (state) => _content(context, ref, state),
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    WidgetRef ref,
    AiManualGenerationViewState state,
  ) {
    switch (state.phase) {
      case AiManualGenerationPhase.signedOut:
        return _RetryMessage(
          message: '请先登录 Rebirth 云账号。',
          onRetry: () => ref
              .read(aiManualGenerationControllerFamily(requestContext).notifier)
              .reloadCapabilities(),
        );
      case AiManualGenerationPhase.disabled:
        return const Text('当前服务器未启用 AI 生成，本地预览仍可使用。');
      case AiManualGenerationPhase.submitting:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LinearProgressIndicator(
              key: ValueKey('aiGenerationProgress'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: _generateButtonKey,
              onPressed: null,
              child: const Text('生成中...'),
            ),
          ],
        );
      case AiManualGenerationPhase.pendingRecovery:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('网络响应中断或服务器仍在处理，请到本地报告中检查服务器状态。'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.push(RoutePaths.aiCoach),
              icon: const Icon(Icons.history),
              label: const Text('查看本地报告'),
            ),
          ],
        );
      case AiManualGenerationPhase.failure:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _failureMessage(state.failureCode),
              key: const ValueKey('aiGenerationFailureMessage'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 12),
            if (state.reportId case final id?)
              OutlinedButton.icon(
                key: const ValueKey('openFailedAiReportButton'),
                onPressed: () => context.push(RoutePaths.aiCoachReport(id)),
                icon: const Icon(Icons.open_in_new),
                label: const Text('查看失败记录'),
              )
            else
              OutlinedButton.icon(
                onPressed: () => ref
                    .read(
                      aiManualGenerationControllerFamily(
                        requestContext,
                      ).notifier,
                    )
                    .reloadCapabilities(),
                icon: const Icon(Icons.refresh),
                label: const Text('重试检查'),
              ),
          ],
        );
      case AiManualGenerationPhase.success:
        final reportId = state.reportId;
        return OutlinedButton.icon(
          onPressed: reportId == null
              ? null
              : () => context.push(RoutePaths.aiCoachReport(reportId)),
          icon: const Icon(Icons.open_in_new),
          label: const Text('查看已生成报告'),
        );
      case AiManualGenerationPhase.ready:
        final capabilities = state.capabilities!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${capabilities.providerLabel} · ${capabilities.model}'),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: _generateButtonKey,
              onPressed: () => _confirmAndSubmit(context, ref),
              icon: const Icon(Icons.auto_awesome_outlined),
              label: Text(requestContext.isDaily ? '生成每日洞察' : '生成每周回顾'),
            ),
          ],
        );
    }
  }

  ValueKey<String> get _generateButtonKey => ValueKey(
    requestContext.isDaily
        ? 'generateDailyInsightButton'
        : 'generateWeeklyReportButton',
  );

  Future<void> _confirmAndSubmit(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(
      aiManualGenerationControllerFamily(requestContext).notifier,
    );
    final capabilities = await controller.prepareForConfirmation(bundle);
    if (capabilities == null || !context.mounted) return;
    final confirmed = await showAiGenerationConfirmationDialog(
      context,
      bundle: bundle,
      capabilities: capabilities,
    );
    if (!confirmed || !context.mounted) return;
    final outcome = await controller.submit(bundle);
    if (!context.mounted || outcome == null) return;
    if (outcome.completed) {
      await context.push(RoutePaths.aiCoachReport(outcome.reportId));
    } else if (outcome.awaitingRecovery) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请求结果待确认，请在本地报告中检查服务器状态。')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${requestContext.isDaily ? '每日洞察' : '每周回顾'}生成失败，已保存受控失败记录。',
          ),
        ),
      );
    }
  }

  String _failureMessage(AiReportFailureCode? code) => switch (code) {
    AiReportFailureCode.authenticationRequired => '请先登录 Rebirth 云账号。',
    AiReportFailureCode.gatewayDisabled => '当前服务器未启用 AI 生成。',
    AiReportFailureCode.providerTimeout => '生成请求超时；为避免重复费用，系统不会自动重试。',
    AiReportFailureCode.providerRateLimited => 'AI Provider 当前请求较多，请稍后手动重试。',
    AiReportFailureCode.providerRefused => 'AI Provider 拒绝了本次生成请求。',
    AiReportFailureCode.providerAuthenticationFailed =>
      '服务器暂时无法认证 AI Provider。',
    AiReportFailureCode.responseInvalid => 'AI Provider 返回内容未通过结构校验。',
    AiReportFailureCode.outcomeUnknown => '无法确定 Provider 是否产生过结果或费用；不会自动重试。',
    AiReportFailureCode.resultExpired => '服务器临时结果已过保留期，无法恢复正文。',
    AiReportFailureCode.requestBindingFailed => '无法保存恢复信息，未向服务器发送生成请求。',
    AiReportFailureCode.networkOutcomeUnknown => '网络中断，请检查服务器状态。',
    AiReportFailureCode.unsupportedPromptVersion => '服务器不支持当前 Prompt Version。',
    AiReportFailureCode.unsupportedReportType => '服务器不支持当前报告类型。',
    AiReportFailureCode.unsupportedScope => '服务器不支持当前数据范围。',
    AiReportFailureCode.inputHashMismatch => '服务器校验输入 Hash 失败。',
    _ => '${requestContext.isDaily ? '每日洞察' : '每周回顾'}暂时无法生成，请检查服务器后手动重试。',
  };
}

class _RetryMessage extends StatelessWidget {
  const _RetryMessage({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(message)),
        IconButton(
          tooltip: '重试',
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }
}
