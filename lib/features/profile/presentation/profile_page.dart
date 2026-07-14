import 'package:flutter/material.dart';
import 'package:rebirth/core/theme/app_layout.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Profile', style: textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text('这里属于你。', style: textTheme.bodyMedium),
        ],
      ),
    );
  }
}
