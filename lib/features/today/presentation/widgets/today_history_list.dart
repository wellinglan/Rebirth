import 'package:flutter/material.dart';
import 'package:rebirth/core/theme/app_layout.dart';
import 'package:rebirth/features/today/domain/today_entry.dart';

import 'today_history_card.dart';

class TodayHistoryList extends StatelessWidget {
  const TodayHistoryList({
    required this.entries,
    required this.today,
    required this.onEntryTap,
    super.key,
  });

  final List<TodayEntry> entries;
  final String today;
  final ValueChanged<TodayEntry> onEntryTap;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: const ValueKey('todayHistoryList'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.maxContentWidth,
            ),
            child: TodayHistoryCard(
              entry: entry,
              today: today,
              onTap: () => onEntryTap(entry),
            ),
          ),
        );
      },
    );
  }
}
