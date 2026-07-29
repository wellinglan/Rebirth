import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/theme/app_layout.dart';
import 'package:rebirth/features/journal/domain/journal_sync_payload.dart';
import 'package:rebirth/features/journal/domain/journal_prompt_sync_payload.dart';
import 'package:rebirth/features/health/domain/health_sync_payload.dart';
import 'package:rebirth/features/plan/domain/plan_goal.dart';
import 'package:rebirth/features/plan/domain/plan_sync_payload.dart';
import 'package:rebirth/features/profile/domain/profile_sync_payload.dart';
import 'package:rebirth/features/sync/data/sync_conflict_providers.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_record.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/today/domain/today_sync_payload.dart';

import 'sync_conflict_resolution_handlers.dart';
import 'sync_center_controller.dart';

class SyncConflictDetailPage extends ConsumerWidget {
  const SyncConflictDetailPage({required this.conflictId, super.key});

  final String conflictId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conflict = ref.watch(syncConflictDetailsProvider(conflictId));
    final registry = ref.watch(syncConflictResolutionHandlerRegistryProvider);
    return Scaffold(
      key: const ValueKey('syncConflictDetailPage'),
      appBar: AppBar(title: const Text('同步冲突详情')),
      body: SafeArea(
        child: conflict.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
              key: ValueKey('syncConflictDetailLoading'),
              semanticsLabel: '正在加载冲突详情',
            ),
          ),
          error: (_, _) => const Center(
            key: ValueKey('syncConflictDetailNotFound'),
            child: Text('未找到该冲突，或它不属于当前账号与服务器。'),
          ),
          data: (details) {
            final handler = registry.handlerFor(details.record.entityType);
            return _ConflictDetails(
              details: details,
              hasHandler: handler != null,
              isBusy:
                  handler?.isBusy == true &&
                  handler?.resolvingConflictId == details.record.id,
              onRetryHydration: () => _run(
                context,
                ref,
                details.record,
                () => handler!.retryHydration(details.record.id),
              ),
              onRetryRequested: () => _run(
                context,
                ref,
                details.record,
                () => handler!.retryRequestedResolution(details.record.id),
              ),
              onAdoptRemote: () => _confirmAndRun(
                context,
                ref,
                details.record,
                handler: handler!,
                action: SyncConflictResolutionAction.adoptRemote,
              ),
              onKeepLocal: () => _confirmAndRun(
                context,
                ref,
                details.record,
                handler: handler!,
                action: SyncConflictResolutionAction.keepLocal,
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmAndRun(
    BuildContext context,
    WidgetRef ref,
    SyncConflictRecord record, {
    required SyncConflictResolutionHandler handler,
    required SyncConflictResolutionAction action,
  }) async {
    final adopt = action == SyncConflictResolutionAction.adoptRemote;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            key: ValueKey(
              adopt ? 'confirmAdoptRemoteDialog' : 'confirmKeepLocalDialog',
            ),
            title: Text(adopt ? '采用服务器当前版本？' : '保留本地版本并上传？'),
            content: SingleChildScrollView(
              child: Text(_confirmationMessage(record.entityType, adopt)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                key: ValueKey(
                  adopt ? 'confirmAdoptRemoteButton' : 'confirmKeepLocalButton',
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(adopt ? '采用云端' : '保留本地'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) return;
    await _run(
      context,
      ref,
      record,
      () =>
          adopt ? handler.adoptRemote(record.id) : handler.keepLocal(record.id),
    );
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    SyncConflictRecord record,
    Future<Object?> Function() action,
  ) async {
    try {
      await action();
      ref.invalidate(syncConflictDetailsProvider(conflictId));
      ref.invalidate(activeSyncConflictListProvider);
      await ref.read(syncCenterControllerProvider.notifier).refresh();
      if (!context.mounted) return;
      _message(context, '冲突操作已完成');
    } catch (_) {
      if (!context.mounted) return;
      _message(
        context,
        record.entityType == SyncEntityType.profile
            ? '操作未完成，本地 Profile 已保留'
            : record.entityType == SyncEntityType.today
            ? '操作未完成，本地 Today 内容已保留'
            : record.entityType == SyncEntityType.journal
            ? '操作未完成，本地 Journal 内容已保留'
            : record.entityType == SyncEntityType.journalPromptConfiguration
            ? '操作未完成，本地 Journal 问题配置已保留'
            : record.entityType == SyncEntityType.health
            ? '操作未完成，本地 Health 内容已保留'
            : '操作未完成，本地 Plan 内容已保留',
      );
    }
  }

  void _message(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _confirmationMessage(SyncEntityType entityType, bool adopt) {
    if (entityType == SyncEntityType.profile) {
      return adopt
          ? '采用云端后，本地 Profile 的昵称、成长方向与时区将被服务器当前版本替换。'
                '操作失败或取消时本地资料保持不变。'
          : '当前本地 Profile 将覆盖服务器版本，其他设备随后同步时会看到该版本。'
                '服务器再次变化时可能重新产生冲突。';
    }
    if (entityType == SyncEntityType.today) {
      return adopt
          ? '当前本地 Today 冲突修改尚未上传。采用云端后，本地 Today 内容将被服务器当前版本替换；'
                '云端已删除时本地 Today 将软删除。同日 Health 不会删除，操作失败或取消时本地内容保持不变。'
          : '当前本地 Today 将覆盖服务器当前版本，其他设备随后同步时会看到该版本。'
                '云端如果再次变化可能重新产生冲突。同日 Health 不参与上传，操作失败或取消时本地内容保持不变。';
    }
    if (entityType == SyncEntityType.journal) {
      return adopt
          ? '当前本地 Journal 冲突修改尚未上传。采用云端后，本地 Journal 内容将被服务器当前版本替换；'
                '云端已删除时本地 Journal 将软删除。操作失败或取消时本地内容保持不变。'
          : '当前本地 Journal 将覆盖服务器当前版本，其他设备随后同步时会看到该版本。'
                '服务器如果再次变化可能重新产生冲突。操作失败或取消时本地内容保持不变。';
    }
    if (entityType == SyncEntityType.journalPromptConfiguration) {
      return adopt
          ? '采用云端后，当前 Journal 问题配置会被服务器版本替换；历史 Journal 的问题快照和回答不会改变。'
                '操作失败或取消时本地配置保持不变。'
          : '当前 Journal 问题配置将覆盖服务器版本，其他设备随后同步时会看到该配置。'
                '历史 Journal 不会改变，服务器再次变化时可能重新产生冲突。';
    }
    if (entityType == SyncEntityType.health) {
      return adopt
          ? '当前本地 Health 冲突修改尚未上传。采用云端后，本地 Health 记录将被服务器当前版本替换；'
                '云端已删除时本地 Health 将软删除。操作失败或取消时本地内容保持不变。'
          : '当前本地 Health 记录将覆盖服务器当前版本，其他设备随后同步时会看到该版本。'
                '服务器如果再次变化可能重新产生冲突。操作失败或取消时本地内容保持不变。';
    }
    return adopt
        ? '本地冲突修改尚未上传。采用服务器当前版本后，本地该目标将被替换；'
              '如果云端已经删除该目标，本地也会软删除。操作失败时本地内容保持不变。'
        : '当前本地目标将覆盖服务器版本，其他设备随后会看到该版本。'
              '如果服务器再次变化，可能产生新的冲突。操作失败时本地内容保持不变。';
  }
}

class _ConflictDetails extends StatelessWidget {
  const _ConflictDetails({
    required this.details,
    required this.hasHandler,
    required this.isBusy,
    required this.onRetryHydration,
    required this.onRetryRequested,
    required this.onAdoptRemote,
    required this.onKeepLocal,
  });

  final SyncConflictDetails details;
  final bool hasHandler;
  final bool isBusy;
  final VoidCallback onRetryHydration;
  final VoidCallback onRetryRequested;
  final VoidCallback onAdoptRemote;
  final VoidCallback onKeepLocal;

  @override
  Widget build(BuildContext context) {
    final record = details.record;
    final currentLocal = details.currentLocalSnapshot;
    return ListView(
      padding: AppLayout.pagePadding,
      children: [
        Text(
          _displayTitle(record),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(_statusLabel(record.resolutionStatus)),
        const SizedBox(height: AppSpacing.md),
        if (!record.isActive)
          const Card(
            key: ValueKey('resolvedConflictNotice'),
            child: ListTile(
              leading: Icon(Icons.check_circle_outline),
              title: Text('该冲突已处理'),
              subtitle: Text('历史记录会保留，但不会再次参与解决。'),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final local = _VersionSummary(
                title: '本地版本',
                snapshot: currentLocal ?? record.localSnapshot,
                operation:
                    (currentLocal ?? record.localSnapshot).deletedAt == null
                    ? SyncConflictOperation.upsert
                    : SyncConflictOperation.delete,
                notice: details.localSnapshotChanged
                    ? '本地内容在冲突后已变化，将以当前内容执行“保留本地”。'
                    : null,
              );
              final remote = _VersionSummary(
                title: '云端版本',
                snapshot: record.remoteSnapshot,
                operation: record.remoteOperation,
              );
              if (constraints.maxWidth < 720) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    local,
                    const SizedBox(height: AppSpacing.sm),
                    remote,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: local),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: remote),
                ],
              );
            },
          ),
        const SizedBox(height: AppSpacing.md),
        if (record.isActive)
          hasHandler
              ? Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    if (!record.remoteSnapshotReady)
                      _ActionButton(
                        key: const ValueKey('retryConflictHydrationButton'),
                        tooltip: '重新同步获取云端版本',
                        label: isBusy ? '获取中...' : '重新获取云端版本',
                        icon: Icons.cloud_download_outlined,
                        onPressed: isBusy ? null : onRetryHydration,
                      ),
                    if (record.resolutionStatus ==
                        SyncConflictResolutionStatus.unresolved) ...[
                      _ActionButton(
                        key: const ValueKey('adoptRemoteButton'),
                        tooltip: '采用服务器当前版本',
                        label: isBusy ? '处理中...' : '采用云端版本',
                        icon: Icons.cloud_done_outlined,
                        onPressed: isBusy || !record.remoteSnapshotReady
                            ? null
                            : onAdoptRemote,
                      ),
                      _ActionButton(
                        key: const ValueKey('keepLocalButton'),
                        tooltip: '保留本地版本并上传',
                        label: isBusy ? '处理中...' : '保留本地并上传',
                        icon: Icons.upload_outlined,
                        onPressed:
                            isBusy ||
                                record.remoteSnapshot.serverVersion == null
                            ? null
                            : onKeepLocal,
                      ),
                    ],
                    if (record.resolutionStatus ==
                            SyncConflictResolutionStatus.adoptRemoteRequested ||
                        record.resolutionStatus ==
                            SyncConflictResolutionStatus.keepLocalRequested)
                      _ActionButton(
                        key: const ValueKey('retryConflictResolutionButton'),
                        tooltip: '继续上次冲突处理',
                        label: isBusy ? '处理中...' : '继续处理',
                        icon: Icons.refresh,
                        onPressed: isBusy ? null : onRetryRequested,
                      ),
                  ],
                )
              : const Card(
                  key: ValueKey('unsupportedConflictProtectedNotice'),
                  child: ListTile(
                    leading: Icon(Icons.shield_outlined),
                    title: Text('本地内容已保留'),
                    subtitle: Text('当前实体尚未注册冲突处理器，只能查看冲突详情。'),
                  ),
                ),
      ],
    );
  }
}

class _VersionSummary extends StatelessWidget {
  const _VersionSummary({
    required this.title,
    required this.snapshot,
    required this.operation,
    this.notice,
  });

  final String title;
  final SyncConflictSnapshot snapshot;
  final SyncConflictOperation operation;
  final String? notice;

  @override
  Widget build(BuildContext context) {
    final payload = snapshot.payload;
    final profile = payload is ProfileSyncPayload ? payload : null;
    final plan = payload is PlanSyncPayload ? payload : null;
    final today = payload is TodaySyncPayload ? payload : null;
    final journal = payload is JournalSyncPayload ? payload : null;
    final promptConfiguration = payload is JournalPromptConfigurationSyncPayload
        ? payload
        : null;
    final health = payload is HealthSyncPayload ? payload : null;
    final awaiting = operation == SyncConflictOperation.unknownPendingPull;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (notice case final message?) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                message,
                key: const ValueKey('localSnapshotChangedNotice'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            if (awaiting)
              const Text('需要重新同步以获取服务器当前版本。')
            else ...[
              if (profile != null) ...[
                const _Line(label: '资料', value: '个人资料内容已隐藏'),
                _Line(label: '时区', value: profile.timezoneId),
              ] else if (promptConfiguration != null) ...[
                const _Line(label: '配置', value: '默认 Journal 问题'),
                _Line(
                  label: '启用问题',
                  value: promptConfiguration.prompts
                      .where((prompt) => !prompt.isDeleted && prompt.isEnabled)
                      .length
                      .toString(),
                ),
                _Line(
                  label: '问题总数',
                  value: promptConfiguration.prompts.length.toString(),
                ),
                const _Line(label: '内容', value: '问题文本已隐藏'),
              ] else if (health != null) ...[
                _Line(label: '日期', value: health.recordDate),
                _Line(
                  label: '记录类型',
                  value: _healthSourceLabel(health.dataSource),
                ),
                const _Line(label: '内容', value: '健康详情已隐藏'),
              ] else if (journal != null) ...[
                _Line(label: '日期', value: journal.entryDate),
                _Line(
                  label: '状态',
                  value: journal.status.name == 'completed' ? '已完成' : '草稿',
                ),
                _Line(
                  label: '最重要的完成',
                  value: journal.mostImportantAccomplishment ?? '-',
                ),
                _Line(label: '最消耗的事情', value: journal.mostDrainingEvent ?? '-'),
                _Line(label: '情绪来源', value: journal.emotionSource ?? '-'),
                _Line(label: '学习', value: journal.learning ?? '-'),
                _Line(label: '明日调整', value: journal.tomorrowAdjustment ?? '-'),
              ] else if (today != null) ...[
                _Line(label: '日期', value: today.recordDate),
                _Line(
                  label: '状态',
                  value: today.status.name == 'completed' ? '已完成' : '草稿',
                ),
                _Line(label: '心情', value: today.moodScore?.toString() ?? '-'),
                _Line(label: '精力', value: today.energyScore?.toString() ?? '-'),
                _Line(
                  label: '科研时间',
                  value: today.researchMinutes?.toString() ?? '-',
                ),
                _Line(
                  label: '学习时间',
                  value: today.learningMinutes?.toString() ?? '-',
                ),
              ] else ...[
                _Line(label: '标题', value: plan?.title ?? '已删除的 Plan 目标'),
                _Line(
                  label: '状态',
                  value: plan == null ? '已删除' : _goalStatus(plan.status),
                ),
                _Line(
                  label: '层级',
                  value: plan == null ? '-' : _goalLevel(plan.goalLevel),
                ),
                _Line(label: '开始日期', value: plan?.startDate ?? '-'),
                _Line(label: '目标日期', value: plan?.targetDate ?? '-'),
                _Line(label: '归档', value: plan?.archivedAt == null ? '否' : '是'),
              ],
              _Line(label: '删除', value: snapshot.deletedAt == null ? '否' : '是'),
              if (title == '云端版本')
                _Line(
                  label: '云端版本',
                  value: snapshot.serverVersion?.toString() ?? '-',
                ),
            ],
            _Line(
              label: title == '本地版本' ? '本地更新时间' : '云端更新时间',
              value: snapshot.updatedAt == null
                  ? '-'
                  : _formatTimestamp(snapshot.updatedAt!),
            ),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text('$label：$value'),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.tooltip,
    required this.label,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String tooltip;
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: FilledButton.tonalIcon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label),
        ),
      ),
    );
  }
}

