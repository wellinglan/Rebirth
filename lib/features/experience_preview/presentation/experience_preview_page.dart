import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/app_layout.dart';
import '../../../core/utils/date_time_service.dart';
import '../../../core/utils/date_time_service_provider.dart';
import 'widgets/quick_increment_control.dart';
import 'widgets/water_cup_indicator.dart';
import 'widgets/wellbeing_rating_field.dart';

enum ExperiencePreviewView { home, today, health }

class ExperiencePreviewPage extends ConsumerStatefulWidget {
  const ExperiencePreviewPage({super.key});

  @override
  ConsumerState<ExperiencePreviewPage> createState() =>
      _ExperiencePreviewPageState();
}

class _ExperiencePreviewPageState extends ConsumerState<ExperiencePreviewPage> {
  ExperiencePreviewView _view = ExperiencePreviewView.home;
  DateTimeSnapshot? _snapshot;
  Timer? _clockTimer;
  int? _waterIntakeMl;
  int _waterStep = 250;
  int? _researchMinutes;
  int? _learningMinutes;
  int? _exerciseMinutes;
  int? _sleepMinutes;
  int? _moodScore;
  int? _energyScore;
  int? _physicalStateScore;
  String _moodDescription = '';
  String _energyDescription = '';
  String _physicalStateDescription = '';

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) _refreshClock();
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot =
        _snapshot ?? ref.watch(dateTimeServiceProvider).currentSnapshot();
    _snapshot ??= snapshot;
    return Scaffold(
      key: const ValueKey('experiencePreviewPage'),
      appBar: AppBar(
        title: const Text('体验原型'),
        actions: [
          IconButton(
            tooltip: '返回开发者选项',
            onPressed: () => context.pop(),
            icon: const Icon(Icons.science_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final padding = AppLayout.pagePaddingFor(constraints.maxWidth);
            return SingleChildScrollView(
              key: const ValueKey('experiencePreviewScrollView'),
              padding: padding,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _PrototypeNotice(onReset: _resetPrototype),
                      const SizedBox(height: AppSpacing.md),
                      _PreviewViewSelector(
                        value: _view,
                        onChanged: (value) => setState(() => _view = value),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      switch (_view) {
                        ExperiencePreviewView.home => _HomePreview(
                          snapshot: snapshot,
                          onOpenPreview: (view) => setState(() => _view = view),
                          onOpenRoute: (path) => context.push(path),
                        ),
                        ExperiencePreviewView.today => _TodayPreview(
                          moodScore: _moodScore,
                          energyScore: _energyScore,
                          moodDescription: _moodDescription,
                          energyDescription: _energyDescription,
                          researchMinutes: _researchMinutes,
                          learningMinutes: _learningMinutes,
                          onMoodScoreChanged: (value) =>
                              setState(() => _moodScore = value),
                          onEnergyScoreChanged: (value) =>
                              setState(() => _energyScore = value),
                          onMoodDescriptionChanged: (value) =>
                              setState(() => _moodDescription = value),
                          onEnergyDescriptionChanged: (value) =>
                              setState(() => _energyDescription = value),
                          onResearchChanged: (value) =>
                              setState(() => _researchMinutes = value),
                          onLearningChanged: (value) =>
                              setState(() => _learningMinutes = value),
                          onPrototypeSave: _showPrototypeSaveMessage,
                        ),
                        ExperiencePreviewView.health => _HealthPreview(
                          waterIntakeMl: _waterIntakeMl,
                          waterStep: _waterStep,
                          exerciseMinutes: _exerciseMinutes,
                          sleepMinutes: _sleepMinutes,
                          physicalStateScore: _physicalStateScore,
                          physicalStateDescription: _physicalStateDescription,
                          onWaterChanged: (value) =>
                              setState(() => _waterIntakeMl = value),
                          onWaterStepChanged: (value) =>
                              setState(() => _waterStep = value),
                          onExerciseChanged: (value) =>
                              setState(() => _exerciseMinutes = value),
                          onSleepChanged: (value) =>
                              setState(() => _sleepMinutes = value),
                          onPhysicalStateScoreChanged: (value) =>
                              setState(() => _physicalStateScore = value),
                          onPhysicalStateDescriptionChanged: (value) =>
                              setState(() => _physicalStateDescription = value),
                          onPrototypeSave: _showPrototypeSaveMessage,
                        ),
                      },
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _refreshClock() {
    setState(() {
      _snapshot = ref.read(dateTimeServiceProvider).currentSnapshot();
    });
  }

  void _resetPrototype() {
    setState(() {
      _waterIntakeMl = null;
      _waterStep = 250;
      _researchMinutes = null;
      _learningMinutes = null;
      _exerciseMinutes = null;
      _sleepMinutes = null;
      _moodScore = null;
      _energyScore = null;
      _physicalStateScore = null;
      _moodDescription = '';
      _energyDescription = '';
      _physicalStateDescription = '';
    });
  }

  void _showPrototypeSaveMessage() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('原型数据未写入本地记录')));
  }
}

class _PrototypeNotice extends StatelessWidget {
  const _PrototypeNotice({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.science_outlined),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(child: Text('体验原型仅使用内存状态，不写数据库、不调用 AI、不保存或同步。')),
            IconButton(
              tooltip: '重置原型数据',
              onPressed: onReset,
              icon: const Icon(Icons.restart_alt),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewViewSelector extends StatelessWidget {
  const _PreviewViewSelector({required this.value, required this.onChanged});

  final ExperiencePreviewView value;
  final ValueChanged<ExperiencePreviewView> onChanged;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    if (width < 420 || textScale >= 1.5) {
      return DropdownButtonFormField<ExperiencePreviewView>(
        key: const ValueKey('experiencePreviewDropdown'),
        initialValue: value,
        decoration: const InputDecoration(
          labelText: '原型视图',
          prefixIcon: Icon(Icons.preview_outlined),
        ),
        items: const [
          DropdownMenuItem(
            value: ExperiencePreviewView.home,
            child: Text('主页'),
          ),
          DropdownMenuItem(
            value: ExperiencePreviewView.today,
            child: Text('今日'),
          ),
          DropdownMenuItem(
            value: ExperiencePreviewView.health,
            child: Text('健康'),
          ),
        ],
        onChanged: (next) {
          if (next != null) onChanged(next);
        },
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: SegmentedButton<ExperiencePreviewView>(
        key: const ValueKey('experiencePreviewSwitcher'),
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: ExperiencePreviewView.home,
            icon: Icon(Icons.home_outlined),
            label: Text('主页'),
          ),
          ButtonSegment(
            value: ExperiencePreviewView.today,
            icon: Icon(Icons.today_outlined),
            label: Text('今日'),
          ),
          ButtonSegment(
            value: ExperiencePreviewView.health,
            icon: Icon(Icons.favorite_outline),
            label: Text('健康'),
          ),
        ],
        selected: {value},
        onSelectionChanged: (selection) => onChanged(selection.single),
      ),
    );
  }
}

class _HomePreview extends StatelessWidget {
  const _HomePreview({
    required this.snapshot,
    required this.onOpenPreview,
    required this.onOpenRoute,
  });

  final DateTimeSnapshot snapshot;
  final ValueChanged<ExperiencePreviewView> onOpenPreview;
  final ValueChanged<String> onOpenRoute;

  @override
  Widget build(BuildContext context) {
    final now = snapshot.now.toLocal();
    final isNight = now.hour < 6 || now.hour >= 18;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final heroHeight = textScale >= 1.8 ? 540.0 : 340.0;
    final dateStyle = textScale >= 1.8
        ? Theme.of(context).textTheme.bodyMedium
        : Theme.of(context).textTheme.titleMedium;
    final clockStyle = textScale >= 1.8
        ? Theme.of(context).textTheme.headlineMedium
        : Theme.of(context).textTheme.displayMedium;
    final quoteStyle = textScale >= 1.8
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.titleLarge;
    return Column(
      key: const ValueKey('homeExperiencePreview'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          image: true,
          label: isNight ? '安静的夜晚窗边环境图' : '明亮的日间窗边山景环境图',
          child: SizedBox(
            height: heroHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  isNight
                      ? 'assets/images/experience_preview/home_night.webp'
                      : 'assets/images/experience_preview/home_day.webp',
                  key: ValueKey(isNight ? 'homeNightAsset' : 'homeDayAsset'),
                  fit: BoxFit.cover,
                  alignment: isNight
                      ? Alignment.centerRight
                      : Alignment.centerRight,
                ),
                const ColoredBox(color: Color(0x66000000)),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatChineseDate(now),
                            key: const ValueKey('homePreviewDate'),
                            style: dateStyle?.copyWith(color: Colors.white),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            _formatClock(now),
                            key: const ValueKey('homePreviewClock'),
                            style: clockStyle?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            experienceQuoteFor(now),
                            key: const ValueKey('homePreviewQuote'),
                            style: quoteStyle?.copyWith(color: Colors.white),
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
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('这一周', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        _WeekCalendar(now: now),
        const SizedBox(height: AppSpacing.xl),
        Text('今天想照顾的事', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        const _PrioritySummary(),
        const SizedBox(height: AppSpacing.xl),
        Text('轻量概览', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        const _HealthSummary(),
        const SizedBox(height: AppSpacing.xl),
        Text('继续前往', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        _ModuleGrid(onOpenPreview: onOpenPreview, onOpenRoute: onOpenRoute),
      ],
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
    const weekLabels = ['一', '二', '三', '四', '五', '六', '日'];
    return GridView.builder(
      key: const ValueKey('homePreviewWeekCalendar'),
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
          label: '${date.month}月${date.day}日，星期${weekLabels[index]}',
          selected: selected,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [Text(weekLabels[index]), Text('${date.day}')],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PrioritySummary extends StatelessWidget {
  const _PrioritySummary();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            _SummaryLine(
              icon: Icons.radio_button_unchecked,
              text: '完成最重要的一段专注工作',
            ),
            _SummaryLine(icon: Icons.check_circle_outline, text: '给身体留一点活动时间'),
            _SummaryLine(icon: Icons.radio_button_unchecked, text: '晚上写下今天的收获'),
          ],
        ),
      ),
    );
  }
}

class _HealthSummary extends StatelessWidget {
  const _HealthSummary();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: const [
        _SummaryPill(icon: Icons.bedtime_outlined, label: '睡眠', value: '未记录'),
        _SummaryPill(
          icon: Icons.water_drop_outlined,
          label: '饮水',
          value: '未记录',
        ),
        _SummaryPill(
          icon: Icons.directions_walk_outlined,
          label: '运动',
          value: '未记录',
        ),
      ],
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text)),
        ],
      ),
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
  Widget build(BuildContext context) {
    return DecoratedBox(
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
            Text('$label · $value'),
          ],
        ),
      ),
    );
  }
}

