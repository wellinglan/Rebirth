import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/account/domain/public_auth_input.dart';

void main() {
  group('username', () {
    test('accepts and normalizes the server-supported syntax', () {
      expect(PublicAuthInput.usernameError('Alpha.User-1'), isNull);
      expect(PublicAuthInput.normalizeUsername('Alpha.User-1'), 'alpha.user-1');
    });

    test('rejects whitespace, invalid starts, characters, and lengths', () {
      expect(PublicAuthInput.usernameError(' abc1'), isNotNull);
      expect(PublicAuthInput.usernameError('_abc'), isNotNull);
      expect(PublicAuthInput.usernameError('abc+1'), isNotNull);
      expect(PublicAuthInput.usernameError('abc'), isNotNull);
      expect(PublicAuthInput.usernameError('a' * 65), isNotNull);
    });
  });

  group('password', () {
    test('registration preserves meaningful whitespace', () {
      expect(
        PublicAuthInput.registrationPasswordError('  exact password  '),
        isNull,
      );
    });

    test('registration enforces length and rejects control characters', () {
      expect(PublicAuthInput.registrationPasswordError('short'), isNotNull);
      expect(
        PublicAuthInput.registrationPasswordError('valid password\n'),
        isNotNull,
      );
      expect(PublicAuthInput.registrationPasswordError('🔐' * 128), isNull);
      expect(PublicAuthInput.registrationPasswordError('🔐' * 129), isNotNull);
    });

    test('confirmation compares exact code units', () {
      expect(
        PublicAuthInput.confirmationPasswordError(
          'same password',
          'same password',
        ),
        isNull,
      );
      expect(
        PublicAuthInput.confirmationPasswordError(
          'same password ',
          'same password',
        ),
        isNotNull,
      );
    });
  });

  test('blank display name becomes null and nonblank value is trimmed', () {
    expect(PublicAuthInput.normalizeDisplayName('   '), isNull);
    expect(PublicAuthInput.normalizeDisplayName('  Lan  '), 'Lan');
  });
}
