import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/ai_coach/data/local_ai_consent_repository.dart';

void main() {
  late AppDatabase database;
  late DateTime currentTime;
  late LocalAiConsentRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    currentTime = DateTime.utc(2026, 7, 16, 1, 2, 3);
    repository = LocalAiConsentRepository(
      database: database,
      dateTimeService: DateTimeService(now: () => currentTime),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('bootstrap authorization defaults to disabled with no timestamp', () async {
    final authorization = await repository.read();

    expect(authorization.enabled, isFalse);
    expect(authorization.consentAt, isNull);
  });

  test('grant stores UTC consent time and explicitly updates updatedAt', () async {
    final authorization = await repository.grant();
    final settings = await database.select(database.appSettings).getSingle();
    final expected = currentTime.millisecondsSinceEpoch;

    expect(authorization.enabled, isTrue);
    expect(authorization.consentAt, expected);
    expect(settings.aiDataSharingEnabled, isTrue);
    expect(settings.aiDataSharingConsentAt, expected);
    expect(settings.updatedAt, expected);
  });

  test('repeated grant is idempotent and preserves first consent time', () async {
    final first = await repository.grant();
    currentTime = currentTime.add(const Duration(hours: 1));
    final second = await repository.grant();

    expect(second.consentAt, first.consentAt);
    final settings = await database.select(database.appSettings).getSingle();
    expect(settings.updatedAt, first.consentAt);
  });

  test('revoke disables future use and retains last consent time', () async {
    final granted = await repository.grant();
    currentTime = currentTime.add(const Duration(hours: 2));
    final revoked = await repository.revoke();
    final settings = await database.select(database.appSettings).getSingle();

    expect(revoked.enabled, isFalse);
    expect(revoked.consentAt, granted.consentAt);
    expect(settings.aiDataSharingEnabled, isFalse);
    expect(settings.aiDataSharingConsentAt, granted.consentAt);
    expect(settings.updatedAt, currentTime.millisecondsSinceEpoch);
  });

  test('grant and revoke preserve cloud sync, profile, and business rows', () async {
    final bootstrap = await database.bootstrapDao.bootstrap();
    await (database.update(database.appSettings)
          ..where((row) => row.id.equals(bootstrap.settings.id)))
        .write(const AppSettingsCompanion(cloudSyncEnabled: Value(true)));
    await database.into(database.todayRecords).insert(
      TodayRecordsCompanion.insert(
        id: const Value('11111111-1111-4111-8111-111111111111'),
        userId: bootstrap.activeUserId,
        recordDate: '2026-07-16',
        timezoneOffsetMinutes: 480,
        createdAt: const Value(1),
        updatedAt: const Value(1),
      ),
    );
    await database.into(database.aiReports).insert(
      AiReportsCompanion.insert(
        id: const Value('22222222-2222-4222-8222-222222222222'),
        userId: bootstrap.activeUserId,
        reportType: 'weekly_report',
        periodStartDate: '2026-07-10',
        periodEndDate: '2026-07-16',
        inputHash:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        promptVersion: 'weekly-report-v1',
        requestedAt: 1,
        createdAt: const Value(1),
        updatedAt: const Value(1),
      ),
    );

    await repository.grant();
    await repository.revoke();

    final settings = await database.select(database.appSettings).getSingle();
    expect(settings.cloudSyncEnabled, isTrue);
    expect(await database.select(database.userProfiles).get(), hasLength(1));
    expect(await database.select(database.todayRecords).get(), hasLength(1));
    expect(await database.select(database.aiReports).get(), hasLength(1));
    expect(await database.select(database.healthRecords).get(), isEmpty);
    expect(await database.select(database.journalEntries).get(), isEmpty);
  });
}
