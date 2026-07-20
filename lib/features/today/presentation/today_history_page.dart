import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/today/domain/today_entry.dart';

import 'today_history_controller.dart';
import 'widgets/today_entry_detail_dialog.dart';
import 'widgets/today_history_list.dart';

class TodayHistoryPage extends ConsumerStatefulWidget {
  const TodayHistoryPage({this.targetDate, super.key});

  final String? targetDate;

  @override
  ConsumerState<TodayHistoryPage> createState() => _TodayHistoryPageState();
}

class _TodayHistoryPageState extends ConsumerState<TodayHistoryPage> {
  String? _handledTargetDate;

  @override
  void didUpdateWidget(covariant TodayHistoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetDate != widget.targetDate) {
      _handledTargetDate = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(todayHistoryControllerProvider);
    final dateTimeService = ref.watch(dateTimeServiceProvider);
    final today = dateTimeService.currentLocalDateString();
    final targetDate = widget.targetDate;
    final targetDateIsValid =
        targetDate == null || dateTimeService.isValidLocalDateString(targetDate);
    final targetEntry = targetDate != null && targetDateIsValid
        ? ref.watch(todayHistoryEntryForDateProvider(targetDate))
        : null;
    final matchedEntry = targetEntry?.asData?.value;
    if (matchedEntry != null && matchedEntry.recordDate == targetDate) {
      _scheduleTargetDialog(matchedEntry, today);
    }

    return SafeArea(
      key: const ValueKey('todayHistoryPage'),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
            child: Row(
              children: [
                IconButton(
                  key: const ValueKey('todayHistoryBackButton'),
                  onPressed: () => Navigator.of(context).maybePop(),
                  tooltip: '返回今日',
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: 4),
                Text('历史记录', style: Theme.of(context).textTheme.headlineSmall),
              ],
            ),
          ),
          const Divider(height: 1),
          if (targetDate != null)
            _TodayTargetNotice(
              targetDate: targetDate,
              isValid: targetDateIsValid,
              state: targetEntry,
            ),
          Expanded(
            child: history.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  key: ValueKey('todayHistoryLoadingState'),
                ),
              ),
              error: (error, stackTrace) => Center(
                child: Column(
                  key: const ValueKey('todayHistoryErrorState'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('历史记录暂时无法加载'),
                    const SizedBox(height: 12),
                    IconButton(
                      onPressed: () async {
                        try {
                          await ref
                              .read(todayHistoryControllerProvider.notifier)
                              .reload();
                        } catch (_) {
                          // The page keeps displaying its retryable error state.
                        }
                      },
                      tooltip: '重新加载历史记录',
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ),
              data: (entries) => entries.isEmpty
                  ? const Center(
                      child: Text(
                        '还没有历史记录',
                        key: ValueKey('todayHistoryEmptyState'),
                      ),
                    )
                  : TodayHistoryList(
                      entries: entries,
                      today: today,
                      onEntryTap: (entry) => _showDetail(context, entry, today),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDetail(
    BuildContext context,
    TodayEntry entry,
    String today,
  ) {
    return showDialog<void>(
      context: context,
      builder: (context) => TodayEntryDetailDialog(entry: entry, today: today),
    );
  }

  void _scheduleTargetDialog(TodayEntry entry, String today) {
    if (_handledTargetDate == entry.recordDate) return;
    _handledTargetDate = entry.recordDate;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showDetail(context, entry, today);
    });
  }
}

class _TodayTargetNotice extends StatelessWidget {
  const _TodayTargetNotice({
    required this.targetDate,
    required this.isValid,
    required this.state,
  });

  final String targetDate;
  final bool isValid;
  final AsyncValue<TodayEntry?>? state;

  @override
  Widget build(BuildContext context) {
    final message = !isValid
        ? '日期参数无效，无法定位 Today 记录。'
        : state?.when(
                loading: () => '正在查找 $targetDate 的 Today 记录...',
                error: (error, stackTrace) =>
                    '$targetDate 的 Today 记录暂时无法读取。',
                data: (entry) => entry?.recordDate == targetDate
                    ? '已定位 $targetDate 的 Today 记录。'
                    : '未找到 $targetDate 的 Today 记录。',
              ) ??
              '日期参数无效，无法定位 Today 记录。';
    return Container(
      key: const ValueKey('todayHistoryTargetNotice'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Text(message),
    );
  }
}
