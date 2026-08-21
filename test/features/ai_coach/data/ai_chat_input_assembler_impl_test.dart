import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/ai_coach/data/ai_chat_input_assembler_impl.dart';
import 'package:rebirth/features/ai_coach/data/canonical_json_encoder_impl.dart';
import 'package:rebirth/features/ai_coach/data/sha256_input_hash_service.dart';
import 'package:rebirth/features/ai_coach/domain/ai_chat_conversation.dart';
import 'package:rebirth/features/ai_coach/domain/ai_coach_exception.dart';
import 'package:rebirth/features/ai_coach/domain/ai_consent_repository.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_authorization.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_scope.dart';
import 'package:rebirth/features/growth/domain/growth_period.dart';
import 'package:rebirth/features/growth/domain/growth_repository.dart';
import 'package:rebirth/features/growth/domain/growth_snapshot.dart';
import 'package:rebirth/features/health/domain/health_entry.dart';
import 'package:rebirth/features/health/domain/health_repository.dart';
import 'package:rebirth/features/journal/domain/journal_entry.dart';
import 'package:rebirth/features/journal/domain/journal_repository.dart';
import 'package:rebirth/features/today/domain/today_entry.dart';
import 'package:rebirth/features/today/domain/today_repository.dart';

void main() {
  late _ConsentRepository consent;
  late _TodayRepository today;
  late _HealthRepository health;
  late _JournalRepository journals;
  late AiChatInputAssemblerImpl assembler;

  setUp(() {
    consent = _ConsentRepository();
    today = _TodayRepository([
      TodayEntry(
        id: 'today-1',
        userId: 'private-user',
        recordDate: '2026-08-21',
        timezoneOffsetMinutes: 480,
        priorities: const [
          TodayPriority(text: 'private priority', completed: true),
          TodayPriority(),
          TodayPriority(),
        ],
        moodScore: 7,
        moodDescription: 'private mood description',
        energyScore: 6,
        energyDescription: 'private energy description',
        researchMinutes: 30,
        researchDescription: 'private research description',
        learningMinutes: 0,
        learningDescription: 'private learning description',
        dailyNote: 'private daily note',
        status: TodayRecordStatus.completed,
        createdAt: 1,
        updatedAt: 2,
        health: null,
      ),
    ]);
    health = _HealthRepository([
      const HealthEntry(
        id: 'health-1',
        userId: 'private-user',
        todayRecordId: 'today-1',
        recordDate: '2026-08-21',
        sleepDurationMinutes: 450,
        sleepDescription: 'private sleep description',
        weightKg: 60,
        weightDescription: 'private weight description',
        waterIntakeMl: 1000,
        waterDescription: 'private water description',
        exerciseDurationMinutes: 30,
        exerciseDescription: 'private exercise description',
        exerciseType: 'walk',
        physicalStateScore: 8,
        physicalStateDescription: 'private body description',
        note: 'private health note',
        timezoneOffsetMinutes: 480,
        createdAt: 1,
        updatedAt: 3,
      ),
    ]);
    journals = _JournalRepository(const []);
    assembler = AiChatInputAssemblerImpl(
      consentRepository: consent,
      growthRepository: _GrowthRepository(),
      todayRepository: today,
      healthRepository: health,
      journalRepository: journals,
      dateTimeService: DateTimeService(now: () => DateTime(2026, 8, 21, 9)),
      canonicalJsonEncoder: const CanonicalJsonEncoderImpl(),
      inputHashService: const Sha256InputHashService(),
    );
  });

  test('text-only chat sends no optional business context', () async {
    final bundle = await assembler.build(
      conversationMessages: [_message(0, AiChatRole.user, '只聊这句话。')],
      scopes: const {},
    );

    expect(bundle.periodStartDate, '2026-08-15');
    expect(bundle.periodEndDate, '2026-08-21');
    expect(bundle.canonicalPayload['optional_context'], isEmpty);
    expect(bundle.canonicalPayload['sources'], isEmpty);
    expect(today.calls, 0);
    expect(health.calls, 0);
    expect(journals.calls, 0);
  });

  test(
    'explicit metric context excludes descriptions and private notes',
    () async {
      final bundle = await assembler.build(
        conversationMessages: [_message(0, AiChatRole.user, '看看最近状态。')],
        scopes: const {AiDataScope.todayMetrics, AiDataScope.healthMetrics},
      );
      final context =
          bundle.canonicalPayload['optional_context']! as Map<String, Object?>;
      final todayRow =
          (context['today_metrics']! as List).single as Map<String, Object?>;
      final healthRow =
          (context['health_metrics']! as List).single as Map<String, Object?>;

      expect(todayRow['mood_score'], 7);
      expect(todayRow['learning_minutes'], 0);
      expect(healthRow['physical_state_score'], 8);
      expect(healthRow['water_intake_ml'], 1000);
      expect(bundle.canonicalJson, isNot(contains('private mood description')));
      expect(bundle.canonicalJson, isNot(contains('private body description')));
      expect(bundle.canonicalJson, isNot(contains('private daily note')));
      expect(bundle.canonicalJson, isNot(contains('private health note')));
      expect(bundle.sources, hasLength(2));
    },
  );

  test('history is bounded to the latest alternating user window', () async {
    final history = List<AiChatMessage>.generate(13, (index) {
      return _message(
        index,
        index.isEven ? AiChatRole.user : AiChatRole.assistant,
        'message-$index',
      );
    });

    final bundle = await assembler.build(
      conversationMessages: history,
      scopes: const {},
    );

    expect(bundle.messages, hasLength(11));
    expect(bundle.messages.first.content, 'message-2');
    expect(bundle.messages.last.content, 'message-12');
    expect(bundle.messages.first.role, AiChatRole.user);
    expect(bundle.messages.last.role, AiChatRole.user);
  });

  test('consent and unsupported active goals fail closed', () async {
    consent.enabled = false;
    await expectLater(
      assembler.build(
        conversationMessages: [_message(0, AiChatRole.user, 'hello')],
        scopes: const {},
      ),
      throwsA(isA<AiConsentRequiredException>()),
    );
    consent.enabled = true;
    await expectLater(
      assembler.build(
        conversationMessages: [_message(0, AiChatRole.user, 'hello')],
        scopes: const {AiDataScope.activeGoals},
      ),
      throwsA(isA<UnsupportedAiDataScopeException>()),
    );
  });
}

