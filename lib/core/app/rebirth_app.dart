import 'package:flutter/material.dart';

import '../router/app_router.dart';
import '../theme/app_theme.dart';

class RebirthApp extends StatelessWidget {
  const RebirthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Rebirth',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
    );
  }
}
