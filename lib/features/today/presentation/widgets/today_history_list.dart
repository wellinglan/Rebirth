import 'package:flutter/material.dart';
import 'package:rebirth/features/today/domain/today_entry.dart';

import 'today_history_card.dart';

class TodayHistoryList extends StatelessWidget {
  const TodayHistoryList({
    required this.entries,
    required this.onEntryTap,
    super.key,
  });

  final List<TodayEntry> entries;
  final ValueChanged<TodayEntry> onEntryTap;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: const ValueKey('todayHistoryList'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: TodayHistoryCard(
              entry: entry,
              onTap: () => onEntryTap(entry),
            ),
          ),
        );
      },
    );
  }
}
