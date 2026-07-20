import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/ai_coach/data/canonical_json_encoder_impl.dart';
import 'package:rebirth/features/ai_coach/data/sha256_input_hash_service.dart';
import 'package:rebirth/features/ai_coach/domain/ai_coach_exception.dart';

void main() {
  const encoder = CanonicalJsonEncoderImpl();
  const hashService = Sha256InputHashService();

  test('canonical JSON recursively sorts map keys', () {
    final encoded = encoder.encode({
      'z': 1,
      'a': {'y': 2, 'b': 3},
    });
    expect(encoded, '{"a":{"b":3,"y":2},"z":1}');
  });

  test('canonical JSON preserves list order and JSON scalar types', () {
    final encoded = encoder.encode({
      'values': ['成长', null, 0, true, 7, 1.5],
    });
    expect(encoded, '{"values":["成长",null,0,true,7,1.5]}');
    expect(encoded, isNot(contains('\n')));
    expect(encoded, isNot(contains(': ')));
  });

  test('map insertion order does not affect canonical bytes', () {
    final left = encoder.encode({'b': 2, 'a': 1});
    final right = encoder.encode({'a': 1, 'b': 2});
    expect(left, right);
    expect(left.codeUnits, right.codeUnits);
  });

  test('unsupported objects and non-finite doubles are rejected', () {
    expect(
      () => encoder.encode(DateTime(2026)),
      throwsA(isA<InvalidAiInputException>()),
    );
    expect(
      () => encoder.encode(double.infinity),
      throwsA(isA<InvalidAiInputException>()),
    );
  });

  test('SHA-256 is deterministic lowercase hexadecimal', () {
    final canonical = encoder.encode({'a': 1});
    final first = hashService.hashCanonicalJson(canonical);
    final second = hashService.hashCanonicalJson(canonical);
    expect(first, second);
    expect(first, matches(RegExp(r'^[0-9a-f]{64}$')));
  });

  test('contract changes alter hash while null remains distinct from zero', () {
    String hash(Map<String, Object?> value) =>
        hashService.hashCanonicalJson(encoder.encode(value));

    final base = {
      'report_type': 'weekly_report',
      'prompt_version': 'weekly-report-v1',
      'period': {'start_date': '2026-07-10', 'end_date': '2026-07-16'},
      'scopes': ['today_metrics'],
      'data': {'value': null},
      'sources': [
        {'table': 'today_records', 'id': 'a', 'updated_at': 1},
      ],
    };
    expect(
      hash({...base, 'prompt_version': 'weekly-report-v2'}),
      isNot(hash(base)),
    );
    expect(hash({...base, 'report_type': 'daily_insight'}), isNot(hash(base)));
    expect(
      hash({
        ...base,
        'period': {'start_date': '2026-07-09', 'end_date': '2026-07-15'},
      }),
      isNot(hash(base)),
    );
    expect(
      hash({
        ...base,
        'scopes': ['health_metrics'],
      }),
      isNot(hash(base)),
    );
    expect(
      hash({
        ...base,
        'data': {'value': 0},
      }),
      isNot(hash(base)),
    );
    expect(
      hash({
        ...base,
        'sources': [
          {'table': 'today_records', 'id': 'a', 'updated_at': 2},
        ],
      }),
      isNot(hash(base)),
    );
  });

  test('provider and model metadata cannot affect a contract-only hash', () {
    final contract = encoder.encode({'schema_version': 1, 'data': null});
    final hash = hashService.hashCanonicalJson(contract);
    const runtimeMetadataA = {'provider': 'one', 'model': 'small'};
    const runtimeMetadataB = {'provider': 'two', 'model': 'large'};

    expect(runtimeMetadataA, isNot(runtimeMetadataB));
    expect(hashService.hashCanonicalJson(contract), hash);
  });

  test(
    'shared Python and Dart weekly fixture has identical canonical hash',
    () {
      final payload =
          jsonDecode(
                File(
                  'test/fixtures/ai_weekly_input_v1.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final expected = File(
        'test/fixtures/ai_weekly_input_v1_expected_hash.txt',
      ).readAsStringSync().trim();
      final canonical = encoder.encode(Map<String, Object?>.from(payload));

      expect(hashService.hashCanonicalJson(canonical), expected);
      expect(canonical, contains('中文'));
      expect(canonical, contains('"research_minutes":0'));
      expect(canonical, contains('"learning_minutes":null'));
    },
  );

  test('shared Python and Dart Daily Insight fixture has identical hash', () {
    final payload =
        jsonDecode(
              File(
                'test/fixtures/ai_daily_insight_input_v1.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final expected = File(
      'test/fixtures/ai_daily_insight_input_v1_expected_hash.txt',
    ).readAsStringSync().trim();
    final canonical = encoder.encode(Map<String, Object?>.from(payload));

    expect(hashService.hashCanonicalJson(canonical), expected);
    expect(
      expected,
      '41c3116ae42c129c2b407377ccdee15a984706f259665f9f2b967fe3532b56e0',
    );
    expect(canonical, contains('DAILY敏感标记_仅供测试_9A'));
    expect(canonical, contains('"research_minutes":0'));
    expect(canonical, contains('"learning_minutes":null'));
  });

  test('daily empty selected array differs from an unselected missing key', () {
    String hash(Object value) =>
        hashService.hashCanonicalJson(encoder.encode(value));
    final selectedMissing = {
      'data': {'today_metrics': <Object?>[]},
    };
    final unselected = {'data': <String, Object?>{}};

    expect(hash(selectedMissing), isNot(hash(unselected)));
  });
}
