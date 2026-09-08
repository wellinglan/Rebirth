import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/features/account/domain/app_auth_state.dart';
import 'package:rebirth/features/account/presentation/app_auth_controller.dart';
import 'package:rebirth/features/sync/presentation/foreground_auto_sync_controller.dart';

import '../router/app_router.dart';
import '../theme/app_theme.dart';

class RebirthApp extends ConsumerStatefulWidget {
  const RebirthApp({super.key});

  @override
  ConsumerState<RebirthApp> createState() => _RebirthAppState();
}

class _RebirthAppState extends ConsumerState<RebirthApp> {
  late final AppLifecycleListener _lifecycleListener;
  late final ProviderSubscription<AsyncValue<AppAuthState>> _authSubscription;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(onStateChange: _onLifecycleState);
    final initialLifecycleState =
        WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onLifecycleState(initialLifecycleState);
    });
    _authSubscription = ref.listenManual(
      appAuthStateProvider,
      (_, next) => _forwardAuthState(next),
      fireImmediately: true,
    );
  }

  void _forwardAuthState(AsyncValue<AppAuthState> state) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref
            .read(foregroundAutoSyncControllerProvider.notifier)
            .handleAuthState(state),
      );
    });
  }

  void _onLifecycleState(AppLifecycleState state) {
    ref
        .read(foregroundAutoSyncControllerProvider.notifier)
        .handleLifecycleState(state);
  }

  @override
  void dispose() {
    _authSubscription.close();
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Rebirth',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
