import 'dart:async';

import 'package:rebirth/features/account/data/auth_session_store.dart';
import 'package:rebirth/features/account/domain/auth_session.dart';
import 'package:rebirth/features/ai_coach/domain/ai_coach_input_assembler.dart';
import 'package:rebirth/features/ai_coach/domain/ai_coach_input_bundle.dart';
import 'package:rebirth/features/ai_coach/domain/ai_consent_repository.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_authorization.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_scope.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_selection.dart';
import 'package:rebirth/features/ai_coach/domain/ai_generation_mode.dart';
import 'package:rebirth/features/ai_coach/domain/ai_generation_gateway.dart';
import 'package:rebirth/features/ai_coach/domain/ai_generation_request_binding.dart';
import 'package:rebirth/features/ai_coach/domain/ai_input_source_ref.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_repository.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_status.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_type.dart';

final class FakeAiConsentRepository implements AiConsentRepository {
  FakeAiConsentRepository({required this.authorization});

  AiDataAuthorization authorization;
  Object? readError;
  int readCalls = 0;
  int grantCalls = 0;
  int revokeCalls = 0;

  @override
  Future<AiDataAuthorization> read() async {
    readCalls += 1;
    if (readError case final error?) throw error;
    return authorization;
  }

  @override
  Future<AiDataAuthorization> grant() async {
    grantCalls += 1;
    return authorization = AiDataAuthorization(
      enabled: true,
      consentAt: 1784163600000,
    );
  }

  @override
  Future<AiDataAuthorization> revoke() async {
    revokeCalls += 1;
    return authorization = AiDataAuthorization(
      enabled: false,
      consentAt: authorization.consentAt,
    );
  }
}

final class FakeAiCoachInputAssembler implements AiCoachInputAssembler {
  FakeAiCoachInputAssembler({AiCoachInputBundle? bundle})
    : bundle = bundle ?? buildAiBundle();

  AiCoachInputBundle bundle;
  Object? error;
  final List<Future<AiCoachInputBundle>> queuedResponses = [];
  final List<AiDataSelection> selections = [];
  int buildCalls = 0;

  @override
  Future<AiCoachInputBundle> build({
    required AiReportType reportType,
    required AiDataSelection selection,
  }) {
    return buildWeeklyReport(selection: selection);
  }

  @override
  Future<AiCoachInputBundle> buildWeeklyReport({
    required AiDataSelection selection,
  }) async {
    buildCalls += 1;
    selections.add(selection);
    if (queuedResponses.isNotEmpty) {
      return queuedResponses.removeAt(0);
    }
    if (error case final value?) throw value;
    return bundle;
  }

  @override
  Future<AiCoachInputBundle> buildDailyInsight({
    required String targetDate,
    required AiDataSelection selection,
  }) async {
    buildCalls += 1;
    selections.add(selection);
    if (queuedResponses.isNotEmpty) {
      return queuedResponses.removeAt(0);
    }
    if (error case final value?) throw value;
    return bundle;
  }
}

final class FakeAiReportRepository implements AiReportRepository {
  FakeAiReportRepository({List<AiReport> reports = const []})
    : reports = [...reports];

  List<AiReport> reports;
  AiReport? reusable;
  Object? listError;
  Object? deleteError;
  int findCalls = 0;
  int listCalls = 0;
  int getCalls = 0;
  int deleteCalls = 0;
  int createPendingCalls = 0;
  int markCompletedCalls = 0;
  int markFailedCalls = 0;
  String? lastDeletedId;
  String? lastReusableHash;
  String? lastReusablePromptVersion;
  AiCoachInputBundle? lastPendingInput;
  String? lastCompletedId;
  String? lastFailedId;
  String? lastFailureCode;
  String? lastStructuredOutput;

  @override
  Future<AiReport?> findReusableCompleted({
    required AiReportType reportType,
    required String periodStartDate,
    required String periodEndDate,
    required String promptVersion,
    required String inputHash,
  }) async {
    findCalls += 1;
    lastReusableHash = inputHash;
    lastReusablePromptVersion = promptVersion;
    return reusable;
  }

