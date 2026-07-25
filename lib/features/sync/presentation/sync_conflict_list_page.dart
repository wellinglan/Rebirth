import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rebirth/core/router/route_names.dart';
import 'package:rebirth/core/theme/app_layout.dart';
import 'package:rebirth/features/plan/domain/plan_sync_payload.dart';
import 'package:rebirth/features/sync/data/sync_conflict_providers.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_record.dart';

class SyncConflictListPage extends ConsumerWidget {
  const SyncConflictListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conflicts = ref.watch(activeSyncConflictListProvider);
    return Scaffold(
      key: const ValueKey('syncConflictListPage'),
      appBar: AppBar(title: const Text('同步冲突')),
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
            if (items.isEmpty) {
              return const Center(
                key: ValueKey('syncConflictListEmpty'),
                child: Text('无待处理冲突'),
              );
            }
            return ListView.separated(
              key: const ValueKey('syncConflictList'),
              padding: AppLayout.pagePadding,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final conflict = items[index];
                return Card(
                  child: ListTile(
                    key: ValueKey('syncConflict-${conflict.id}'),
                    isThreeLine: true,
                    leading: const Icon(Icons.alt_route_outlined),
                    title: Text(_displayTitle(conflict)),
                    subtitle: Text(
                      'Plan · ${_conflictType(conflict)}\n'
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
  if (local is PlanSyncPayload && local.title.trim().isNotEmpty) {
    return local.title;
  }
  final remote = conflict.remoteSnapshot.payload;
  if (remote is PlanSyncPayload && remote.title.trim().isNotEmpty) {
    return remote.title;
  }
  return '已删除的 Plan 目标';
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
  };
}

String _formatTimestamp(int value) {
  final date = DateTime.fromMillisecondsSinceEpoch(value).toLocal();
  String two(int part) => part.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)} '
      '${two(date.hour)}:${two(date.minute)}';
}
