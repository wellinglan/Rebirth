import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/network/api_exception.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/account/data/account_repository_provider.dart';
import 'package:rebirth/features/account/domain/account_exception.dart';
import 'package:rebirth/features/account/domain/account_status.dart';

import 'account_view_state.dart';

final accountControllerProvider =
    AsyncNotifierProvider<AccountController, AccountViewState>(
      AccountController.new,
    );

class AccountController extends AsyncNotifier<AccountViewState> {
  @override
  Future<AccountViewState> build() => _loadLocalStatus();

  Future<AccountViewState> _loadLocalStatus() async {
    final status = await ref.read(accountRepositoryProvider).getAccountStatus();
    return AccountViewState(status: status);
  }

  Future<void> reload() async {
    state = const AsyncLoading<AccountViewState>();
    state = await AsyncValue.guard(_loadLocalStatus);
  }

  Future<bool> checkBackendHealth() async {
    final current = state.value;
    if (current == null || current.isBusy) return false;
    _setAction(current, AccountAction.checkingBackend);
    try {
      final health = await ref
          .read(accountRepositoryProvider)
          .checkBackendHealth();
      if (!health.isCompatible) {
        throw const ApiException(message: '开发后端 API 或同步协议版本不兼容。');
      }
      _finish(
        current.status.copyWith(
          backendReachable: true,
          lastCheckedAt: _nowMilliseconds(),
          errorMessage: null,
        ),
      );
      return true;
    } catch (error) {
      _finish(
        current.status.copyWith(
          backendReachable: false,
          lastCheckedAt: _nowMilliseconds(),
          errorMessage: _messageFor(error),
        ),
      );
      return false;
    }
  }

  Future<bool> devLogin(String devUserKey) async {
    final current = state.value;
    if (current == null || current.isBusy) return false;
    _setAction(current, AccountAction.loggingIn);
    try {
      await ref.read(accountRepositoryProvider).devLogin(devUserKey);
      final refreshed = await ref
          .read(accountRepositoryProvider)
          .getAccountStatus();
      _finish(
        refreshed.copyWith(
          backendReachable: true,
          lastCheckedAt: _nowMilliseconds(),
          errorMessage: null,
        ),
      );
      return true;
    } catch (error) {
      _finish(
        current.status.copyWith(
          backendReachable: error is ApiException
              ? !error.isNetworkError && current.status.backendReachable
              : current.status.backendReachable,
          errorMessage: _messageFor(error),
        ),
      );
      return false;
    }
  }

  Future<bool> registerCurrentDevice() async {
    final current = state.value;
    if (current == null || current.isBusy) return false;
    _setAction(current, AccountAction.registeringDevice);
    try {
      await ref.read(accountRepositoryProvider).registerCurrentDevice();
      final refreshed = await ref
          .read(accountRepositoryProvider)
          .getAccountStatus();
      _finish(
        refreshed.copyWith(
          backendReachable: true,
          lastCheckedAt: current.status.lastCheckedAt ?? _nowMilliseconds(),
          errorMessage: null,
        ),
      );
      return true;
    } catch (error) {
      _finish(current.status.copyWith(errorMessage: _messageFor(error)));
      return false;
    }
  }

  Future<bool> logout() async {
    final current = state.value;
    if (current == null || current.isBusy) return false;
    _setAction(current, AccountAction.loggingOut);
    try {
      await ref.read(accountRepositoryProvider).logout();
      final refreshed = await ref
          .read(accountRepositoryProvider)
          .getAccountStatus();
      _finish(
        refreshed.copyWith(
          backendReachable: current.status.backendReachable,
          lastCheckedAt: current.status.lastCheckedAt,
          errorMessage: null,
        ),
      );
      return true;
    } catch (error) {
      _finish(current.status.copyWith(errorMessage: _messageFor(error)));
      return false;
    }
  }

  void _setAction(AccountViewState current, AccountAction action) {
    state = AsyncData(current.copyWith(action: action));
  }

  void _finish(AccountStatus status) {
    state = AsyncData(AccountViewState(status: status));
  }

  int _nowMilliseconds() {
    return ref.read(dateTimeServiceProvider).currentSnapshot().utcMilliseconds;
  }

  String _messageFor(Object error) {
    if (error is ApiException) return error.message;
    if (error is AccountAuthenticationRequiredException) return '请先开发登录';
    if (error is ArgumentError) return '请输入有效的开发账号标识。';
    return '操作暂时无法完成，请稍后重试。';
  }
}
