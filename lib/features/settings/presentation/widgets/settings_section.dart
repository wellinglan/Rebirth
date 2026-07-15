import 'package:flutter/material.dart';
import 'package:rebirth/core/theme/app_layout.dart';

class SettingsSection extends StatelessWidget {
  const SettingsSection({required this.title, required this.child, super.key});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppLayout.cardGap),
        child,
      ],
    );
  }
}