AiChatMessage _message(int sequence, AiChatRole role, String content) {
  return AiChatMessage(
    id: 'message-$sequence',
    threadId: 'thread-1',
    role: role,
    sequence: sequence,
    content: content,
    requestId: role == AiChatRole.assistant ? 'request-$sequence' : null,
    status: AiChatMessageStatus.completed,
    promptVersion: role == AiChatRole.assistant ? 'coach-chat-v1' : null,
    safetyCategory: role == AiChatRole.assistant
        ? AiChatSafetyCategory.normal
        : null,
    errorCode: null,
    createdAt: sequence,
    updatedAt: sequence,
  );
}

final class _ConsentRepository extends Fake implements AiConsentRepository {
  bool enabled = true;

  @override
  Future<AiDataAuthorization> read() async => enabled
      ? AiDataAuthorization(enabled: true, consentAt: 1)
      : const AiDataAuthorization.disabled();
}

final class _GrowthRepository extends Fake implements GrowthRepository {
  @override
  Future<GrowthSnapshot> loadRecent(GrowthPeriod period) {
    throw StateError('Growth was not selected.');
  }
}

final class _TodayRepository extends Fake implements TodayRepository {
  _TodayRepository(this.entries);

  final List<TodayEntry> entries;
  int calls = 0;

  @override
  Future<List<TodayEntry>> listByDateRange({
    required String startDate,
    required String endDate,
    int? limit,
  }) async {
    calls += 1;
    return entries;
  }
}

final class _HealthRepository extends Fake implements HealthRepository {
  _HealthRepository(this.entries);

  final List<HealthEntry> entries;
  int calls = 0;

  @override
  Future<List<HealthEntry>> listByDateRange({
    required String startDate,
    required String endDate,
  }) async {
    calls += 1;
    return entries;
  }
}

final class _JournalRepository extends Fake implements JournalRepository {
  _JournalRepository(this.entries);

  final List<JournalEntry> entries;
  int calls = 0;

  @override
  Future<List<JournalEntry>> listByDateRange({
    required String startDate,
    required String endDate,
    int? limit,
  }) async {
    calls += 1;
    return entries;
  }
}
