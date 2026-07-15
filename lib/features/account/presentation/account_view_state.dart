import 'package:rebirth/features/account/domain/account_status.dart';

enum AccountAction {
  idle,
  checkingBackend,
  loggingIn,
  registeringDevice,
  loggingOut,
}

final class AccountViewState {
  const AccountViewState({
    required this.status,
    this.action = AccountAction.idle,
  });

  final AccountStatus status;
  final AccountAction action;

  bool get isBusy => action != AccountAction.idle;
  bool get isCheckingBackend => action == AccountAction.checkingBackend;
  bool get isLoggingIn => action == AccountAction.loggingIn;
  bool get isRegisteringDevice => action == AccountAction.registeringDevice;
  bool get isLoggingOut => action == AccountAction.loggingOut;

  AccountViewState copyWith({AccountStatus? status, AccountAction? action}) {
    return AccountViewState(
      status: status ?? this.status,
      action: action ?? this.action,
    );
  }
}