  @override
  Future<List<AiReport>> listRecent({int limit = 20}) async {
    listCalls += 1;
    if (listError case final error?) throw error;
    return List<AiReport>.unmodifiable(reports.take(limit));
  }

  @override
  Future<List<AiReport>> listPending() async => reports
      .where((report) => report.status == AiReportStatus.pending)
      .toList(growable: false);

  @override
  Future<AiReport?> getById(String id) async {
    getCalls += 1;
    return reports.where((report) => report.id == id).firstOrNull;
  }

  @override
  Future<void> softDelete(String id) async {
    deleteCalls += 1;
    lastDeletedId = id;
    if (deleteError case final error?) throw error;
    reports.removeWhere((report) => report.id == id);
  }

  @override
  Future<AiReport> createPending({required AiCoachInputBundle input}) async {
    createPendingCalls += 1;
    lastPendingInput = input;
    final report = buildAiReport(
      id: 'pending-$createPendingCalls',
      status: AiReportStatus.pending,
    );
    reports.insert(0, report);
    return report;
  }

  @override
  Future<AiReport> markCompleted({
    required String reportId,
    required String reportContent,
    String? structuredOutputJson,
    String? provider,
    String? model,
  }) async {
    markCompletedCalls += 1;
    lastCompletedId = reportId;
    lastStructuredOutput = structuredOutputJson;
    final report = _replace(
      reportId,
      status: AiReportStatus.completed,
      reportContent: reportContent,
      structuredOutputJson: structuredOutputJson,
      provider: provider,
      model: model,
    );
    return report;
  }

  @override
  Future<AiReport> markFailed({
    required String reportId,
    required String errorCode,
  }) async {
    markFailedCalls += 1;
    lastFailedId = reportId;
    lastFailureCode = errorCode;
    return _replace(
      reportId,
      status: AiReportStatus.failed,
      errorCode: errorCode,
    );
  }

  AiReport _replace(
    String id, {
    required AiReportStatus status,
    String? reportContent,
    String? structuredOutputJson,
    String? provider,
    String? model,
    String? errorCode,
  }) {
    final index = reports.indexWhere((report) => report.id == id);
    final existing = reports[index];
    final updated = AiReport(
      id: existing.id,
      userId: existing.userId,
      reportType: existing.reportType,
      periodStartDate: existing.periodStartDate,
      periodEndDate: existing.periodEndDate,
      inputSources: existing.inputSources,
      inputHash: existing.inputHash,
      promptVersion: existing.promptVersion,
      provider: provider,
      model: model,
      generationMode: existing.generationMode,
      status: status,
      reportContent: reportContent,
      structuredOutputJson: structuredOutputJson,
      hasInputSnapshot: existing.hasInputSnapshot,
      errorCode: errorCode,
      requestedAt: existing.requestedAt,
      generatedAt: status == AiReportStatus.completed
          ? existing.requestedAt + 1000
          : null,
      createdAt: existing.createdAt,
      updatedAt: existing.updatedAt + 1000,
    );
    reports[index] = updated;
    return updated;
  }
}

final class FakeAiGenerationGateway implements AiGenerationGateway {
  FakeAiGenerationGateway({AiGenerationCapabilities? capabilities})
    : capabilities =
          capabilities ??
          AiGenerationCapabilities(
            enabled: true,
            provider: 'fake',
            providerLabel: 'Development Fake',
            model: 'deterministic-test-provider',
            supportedReportTypes: const ['weekly_report'],
            promptVersions: const ['weekly-report-v1'],
            inputSchemaVersion: 1,
            outputSchemaVersion: 1,
            streaming: false,
            responseStorageRequested: false,
          );

  AiGenerationCapabilities capabilities;
  Object? capabilitiesError;
  Object? generationError;
  Object? statusError;
  AiRemoteRequestResult? statusResult;
  Completer<AiRemoteRequestResult>? statusCompleter;
  int capabilitiesCalls = 0;
  int generationCalls = 0;
  int statusCalls = 0;
  String? lastRequestId;
  AiCoachInputBundle? lastBundle;

  @override
  Future<AiGenerationCapabilities> getCapabilities() async {
    capabilitiesCalls += 1;
    if (capabilitiesError case final error?) throw error;
    return capabilities;
  }

