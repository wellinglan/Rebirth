@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/network/api_client.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/account/data/auth_session_store.dart';
import 'package:rebirth/features/account/domain/auth_session.dart';
import 'package:rebirth/features/account/domain/auth_user.dart';
import 'package:rebirth/features/ai_coach/data/canonical_json_encoder_impl.dart';
import 'package:rebirth/features/ai_coach/data/local_ai_consent_repository.dart';
import 'package:rebirth/features/ai_coach/data/local_ai_report_repository.dart';
import 'package:rebirth/features/ai_coach/data/remote_ai_generation_gateway.dart';
import 'package:rebirth/features/ai_coach/domain/ai_coach_input_bundle.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_scope.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_selection.dart';
import 'package:rebirth/features/ai_coach/domain/ai_generation_gateway.dart';
import 'package:rebirth/features/ai_coach/domain/ai_generation_request_binding.dart';
import 'package:rebirth/features/ai_coach/domain/ai_input_source_ref.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_status.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_type.dart';

void main() {
  final enabled = Platform.environment['REBIRTH_RUN_FAKE_FULL_STACK'] == '1';

  test(
    'Dio JWT ledger Fake Provider and local report lifecycle complete',
    () async {
      final baseUrl =
          Platform.environment['REBIRTH_FAKE_FULL_STACK_URL'] ??
          'http://127.0.0.1:8000';
      final api = DioApiClient(baseUrl: baseUrl);
      final login = await api.postJson(
        '/auth/dev-login',
        body: {'dev_user_key': 'flutter-full-stack-ledger'},
      );
      final userJson = Map<String, Object?>.from(login['user']! as Map);
      final session = AuthSession(
        accessToken: login['access_token']! as String,
        refreshToken: login['refresh_token']! as String,
        serverBaseUrl: baseUrl,
        user: AuthUser(
          id: userJson['id']! as String,
          displayName: userJson['display_name'] as String?,
        ),
      );
      final sessions = _MemorySessionStore();
      await sessions.save(session);

      final fixture = Map<String, Object?>.from(
        jsonDecode(
              File('test/fixtures/ai_weekly_input_v1.json').readAsStringSync(),
            )
            as Map,
      );
      final hash = File(
        'test/fixtures/ai_weekly_input_v1_expected_hash.txt',
      ).readAsStringSync().trim();
      final rawSources = fixture['sources']! as List;
      final scopes = (fixture['scopes']! as List)
          .cast<String>()
          .map(
            (value) => AiDataScope.values.firstWhere(
              (scope) => scope.contractValue == value,
            ),
          )
          .toSet();
      const requestId = '91111111-2222-4333-8444-555555555555';
      final bundle = AiCoachInputBundle(
        reportType: AiReportType.weeklyReport,
        promptVersion: 'weekly-report-v1',
        periodStartDate: '2026-07-10',
        periodEndDate: '2026-07-16',
        selection: AiDataSelection(scopes: scopes),
        sources: rawSources.map((value) {
          final source = Map<String, Object?>.from(value as Map);
          return AiInputSourceRef(
            table: source['table']! as String,
            id: source['id']! as String,
            updatedAt: source['updated_at']! as int,
          );
        }).toList(growable: false),
        canonicalPayload: fixture,
        canonicalJson: jsonEncode(fixture),
        inputHash: hash,
      );

      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final time = DateTimeService(now: () => DateTime(2026, 7, 16, 12));
      final consent = LocalAiConsentRepository(
        database: database,
        dateTimeService: time,
      );
      await consent.grant();
      final reports = LocalAiReportRepository(
        database: database,
        dateTimeService: time,
        consentRepository: consent,
        canonicalJsonEncoder: const CanonicalJsonEncoderImpl(),
        idFactory: () => requestId,
      );
      final bindings = _MemoryBindingStore();
      final pending = await reports.createPending(input: bundle);
      await bindings.save(
        AiGenerationRequestBinding(
          localReportId: pending.id,
          requestId: pending.id,
          normalizedEndpoint: baseUrl,
          cloudUserId: session.user.id,
          inputHash: hash,
          reportType: 'weekly_report',
          promptVersion: 'weekly-report-v1',
          createdAt: pending.createdAt,
        ),
      );

      final gateway = RemoteAiGenerationGateway(
        apiClient: api,
        sessionStore: sessions,
      );
      final capabilities = await gateway.getCapabilities();
      expect(capabilities.durableRequestLedger, isTrue);
      final remote = await gateway.generateWeekly(
        requestId: pending.id,
        bundle: bundle,
      );
      expect(remote.status, AiRemoteRequestStatus.completed);
      final completed = remote.completedResult!;
      await reports.markCompleted(
        reportId: pending.id,
        reportContent: completed.reportContent,
        structuredOutputJson: completed.structuredOutputJson,
        provider: completed.provider,
        model: completed.model,
      );
      await bindings.delete(pending.id);

      final history = await reports.listRecent();
      expect(history.single.status, AiReportStatus.completed);
      expect(history.single.reportContent, startsWith('# 开发测试每周回顾'));
      expect(await bindings.read(pending.id), isNull);
      final recovered = await gateway.getRequestStatus(
        requestId: requestId,
        inputHash: hash,
        reportType: 'weekly_report',
        promptVersion: 'weekly-report-v1',
      );
      expect(recovered.status, AiRemoteRequestStatus.completed);
    },
    skip: enabled ? false : 'Set REBIRTH_RUN_FAKE_FULL_STACK=1 with Uvicorn.',
  );
}

final class _MemorySessionStore implements AuthSessionStore {
  AuthSession? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<AuthSession?> read() async => value;

  @override
  Future<void> save(AuthSession session) async => value = session;
}

final class _MemoryBindingStore implements AiGenerationRequestBindingStore {
  final Map<String, AiGenerationRequestBinding> values = {};

  @override
  Future<void> delete(String localReportId) async {
    values.remove(localReportId);
  }

  @override
  Future<AiGenerationRequestBinding?> read(String localReportId) async =>
      values[localReportId];

  @override
  Future<List<AiGenerationRequestBinding>> readAll() async =>
      List.unmodifiable(values.values);

  @override
  Future<void> save(AiGenerationRequestBinding binding) async {
    values[binding.localReportId] = binding;
  }
}