String _goalStatus(PlanGoalStatus value) => switch (value) {
  PlanGoalStatus.notStarted => '未开始',
  PlanGoalStatus.inProgress => '进行中',
  PlanGoalStatus.completed => '已完成',
  PlanGoalStatus.paused => '已暂停',
  PlanGoalStatus.cancelled => '已取消',
};

String _goalLevel(PlanGoalLevel value) => switch (value) {
  PlanGoalLevel.life => '人生',
  PlanGoalLevel.year => '年度',
  PlanGoalLevel.quarter => '季度',
  PlanGoalLevel.month => '月度',
  PlanGoalLevel.week => '周',
  PlanGoalLevel.day => '日',
  PlanGoalLevel.custom => '自定义',
};

String _displayTitle(SyncConflictRecord record) {
  final local = record.localSnapshot.payload;
  if (local is ProfileSyncPayload) return 'Profile';
  if (local is PlanSyncPayload) return local.title;
  if (local is TodaySyncPayload) return '${local.recordDate} Today';
  if (local is JournalSyncPayload) return '${local.entryDate} Journal';
  if (local is JournalPromptConfigurationSyncPayload) {
    return 'Journal 问题配置';
  }
  if (local is HealthSyncPayload) return '${local.recordDate} Health';
  final remote = record.remoteSnapshot.payload;
  if (remote is ProfileSyncPayload) return 'Profile';
  if (remote is PlanSyncPayload) return remote.title;
  if (remote is TodaySyncPayload) return '${remote.recordDate} Today';
  if (remote is JournalSyncPayload) return '${remote.entryDate} Journal';
  if (remote is JournalPromptConfigurationSyncPayload) {
    return 'Journal 问题配置';
  }
  if (remote is HealthSyncPayload) return '${remote.recordDate} Health';
  if (record.entityType == SyncEntityType.today) {
    return '已删除的 Today 记录';
  }
  if (record.entityType == SyncEntityType.journal) {
    return '已删除的 Journal 记录';
  }
  if (record.entityType == SyncEntityType.journalPromptConfiguration) {
    return '已删除的 Journal 问题配置';
  }
  if (record.entityType == SyncEntityType.health) {
    return '已删除的 Health 记录';
  }
  if (record.entityType == SyncEntityType.profile) {
    return '已删除的 Profile';
  }
  return '已删除的 Plan 目标';
}

String _statusLabel(SyncConflictResolutionStatus status) => switch (status) {
  SyncConflictResolutionStatus.unresolved => '待处理',
  SyncConflictResolutionStatus.awaitingRemoteSnapshot => '等待获取云端版本',
  SyncConflictResolutionStatus.adoptRemoteRequested => '采用云端操作待继续',
  SyncConflictResolutionStatus.keepLocalRequested => '保留本地操作待继续',
  SyncConflictResolutionStatus.resolvedAdoptRemote => '已采用云端版本',
  SyncConflictResolutionStatus.resolvedKeepLocal => '已保留本地版本',
  SyncConflictResolutionStatus.superseded => '已被新冲突替代',
  SyncConflictResolutionStatus.supersededByAccountIsolationMigration =>
    '已由账号隔离迁移安全关闭',
};

String _formatTimestamp(int value) {
  final date = DateTime.fromMillisecondsSinceEpoch(value).toLocal();
  String two(int part) => part.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)} '
      '${two(date.hour)}:${two(date.minute)}';
}

String _healthSourceLabel(String value) => switch (value) {
  'manual' => '手动记录',
  'health_connect' => 'Health Connect',
  'apple_health' => 'Apple Health',
  _ => '健康记录',
};
