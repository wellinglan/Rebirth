import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'journal_controller.dart';

class JournalPage extends ConsumerWidget {
  const JournalPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journalState = ref.watch(journalControllerProvider);

    return Center(
      child: journalState.when(
        loading: () => const CircularProgressIndicator(
          key: ValueKey('journalLoadingState'),
        ),
        error: (error, stackTrace) =>
            const Text('复盘记录加载失败', key: ValueKey('journalErrorState')),
        data: (entries) => entries.isEmpty
            ? const Text('还没有复盘记录', key: ValueKey('journalEmptyState'))
            : Text(
                '最近复盘 ${entries.length} 篇',
                key: const ValueKey('journalCountState'),
              ),
      ),
    );
  }
}
