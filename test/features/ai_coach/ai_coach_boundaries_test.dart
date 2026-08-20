import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AI Coach domain remains pure Dart', () {
    final sources = _dartSources('lib/features/ai_coach/domain');
    for (final source in sources) {
      expect(source, isNot(contains('package:flutter')));
      expect(source, isNot(contains('package:drift')));
      expect(source, isNot(contains('package:dio')));
      expect(source, isNot(contains('app_database')));
    }
  });

  test('AI gateway contains no vendor URL or provider API key path', () {
    final sources = _dartSources('lib');
    for (final source in sources) {
      expect(source, isNot(contains('api.openai.com')));
      expect(source, isNot(contains('OPENAI_API_KEY')));
    }
  });

  test('schema version 13 keeps AI presentation boundaries', () {
    final database = File(
      'lib/core/database/app_database.dart',
    ).readAsStringSync();
    expect(database, contains('int get schemaVersion => 14;'));
    final presentation = [
      ..._dartSources('lib/features/ai_coach/presentation/widgets'),
      File(
        'lib/features/ai_coach/presentation/ai_coach_page.dart',
      ).readAsStringSync(),
      File(
        'lib/features/ai_coach/presentation/ai_report_detail_page.dart',
      ).readAsStringSync(),
      File(
        'lib/features/ai_coach/presentation/ai_daily_insight_page.dart',
      ).readAsStringSync(),
      File(
        'lib/features/ai_coach/presentation/ai_weekly_report_page.dart',
      ).readAsStringSync(),
    ];
    expect(presentation, isNotEmpty);
    for (final source in presentation) {
      expect(source, isNot(contains('package:drift')));
      expect(source, isNot(contains('app_database')));
      expect(source, isNot(contains('local_ai_')));
      expect(source, isNot(contains('core/network')));
      expect(source, isNot(contains('ApiClient')));
      expect(source, isNot(contains('createPending(')));
      expect(source, isNot(contains('markCompleted(')));
      expect(source, isNot(contains('markFailed(')));
      expect(source, isNot(contains('DateTime.now')));
    }
  });

  test('AI Coach UI does not expose canonical JSON or snapshot bodies', () {
    final presentation = _dartSources('lib/features/ai_coach/presentation');
    for (final source in presentation) {
      expect(source, isNot(contains('.canonicalJson')));
      expect(source, isNot(contains('inputSnapshotJson')));
    }
  });

  test('AI Coach home hides engineering identity and account state is reset', () {
    final home = File(
      'lib/features/ai_coach/presentation/ai_coach_page.dart',
    ).readAsStringSync();
    for (final term in [
      'Prompt Version',
      'Input Hash',
      'Request Binding',
      'Generation Gateway',
    ]) {
      expect(home, isNot(contains(term)));
    }

    final invalidator = File(
      'lib/features/account/presentation/account_scoped_provider_invalidator.dart',
    ).readAsStringSync();
    for (final provider in [
      'aiUsageControllerProvider',
      'aiRequestPreviewControllerFamily',
      'aiManualGenerationControllerFamily',
      'aiPendingRecoveryControllerProvider',
      'aiReportHistoryControllerProvider',
      'aiReportFeedbackProvider',
      'aiReportFeedbackControllerFamily',
    ]) {
      expect(invalidator, contains('ref.invalidate($provider)'));
    }
  });

  test('structured feedback appears only on report detail surfaces', () {
    final feedbackCard = File(
      'lib/features/ai_coach/presentation/widgets/ai_report_feedback_card.dart',
    ).readAsStringSync();
    expect(feedbackCard, isNot(contains('TextField(')));
    expect(feedbackCard, isNot(contains('TextFormField(')));
    expect(feedbackCard, contains('AiReportFeedbackReason.values'));

    for (final path in [
      'lib/features/ai_coach/presentation/ai_coach_page.dart',
      'lib/features/ai_reports/presentation/ai_report_library_page.dart',
      'lib/features/settings/presentation/settings_page.dart',
    ]) {
      expect(
        File(path).readAsStringSync(),
        isNot(contains('AiReportFeedbackCard')),
      );
    }
    expect(
      File(
        'lib/features/ai_coach/presentation/ai_report_detail_page.dart',
      ).readAsStringSync(),
      contains('AiReportFeedbackCard'),
    );
    final detail = File(
      'lib/features/ai_coach/presentation/ai_report_detail_page.dart',
    ).readAsStringSync();
    for (final technicalLabel in [
      'Prompt Version',
      'Input Hash',
      "label: 'Provider'",
      "label: 'Model'",
      'Request ID',
    ]) {
      expect(detail, isNot(contains(technicalLabel)));
    }
  });

  test(
    'feedback uses a dedicated JWT API without changing Sync Protocol 2',
    () {
      final remote = File(
        'lib/features/ai_coach/data/remote_ai_report_feedback_data_source.dart',
      ).readAsStringSync();
      expect(remote, contains("'/ai/report-feedback"));
      expect(remote, isNot(contains("'user_id'")));
      expect(remote, isNot(contains("'cloud_user_id'")));
      expect(remote, isNot(contains("'report_content'")));
      expect(remote, isNot(contains("'prompt_text'")));

      final entityTypes = File(
        'lib/features/sync/domain/sync_entity_type.dart',
      ).readAsStringSync();
      expect(entityTypes, isNot(contains('aiReportFeedback')));
      final syncController = File(
        'lib/features/sync/presentation/ai_report_sync_controller.dart',
      ).readAsStringSync();
      expect(syncController, contains('aiReportFeedbackSyncServiceProvider'));
    },
  );

  test('fake AI report generation service is not production composition', () {
    final productionSources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where(
          (file) => !file.path
              .replaceAll('\\', '/')
              .endsWith(
                'lib/features/ai_coach/data/fake_ai_report_generation_service.dart',
              ),
        )
        .map((file) => file.readAsStringSync());
    for (final source in productionSources) {
      expect(source, isNot(contains('FakeAiReportGenerationService')));
    }
  });
}

Iterable<String> _dartSources(String path) {
  return Directory(path)
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .map((file) => file.readAsStringSync());
}
