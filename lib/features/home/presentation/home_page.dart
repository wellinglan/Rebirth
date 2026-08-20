import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/experience/local_daily_quote.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/app_layout.dart';
import '../../../core/utils/date_time_service.dart';
import '../../../core/utils/date_time_service_provider.dart';
import '../../today/domain/today_entry.dart';
import '../domain/home_overview.dart';
import 'home_controller.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  Timer? _timer;
  late DateTimeSnapshot _snapshot;

  @override
  void initState() {
    super.initState();
    _snapshot = ref.read(dateTimeServiceProvider).currentSnapshot();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      final next = ref.read(dateTimeServiceProvider).currentSnapshot();
      final dateChanged = next.localDateString != _snapshot.localDateString;
      setState(() => _snapshot = next);
      if (dateChanged) ref.invalidate(homeOverviewProvider);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final overview = ref.watch(homeOverviewProvider);
    return Scaffold(
      key: const ValueKey('productionHomePage'),
      appBar: AppBar(
        title: const Text('Rebirth'),
        actions: [
          IconButton(
            tooltip: '设置',
            onPressed: () => context.push(RoutePaths.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.refresh(homeOverviewProvider.future),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: AppLayout.pagePadding,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HomeHero(snapshot: _snapshot),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      '这一周',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _WeekCalendar(now: _snapshot.now.toLocal()),
                    const SizedBox(height: AppSpacing.xl),
                    overview.when(
                      loading: () => const _OverviewLoading(),
                      error: (_, _) => _OverviewError(
                        onRetry: () => ref.invalidate(homeOverviewProvider),
                      ),
                      data: (data) => _OverviewBody(data: data),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      '继续前往',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const _ModuleGrid(),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeHero extends StatelessWidget {
  const _HomeHero({required this.snapshot});

  final DateTimeSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final now = snapshot.now.toLocal();
    final night = now.hour < 6 || now.hour >= 18;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return Semantics(
      image: true,
      label: night ? '安静的夜晚窗边环境图' : '明亮的日间窗边山景环境图',
      child: SizedBox(
        height: textScale >= 1.8
            ? 800
            : textScale >= 1.3
            ? 460
            : 340,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              night
                  ? 'assets/images/experience_preview/home_night.webp'
                  : 'assets/images/experience_preview/home_day.webp',
              fit: BoxFit.cover,
            ),
            const ColoredBox(color: Color(0x66000000)),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 540),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${now.year}年${now.month}月${now.day}日 · 星期${_weekday(now.weekday)}',
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${_two(now.hour)}:${_two(now.minute)}',
                        style: Theme.of(context).textTheme.displayMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        localDailyQuote(snapshot.localDateString),
                        style: Theme.of(
                          context,
                        ).textTheme.titleLarge?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        '本地固定寄语 · 不调用 AI',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewBody extends StatelessWidget {
  const _OverviewBody({required this.data});
  final HomeOverview data;

  @override
  Widget build(BuildContext context) {
    final today = data.today;
    final health = data.health;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (data.hasPartialFailure)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              data.hasData ? '部分摘要暂时无法读取，其余内容仍可使用。' : '今日摘要暂时无法读取。',
              key: const ValueKey('homePartialFailure'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Text('今天想照顾的事', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        _PrioritySummary(entry: today),
        const SizedBox(height: AppSpacing.xl),
        Text('轻量概览', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _SummaryPill(
              icon: Icons.sentiment_satisfied_alt_outlined,
              label: '心情',
              value: _score(today?.moodScore),
            ),
            _SummaryPill(
              icon: Icons.bolt_outlined,
              label: '精力',
              value: _score(today?.energyScore),
            ),
            _SummaryPill(
              icon: Icons.bedtime_outlined,
              label: '睡眠',
              value: _minutes(health?.sleepDurationMinutes),
            ),
            _SummaryPill(
              icon: Icons.water_drop_outlined,
              label: '饮水',
              value: health?.waterIntakeMl == null
                  ? '未记录'
                  : '${health!.waterIntakeMl} ml',
            ),
            _SummaryPill(
              icon: Icons.directions_walk_outlined,
              label: '运动',
              value: _minutes(health?.exerciseDurationMinutes),
            ),
          ],
        ),
      ],
    );
  }

  static String _score(int? value) => value == null ? '未记录' : '$value / 10';
  static String _minutes(int? value) {
    if (value == null) return '未记录';
    final hours = value ~/ 60;
    final minutes = value % 60;
    if (hours == 0) return '$minutes 分钟';
    if (minutes == 0) return '$hours 小时';
    return '$hours 小时 $minutes 分';
  }
}

class _PrioritySummary extends StatelessWidget {
  const _PrioritySummary({required this.entry});
  final TodayEntry? entry;

  @override
  Widget build(BuildContext context) {
    final priorities =
        entry?.priorities.where((item) => item.isPopulated).toList() ??
        const <TodayPriority>[];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: priorities.isEmpty
            ? const Text('今天还没有写下三件事。')
            : Column(
                children: [
                  for (final item in priorities)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item.completed
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            size: 22,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(child: Text(item.text!)),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _WeekCalendar extends StatelessWidget {
  const _WeekCalendar({required this.now});
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final today = DateTime(now.year, now.month, now.day);
    final monday = DateTime(now.year, now.month, now.day - now.weekday + 1);
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisExtent: 76,
        crossAxisSpacing: 4,
      ),
      itemCount: 7,
      itemBuilder: (context, index) {
        final date = DateTime(monday.year, monday.month, monday.day + index);
        final selected = date == today;
        return Semantics(
          label: '${date.month}月${date.day}日，星期${labels[index]}',
          selected: selected,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [Text(labels[index]), Text('${date.day}')],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(AppRadius.sm),
    ),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon),
          const SizedBox(width: AppSpacing.xs),
          Flexible(child: Text('$label · $value')),
        ],
      ),
    ),
  );
}

class _ModuleGrid extends StatelessWidget {
  const _ModuleGrid();

  @override
  Widget build(BuildContext context) {
    const modules =
        <({String title, String subtitle, IconData icon, String path})>[
          (
            title: 'Today',
            subtitle: '开始今天',
            icon: Icons.today_outlined,
            path: RoutePaths.today,
          ),
          (
            title: 'Journal',
            subtitle: '写下反思',
            icon: Icons.menu_book_outlined,
            path: RoutePaths.journal,
          ),
          (
            title: 'Plan',
            subtitle: '整理目标',
            icon: Icons.account_tree_outlined,
            path: RoutePaths.plan,
          ),
          (
            title: 'Health',
            subtitle: '照顾身体',
            icon: Icons.favorite_outline,
            path: RoutePaths.health,
          ),
          (
            title: 'Growth',
            subtitle: '看看变化',
            icon: Icons.insights_outlined,
            path: RoutePaths.growth,
          ),
          (
            title: 'AI Coach',
            subtitle: '获得陪伴',
            icon: Icons.auto_awesome_outlined,
            path: RoutePaths.aiCoach,
          ),
        ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 3
            : constraints.maxWidth >= 560
            ? 2
            : 1;
        final width =
            (constraints.maxWidth - (columns - 1) * AppSpacing.sm) / columns;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final module in modules)
              SizedBox(
                width: width,
                child: Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    minVerticalPadding: AppSpacing.md,
                    leading: Icon(module.icon),
                    title: Text(module.title),
                    subtitle: Text(module.subtitle),
                    trailing: const Icon(Icons.arrow_forward),
                    onTap: () => context.go(module.path),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _OverviewLoading extends StatelessWidget {
  const _OverviewLoading();
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: CircularProgressIndicator(),
    ),
  );
}

class _OverviewError extends StatelessWidget {
  const _OverviewError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Text('今日摘要暂时无法读取。'),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('重试'),
      ),
    ],
  );
}

String _two(int value) => value.toString().padLeft(2, '0');
String _weekday(int value) =>
    const ['一', '二', '三', '四', '五', '六', '日'][value - 1];
