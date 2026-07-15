import 'package:dio/dio.dart';

import 'api_exception.dart';

abstract interface class ApiClient {
  Future<Map<String, Object?>> getJson(
    String path, {
    String? accessToken,
    Duration? timeout,
  });

  Future<Map<String, Object?>> postJson(
    String path, {
    required Map<String, Object?> body,
    String? accessToken,
    Duration? timeout,
  });
}

final class DioApiClient implements ApiClient {
  DioApiClient({
    required String baseUrl,
    Dio? dio,
    this.defaultTimeout = const Duration(seconds: 5),
  }) : _dio = dio ?? Dio(BaseOptions(baseUrl: _normalizeBaseUrl(baseUrl)));

  final Dio _dio;
  final Duration defaultTimeout;

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    String? accessToken,
    Duration? timeout,
  }) {
    return _request(
      method: 'GET',
      path: path,
      accessToken: accessToken,
      timeout: timeout,
    );
  }

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    required Map<String, Object?> body,
    String? accessToken,
    Duration? timeout,
  }) {
    return _request(
      method: 'POST',
      path: path,
      body: body,
      accessToken: accessToken,
      timeout: timeout,
    );
  }

  Future<Map<String, Object?>> _request({
    required String method,
    required String path,
    Map<String, Object?>? body,
    String? accessToken,
    Duration? timeout,
  }) async {
    final requestTimeout = timeout ?? defaultTimeout;
    try {
      final response = await _dio.request<Object?>(
        path,
        data: body,
        options: Options(
          method: method,
          contentType: Headers.jsonContentType,
          responseType: ResponseType.json,
          connectTimeout: requestTimeout,
          sendTimeout: requestTimeout,
          receiveTimeout: requestTimeout,
          headers: _authorizationHeaders(accessToken),
        ),
      );
      final data = response.data;
      if (data is! Map) {
        throw const ApiException(message: '后端返回了无法识别的数据。');
      }
      return Map<String, Object?>.from(data);
    } on ApiException {
      rethrow;
    } on DioException catch (error) {
      throw _toApiException(error);
    } catch (error) {
      throw ApiException(message: '请求失败，请稍后重试。', cause: error);
    }
  }

  Map<String, String>? _authorizationHeaders(String? accessToken) {
    if (accessToken == null || accessToken.isEmpty) {
      return null;
    }
    return {'Authorization': 'Bearer $accessToken'};
  }

  ApiException _toApiException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return ApiException(
          message: '请求超时，请确认后端已启动后重试。',
          cause: error.error,
          isNetworkError: true,
        );
      case DioExceptionType.connectionError:
        return ApiException(
          message: '无法连接开发后端，请确认服务已启动且网络可达。',
          cause: error.error,
          isNetworkError: true,
        );
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        return ApiException(
          message: statusCode == 401
              ? '登录状态已失效，请重新登录。'
              : '后端返回错误${statusCode == null ? '' : '（$statusCode）'}。',
          statusCode: statusCode,
        );
      case DioExceptionType.cancel:
        return const ApiException(message: '请求已取消。');
      case DioExceptionType.badCertificate:
        return const ApiException(message: '无法验证后端证书。', isNetworkError: true);
      case DioExceptionType.unknown:
        return ApiException(
          message: '网络请求失败，请稍后重试。',
          cause: error.error,
          isNetworkError: true,
        );
    }
  }

  static String _normalizeBaseUrl(String value) {
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }
}
