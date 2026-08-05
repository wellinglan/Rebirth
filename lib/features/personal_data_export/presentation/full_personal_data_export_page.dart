import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/theme/app_layout.dart';

import 'full_personal_data_export_controller.dart';

class FullPersonalDataExportPage extends ConsumerWidget {
  const FullPersonalDataExportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(fullPersonalDataExportControllerProvider);
    ref.listen(fullPersonalDataExportControllerProvider, (previous, next) {
      if (previous?.phase == next.phase) return;
      final message = switch (next.phase) {
        FullPersonalDataExportPhase.saved =>
          '完整个人数据已保存，共 ${next.recordCount} 条记录。',
        FullPersonalDataExportPhase.cancelled => '已取消导出，未生成文件。',
        FullPersonalDataExportPhase.failed => next.message,
        FullPersonalDataExportPhase.idle ||
        FullPersonalDataExportPhase.exporting => null,
      };
      if (message != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    });

    return Scaffold(
      key: const ValueKey('fullPersonalDataExportPage'),
      appBar: AppBar(title: const Text('导出全部个人数据')),
      body: SafeArea(
        child: ListView(
          key: const ValueKey('fullPersonalDataExportContent'),
          padding: AppLayout.pagePadding,
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppLayout.maxContentWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '完整个人数据备份',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Text('将当前登录账号的本地业务数据整理为一个可校验的 JSON 文件，由你选择保存位置。'),
                    const SizedBox(height: AppSpacing.lg),
                    const _SensitiveDataNotice(),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      '导出范围',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const _ExportScopeList(),
                    const SizedBox(height: AppSpacing.md),
                    const _BoundaryNotice(),
                    if (state.isExporting) ...[
                      const SizedBox(height: AppSpacing.md),
                      const LinearProgressIndicator(
                        key: ValueKey('fullPersonalDataExportProgress'),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Text('正在读取并校验当前账号的数据，请稍候。'),
                    ],
                    if (state.phase == FullPersonalDataExportPhase.failed &&
                        state.message != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      _FailureNotice(message: state.message!),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: const ValueKey(
                          'startFullPersonalDataExportButton',
                        ),
                        autofocus: true,
                        onPressed: state.isExporting
                            ? null
                            : () => _confirmAndExport(context, ref),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.xs,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (state.isExporting)
                                const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              else
                                const Icon(Icons.download_outlined),
                              const SizedBox(width: AppSpacing.xs),
                              Flexible(
                                child: Text(
                                  state.isExporting ? '正在准备备份...' : '选择位置并导出',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
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

  Future<void> _confirmAndExport(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('fullPersonalDataExportConfirmationDialog'),
        scrollable: true,
        title: const Text('确认导出敏感数据？'),
        content: const Text(
          '文件可能包含 Journal、Health 和 AI 报告正文，且不会自动加密。请保存到可信位置。当前版本不能从该文件恢复数据。',
        ),
        actions: [
          TextButton(
            key: const ValueKey('cancelFullPersonalDataExportButton'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const ValueKey('confirmFullPersonalDataExportButton'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确认导出'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(fullPersonalDataExportControllerProvider.notifier).export();
  }
}

class _SensitiveDataNotice extends StatelessWidget {
  const _SensitiveDataNotice();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: '敏感数据提醒，备份是未加密的明文 JSON，当前不能恢复',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber_outlined,
                color: colors.onErrorContainer,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '这是未加密的明文 JSON 文件，可能包含敏感正文。请妥善保管；当前版本只支持导出，不支持恢复。',
                  style: TextStyle(color: colors.onErrorContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExportScopeList extends StatelessWidget {
  const _ExportScopeList();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ScopeItem(text: 'Profile 与 Plan 层级关系'),
        _ScopeItem(text: 'Today、Journal 与动态反思问题快照'),
        _ScopeItem(text: 'Health 敏感字段与备注'),
        _ScopeItem(text: 'AI 报告当前正文、生命周期和版本历史'),
      ],
    );
  }
}

class _ScopeItem extends StatelessWidget {
  const _ScopeItem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, size: 20),
          const SizedBox(width: AppSpacing.xs),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _BoundaryNotice extends StatelessWidget {
  const _BoundaryNotice();

  @override
  Widget build(BuildContext context) {
    return const Text(
      '不包含密码、登录凭据、设备信息、服务器地址、同步状态、冲突快照或 AI Server Ledger。Growth 将由事实源重新计算。导出不会联网、调用 AI 或启动同步。',
    );
  }
}

class _FailureNotice extends StatelessWidget {
  const _FailureNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Text(
        message,
        key: const ValueKey('fullPersonalDataExportFailure'),
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}
