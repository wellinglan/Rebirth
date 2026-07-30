import 'package:rebirth/core/network/api_exception.dart';
import 'package:rebirth/features/account/data/secure_auth_session_store.dart';
import 'package:rebirth/features/account/domain/account_boundary.dart';

abstract final class AuthPresentationErrorMapper {
  static String messageFor(Object error) {
    if (error is AuthSessionStorageException) {
      return '无法安全保存登录状态，请检查系统设置后重试。';
    }
    if (error is AccountSessionRejectedException ||
        error is AccountScopeMismatchException) {
      return '登录状态已失效，请重新登录。';
    }
    if (error is ApiException) {
      if (error.isNetworkError) {
        return '当前无法连接服务器，请检查网络后重试。';
      }
      return switch (error.errorCode) {
        'invalid_credentials' => '用户名或密码不正确。',
        'login_identifier_unavailable' => '该用户名不可用。',
        'password_policy_violation' => '密码不符合安全要求。',
        'authentication_rate_limited' => '尝试次数过多，请稍后再试。',
        'session_revoked' ||
        'session_expired' ||
        'refresh_token_invalid' ||
        'refresh_token_expired' ||
        'refresh_token_reused' => '登录状态已失效，请重新登录。',
        _ when (error.statusCode ?? 0) >= 500 => '服务暂时不可用，请稍后再试。',
        _ => '操作未完成，请稍后重试。',
      };
    }
    if (error is UnsupportedError) return '当前构建未启用开发者登录。';
    return '操作未完成，请稍后重试。';
  }
}
