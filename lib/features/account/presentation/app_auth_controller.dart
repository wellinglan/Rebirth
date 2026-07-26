import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/features/account/data/account_repository_provider.dart';
import 'package:rebirth/features/account/domain/account_boundary.dart';
import 'package:rebirth/features/account/domain/app_auth_state.dart';
import 'package:rebirth/features/account/domain/auth_session.dart';

import 'account_scoped_provider_invalidator.dart';

final appAuthControllerProvider =
    AsyncNotifierProvider<AppAuthController, AppAuthState>(
      AppAuthController.new,
    );

final appAuthStateProvider = Provider<AsyncValue<AppAuthState>>(
  (ref) => ref.watch(appAuthControllerProvider),
);

class AppAuthController extends AsyncNotifier<AppAuthState> {
  bool _ownershipMutationInProgress = false;

  @override
  Future<AppAuthState> build() => _restore();

  Future<AppAuthState> _restore() async {
    try {
      final session = await ref.read(authSessionStoreProvider).read();
      if (session == null) {
        await ref
            .read(accountBoundaryRepositoryProvider)
            .deactivateAllProfiles();
        return const AppAuthState.signedOut();
      }
      final resolution = await ref
          .read(accountBoundaryRepositoryProvider)
          .resolveAndActivate(session);
      if (!resolution.isActivated) {
        return AppAuthState(
          status: AppAuthStatus.bindingRequired,
          cloudUserId: session.user.id,
          accountScope: resolution.accountScope,
          unboundProfileCount: resolution.unboundProfileCount,
          message: '检测到旧本地数据。请明确选择其归属，系统不会自动绑定或同步。',
        );
      }
      final online = await _backendIsReachable();
      return AppAuthState(
        status: online
            ? AppAuthStatus.authenticated
            : AppAuthStatus.authenticatedOffline,
        localUserId: resolution.localUserId,
        cloudUserId: session.user.id,
        accountScope: resolution.accountScope,
        syncEligibility: resolution.syncEligibility,
      );
    } on AccountSessionRejectedException catch (error) {
      return AppAuthState(
        status: AppAuthStatus.sessionRejected,
        message: error.message,
      );
    } on AccountScopeMismatchException catch (error) {
      return AppAuthState(
        status: AppAuthStatus.sessionRejected,
        message: error.message,
      );
    } catch (_) {
      return const AppAuthState(
        status: AppAuthStatus.fatalMigrationError,
        message: '本地账号数据空间初始化失败，请重试。',
      );
    }
  }

  Future<bool> devLogin(String devUserKey) async {
    if (state.isLoading) return false;
    state = const AsyncLoading<AppAuthState>();
    try {
      final session = await ref
          .read(accountRepositoryProvider)
          .devLogin(devUserKey);
      final resolution = await ref
          .read(accountBoundaryRepositoryProvider)
          .resolveAndActivate(session);
      invalidateAccountScopedProviders(ref);
      if (!resolution.isActivated) {
        state = AsyncData(
          AppAuthState(
            status: AppAuthStatus.bindingRequired,
            cloudUserId: session.user.id,
            accountScope: resolution.accountScope,
            unboundProfileCount: resolution.unboundProfileCount,
            message: '检测到旧本地数据。请明确选择其归属，系统不会自动绑定或同步。',
          ),
        );
        return false;
      }
      state = AsyncData(
        AppAuthState(
          status: AppAuthStatus.authenticated,
          localUserId: resolution.localUserId,
          cloudUserId: session.user.id,
          accountScope: resolution.accountScope,
          syncEligibility: resolution.syncEligibility,
        ),
      );
      return true;
    } catch (error) {
      await ref.read(accountRepositoryProvider).logout();
      await ref.read(accountBoundaryRepositoryProvider).deactivateAllProfiles();
      invalidateAccountScopedProviders(ref);
      state = AsyncData(AppAuthState.signedOut(message: _messageFor(error)));
      return false;
    }
  }

  Future<void> claimLegacyDataSpace(String localUserId) {
    return _completeOwnershipResolution(
      (session, scope) => ref
          .read(accountBoundaryRepositoryProvider)
          .claimLegacyDataSpace(
            session: session,
            expectedScope: scope,
            localUserId: localUserId,
          ),
    );
  }

  Future<void> createFreshDataSpace() {
    return _completeOwnershipResolution(
      (session, scope) => ref
          .read(accountBoundaryRepositoryProvider)
          .createFreshDataSpace(session: session, expectedScope: scope),
    );
  }

  Future<void> _completeOwnershipResolution(
    Future<AccountBindingResolution> Function(
      AuthSession session,
      CloudAccountScope scope,
    )
    operation,
  ) async {
    if (_ownershipMutationInProgress) return;
    final current = state.value;
    final scope = current?.accountScope;
    if (current?.status != AppAuthStatus.bindingRequired || scope == null) {
      throw const AccountSessionRejectedException('当前页面状态已变化，请重新登录后操作。');
    }
    _ownershipMutationInProgress = true;
    try {
      final session = await ref.read(authSessionStoreProvider).read();
      if (session == null) {
        throw const AccountSessionRejectedException('登录会话已失效，请重新登录。');
      }
      final resolution = await operation(session, scope);
      if (!resolution.isActivated) {
        throw const AccountScopeMismatchException('本地数据归属操作未完成。');
      }
      invalidateAccountScopedProviders(ref);
      final online = await _backendIsReachable();
      state = AsyncData(
        AppAuthState(
          status: online
              ? AppAuthStatus.authenticated
              : AppAuthStatus.authenticatedOffline,
          localUserId: resolution.localUserId,
          cloudUserId: session.user.id,
          accountScope: resolution.accountScope,
          syncEligibility: resolution.syncEligibility,
        ),
      );
    } finally {
      _ownershipMutationInProgress = false;
    }
  }

  Future<void> logout() async {
    if (state.isLoading) return;
    state = const AsyncLoading<AppAuthState>();
    try {
      await ref.read(accountRepositoryProvider).logout();
      await ref.read(accountBoundaryRepositoryProvider).deactivateAllProfiles();
      invalidateAccountScopedProviders(ref);
      state = const AsyncData(AppAuthState.signedOut());
    } catch (_) {
      state = const AsyncData(
        AppAuthState(
          status: AppAuthStatus.fatalMigrationError,
          message: '退出登录时无法锁定本地数据空间，请重试。',
        ),
      );
    }
  }

  Future<void> retry() async {
    state = const AsyncLoading<AppAuthState>();
    state = AsyncData(await _restore());
  }

  Future<bool> _backendIsReachable() async {
    try {
      final health = await ref
          .read(accountRepositoryProvider)
          .checkBackendHealth();
      if (!health.isCompatible) {
        throw const AccountSessionRejectedException(
          '服务器 API 或同步协议不兼容，请重新配置后登录。',
        );
      }
      return true;
    } on AccountSessionRejectedException {
      rethrow;
    } catch (_) {
      return false;
    }
  }

  String _messageFor(Object error) {
    if (error is ArgumentError) return '请输入有效的开发账号标识。';
    if (error is AccountSessionRejectedException) return error.message;
    if (error is AccountScopeMismatchException) return error.message;
    return '登录失败，请检查服务器连接和账号标识。';
  }
}
