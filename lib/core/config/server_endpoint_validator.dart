final class ServerEndpointValidator {
  const ServerEndpointValidator();

  String normalize(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('请输入服务器地址。');
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const FormatException('请输入包含 http:// 或 https:// 的有效地址。');
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw const FormatException('服务器地址仅支持 HTTP 或 HTTPS。');
    }
    if (uri.userInfo.isNotEmpty) {
      throw const FormatException('服务器地址不能包含用户名、密码或 token。');
    }
    if (uri.hasQuery) {
      throw const FormatException('服务器地址不能包含查询参数。');
    }
    if (uri.hasFragment) {
      throw const FormatException('服务器地址不能包含片段。');
    }
    if (uri.path.isNotEmpty && uri.path != '/') {
      throw const FormatException('服务器地址不能包含 API 路径。');
    }

    return uri.replace(path: '').toString();
  }

  String? errorFor(String value) {
    try {
      normalize(value);
      return null;
    } on FormatException catch (error) {
      return error.message;
    }
  }
}

