import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rebirth/core/router/route_names.dart';
import 'package:rebirth/core/theme/app_layout.dart';

import '../application/foreground_auto_sync_state.dart';
import '../domain/sync_module.dart';
import 'foreground_auto_sync_controller.dart';
import 'sync_center_controller.dart';
import 'sync_center_view_state.dart';

class SyncCenterPage extends ConsumerWidget {
  const SyncCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(syncCenterControllerProvider);
    final automaticState = ref.watch(foregroundAutoSyncControllerProvider);
    return Scaffold(
      key: const ValueKey('syncCenterPage'),
      appBar: AppBar(
        title: const Text('同步中心'),
        actions: [
          IconButton(
            key: const ValueKey('refreshSyncCenterButton'),
            tooltip: '刷新本地同步状态',
            onPressed:
                state.value?.isRunning == true || automaticState.isSyncing
                ? null
                : () =>
                      ref.read(syncCenterControllerProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: state.when(
          loading: () => const Center(
            child: CircularProgressIndicator(semanticsLabel: '正在读取本地同步状态'),
          ),
          error: (_, _) => Center(
            child: OutlinedButton.icon(
              onPressed: () =>
                  ref.read(syncCenterControllerProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh),
              label: const Text('重新加载'),
            ),
          ),
          data: (value) =>
              _SyncCenterContent(state: value, automaticState: automaticState),
        ),
      ),
    );
  }
}

class _SyncCenterContent extends ConsumerWidget {
  const _SyncCenterContent({required this.state, required this.automaticState});

  final SyncCenterViewState state;
  final ForegroundAutoSyncState automaticState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: AppLayout.pagePadding,
      children: [
        const Text('自动同步仅在你授权且 App 位于前台时运行；无歧义的单边或非重叠变化可能自动协调，真实冲突仍由你决定。'),
        const SizedBox(height: AppSpacing.md),
        _AutomaticSyncCard(state: automaticState, modules: state.modules),
        const SizedBox(height: AppSpacing.sm),
        _OverallSyncCard(state: state, automaticState: automaticState),
        const SizedBox(height: AppLayout.sectionGap),
        Text('数据模块', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        for (final descriptor in state.modules) ...[
          _SyncModuleCard(
            descriptor: descriptor,
            result: state.results[descriptor.moduleId],
            conflictCount: state.conflictCounts[descriptor.moduleId] ?? 0,
            actionsEnabled: !state.isRunning && !automaticState.isSyncing,
            onSync: () => _syncModule(context, ref, descriptor.moduleId),
            onOpenConflicts: () => context.push(
              RoutePaths.syncConflictsForModule(descriptor.moduleId.stableId),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        const SizedBox(height: AppSpacing.sm),
        Text(
          '同步失败不会删除本地数据。只有可证明无歧义的变化会自动协调；其他冲突需要你明确选择保留本地或采用云端。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Future<void> _syncModule(
    BuildContext context,
    WidgetRef ref,
    SyncModuleId moduleId,
  ) async {
    try {
      final result = await ref
          .read(syncCenterControllerProvider.notifier)
          .syncModule(moduleId);
      if (context.mounted) _message(context, result.userFacingMessage);
    } catch (_) {
      if (context.mounted) _message(context, '同步未完成，本地数据未受影响');
    }
  }

  void _message(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AutomaticSyncCard extends ConsumerWidget {
  const _AutomaticSyncCard({required this.state, required this.modules});

  final ForegroundAutoSyncState state;
  final List<SyncModuleDescriptor> modules;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final canChange = state.hasAccountPreference && !state.isSavingPreference;
    return Card(
      key: const ValueKey('automaticSyncCard'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label: '在此设备自动同步，当前${state.enabled ? '已开启' : '未开启'}',
            child: SwitchListTile.adaptive(
              key: const ValueKey('automaticSyncSwitch'),
              value: state.enabled,
              onChanged: canChange
                  ? (enabled) => _changePreference(context, ref, enabled)
                  : null,
              secondary: state.isSavingPreference
                  ? const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync_lock_outlined),
              title: const Text('在此设备自动同步'),
              subtitle: const Text('仅前台运行；每个账号、每台设备分别设置'),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  liveRegion: true,
                  label: '自动同步状态，${_statusLabel(state, modules)}',
                  child: Text(
                    _statusLabel(state, modules),
                    key: const ValueKey('automaticSyncStatus'),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Semantics(
                  liveRegion: true,
                  label:
                      '本次启动已自动协调 ${state.automaticallyReconciledCount} 条，'
                      '仍有 ${state.conflictCount} 条需要处理',
                  child: Text(
                    '已自动协调 ${state.automaticallyReconciledCount} 条 · '
                    '仍有 ${state.conflictCount} 条需要处理',
                    key: const ValueKey('automaticReconciliationSummary'),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                if (state.conflictCount > 0 ||
                    state.status ==
                        ForegroundAutoSyncStatus.needsAttention) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      key: const ValueKey('automaticSyncConflictButton'),
                      onPressed: () => context.push(RoutePaths.syncConflicts),
                      icon: const Icon(Icons.rule_folder_outlined),
                      label: const Text('处理同步问题'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changePreference(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
  ) async {
    if (enabled) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          key: const ValueKey('automaticSyncConsentDialog'),
          title: const Text('开启此设备自动同步？'),
          content: const SingleChildScrollView(
            child: Text(
              '开启后，Rebirth 会在 App 前台同步 Profile、Plan、Today、Journal、Health 和 AI 报告。\n\n'
              'Journal、Health 和 AI 报告可能包含敏感内容。本设置仅对当前设备和当前账号生效；无歧义的单边或非重叠变化可能自动协调，真实冲突仍需你处理。AI Chat 不会同步，云同步授权也不等于 AI 数据授权。',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              key: const ValueKey('confirmAutomaticSyncButton'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('确认开启'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }

    final saved = await ref
        .read(foregroundAutoSyncControllerProvider.notifier)
        .setEnabled(enabled);
    if (!saved && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(enabled ? '开启自动同步失败，请重试' : '关闭自动同步失败，请重试')),
        );
    }
  }

  String _statusLabel(
    ForegroundAutoSyncState state,
    List<SyncModuleDescriptor> modules,
  ) {
    final moduleName = _moduleNameFor(state.currentModule, modules);
    return switch (state.status) {
      ForegroundAutoSyncStatus.unavailable => state.message ?? '会话不可用，自动同步未运行',
      ForegroundAutoSyncStatus.loadingPreference => '正在读取此设备的自动同步设置',
      ForegroundAutoSyncStatus.disabled => '未开启',
      ForegroundAutoSyncStatus.waitingForAccount =>
        state.message ?? '等待账号和设备准备完成',
      ForegroundAutoSyncStatus.pending =>
        '等待同步${state.pendingModuleCount > 0 ? ' · ${state.pendingModuleCount} 个模块' : ''}',
      ForegroundAutoSyncStatus.syncing =>
        '正在自动同步${moduleName == null ? '' : ' · $moduleName'}',
      ForegroundAutoSyncStatus.retryScheduled =>
        state.message ?? '网络暂不可用，稍后在前台重试',
      ForegroundAutoSyncStatus.needsAttention => state.message ?? '需要处理同步冲突',
      ForegroundAutoSyncStatus.failed => state.message ?? '自动同步未完成，本地数据已保留',
      ForegroundAutoSyncStatus.idle when state.lastSuccessAt != null =>
        '本次启动最近同步完成 · ${_clockLabel(state.lastSuccessAt!)}',
      ForegroundAutoSyncStatus.idle => '空闲，等待本地修改或其他设备更新',
    };
  }

  String _clockLabel(int milliseconds) {
    final local = DateTime.fromMillisecondsSinceEpoch(
      milliseconds,
      isUtc: true,
    ).toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  String? _moduleNameFor(
    SyncModuleId? moduleId,
    List<SyncModuleDescriptor> modules,
  ) {
    if (moduleId == null) return null;
    for (final module in modules) {
      if (module.moduleId == moduleId) return module.displayName;
    }
    return null;
  }
}

class _OverallSyncCard extends ConsumerWidget {
  const _OverallSyncCard({required this.state, required this.automaticState});

  final SyncCenterViewState state;
  final ForegroundAutoSyncState automaticState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentName = state.currentModule == null
        ? null
        : state.modules
              .firstWhere((module) => module.moduleId == state.currentModule)
              .displayName;
    return Card(
      key: const ValueKey('syncCenterOverallCard'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.sync_outlined),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    state.overallStatusLabel,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            if (state.isSyncingAll) ...[
              const SizedBox(height: AppSpacing.sm),
              Semantics(
                liveRegion: true,
                label:
                    '同步进度 ${state.completedModules} / ${state.modules.length}'
                    '${currentName == null ? '' : '，当前 $currentName'}',
                child: Text(
                  '${state.completedModules} / ${state.modules.length}'
                  '${currentName == null ? '' : ' · 正在同步 $currentName'}',
                  key: const ValueKey('syncAllProgress'),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text(
              state.totalConflictCount == 0
                  ? '无待处理问题'
                  : '有 ${state.totalConflictCount} 项待处理问题',
              semanticsLabel: state.totalConflictCount == 0
                  ? '无待处理同步问题'
                  : '有 ${state.totalConflictCount} 项待处理同步问题',
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                FilledButton.icon(
                  key: const ValueKey('syncAllButton'),
                  onPressed: state.isRunning || automaticState.isSyncing
                      ? null
                      : () => _syncAll(context, ref),
                  icon: state.isSyncingAll
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                  label: Text(state.isSyncingAll ? '同步中...' : '同步全部'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('openSyncIssuesButton'),
                  onPressed: () => context.push(RoutePaths.syncConflicts),
                  icon: const Icon(Icons.rule_folder_outlined),
                  label: const Text('待处理问题'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _syncAll(BuildContext context, WidgetRef ref) async {
    try {
      final result = await ref
          .read(syncCenterControllerProvider.notifier)
          .syncAll();
      if (!context.mounted) return;
      final message = result.hasConflict
          ? '同步完成，部分数据需要处理'
          : result.hasFailure
          ? '同步部分完成，请查看各模块结果'
          : '全部模块同步完成';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('同步未完成，本地数据未受影响')));
    }
  }
}

class _SyncModuleCard extends StatelessWidget {
  const _SyncModuleCard({
    required this.descriptor,
    required this.result,
    required this.conflictCount,
    required this.actionsEnabled,
    required this.onSync,
    required this.onOpenConflicts,
  });

  final SyncModuleDescriptor descriptor;
  final SyncModuleExecutionResult? result;
  final int conflictCount;
  final bool actionsEnabled;
  final VoidCallback onSync;
  final VoidCallback onOpenConflicts;

  @override
  Widget build(BuildContext context) {
    final status = result?.status ?? SyncModuleExecutionStatus.idle;
    return Card(
      key: ValueKey('syncModule-${descriptor.moduleId.stableId}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_iconFor(descriptor.moduleId)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        descriptor.displayName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(descriptor.description),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(_statusLabel(status)),
              ],
            ),
            if (descriptor.sensitivity == SyncModuleSensitivity.sensitive) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(switch (descriptor.moduleId) {
                SyncModuleId.health => 'Health 包含敏感个人数据，请确认当前设备的同步授权。',
                SyncModuleId.aiReport => 'AI 报告可能包含敏感内容，请确认当前设备的同步授权。',
                _ => 'Journal 内容可能包含敏感信息，请确认当前设备的同步授权。',
              }, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              children: [
                _Metric(label: '上传', value: result?.pushedCount ?? 0),
                _Metric(label: '拉取', value: result?.pulledCount ?? 0),
                _Metric(label: '删除', value: result?.deletedCount ?? 0),
                _Metric(
                  label: '冲突',
                  value: result?.conflictCount ?? conflictCount,
                ),
                _Metric(label: '失败项', value: result?.failedEntityCount ?? 0),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                FilledButton.tonalIcon(
                  key: ValueKey(
                    'syncModuleButton-${descriptor.moduleId.stableId}',
                  ),
                  onPressed: actionsEnabled ? onSync : null,
                  icon: status == SyncModuleExecutionStatus.running
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                  label: Text(
                    status == SyncModuleExecutionStatus.running
                        ? '同步中...'
                        : '同步 ${descriptor.displayName}',
                  ),
                ),
                if (conflictCount > 0)
                  OutlinedButton.icon(
                    onPressed: onOpenConflicts,
                    icon: const Icon(Icons.rule_folder_outlined),
                    label: Text('查看问题 ($conflictCount)'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Text('$label $value');
  }
}

IconData _iconFor(SyncModuleId moduleId) => switch (moduleId) {
  SyncModuleId.profile => Icons.person_outline,
  SyncModuleId.plan => Icons.account_tree_outlined,
  SyncModuleId.today => Icons.today_outlined,
  SyncModuleId.journal => Icons.auto_stories_outlined,
  SyncModuleId.health => Icons.favorite_outline,
  SyncModuleId.aiReport => Icons.auto_awesome_outlined,
};

String _statusLabel(SyncModuleExecutionStatus status) => switch (status) {
  SyncModuleExecutionStatus.idle => '等待同步',
  SyncModuleExecutionStatus.queued => '等待执行',
  SyncModuleExecutionStatus.running => '正在同步',
  SyncModuleExecutionStatus.noChanges => '无新变化',
  SyncModuleExecutionStatus.succeeded => '同步完成',
  SyncModuleExecutionStatus.conflict => '需要处理',
  SyncModuleExecutionStatus.partial => '部分完成',
  SyncModuleExecutionStatus.failed => '同步失败',
  SyncModuleExecutionStatus.skipped => '未执行',
};
