import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/wellbeing/wellbeing_score.dart';

void main() {
  test('legacy 1 through 5 scores normalize to even 1 through 10 values', () {
    expect(
      [1, 2, 3, 4, 5].map((score) => normalizeWellbeingScore(score, null)),
      [2, 4, 6, 8, 10],
    );
  });

  test('current scores and null remain unchanged', () {
    expect(normalizeWellbeingScore(null, 10), isNull);
    expect(normalizeWellbeingScore(1, 10), 1);
    expect(normalizeWellbeingScore(10, 10), 10);
  });

  test('descriptions trim blanks and enforce the 80 character boundary', () {
    expect(normalizeWellbeingDescription('  calm  '), 'calm');
    expect(normalizeWellbeingDescription('   '), isNull);
    expect(normalizeWellbeingDescription('a' * 80), hasLength(80));
    expect(
      () => normalizeWellbeingDescription('a' * 81),
      throwsArgumentError,
    );
  });
}