class _ModuleGrid extends StatelessWidget {
  const _ModuleGrid({required this.onOpenPreview, required this.onOpenRoute});

  final ValueChanged<ExperiencePreviewView> onOpenPreview;
  final ValueChanged<String> onOpenRoute;

  @override
  Widget build(BuildContext context) {
    final modules =
        <({String title, String subtitle, IconData icon, VoidCallback open})>[
          (
            title: 'Today',
            subtitle: '开始今天',
            icon: Icons.today_outlined,
            open: () => onOpenPreview(ExperiencePreviewView.today),
          ),
          (
            title: 'Journal',
            subtitle: '写下反思',
            icon: Icons.menu_book_outlined,
            open: () => onOpenRoute(RoutePaths.journal),
          ),
          (
            title: 'Plan',
            subtitle: '整理目标',
            icon: Icons.account_tree_outlined,
            open: () => onOpenRoute(RoutePaths.plan),
          ),
          (
            title: 'Health',
            subtitle: '照顾身体',
            icon: Icons.favorite_outline,
            open: () => onOpenPreview(ExperiencePreviewView.health),
          ),
          (
            title: 'Growth',
            subtitle: '看看变化',
            icon: Icons.insights_outlined,
            open: () => onOpenRoute(RoutePaths.growth),
          ),
          (
            title: 'AI Coach',
            subtitle: '获得陪伴',
            icon: Icons.auto_awesome_outlined,
            open: () => onOpenRoute(RoutePaths.aiCoach),
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
                    onTap: module.open,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TodayPreview extends StatelessWidget {
  const _TodayPreview({
    required this.moodScore,
    required this.energyScore,
    required this.moodDescription,
    required this.energyDescription,
    required this.researchMinutes,
    required this.learningMinutes,
    required this.onMoodScoreChanged,
    required this.onEnergyScoreChanged,
    required this.onMoodDescriptionChanged,
    required this.onEnergyDescriptionChanged,
    required this.onResearchChanged,
    required this.onLearningChanged,
    required this.onPrototypeSave,
  });

  final int? moodScore;
  final int? energyScore;
  final String moodDescription;
  final String energyDescription;
  final int? researchMinutes;
  final int? learningMinutes;
  final ValueChanged<int?> onMoodScoreChanged;
  final ValueChanged<int?> onEnergyScoreChanged;
  final ValueChanged<String> onMoodDescriptionChanged;
  final ValueChanged<String> onEnergyDescriptionChanged;
  final ValueChanged<int?> onResearchChanged;
  final ValueChanged<int?> onLearningChanged;
  final VoidCallback onPrototypeSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('todayExperiencePreview'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('今日', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.xs),
        const Text('快捷预设在需要时出现，页面默认只保留当前选择与精确值。'),
        const SizedBox(height: AppSpacing.lg),
        Text('今天的三件事', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        for (var index = 1; index <= 3; index++) ...[
          TextField(
            key: ValueKey('prototypePriority$index'),
            decoration: InputDecoration(
              labelText: '第 $index 件事',
              prefixIcon: const Icon(Icons.radio_button_unchecked),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        const SizedBox(height: AppSpacing.sm),
        _WellbeingScoreArea(
          moodScore: moodScore,
          energyScore: energyScore,
          moodDescription: moodDescription,
          energyDescription: energyDescription,
          onMoodScoreChanged: onMoodScoreChanged,
          onEnergyScoreChanged: onEnergyScoreChanged,
          onMoodDescriptionChanged: onMoodDescriptionChanged,
          onEnergyDescriptionChanged: onEnergyDescriptionChanged,
        ),
        const SizedBox(height: AppSpacing.xl),
        _PrototypeDurationSection(
          label: '研究',
          icon: Icons.science_outlined,
          value: researchMinutes,
          onChanged: onResearchChanged,
        ),
        const SizedBox(height: AppSpacing.lg),
        _PrototypeDurationSection(
          label: '学习',
          icon: Icons.school_outlined,
          value: learningMinutes,
          onChanged: onLearningChanged,
        ),
        const SizedBox(height: AppSpacing.lg),
        const TextField(
          key: ValueKey('prototypeDailyNote'),
          minLines: 3,
          maxLines: 5,
          decoration: InputDecoration(labelText: '随手记'),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          key: const ValueKey('prototypeTodaySave'),
          onPressed: onPrototypeSave,
          icon: const Icon(Icons.save_outlined),
          label: const Text('模拟保存'),
        ),
      ],
    );
  }
}

class _WellbeingScoreArea extends StatelessWidget {
  const _WellbeingScoreArea({
    required this.moodScore,
    required this.energyScore,
    required this.moodDescription,
    required this.energyDescription,
    required this.onMoodScoreChanged,
    required this.onEnergyScoreChanged,
    required this.onMoodDescriptionChanged,
    required this.onEnergyDescriptionChanged,
  });

  final int? moodScore;
  final int? energyScore;
  final String moodDescription;
  final String energyDescription;
  final ValueChanged<int?> onMoodScoreChanged;
  final ValueChanged<int?> onEnergyScoreChanged;
  final ValueChanged<String> onMoodDescriptionChanged;
  final ValueChanged<String> onEnergyDescriptionChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fields = [
          WellbeingRatingField(
            key: const ValueKey('prototypeMoodRating'),
            label: '心情',
            icon: Icons.sentiment_satisfied_alt_outlined,
            value: moodScore,
            description: moodDescription,
            descriptionHint: '例如：今天心里比较轻松',
            onScoreChanged: onMoodScoreChanged,
            onDescriptionChanged: onMoodDescriptionChanged,
          ),
          WellbeingRatingField(
            key: const ValueKey('prototypeEnergyRating'),
            label: '精力',
            icon: Icons.bolt_outlined,
            value: energyScore,
            description: energyDescription,
            descriptionHint: '例如：午后有些疲惫',
            onScoreChanged: onEnergyScoreChanged,
            onDescriptionChanged: onEnergyDescriptionChanged,
          ),
        ];
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        if (constraints.maxWidth >= 840 && textScale < 1.5) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: fields.first),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: fields.last),
            ],
          );
        }
        return Column(
          children: [
            fields.first,
            const SizedBox(height: AppSpacing.md),
            fields.last,
          ],
        );
      },
    );
  }
}

