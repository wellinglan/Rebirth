import 'package:flutter/material.dart';

class GrowthPage extends StatelessWidget {
  const GrowthPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Growth', style: textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text('看见缓慢而真实的变化。', style: textTheme.bodyMedium),
        ],
      ),
    );
  }
}
