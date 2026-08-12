import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_feedback.dart';
import 'package:rebirth/features/ai_coach/presentation/ai_report_feedback_controller.dart';

class AiReportFeedbackCard extends ConsumerStatefulWidget {
  const AiReportFeedbackCard({
    required this.reportId,
    required this.reportVersion,
    this.compact = false,
    super.key,
  });

  final String reportId;
  final int reportVersion;
  final bool compact;

  @override
  ConsumerState<AiReportFeedbackCard> createState() =>
      _AiReportFeedbackCardState();
}

class _AiReportFeedbackCardState extends ConsumerState<AiReportFeedbackCard> {
  AiReportHelpfulness? _selection;
  Set<AiReportFeedbackReason> _reasons = {};
  String? _loadedIdentity;
  bool _saving = false;

  AiReportFeedbackTarget get _target =>
      (reportId: widget.reportId, reportVersion: widget.reportVersion);

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(aiReportFeedbackProvider(_target));
    final child = Padding(
      padding: EdgeInsets.all(widget.compact ? 0 : 16),
      child: async.when(
        loading: () => const Center(
          child: SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (error, stackTrace) => const Text('暂时无法读取反馈，请稍后重试。'),
        data: (feedback) {
          _initialize(feedback);
          return _content(context, feedback);
        },
      ),
    );
    if (widget.compact) {
      return KeyedSubtree(
        key: ValueKey(
          'aiReportFeedback-${widget.reportId}-${widget.reportVersion}',
        ),
        child: child,
      );
    }
    return Card(
      key: ValueKey(
        'aiReportFeedback-${widget.reportId}-${widget.reportVersion}',
      ),
      child: child,
    );
  }

  Widget _content(BuildContext context, AiReportFeedback? feedback) {
    final controller = ref.read(aiReportFeedbackControllerFamily(_target));
    final remote = feedback?.remoteSnapshot;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('这份报告对你有帮助吗？', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        SegmentedButton<AiReportHelpfulness>(
          key: const ValueKey('aiReportHelpfulnessSelector'),
          emptySelectionAllowed: true,
          selected: _selection == null ? const {} : {_selection!},
          onSelectionChanged: _saving
              ? null
              : (values) => setState(() {
                  _selection = values.isEmpty ? null : values.first;
                  if (_selection == AiReportHelpfulness.helpful) {
                    _reasons = {};
                  }
                }),
          segments: const [
            ButtonSegment(
              value: AiReportHelpfulness.helpful,
              icon: Icon(Icons.thumb_up_outlined),
              label: Text('有帮助'),
            ),
            ButtonSegment(
              value: AiReportHelpfulness.notHelpful,
              icon: Icon(Icons.thumb_down_outlined),
              label: Text('没帮助'),
            ),
          ],
        ),
        if (_selection == AiReportHelpfulness.notHelpful) ...[
          const SizedBox(height: 12),
          const Text('请选择至少一个原因'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final reason in AiReportFeedbackReason.values)
                FilterChip(
                  label: Text(reason.label),
                  selected: _reasons.contains(reason),
                  onSelected: _saving
                      ? null
                      : (selected) => setState(() {
                          selected
                              ? _reasons.add(reason)
                              : _reasons.remove(reason);
                        }),
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        const Text(
          '反馈只记录结构化选择，不包含报告正文。',
          key: ValueKey('aiReportFeedbackPrivacyNote'),
        ),
        if (feedback != null &&
            feedback.syncStatus != AiReportFeedbackSyncStatus.synced) ...[
          const SizedBox(height: 8),
          Text(
            feedback.syncStatus == AiReportFeedbackSyncStatus.conflict
                ? '这份反馈在另一台设备上也有修改，请选择要保留的版本。'
                : '已保存在本地。下次手动同步 AI 报告时会尝试同步反馈。',
          ),
        ],
        if (remote != null) ...[
          const SizedBox(height: 12),
          _ConflictSummary(title: '本地选择', feedback: feedback!),
          const SizedBox(height: 8),
          _RemoteConflictSummary(remote: remote),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                key: const ValueKey('adoptRemoteFeedbackButton'),
                onPressed: _saving
                    ? null
                    : () => _run(
                        () => controller.adoptRemote(feedback.id),
                        '已采用云端反馈',
                      ),
                child: const Text('采用云端'),
              ),
              FilledButton.tonal(
                key: const ValueKey('keepLocalFeedbackButton'),
                onPressed: _saving
                    ? null
                    : () => _run(
                        () => controller.keepLocal(feedback.id),
                        '已保留本地反馈，下次手动同步时提交',
                      ),
                child: const Text('保留本地'),
              ),
            ],
          ),
        ] else ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              if (feedback != null)
                TextButton(
                  key: const ValueKey('clearAiReportFeedbackButton'),
                  onPressed: _saving
                      ? null
                      : () => _run(controller.clear, '反馈已清除'),
                  child: const Text('清除反馈'),
                ),
              FilledButton.icon(
                key: const ValueKey('saveAiReportFeedbackButton'),
                onPressed: _canSave
                    ? () => _run(
                        () => controller.save(
                          helpfulness: _selection!,
                          reasons: _reasons,
                        ),
                        '反馈已保存',
                      )
                    : null,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? '保存中...' : '保存反馈'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  bool get _canSave =>
      !_saving &&
      _selection != null &&
      (_selection == AiReportHelpfulness.helpful || _reasons.isNotEmpty);

  void _initialize(AiReportFeedback? feedback) {
    final identity = feedback == null
        ? 'none'
        : '${feedback.id}:${feedback.updatedAt}:${feedback.syncStatus.databaseValue}';
    if (_loadedIdentity == identity) return;
    _loadedIdentity = identity;
    _selection = feedback?.helpfulness;
    _reasons = feedback?.reasons.toSet() ?? {};
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(success)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('反馈操作未完成，本地报告未改变。')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _ConflictSummary extends StatelessWidget {
  const _ConflictSummary({required this.title, required this.feedback});
  final String title;
  final AiReportFeedback feedback;

  @override
  Widget build(BuildContext context) =>
      Text('$title：${_summary(feedback.helpfulness, feedback.reasons)}');
}

class _RemoteConflictSummary extends StatelessWidget {
  const _RemoteConflictSummary({required this.remote});
  final AiReportFeedbackRemoteSnapshot remote;

  @override
  Widget build(BuildContext context) =>
      Text('云端选择：${_summary(remote.helpfulness, remote.reasons)}');
}

String _summary(
  AiReportHelpfulness helpfulness,
  Iterable<AiReportFeedbackReason> reasons,
) {
  if (helpfulness == AiReportHelpfulness.helpful) return '有帮助';
  return '没帮助（${reasons.map((item) => item.label).join('、')}）';
}
