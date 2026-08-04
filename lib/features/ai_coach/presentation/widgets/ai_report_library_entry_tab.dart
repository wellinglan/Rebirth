import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rebirth/core/router/route_names.dart';
import 'package:rebirth/core/theme/app_layout.dart';

class AiReportLibraryEntryTab extends StatelessWidget {
  const AiReportLibraryEntryTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('aiReportLibraryEntryTab'),
      padding: AppLayout.pagePadding,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.maxContentWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('本地报告', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.sm),
                const Text('所有报告统一在 AI 报告库中管理，可查看状态、同步情况、版本历史和归档报告。'),
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  key: const ValueKey('openAiReportLibraryFromCoachButton'),
                  onPressed: () => context.push(RoutePaths.aiReports),
                  icon: const Icon(Icons.library_books_outlined),
                  label: const Text('打开 AI 报告库'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
