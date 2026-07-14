import 'package:flutter/material.dart';

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
          const SizedBox(height: 6),
          Text('这里属于你。', style: textTheme.bodyMedium),
        ],
      ),
    );
  }
}
