import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rebirth/core/router/route_names.dart';
import 'package:rebirth/core/theme/app_layout.dart';
import 'package:rebirth/features/journal/domain/journal_sync_payload.dart';
import 'package:rebirth/features/journal/domain/journal_prompt_sync_payload.dart';
import 'package:rebirth/features/health/domain/health_sync_payload.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_sync_payload.dart';
import 'package:rebirth/features/plan/domain/plan_sync_payload.dart';
import 'package:rebirth/features/profile/domain/profile_sync_payload.dart';
import 'package:rebirth/features/sync/data/sync_conflict_providers.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_record.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/today/domain/today_sync_payload.dart';

class SyncConflictListPage extends ConsumerStatefulWidget {
  const SyncConflictListPage({this.initialModuleId, super.key});

  final String? initialModuleId;

  @override
  ConsumerState<SyncConflictListPage> createState() =>
      _SyncConflictListPageState();
}

class _SyncConflictListPageState extends ConsumerState<SyncConflictListPage> {
  late SyncConflictModuleFilter _filter;

  @override
  void initState() {
    super.initState();
    _filter = SyncConflictModuleFilter.fromStableId(widget.initialModuleId);
  }

  @override
  Widget build(BuildContext context) {
    final conflicts = ref.watch(activeSyncConflictListProvider);
    return Scaffold(
      key: const ValueKey('syncConflictListPage'),
      appBar: AppBar(title: const Text('待处理问题')),
      body: SafeArea(
        child: conflicts.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
              key: ValueKey('syncConflictListLoading'),
              semanticsLabel: '正在加载同步冲突',
            ),
          ),
          error: (_, _) => _ConflictListError(
            onRetry: () => ref.invalidate(activeSyncConflictListProvider),
          ),
          data: (items) {
            final filtered = items
                .where((item) => _filter.includes(item.entityType))
                .toList(growable: false);
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    0,
                  ),
                  child: DropdownButtonFormField<SyncConflictModuleFilter>(
                    key: const ValueKey('syncConflictModuleFilter'),
                    initialValue: _filter,
                    decoration: const InputDecoration(
                      labelText: '筛选模块',
                      prefixIcon: Icon(Icons.filter_list),
                    ),
                    items: [
                      for (final value in SyncConflictModuleFilter.values)
                        DropdownMenuItem(
                          value: value,
                          child: Text(value.label),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _filter = value);
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          key: const ValueKey('syncConflictListEmpty'),
                          child: Text(items.isEmpty ? '无待处理问题' : '该模块没有待处理问题'),
                        )
                      : ListView.separated(
                          key: const ValueKey('syncConflictList'),
                          padding: AppLayout.pagePadding,
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, index) {
                            final conflict = filtered[index];
                            return Card(
                              child: ListTile(
                                key: ValueKey('syncConflict-${conflict.id}'),
                                isThreeLine: true,
                                leading: const Icon(Icons.alt_route_outlined),
                                title: Text(_displayTitle(conflict)),
                                subtitle: Text(
                                  '${_entityLabel(conflict.entityType)} · '
                                  '${_conflictType(conflict)}\n'
                                  '${_statusLabel(conflict.resolutionStatus)} · '
                                  '${_formatTimestamp(conflict.detectedAt)}',
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => context.push(
                                  RoutePaths.syncConflictDetails(conflict.id),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ConflictListError extends StatelessWidget {
  const _ConflictListError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('syncConflictListError'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('同步冲突暂时无法加载'),
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

String _displayTitle(SyncConflictRecord conflict) {
  final local = conflict.localSnapshot.payload;
  if (local is ProfileSyncPayload) return 'Profile';
  if (local is PlanSyncPayload && local.title.trim().isNotEmpty) {
    return local.title;
  }
  final remote = conflict.remoteSnapshot.payload;
  if (remote is ProfileSyncPayload) return 'Profile';
  if (remote is PlanSyncPayload && remote.title.trim().isNotEmpty) {
    return remote.title;
  }
  if (local is TodaySyncPayload) {
    return '${local.recordDate} Today';
  }
  if (remote is TodaySyncPayload) {
    return '${remote.recordDate} Today';
  }
  if (local is JournalSyncPayload) {
    return '${local.entryDate} Journal';
  }
  if (remote is JournalSyncPayload) {
    return '${remote.entryDate} Journal';
  }
  if (local is JournalPromptConfigurationSyncPayload ||
      remote is JournalPromptConfigurationSyncPayload) {
    return 'Journal 问题配置';
  }
  if (local is HealthSyncPayload) {
    return '${local.recordDate} Health';
  }
  if (remote is HealthSyncPayload) {
    return '${remote.recordDate} Health';
  }
  if (local is AiReportSyncPayload) return local.title;
  if (remote is AiReportSyncPayload) return remote.title;
  if (conflict.entityType == SyncEntityType.today) {
    return '已删除的 Today 记录';
  }
  if (conflict.entityType == SyncEntityType.profile) {
    return 'Profile';
  }
  if (conflict.entityType == SyncEntityType.journal) {
    return '已删除的 Journal 记录';
  }
  if (conflict.entityType == SyncEntityType.journalPromptConfiguration) {
    return '已删除的 Journal 问题配置';
  }
  if (conflict.entityType == SyncEntityType.health) {
    return '已删除的 Health 记录';
  }
  return '已删除的 Plan 目标';
}

String _entityLabel(SyncEntityType type) => switch (type) {
  SyncEntityType.profile => 'Profile',
  SyncEntityType.today => 'Today',
  SyncEntityType.journalPromptConfiguration => 'Journal',
  SyncEntityType.journal => 'Journal',
  SyncEntityType.plan => 'Plan',
  SyncEntityType.health => 'Health',
  SyncEntityType.aiReport => 'AI 报告',
};

enum SyncConflictModuleFilter {
  all('全部'),
  profile('Profile'),
  plan('Plan'),
  today('Today'),
  journal('Journal'),
  health('Health'),
  aiReport('AI Report');

  const SyncConflictModuleFilter(this.label);

  final String label;

  static SyncConflictModuleFilter fromStableId(String? value) {
    return switch (value) {
      'module.profile' => profile,
      'module.plan' => plan,
      'module.today' => today,
      'module.journal' => journal,
      'module.health' => health,
      'module.ai_report' => aiReport,
      _ => all,
    };
  }

  bool includes(SyncEntityType entityType) {
    return switch (this) {
      SyncConflictModuleFilter.all => true,
      SyncConflictModuleFilter.profile => entityType == SyncEntityType.profile,
      SyncConflictModuleFilter.plan => entityType == SyncEntityType.plan,
      SyncConflictModuleFilter.today => entityType == SyncEntityType.today,
      SyncConflictModuleFilter.journal =>
        entityType == SyncEntityType.journal ||
            entityType == SyncEntityType.journalPromptConfiguration,
      SyncConflictModuleFilter.health => entityType == SyncEntityType.health,
      SyncConflictModuleFilter.aiReport =>
        entityType == SyncEntityType.aiReport,
    };
  }
}

String _conflictType(SyncConflictRecord conflict) {
  final localDeleted = conflict.localSnapshot.deletedAt != null;
  return switch ((localDeleted, conflict.remoteOperation)) {
    (_, SyncConflictOperation.unknownPendingPull) => '等待获取云端版本',
    (false, SyncConflictOperation.upsert) => '双端修改',
    (false, SyncConflictOperation.delete) => '本地修改 / 云端删除',
    (true, SyncConflictOperation.upsert) => '本地删除 / 云端修改',
    (true, SyncConflictOperation.delete) => '双端删除',
  };
}

String _statusLabel(SyncConflictResolutionStatus status) {
  return switch (status) {
    SyncConflictResolutionStatus.unresolved => '待处理',
    SyncConflictResolutionStatus.awaitingRemoteSnapshot => '等待云端版本',
    SyncConflictResolutionStatus.adoptRemoteRequested => '采用云端处理中',
    SyncConflictResolutionStatus.keepLocalRequested => '保留本地处理中',
    SyncConflictResolutionStatus.resolvedAdoptRemote => '已采用云端',
    SyncConflictResolutionStatus.resolvedKeepLocal => '已保留本地',
    SyncConflictResolutionStatus.superseded => '已被新冲突替代',
    SyncConflictResolutionStatus.supersededByAccountIsolationMigration =>
      '已由账号隔离迁移关闭',
  };
}

String _formatTimestamp(int value) {
  final date = DateTime.fromMillisecondsSinceEpoch(value).toLocal();
  String two(int part) => part.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)} '
      '${two(date.hour)}:${two(date.minute)}';
}
