import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/sync/domain/sync_exception.dart';
import 'package:rebirth/features/today/data/today_sync_payload_codec.dart';
import 'package:rebirth/features/today/domain/today_entry.dart';
import 'package:rebirth/features/today/domain/today_sync_payload.dart';

void main() {
  const codec = TodaySyncPayloadCodec();

  test('canonical JSON and SHA-256 fingerprint are stable', () {
    final payload = _payload();
    const expected =
        '{"created_at":10,"daily_note":null,"energy_description":null,'
        '"energy_score":4,"learning_description":null,'
        '"learning_minutes":0,"mood_description":null,"mood_score":5,'
        '"priority_1":"Research",'
        '"priority_1_completed":true,"priority_1_goal_id":null,'
        '"priority_2":null,"priority_2_completed":false,'
        '"priority_2_goal_id":null,"priority_3":null,'
        '"priority_3_completed":false,"priority_3_goal_id":null,'
        '"record_date":"2026-07-28","record_status":"completed",'
        '"research_description":"Focused work","research_minutes":90,'
        '"timezone_offset_minutes":480,'
        '"wellbeing_score_scale":10}';

    expect(codec.canonicalJson(payload), expected);
    expect(
      codec.fingerprint(payload),
      '02f183e443adc9cea08bb1ffcaddd1d4538d63562af007ca893d46a52e0eadef',
    );
  });

  test('typed codec roundtrip preserves null and zero', () {
    final encoded = codec.encode(_payload());
    final decoded = codec.decode(recordId: _recordId, json: encoded);

    expect(decoded.recordDate, '2026-07-28');
    expect(decoded.dailyNote, isNull);
    expect(decoded.learningMinutes, 0);
    expect(decoded.researchMinutes, 90);
    expect(decoded.researchDescription, 'Focused work');
    expect(decoded.learningDescription, isNull);
    expect(decoded.priority1Completed, isTrue);
    expect(decoded.status, TodayRecordStatus.completed);
    expect(encoded, isNot(contains('user_id')));
    expect(encoded, isNot(contains('sync_status')));
    expect(encoded, isNot(contains('server_version')));
  });

  test('legacy payload without scale is interpreted as 1 through 5', () {
    final legacy = {...codec.encode(_payload())}
      ..remove('wellbeing_score_scale')
      ..remove('mood_description')
      ..remove('energy_description')
      ..remove('research_description')
      ..remove('learning_description');
    final decoded = codec.decode(recordId: _recordId, json: legacy);

    expect(decoded.wellbeingScoreScale, 5);
    expect(decoded.moodDescription, isNull);
    expect(decoded.energyDescription, isNull);
    expect(decoded.researchDescription, isNull);
    expect(decoded.learningDescription, isNull);
  });

  test('Sprint 17B payload remains supported without metric narratives', () {
    final current = {...codec.encode(_payload())}
      ..remove('research_description')
      ..remove('learning_description');
    final decoded = codec.decode(recordId: _recordId, json: current);

    expect(decoded.wellbeingScoreScale, 10);
    expect(decoded.researchDescription, isNull);
    expect(decoded.learningDescription, isNull);
  });

  test('codec rejects missing and extra fields', () {
    final encoded = codec.encode(_payload());
    expect(
      () => codec.decode(
        recordId: _recordId,
        json: {...encoded}..remove('record_date'),
      ),
      throwsA(isA<SyncException>()),
    );
    expect(
      () => codec.decode(
        recordId: _recordId,
        json: {...encoded}..remove('learning_description'),
      ),
      throwsA(isA<SyncException>()),
    );
    expect(
      () => codec.decode(
        recordId: _recordId,
        json: {...encoded, 'health': 'must-not-sync'},
      ),
      throwsA(isA<SyncException>()),
    );
  });

  test('codec rejects invalid dates, scores, minutes, and priorities', () {
    for (final payload in [
      _payload(recordDate: '2026-02-30'),
      _payload(moodScore: 11),
      _payload(researchMinutes: -1),
      _payload(priority1: null, priority1Completed: true),
      _payload(researchDescription: 'x' * 81),
    ]) {
      expect(() => codec.encode(payload), throwsA(isA<SyncException>()));
    }
  });
}

const _recordId = '11111111-1111-4111-8111-111111111111';

TodaySyncPayload _payload({
  String recordDate = '2026-07-28',
  String? priority1 = 'Research',
  bool priority1Completed = true,
  int? moodScore = 5,
  int? researchMinutes = 90,
  String? researchDescription = 'Focused work',
}) {
  return TodaySyncPayload(
    recordDate: recordDate,
    timezoneOffsetMinutes: 480,
    priority1: priority1,
    priority1Completed: priority1Completed,
    priority1GoalId: null,
    priority2: null,
    priority2Completed: false,
    priority2GoalId: null,
    priority3: null,
    priority3Completed: false,
    priority3GoalId: null,
    moodScore: moodScore,
    energyScore: 4,
    researchMinutes: researchMinutes,
    researchDescription: researchDescription,
    learningMinutes: 0,
    dailyNote: null,
    status: TodayRecordStatus.completed,
    createdAt: 10,
  );
}
