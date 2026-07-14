import 'package:flutter/material.dart';

enum PlanGoalAction { archive, restore, delete }

class PlanGoalActionsMenu extends StatelessWidget {
  const PlanGoalActionsMenu({
    required this.goalId,
    required this.isArchived,
    required this.onSelected,
    super.key,
  });

  final String goalId;
  final bool isArchived;
  final ValueChanged<PlanGoalAction> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<PlanGoalAction>(
      key: ValueKey('planGoalActionsMenu_$goalId'),
      tooltip: '更多操作',
      onSelected: onSelected,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: isArchived ? PlanGoalAction.restore : PlanGoalAction.archive,
          child: ListTile(
            leading: Icon(
              isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
            ),
            title: Text(isArchived ? '恢复归档' : '归档'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: PlanGoalAction.delete,
          child: ListTile(
            leading: Icon(Icons.delete_outline),
            title: Text('删除'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
      icon: const Icon(Icons.more_vert),
    );
  }
}
