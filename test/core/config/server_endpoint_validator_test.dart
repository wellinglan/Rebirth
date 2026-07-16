import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/config/server_endpoint_validator.dart';

void main() {
  const validator = ServerEndpointValidator();

  test('accepts and normalizes HTTP, HTTPS, and ports', () {
    expect(
      validator.normalize(' http://localhost:8000/ '),
      'http://localhost:8000',
    );
    expect(
      validator.normalize('https://api.example.com'),
      'https://api.example.com',
    );
    expect(
      validator.normalize('https://10.0.0.2:9443/'),
      'https://10.0.0.2:9443',
    );
  });

  for (final invalid in <String, String>{
    '': '请输入服务器地址',
    'http://': '有效地址',
    'ftp://example.com': 'HTTP 或 HTTPS',
    'file:///tmp/server': '有效地址',
    'http://user:token@example.com': '不能包含用户名',
    'http://example.com?token=value': '不能包含查询参数',
    'http://example.com#token': '不能包含片段',
    'http://example.com/api': '不能包含 API 路径',
  }.entries) {
    test('rejects ${invalid.key.isEmpty ? 'empty input' : invalid.key}', () {
      expect(
        () => validator.normalize(invalid.key),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains(invalid.value),
          ),
        ),
      );
    });
  }
}
