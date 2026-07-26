import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/theme/app_layout.dart';
import 'package:rebirth/features/account/domain/account_boundary.dart';

import 'app_auth_controller.dart';
import 'legacy_data_resolution_controller.dart';

class AuthStartupPage extends StatelessWidget {
  const AuthStartupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      key: ValueKey('authStartupPage'),
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class AccountBindingRequiredPage extends ConsumerWidget {
  const AccountBindingRequiredPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolution = ref.watch(legacyDataResolutionControllerProvider);
    return PopScope(
      canPop: false,
      child: Scaffold(
        key: const ValueKey('accountBindingRequiredPage'),
        appBar: AppBar(
          title: const Text(
            '确认本地数据归属',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: SafeArea(
          child: resolution.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                key: ValueKey('legacyDataSummariesLoading'),
              ),
            ),
            error: (error, stackTrace) => _LegacyResolutionError(
              onRetry: () => ref
                  .read(legacyDataResolutionControllerProvider.notifier)
                  .retry(),
            ),
            data: (value) => _LegacyResolutionContent(
              state: value,
              onClaim: (summary) => _confirmClaim(context, ref, summary),
              onCreateFresh: () => _confirmFreshSpace(context, ref),
              onLogout: () => ref
                  .read(legacyDataResolutionControllerProvider.notifier)
                  .logout(),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmClaim(
    BuildContext context,
    WidgetRef ref,
    LegacyLocalDataSpaceSummary summary,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _OwnershipConfirmationDialog(
        dialogKey: const ValueKey('claimLegacyConfirmationDialog'),
        title: '确认归属此本地数据？',
        confirmLabel: '确认归属',
        content: const [
          '该操作会把所选本地数据空间标记为当前服务器与当前账号所有，其他账号将无法访问。',
          '本地记录不会上传，历史版本、游标和冲突也不会被清空。',
          '为避免误用旧账号的同步元数据，Profile 与 Plan 云同步将暂时受限，等待后续独立验证。',
          '取消不会修改任何数据。',
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref
        .read(legacyDataResolutionControllerProvider.notifier)
        .claim(summary.selectionKey);
  }

  Future<void> _confirmFreshSpace(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _OwnershipConfirmationDialog(
        dialogKey: const ValueKey('createFreshConfirmationDialog'),
        title: '创建全新数据空间？',
        confirmLabel: '创建新空间',
        content: const [
          '将为当前账号创建一个空白的本地数据空间。',
          '现有旧数据不会删除、复制或自动归属，仍保持隔离和不可访问。',
          '旧记录的同步版本、游标和冲突不会被重置，也不会自动拉取或上传数据。',
          '取消不会修改任何数据。',
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref
        .read(legacyDataResolutionControllerProvider.notifier)
        .createFreshSpace();
  }
}

class _LegacyResolutionContent extends StatelessWidget {
  const _LegacyResolutionContent({
    required this.state,
    required this.onClaim,
    required this.onCreateFresh,
    required this.onLogout,
  });

  final LegacyDataResolutionState state;
  final ValueChanged<LegacyLocalDataSpaceSummary> onClaim;
  final VoidCallback onCreateFresh;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 480
            ? AppSpacing.md
            : AppSpacing.lg;
        return ListView(
          key: const ValueKey('legacyDataResolutionList'),
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            AppSpacing.md,
            horizontalPadding,
            AppSpacing.xl,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 840),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 32,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            '检测到旧本地数据',
                            style: theme.textTheme.headlineSmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'Rebirth 不会猜测这些数据属于哪个账号，也不会自动同步。'
                      '请选择一个数据空间明确归属，或为当前账号创建全新空间。',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (state.summaries.isEmpty)
                      const _NoLegacySpacesNotice()
                    else
                      ...state.summaries.map(
                        (summary) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: _LegacySpaceCard(
                            summary: summary,
                            enabled: !state.isBusy,
                            onClaim: () => onClaim(summary),
                          ),
                        ),
                      ),
                    if (state.message case final message?) ...[
                      Text(
                        message,
                        key: const ValueKey('legacyResolutionErrorMessage'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (state.isBusy) ...[
                      const LinearProgressIndicator(
                        key: ValueKey('legacyResolutionBusyIndicator'),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _busyLabel(state.action),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      alignment: WrapAlignment.center,
                      children: [
                        Tooltip(
                          message: '创建不包含旧记录的空白数据空间',
                          child: Semantics(
                            button: true,
                            label: '为当前账号创建全新数据空间',
                            child: FilledButton.icon(
                              key: const ValueKey('createFreshDataSpaceButton'),
                              onPressed: state.isBusy ? null : onCreateFresh,
                              icon: const Icon(Icons.add_box_outlined),
                              label: const Text('为当前账号创建全新空间'),
                            ),
                          ),
                        ),
                        Tooltip(
                          message: '保留全部本地数据并退出登录',
                          child: Semantics(
                            button: true,
                            label: '暂不处理并退出登录',
                            child: OutlinedButton.icon(
                              key: const ValueKey(
                                'bindingRequiredLogoutButton',
                              ),
                              onPressed: state.isBusy ? null : onLogout,
                              icon: const Icon(Icons.logout),
                              label: const Text('暂不处理并退出'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _busyLabel(LegacyDataResolutionAction action) {
    return switch (action) {
      LegacyDataResolutionAction.bindingLegacy => '正在确认本地数据归属...',
      LegacyDataResolutionAction.creatingFreshSpace => '正在创建全新数据空间...',
      LegacyDataResolutionAction.signingOut => '正在退出登录...',
      _ => '',
    };
  }
}

class _LegacySpaceCard extends StatelessWidget {
  const _LegacySpaceCard({
    required this.summary,
    required this.enabled,
    required this.onClaim,
  });

  final LegacyLocalDataSpaceSummary summary;
  final bool enabled;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final latest = summary.latestBusinessUpdatedAt;
    return Card(
      key: ValueKey('legacySpaceCard-${summary.selectionKey}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(summary.displayLabel, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text('创建日期：${summary.profileCreatedDate}'),
            Text(
              '最近业务更新：${latest == null ? '无业务记录' : _formatTimestamp(latest)}',
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                _SummaryCount(label: 'Today', value: summary.todayCount),
                _SummaryCount(label: 'Journal', value: summary.journalCount),
                _SummaryCount(label: 'Plan', value: summary.goalCount),
                _SummaryCount(label: 'Health', value: summary.healthCount),
                _SummaryCount(label: 'AI Report', value: summary.aiReportCount),
                _SummaryCount(label: '删除记录', value: summary.tombstoneCount),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '历史同步痕迹：${summary.hasSyncHistory ? '有' : '无'}'
              '  冲突历史：${summary.hasConflictHistory ? '有' : '无'}'
              '  待处理 AI：${summary.hasAiPending ? '有' : '无'}',
            ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: Tooltip(
                message: '将此数据空间明确归属到当前账号',
                child: Semantics(
                  button: true,
                  label: '将${summary.displayLabel}归属到当前账号',
                  child: FilledButton.tonalIcon(
                    key: ValueKey(
                      'claimLegacySpaceButton-${summary.selectionKey}',
                    ),
                    onPressed: enabled ? onClaim : null,
                    icon: const Icon(Icons.verified_user_outlined),
                    label: const Text('将此数据归属到当前账号'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(int milliseconds) {
    final value = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${twoDigits(value.month)}-${twoDigits(value.day)} '
        '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
  }
}

class _SummaryCount extends StatelessWidget {
  const _SummaryCount({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Text('$label：$value');
  }
}

class _NoLegacySpacesNotice extends StatelessWidget {
  const _NoLegacySpacesNotice();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.md),
      child: Text(
        '当前没有可认领的旧数据空间。可以创建全新空间，或退出后重新检查。',
        key: ValueKey('noLegacySpacesNotice'),
      ),
    );
  }
}

class _LegacyResolutionError extends StatelessWidget {
  const _LegacyResolutionError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: AppSpacing.sm),
            const Text('无法读取旧本地数据概览，任何数据都没有被修改。'),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              key: const ValueKey('retryLegacyDataSummariesButton'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OwnershipConfirmationDialog extends StatelessWidget {
  const _OwnershipConfirmationDialog({
    required this.dialogKey,
    required this.title,
    required this.confirmLabel,
    required this.content,
  });

  final Key dialogKey;
  final String title;
  final String confirmLabel;
  final List<String> content;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: dialogKey,
      title: Text(title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final paragraph in content) ...[
                Text(paragraph),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('cancelOwnershipConfirmationButton'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const ValueKey('confirmOwnershipButton'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}

class SessionRejectedPage extends ConsumerWidget {
  const SessionRejectedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message =
        ref.watch(appAuthStateProvider).value?.message ?? '当前会话无法继续使用。';
    return _AuthStatusScaffold(
      pageKey: const ValueKey('sessionRejectedPage'),
      icon: Icons.lock_reset_outlined,
      title: '需要重新登录',
      message: message,
      actions: [
        FilledButton.icon(
          key: const ValueKey('sessionRejectedLogoutButton'),
          onPressed: () =>
              ref.read(appAuthControllerProvider.notifier).logout(),
          icon: const Icon(Icons.login),
          label: const Text('返回登录'),
        ),
      ],
    );
  }
}

class FatalMigrationErrorPage extends ConsumerWidget {
  const FatalMigrationErrorPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message =
        ref.watch(appAuthStateProvider).value?.message ?? '本地数据空间初始化失败。';
    return _AuthStatusScaffold(
      pageKey: const ValueKey('fatalMigrationErrorPage'),
      icon: Icons.error_outline,
      title: '无法打开账号数据',
      message: '$message\n本地数据没有被删除。',
      actions: [
        FilledButton.icon(
          key: const ValueKey('retryAuthStartupButton'),
          onPressed: () => ref.read(appAuthControllerProvider.notifier).retry(),
          icon: const Icon(Icons.refresh),
          label: const Text('重试'),
        ),
      ],
    );
  }
}

class _AuthStatusScaffold extends StatelessWidget {
  const _AuthStatusScaffold({
    required this.pageKey,
    required this.icon,
    required this.title,
    required this.message,
    required this.actions,
  });

  final Key pageKey;
  final IconData icon;
  final String title;
  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: pageKey,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  Icon(icon, size: 48),
                  const SizedBox(height: AppSpacing.md),
                  Text(title, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: AppSpacing.sm),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: actions,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