  @override
  Future<AiRemoteRequestResult> generateWeekly({
    required String requestId,
    required AiCoachInputBundle bundle,
  }) async {
    generationCalls += 1;
    lastRequestId = requestId;
    lastBundle = bundle;
    if (generationError case final error?) throw error;
    final completed = AiGenerationResult(
      requestId: requestId,
      reportType: 'weekly_report',
      promptVersion: bundle.promptVersion,
      inputHash: bundle.inputHash,
      provider: 'fake',
      model: 'deterministic-test-provider',
      outputSchemaVersion: 1,
      reportContent: '# 开发测试每周回顾',
      structuredOutputJson:
          '{"title":"测试","summary":"测试摘要","observations":[],"suggestions":[],"data_limitations":[]}',
    );
    return AiRemoteRequestResult(
      status: AiRemoteRequestStatus.completed,
      requestId: requestId,
      inputHash: bundle.inputHash,
      reportType: 'weekly_report',
      promptVersion: bundle.promptVersion,
      completedResult: completed,
    );
  }

  @override
  Future<AiRemoteRequestResult> generateDaily({
    required String requestId,
    required AiCoachInputBundle bundle,
  }) {
    return generateWeekly(requestId: requestId, bundle: bundle);
  }

  @override
  Future<AiRemoteRequestResult> getRequestStatus({
    required String requestId,
    required String inputHash,
    required String reportType,
    required String promptVersion,
  }) async {
    statusCalls += 1;
    if (statusError case final error?) throw error;
    if (statusCompleter case final completer?) return completer.future;
    if (statusResult case final result?) return result;
    return AiRemoteRequestResult(
      status: AiRemoteRequestStatus.processing,
      requestId: requestId,
      inputHash: inputHash,
      reportType: reportType,
      promptVersion: promptVersion,
    );
  }
}

final class FakeAiGenerationRequestBindingStore
    implements AiGenerationRequestBindingStore {
  final Map<String, AiGenerationRequestBinding> values = {};
  Object? saveError;
  int saveCalls = 0;
  int deleteCalls = 0;

  @override
  Future<void> save(AiGenerationRequestBinding binding) async {
    saveCalls += 1;
    if (saveError case final error?) throw error;
    values[binding.localReportId] = binding;
  }

  @override
  Future<AiGenerationRequestBinding?> read(String localReportId) async =>
      values[localReportId];

  @override
  Future<List<AiGenerationRequestBinding>> readAll() async =>
      List.unmodifiable(values.values);

  @override
  Future<void> delete(String localReportId) async {
    deleteCalls += 1;
    values.remove(localReportId);
  }
}

final class FakeAuthSessionStore implements AuthSessionStore {
  FakeAuthSessionStore({this.session});

  AuthSession? session;

  @override
  Future<AuthSession?> read() async => session;

  @override
  Future<void> save(AuthSession session) async => this.session = session;

  @override
  Future<void> clear() async => session = null;
}