class _PrototypeDurationSection extends StatelessWidget {
  const _PrototypeDurationSection({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    icon,
                    key: ValueKey('${label}Icon'),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    '$label时间',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _PresetMenuButton(
                  label: '$label时间预设',
                  values: const [15, 30, 45, 60, 90, 120],
                  unit: '分钟',
                  onSelected: onChanged,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            QuickIncrementControl(
              value: value,
              stepOptions: const [15, 30, 60],
              selectedStep: 15,
              unit: '分钟',
              minimumValue: 0,
              label: '$label时间',
              valueFormatter: formatDurationMinutes,
              onChanged: onChanged,
            ),
            const SizedBox(height: AppSpacing.md),
            _ExactIntegerInput(
              label: '$label精确分钟',
              value: value,
              unit: '分钟',
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthPreview extends StatelessWidget {
  const _HealthPreview({
    required this.waterIntakeMl,
    required this.waterStep,
    required this.exerciseMinutes,
    required this.sleepMinutes,
    required this.physicalStateScore,
    required this.physicalStateDescription,
    required this.onWaterChanged,
    required this.onWaterStepChanged,
    required this.onExerciseChanged,
    required this.onSleepChanged,
    required this.onPhysicalStateScoreChanged,
    required this.onPhysicalStateDescriptionChanged,
    required this.onPrototypeSave,
  });

  final int? waterIntakeMl;
  final int waterStep;
  final int? exerciseMinutes;
  final int? sleepMinutes;
  final int? physicalStateScore;
  final String physicalStateDescription;
  final ValueChanged<int?> onWaterChanged;
  final ValueChanged<int> onWaterStepChanged;
  final ValueChanged<int?> onExerciseChanged;
  final ValueChanged<int?> onSleepChanged;
  final ValueChanged<int?> onPhysicalStateScoreChanged;
  final ValueChanged<String> onPhysicalStateDescriptionChanged;
  final VoidCallback onPrototypeSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('healthExperiencePreview'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('健康', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.xs),
        const Text('用直观模型反馈记录变化，不给出医疗判断。'),
        const SizedBox(height: AppSpacing.lg),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                const _SectionHeading(
                  label: '饮水',
                  icon: Icons.water_drop_outlined,
                ),
                const SizedBox(height: AppSpacing.md),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cup = WaterCupIndicator(waterIntakeMl: waterIntakeMl);
                    final control = QuickIncrementControl(
                      value: waterIntakeMl,
                      stepOptions: const [100, 250, 500],
                      selectedStep: waterStep,
                      unit: 'ml',
                      minimumValue: 0,
                      label: '饮水量',
                      onChanged: onWaterChanged,
                      onStepChanged: onWaterStepChanged,
                    );
                    if (constraints.maxWidth < 620) {
                      return Column(
                        children: [
                          cup,
                          const SizedBox(height: AppSpacing.lg),
                          control,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        cup,
                        const SizedBox(width: AppSpacing.xl),
                        Expanded(child: control),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                _ExactIntegerInput(
                  label: '饮水精确数值',
                  value: waterIntakeMl,
                  unit: 'ml',
                  onChanged: onWaterChanged,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        _PrototypeDurationSection(
          label: '运动',
          icon: Icons.directions_run_outlined,
          value: exerciseMinutes,
          onChanged: onExerciseChanged,
        ),
        const SizedBox(height: AppSpacing.lg),
        _PrototypeDurationSection(
          label: '睡眠',
          icon: Icons.bedtime_outlined,
          value: sleepMinutes,
          onChanged: onSleepChanged,
        ),
        const SizedBox(height: AppSpacing.lg),
        WellbeingRatingField(
          key: const ValueKey('prototypePhysicalStateRating'),
          label: '身体感受',
          icon: Icons.self_improvement_outlined,
          value: physicalStateScore,
          description: physicalStateDescription,
          descriptionHint: '例如：肩颈略紧，其他感觉平稳',
          onScoreChanged: onPhysicalStateScoreChanged,
          onDescriptionChanged: onPhysicalStateDescriptionChanged,
        ),
        const SizedBox(height: AppSpacing.lg),
        const _PrototypeNumberField(
          label: '体重',
          unit: 'kg',
          icon: Icons.monitor_weight_outlined,
        ),
        const SizedBox(height: AppSpacing.md),
        const TextField(
          key: ValueKey('prototypeHealthNote'),
          minLines: 3,
          maxLines: 5,
          decoration: InputDecoration(labelText: '健康备注'),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          key: const ValueKey('prototypeHealthSave'),
          onPressed: onPrototypeSave,
          icon: const Icon(Icons.save_outlined),
          label: const Text('模拟保存'),
        ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ExcludeSemantics(
          child: Icon(
            icon,
            key: ValueKey('${label}Icon'),
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _ExactIntegerInput extends StatefulWidget {
  const _ExactIntegerInput({
    required this.label,
    required this.value,
    required this.unit,
    required this.onChanged,
  });

  final String label;
  final int? value;
  final String unit;
  final ValueChanged<int?> onChanged;

  @override
  State<_ExactIntegerInput> createState() => _ExactIntegerInputState();
}

class _ExactIntegerInputState extends State<_ExactIntegerInput> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value?.toString() ?? '');
  }

  @override
  void didUpdateWidget(covariant _ExactIntegerInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      final next = widget.value?.toString() ?? '';
      if (_controller.text != next) {
        _controller.value = TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: next.length),
        );
      }
      _error = null;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: ValueKey('${widget.label}Field'),
      controller: _controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: widget.label,
        suffixText: widget.unit,
        errorText: _error,
        helperText: '非负整数；留空表示未记录',
      ),
      onChanged: (raw) {
        final text = raw.trim();
        if (text.isEmpty) {
          setState(() => _error = null);
          widget.onChanged(null);
          return;
        }
        final parsed = int.tryParse(text);
        if (parsed == null || parsed < 0) {
          setState(() => _error = '请输入非负整数');
          return;
        }
        setState(() => _error = null);
        widget.onChanged(parsed);
      },
    );
  }
}

class _PrototypeNumberField extends StatefulWidget {
  const _PrototypeNumberField({
    required this.label,
    required this.unit,
    required this.icon,
  });

  final String label;
  final String unit;
  final IconData icon;

  @override
  State<_PrototypeNumberField> createState() => _PrototypeNumberFieldState();
}

class _PrototypeNumberFieldState extends State<_PrototypeNumberField> {
  String? _error;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: ValueKey('prototype${widget.label}'),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: Icon(widget.icon, key: ValueKey('${widget.label}Icon')),
        suffixText: widget.unit,
        errorText: _error,
        helperText: '非负数或空；仅保留在原型内存中',
      ),
      onChanged: (raw) {
        final text = raw.trim();
        final parsed = double.tryParse(text);
        setState(() {
          _error = text.isEmpty || (parsed != null && parsed >= 0)
              ? null
              : '请输入非负数';
        });
      },
    );
  }
}

class _PresetMenuButton extends StatelessWidget {
  const _PresetMenuButton({
    required this.label,
    required this.values,
    required this.unit,
    required this.onSelected,
  });

  final String label;
  final List<int> values;
  final String unit;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: ValueKey('${label}Button'),
      onPressed: () => _show(context),
      icon: const Icon(Icons.tune),
      label: const Text('选择预设'),
    );
  }

  Future<void> _show(BuildContext context) async {
    final compact =
        MediaQuery.sizeOf(context).width < AppLayout.navigationRailBreakpoint;
    final selected = compact
        ? await showModalBottomSheet<int>(
            context: context,
            showDragHandle: true,
            builder: (context) => SafeArea(
              child: ListView(
                key: ValueKey('${label}BottomSheet'),
                shrinkWrap: true,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  for (final value in values)
                    ListTile(
                      title: Text(_presetLabel(value, unit)),
                      onTap: () => Navigator.of(context).pop(value),
                    ),
                ],
              ),
            ),
          )
        : await showMenu<int>(
            context: context,
            position: const RelativeRect.fromLTRB(260, 180, 24, 24),
            items: [
              for (final value in values)
                PopupMenuItem(
                  value: value,
                  child: Text(_presetLabel(value, unit)),
                ),
            ],
          );
    if (selected != null) onSelected(selected);
  }
}

String formatDurationMinutes(int? minutes) {
  if (minutes == null) return '未记录';
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  if (hours == 0) return '$remainder 分钟';
  if (remainder == 0) return '$hours 小时';
  return '$hours 小时 $remainder 分钟';
}

String experienceQuoteFor(DateTime date) {
  const quotes = [
    '不必赶路，先把今天过得清楚。',
    '给重要的事留一点安静的时间。',
    '小小的照顾，也会积累成改变。',
    '允许今天有自己的节奏。',
    '把注意力放回此刻能做的事。',
    '完成不是唯一的尺度，感受也很重要。',
    '为明天留一点从容。',
  ];
  final local = date.toLocal();
  final dayNumber =
      DateTime.utc(local.year, local.month, local.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;
  return quotes[dayNumber.abs() % quotes.length];
}

String _formatChineseDate(DateTime date) {
  const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
  return '${date.year}年${date.month}月${date.day}日 · 星期${weekdays[date.weekday - 1]}';
}

String _formatClock(DateTime date) {
  return '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}

String _presetLabel(int minutes, String unit) {
  if (unit != '分钟') return '$minutes $unit';
  return formatDurationMinutes(minutes);
}
