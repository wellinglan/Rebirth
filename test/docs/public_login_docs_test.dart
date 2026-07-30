import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('public login docs use placeholders and preserve manual truth', () {
    final design = File(
      'docs/41_PUBLIC_USERNAME_PASSWORD_LOGIN.md',
    ).readAsStringSync();
    final build = File(
      'docs/release/rebirth_client_environment_build_guide.md',
    ).readAsStringSync();
    final manual = File(
      'docs/manual_tests/41_public_username_password_login.md',
    ).readAsStringSync();

    expect(build, contains('REBIRTH_ENV=production'));
    expect(build, contains('REBIRTH_ENV=alpha'));
    expect(build, contains('REBIRTH_SERVER_ENDPOINT=<endpoint>'));
    expect(build, isNot(contains('100.')));
    expect(design, contains('schemaVersion remains 9'));
    expect(design, contains('Sync Protocol remains 2'));
    expect(
      RegExp(r'\| [A-J]\d+ \|.*\| NOT EXECUTED \|').allMatches(manual).length,
      114,
    );
    expect(manual, contains('| PASS | 0 |'));
    expect(manual, contains('| FAIL | 0 |'));
    expect(manual, contains('| NOT EXECUTED | 114 |'));
  });
}
