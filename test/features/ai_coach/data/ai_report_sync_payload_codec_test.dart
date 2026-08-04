import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/ai_coach/data/ai_report_sync_payload_codec.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_metadata.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_status.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_sync_payload.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_type.dart';
import 'package:rebirth/features/sync/domain/sync_exception.dart';

void main() {
  const codec = AiReportSyncPayloadCodec();
  AiReportSyncPayload payload() => AiReportSyncPayload(
    reportType: AiReportType.weeklyReport,
    title: 'Weekly review',
    periodStartDate: '2026-08-01',
    periodEndDate: '2026-08-07',
    status: AiReportStatus.completed,
    createdAt: 10,
    generationSource: 'ai_coach',
    sensitivity: AiReportSensitivity.high,
    quality: AiReportQuality.unreviewed,
    currentVersion: 1,
    versions: const [
      AiReportVersionSyncPayload(
        id: '72222222-2222-4222-8222-222222222222',
        version: 1,
        status: AiReportStatus.completed,
        generationSource: 'ai_coach',
        content: 'Private report',
        sensitivity: AiReportSensitivity.high,
        quality: AiReportQuality.unreviewed,
        errorCode: null,
        createdAt: 10,
        completedAt: 11,
      ),
    ],
  );

  test('only portable immutable report data is encoded', () {
    final json = codec.encode(payload());
    expect(json.keys, isNot(contains('prompt')));
    expect(json.keys, isNot(contains('provider')));
    expect(json.keys, isNot(contains('usage')));
    expect(
      codec
          .decode(recordId: '71111111-1111-4111-8111-111111111111', json: json)
          .title,
      'Weekly review',
    );
  });

  test('report payload refuses a rewritten immutable version', () {
    final json = codec.encode(payload())..['unexpected'] = 'no';
    expect(
      () => codec.decode(
        recordId: '71111111-1111-4111-8111-111111111111',
        json: json,
      ),
      throwsA(isA<SyncException>()),
    );
  });
}
