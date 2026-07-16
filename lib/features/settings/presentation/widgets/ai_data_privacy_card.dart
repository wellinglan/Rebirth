import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai_data_consent_controller.dart';

class AiDataPrivacyCard extends ConsumerWidget {
  const AiDataPrivacyCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consentState = ref.watch(aiDataConsentControllerProvider);
    return consentState.when(
      loading: () => const Card(
        key: ValueKey('aiDataConsentLoadingState'),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, stackTrace) => Card(
        key: const ValueKey('aiDataConsentLoadError'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('AI 数据授权状态暂时无法读取。'),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const ValueKey('retryAiDataConsentButton'),
                onPressed: () => ref
                    .read(aiDataConsentControllerProvider.notifier)
                    .reload(),
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
      data: (state) {
        final authorization = state.authorization;
        return Card(
          key: const ValueKey('aiDataPrivacyCard'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  container: true,
                  excludeSemantics: true,
                  label: authorization.enabled
                      ? 'AI 数据使用已启用'
                      : 'AI 数据使用未启用',
                  child: Row(
                    children: [
                      Icon(
                        authorization.enabled
                            ? Icons.verified_user_outlined
                            : Icons.shield_outlined,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          authorization.enabled ? '已启用' : '未启用',
                          key: const ValueKey('aiDataConsentStatus'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '当前版本只在本地、由你主动操作时准备所选数据；不会向网络发送，也不会自动生成报告。',
                ),
                if (authorization.consentAt case final consentAt?) ...[
                  const SizedBox(height: 8),
                  Text(
                    '最近同意时间：${_formatTimestamp(consentAt)}',
                    key: const ValueKey('aiDataConsentTimestamp'),
                  ),
                ],
                if (state.errorMessage case final message?) ...[
                  const SizedBox(height: 8),
                  Text(
                    message,
                    key: const ValueKey('aiDataConsentSaveError'),
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 16),
                Semantics(
                  key: const ValueKey('aiDataConsentActionSemantics'),
                  button: true,
                  enabled: !state.isSaving,
                  excludeSemantics: true,
                  label: authorization.enabled
                      ? '撤销 AI 数据使用授权'
                      : '启用 AI 数据使用',
                  child: authorization.enabled
                      ? OutlinedButton.icon(
                          key: const ValueKey('revokeAiDataSharingButton'),
                          onPressed: state.isSaving
                              ? null
                              : () => _confirmRevoke(context, ref),
                          icon: state.isSaving
                              ? const _SavingIndicator()
                              : const Icon(Icons.block_outlined),
                          label: Text(state.isSaving ? '保存中...' : '撤销授权'),
                        )
                      : FilledButton.icon(
                          key: const ValueKey('enableAiDataSharingButton'),
                          onPressed: state.isSaving
                              ? null
                              : () => _confirmGrant(context, ref),
                          icon: state.isSaving
                              ? const _SavingIndicator()
                              : const Icon(Icons.lock_open_outlined),
                          label: Text(state.isSaving ? '保存中...' : '启用 AI 数据使用'),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmGrant(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('aiDataConsentDialog'),
        title: const Text('启用 AI 数据使用？'),
        content: const Text(
          '当前版本不会向网络发送数据。启用后，只允许 App 在你主动操作时准备输入；'
          '每次生成仍需选择具体数据范围，Journal 文本不会自动包含。你可以随时撤销，'
          '撤销不会删除已有本地报告或 Today、Journal、Health、Plan 等原始记录。',
        ),
        actions: [
          TextButton(
            key: const ValueKey('cancelAiDataConsentButton'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const ValueKey('confirmAiDataConsentButton'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('同意并启用'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(aiDataConsentControllerProvider.notifier).grant();
  }

  Future<void> _confirmRevoke(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('revokeAiDataConsentDialog'),
        title: const Text('撤销 AI 数据授权？'),
        content: const Text(
          '撤销后将停止未来的 AI 输入准备。已有本地报告会保留，Today、Journal、Health、'
          'Plan 和其他原始数据不受影响。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const ValueKey('confirmRevokeAiDataConsentButton'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认撤销'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(aiDataConsentControllerProvider.notifier).revoke();
  }

  static String _formatTimestamp(int milliseconds) {
    final value = DateTime.fromMillisecondsSinceEpoch(
      milliseconds,
      isUtc: true,
    ).toLocal();
    String twoDigits(int part) => part.toString().padLeft(2, '0');
    return '${value.year}-${twoDigits(value.month)}-${twoDigits(value.day)} '
        '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
  }
}

class _SavingIndicator extends StatelessWidget {
  const _SavingIndicator();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
