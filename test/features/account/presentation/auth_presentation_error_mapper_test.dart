import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/network/api_exception.dart';
import 'package:rebirth/features/account/data/secure_auth_session_store.dart';
import 'package:rebirth/features/account/presentation/auth_presentation_error_mapper.dart';

void main() {
  test('unknown username and wrong password share one safe message', () {
    const error = ApiException(
      message: 'raw detail',
      statusCode: 401,
      errorCode: 'invalid_credentials',
    );

    expect(AuthPresentationErrorMapper.messageFor(error), '用户名或密码不正确。');
  });

  test(
    'registration, rate limit, network, and server failures are distinct',
    () {
      expect(
        AuthPresentationErrorMapper.messageFor(
          const ApiException(
            message: 'raw',
            statusCode: 409,
            errorCode: 'login_identifier_unavailable',
          ),
        ),
        '该用户名不可用。',
      );
      expect(
        AuthPresentationErrorMapper.messageFor(
          const ApiException(
            message: 'raw',
            statusCode: 429,
            errorCode: 'authentication_rate_limited',
          ),
        ),
        '尝试次数过多，请稍后再试。',
      );
      expect(
        AuthPresentationErrorMapper.messageFor(
          const ApiException(message: 'raw URL', isNetworkError: true),
        ),
        '当前无法连接服务器，请检查网络后重试。',
      );
      expect(
        AuthPresentationErrorMapper.messageFor(
          const ApiException(message: 'raw SQL', statusCode: 503),
        ),
        '服务暂时不可用，请稍后再试。',
      );
    },
  );

  test('secure-store failure never exposes its raw detail', () {
    const error = AuthSessionStorageException('secret storage detail');
    final message = AuthPresentationErrorMapper.messageFor(error);

    expect(message, '无法安全保存登录状态，请检查系统设置后重试。');
    expect(message, isNot(contains('secret')));
  });
}