AiCoachInputBundle buildAiBundle({
  Set<AiDataScope>? scopes,
  String hash =
      '12345678aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa87654321',
  String canonicalJson = '{"journal":"private canonical content"}',
}) {
  final selected =
      scopes ?? AiDataScope.values.where((scope) => scope.supported).toSet();
  final data = <String, Object?>{};
  if (selected.contains(AiDataScope.growthSummary)) {
    data['growth_summary'] = {
      'period_days': 7,
      'research': {'recorded_day_count': 0, 'total': 0, 'average': null},
      'learning': {'recorded_day_count': 1, 'total': 0, 'average': 0.0},
      'exercise': {'recorded_day_count': 2, 'total': 45, 'average': 22.5},
      'sleep': {'recorded_day_count': 1, 'total': 420, 'average': 420.0},
      'mood': {'recorded_day_count': 1, 'total': 4, 'average': 4.0},
      'energy': {'recorded_day_count': 0, 'total': 0, 'average': null},
      'journal_recorded_days': 2,
      'journal_completed_days': 1,
    };
  }
  if (selected.contains(AiDataScope.todayMetrics)) {
    data['today_metrics'] = [
      {
        'record_date': '2026-07-16',
        'research_minutes': 30,
        'learning_minutes': null,
        'mood_score': 4,
        'energy_score': 3,
        'populated_priority_count': 2,
        'completed_priority_count': 1,
        'status': 'completed',
        'daily_note': 'excluded private note',
        'priority_text': 'excluded private priority',
      },
      {
        'record_date': '2026-07-10',
        'research_minutes': 0,
        'learning_minutes': 60,
        'mood_score': null,
        'energy_score': null,
        'populated_priority_count': 0,
        'completed_priority_count': 0,
        'status': 'draft',
      },
    ];
  }
  if (selected.contains(AiDataScope.healthMetrics)) {
    data['health_metrics'] = [
      {
        'record_date': '2026-07-16',
        'sleep_duration_minutes': 450,
        'exercise_duration_minutes': 30,
        'physical_state_score': 4,
        'water_intake_ml': 1800,
        'weight_kg': 65.5,
        'note': 'excluded health note',
        'source_record_id': 'excluded-source-id',
      },
    ];
  }
  if (selected.contains(AiDataScope.journalReflections)) {
    data['journal_reflections'] = [
      {
        'entry_date': '2026-07-16',
        'status': 'completed',
        'most_important_accomplishment': '完成核心任务',
        'most_draining_event': '一段私人经历',
        'emotion_source': '关系变化',
        'learning': '  ',
        'tomorrow_adjustment': '早点休息',
      },
      {
        'entry_date': '2026-07-10',
        'status': 'draft',
        'most_important_accomplishment': null,
        'most_draining_event': null,
        'emotion_source': null,
        'learning': '保持耐心',
        'tomorrow_adjustment': null,
      },
    ];
  }
  return AiCoachInputBundle(
    reportType: AiReportType.weeklyReport,
    promptVersion: 'weekly-report-v1',
    periodStartDate: '2026-07-10',
    periodEndDate: '2026-07-16',
    selection: AiDataSelection(scopes: selected),
    sources: [
      AiInputSourceRef(table: 'today_records', id: 'private-id', updatedAt: 1),
    ],
    canonicalPayload: {
      'schema_version': 1,
      'report_type': 'weekly_report',
      'prompt_version': 'weekly-report-v1',
      'period': {'start_date': '2026-07-10', 'end_date': '2026-07-16'},
      'scopes': selected.map((scope) => scope.contractValue).toList(),
      'data': data,
      'sources': const [],
      'user_id': 'excluded-user',
      'device_id': 'excluded-device',
      'endpoint': 'https://excluded.invalid',
      'sync_status': 'excluded-sync',
    },
    canonicalJson: canonicalJson,
    inputHash: hash,
  );
}

AiReport buildAiReport({
  required String id,
  AiReportStatus status = AiReportStatus.completed,
  int requestedAt = 1784163600000,
  bool hasInputSnapshot = false,
  String? provider = 'local-fixture-provider',
  String? model = 'local-fixture-model',
}) {
  return AiReport(
    id: id,
    userId: 'private-user-id',
    reportType: AiReportType.weeklyReport,
    periodStartDate: '2026-07-10',
    periodEndDate: '2026-07-16',
    inputSources: [
      AiInputSourceRef(table: 'today_records', id: 'source-id', updatedAt: 1),
    ],
    inputHash:
        '12345678aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa87654321',
    promptVersion: 'weekly-report-v1',
    provider: provider,
    model: model,
    generationMode: AiGenerationMode.manual,
    status: status,
    reportContent: status == AiReportStatus.completed ? '这是本地保存的报告正文。' : null,
    structuredOutputJson: status == AiReportStatus.completed
        ? '{"private":"not displayed"}'
        : null,
    hasInputSnapshot: hasInputSnapshot,
    errorCode: status == AiReportStatus.failed ? 'request_failed' : null,
    requestedAt: requestedAt,
    generatedAt: status == AiReportStatus.completed ? requestedAt + 1000 : null,
    createdAt: requestedAt,
    updatedAt: requestedAt + 1000,
  );
}
