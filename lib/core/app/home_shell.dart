import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/route_names.dart';
import '../theme/app_layout.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const _titles = <String>['今日', '复盘', '计划', '健康', '成长', 'AI 教练'];

  static const _destinations = <_HomeDestination>[
    _HomeDestination('今日', Icons.today_outlined, Icons.today),
    _HomeDestination('复盘', Icons.auto_stories_outlined, Icons.auto_stories),
    _HomeDestination('计划', Icons.account_tree_outlined, Icons.account_tree),
    _HomeDestination('健康', Icons.monitor_heart_outlined, Icons.monitor_heart),
    _HomeDestination('成长', Icons.insights_outlined, Icons.insights),
    _HomeDestination('AI 教练', Icons.auto_awesome_outlined, Icons.auto_awesome),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final useRail = AppLayout.usesNavigationRail(constraints.maxWidth);
        final useExpandedRail = AppLayout.usesExpandedNavigation(
          constraints.maxWidth,
          textScale,
        );
        return Scaffold(
          appBar: AppBar(
            title: Text(_titles[navigationShell.currentIndex]),
            actions: [
              IconButton(
                key: const ValueKey('homeEntryButton'),
                onPressed: () => context.go(RoutePaths.home),
                tooltip: '主页',
                icon: const Icon(Icons.home_outlined),
              ),
              IconButton(
                key: const ValueKey('settingsEntryButton'),
                onPressed: () => context.push(RoutePaths.settings),
                tooltip: '设置',
                icon: const Icon(Icons.settings_outlined),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
          ),
          body: useRail
              ? Row(
                  children: [
                    NavigationRail(
                      key: const ValueKey('homeNavigationRail'),
                      extended: useExpandedRail,
                      minWidth: 80,
                      minExtendedWidth: 224,
                      selectedIndex: navigationShell.currentIndex,
                      labelType: useExpandedRail
                          ? null
                          : textScale >= 1.5
                          ? NavigationRailLabelType.selected
                          : NavigationRailLabelType.all,
                      groupAlignment: -0.75,
                      leading: Padding(
                        padding: const EdgeInsets.only(
                          top: AppSpacing.xs,
                          bottom: AppSpacing.lg,
                        ),
                        child: useExpandedRail
                            ? const SizedBox(
                                key: ValueKey('homeNavigationBrand'),
                                width: 176,
                                child: Text(
                                  'Rebirth',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            : Semantics(
                                label: 'Rebirth 主导航',
                                child: const Icon(Icons.eco_outlined),
                              ),
                      ),
                      onDestinationSelected: _goToBranch,
                      destinations: [
                        for (final destination in _destinations)
                          NavigationRailDestination(
                            icon: Icon(destination.icon),
                            selectedIcon: Icon(destination.selectedIcon),
                            label: Text(destination.label),
                          ),
                      ],
                    ),
                    const VerticalDivider(width: 1, thickness: 1),
                    Expanded(child: navigationShell),
                  ],
                )
              : navigationShell,
          bottomNavigationBar: useRail
              ? null
              : NavigationBar(
                  key: const ValueKey('homeNavigationBar'),
                  selectedIndex: navigationShell.currentIndex,
                  labelBehavior: textScale >= 1.5
                      ? NavigationDestinationLabelBehavior.alwaysHide
                      : NavigationDestinationLabelBehavior.onlyShowSelected,
                  onDestinationSelected: _goToBranch,
                  destinations: [
                    for (final destination in _destinations)
                      NavigationDestination(
                        icon: Icon(destination.icon),
                        selectedIcon: Icon(destination.selectedIcon),
                        label: destination.label,
                        tooltip: destination.label,
                      ),
                  ],
                ),
        );
      },
    );
  }

  void _goToBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

final class _HomeDestination {
  const _HomeDestination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
