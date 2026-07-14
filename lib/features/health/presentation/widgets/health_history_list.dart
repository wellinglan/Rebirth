import 'package:flutter/material.dart';
import 'package:rebirth/features/health/domain/health_entry.dart';

import 'health_entry_detail_dialog.dart';
import 'health_history_card.dart';

class HealthHistoryList extends StatelessWidget {
  const HealthHistoryList({required this.entries, super.key});

  final List<HealthEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text('还没有健康记录', key: ValueKey('healthHistoryEmpty')),
        ),
      );
    }

    return Column(
      children: [
        for (final entry in entries)
          HealthHistoryCard(
            entry: entry,
            onTap: () => showDialog<void>(
              context: context,
              builder: (context) => HealthEntryDetailDialog(entry: entry),
            ),
          ),
      ],
    );
  }
}
