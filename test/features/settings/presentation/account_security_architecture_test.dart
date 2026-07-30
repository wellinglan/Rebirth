import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('account security presentation stays behind controller boundary', () {
    final source = File(
      'lib/features/settings/presentation/account_security_page.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('app_database.dart')));
    expect(source, isNot(contains('package:drift/')));
    expect(source, isNot(contains('identity_repository_impl.dart')));
    expect(source, isNot(contains('IdentityApiDataSource')));
  });
}
