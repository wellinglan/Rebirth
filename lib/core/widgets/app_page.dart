import 'package:flutter/material.dart';

import '../theme/app_layout.dart';

class AppScrollablePage extends StatelessWidget {
  const AppScrollablePage({
    required this.child,
    this.maxWidth = AppLayout.maxContentWidth,
    this.scrollKey,
    super.key,
  });

  final Widget child;
  final double maxWidth;
  final Key? scrollKey;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          key: scrollKey,
          padding: AppLayout.pagePaddingFor(constraints.maxWidth),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
