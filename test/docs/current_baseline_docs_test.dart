import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const baselinePath = 'docs/CURRENT_BASELINE.md';
  const releaseReadinessPath = 'docs/RELEASE_READINESS.md';
  const docsIndexPath = 'docs/README.md';
  const manualRegistryPath = 'docs/manual_tests/README.md';
  const personalDataExportContractPath =
      'docs/50_FULL_PERSONAL_DATA_EXPORT_AND_BACKUP.md';
  const personalDataExportMatrixPath =
      'docs/manual_tests/55_full_personal_data_export_and_backup.md';
  const promptGovernancePath =
      'docs/52_PROMPT_GOVERNANCE_AND_QUALITY_EVALUATION.md';
  const promptGovernanceMatrixPath =
      'docs/manual_tests/57_prompt_governance_and_quality_evaluation.md';
  const feedbackContractPath =
      'docs/54_AI_COACH_FEEDBACK_AND_QUALITY_SIGNAL.md';
  const feedbackMatrixPath =
      'docs/manual_tests/59_ai_coach_feedback_and_quality_signal.md';
  const designSystemPath = 'docs/55_PRODUCT_EXPERIENCE_AND_DESIGN_SYSTEM.md';
  const designSystemMatrixPath =
      'docs/manual_tests/60_product_experience_design_system.md';
  const experiencePrototypePath =
      'docs/56_HOME_TODAY_HEALTH_EXPERIENCE_PROTOTYPE.md';
  const experiencePrototypeMatrixPath =
      'docs/manual_tests/61_home_today_health_experience_prototype.md';
  const productionExperiencePath =
      'docs/57_HOME_TODAY_HEALTH_PRODUCTION_INTEGRATION.md';
  const productionExperienceMatrixPath =
      'docs/manual_tests/62_home_today_health_production_integration.md';

  test(
    'project documentation entry points exist and README is not template',
    () {
      final requiredFiles = <String>[
        'README.md',
        baselinePath,
        releaseReadinessPath,
        docsIndexPath,
        manualRegistryPath,
        personalDataExportContractPath,
        personalDataExportMatrixPath,
        promptGovernancePath,
        promptGovernanceMatrixPath,
        feedbackContractPath,
        feedbackMatrixPath,
        designSystemPath,
        designSystemMatrixPath,
        experiencePrototypePath,
        experiencePrototypeMatrixPath,
        productionExperiencePath,
        productionExperienceMatrixPath,
      ];

      for (final path in requiredFiles) {
        expect(File(path).existsSync(), isTrue, reason: '$path should exist');
      }

      final readme = File('README.md').readAsStringSync();
      expect(readme, isNot(contains('A new Flutter project.')));
      expect(readme, isNot(contains('This project is a starting point')));
      expect(readme, isNot(contains('A few resources to get you started')));
      expect(readme, contains('Rebirth'));
      expect(readme, contains('private Alpha'));
    },
  );

  test('baseline versions match source contracts', () {
    final baseline = File(baselinePath).readAsStringSync();
    final databaseSource = File(
      'lib/core/database/app_database.dart',
    ).readAsStringSync();
    final serverSchemas = File('server/app/schemas.py').readAsStringSync();

    final schemaMatch = RegExp(
      r'int get schemaVersion\s*=>\s*(\d+)',
    ).firstMatch(databaseSource);
    final apiMatch = RegExp(
      r'api_version:\s*Literal\[(\d+)\]\s*=\s*(\d+)',
    ).firstMatch(serverSchemas);
    final protocolMatch = RegExp(
      r'sync_protocol_version:\s*Literal\[(\d+)\]\s*=\s*(\d+)',
    ).firstMatch(serverSchemas);

    expect(schemaMatch, isNotNull);
    expect(apiMatch, isNotNull);
    expect(protocolMatch, isNotNull);
    expect(schemaMatch!.group(1), '13');
    expect(apiMatch!.group(1), '1');
    expect(apiMatch.group(2), '1');
    expect(protocolMatch!.group(1), '2');
    expect(protocolMatch.group(2), '2');

    expect(baseline, contains('| Flutter schemaVersion | `13` |'));
    expect(baseline, contains('| API Version | `1` |'));
    expect(baseline, contains('| Sync Protocol Version | `2` |'));
  });

  test('personal data export docs preserve the accepted backup-only Gate', () {
    final baseline = File(baselinePath).readAsStringSync();
    final contract = File(personalDataExportContractPath).readAsStringSync();
    final matrix = File(personalDataExportMatrixPath).readAsStringSync();
    final registry = File(manualRegistryPath).readAsStringSync();

    expect(baseline, contains('Full Personal Data Export'));
    expect(contract, contains('restore_supported'));
    expect(contract, contains('plaintext'));
    expect(contract, contains('does not implement import or restore'));
    expect(matrix, contains('49 PASS / 0 FAIL / 5 NOT EXECUTED'));
    expect(matrix, contains('| PASS |'));
    expect(matrix, contains('| NOT EXECUTED |'));
    expect(registry, contains('Full Personal Data Export'));
    expect(registry, contains('49 / 0 / 5'));
  });

  test('prompt governance docs preserve accepted evidence and cost limits', () {
    final baseline = File(baselinePath).readAsStringSync();
    final contract = File(promptGovernancePath).readAsStringSync();
    final matrix = File(promptGovernanceMatrixPath).readAsStringSync();
    final registry = File(manualRegistryPath).readAsStringSync();

    expect(baseline, contains('Prompt Registry'));
    expect(contract, contains('daily-insight-v1'));
    expect(contract, contains('daily-insight-v2'));
    expect(contract, contains('real Provider evaluation'));
    expect(contract, contains('NOT EXECUTED'));
    expect(matrix, contains('30 PASS / 0 FAIL / 8 NOT EXECUTED'));
    expect(matrix, contains('| PASS |'));
    expect(matrix, contains('| NOT EXECUTED |'));
    expect(matrix, contains('ACCEPTED AUTOMATION AND COST LIMITATIONS'));
    expect(registry, contains('Prompt Governance and Quality Evaluation'));
    expect(registry, contains('30 / 0 / 8'));
  });

  test('baseline and source contain all six manual sync modules', () {
    final baseline = File(baselinePath).readAsStringSync();
    final registry = File(
      'lib/features/sync/application/sync_module_registry.dart',
    ).readAsStringSync();
    const modules = <String>[
      'Profile',
      'Plan',
      'Today',
      'Journal',
      'Health',
      'AI Report',
    ];
    const moduleIds = <String>[
      'profile',
      'plan',
      'today',
      'journal',
      'health',
      'aiReport',
    ];

    for (final module in modules) {
      expect(baseline, contains(module), reason: '$module missing in baseline');
    }
    for (final moduleId in moduleIds) {
      expect(
        registry,
        contains('moduleId: SyncModuleId.$moduleId'),
        reason: '$moduleId missing in source registry',
      );
    }
    expect(RegExp(r'moduleId: SyncModuleId\.').allMatches(registry).length, 6);
  });

  test('feedback docs preserve protocol and honest manual Gate boundaries', () {
    final baseline = File(baselinePath).readAsStringSync();
    final contract = File(feedbackContractPath).readAsStringSync();
    final matrix = File(feedbackMatrixPath).readAsStringSync();
    final registry = File(manualRegistryPath).readAsStringSync();

    expect(baseline, contains('20260812_0008'));
    expect(contract, contains('schemaVersion: `12`'));
    expect(contract, contains('API Version: `1`'));
    expect(contract, contains('Sync Protocol: `2`'));
    expect(contract.toLowerCase(), contains('no free-text'));
    expect(contract, contains('Publishing a GHCR image'));
    expect(matrix, contains('3 PASS / 0 FAIL / 36 NOT EXECUTED'));
    expect(matrix, contains('| PASS |'));
    expect(matrix, contains('| NOT EXECUTED |'));
    expect(registry, contains('AI Coach Feedback & Quality Signal'));
    expect(registry, contains('3 / 0 / 36'));
  });

  test('design system docs preserve product and technical boundaries', () {
    final baseline = File(baselinePath).readAsStringSync();
    final contract = File(designSystemPath).readAsStringSync();
    final matrix = File(designSystemMatrixPath).readAsStringSync();
    final prototype = File(experiencePrototypePath).readAsStringSync();
    final prototypeMatrix = File(
      experiencePrototypeMatrixPath,
    ).readAsStringSync();
    final registry = File(manualRegistryPath).readAsStringSync();

    expect(baseline, contains('17A.1 Revision 1'));
    expect(contract, contains('calm growth workspace'));
    expect(contract, contains('schemaVersion: `12`'));
    expect(contract, contains('API Version: `1`'));
    expect(contract, contains('Sync Protocol: `2`'));
    expect(
      contract,
      contains('Sprint 16B manual acceptance remains suspended'),
    );
    expect(matrix, contains('0 PASS / 0 FAIL / 30 NOT EXECUTED'));
    expect(matrix, isNot(contains('| PASS |')));
    expect(registry, contains('Product Experience Foundation'));
    expect(registry, contains('0 / 0 / 30'));
    expect(prototype, contains('QuickIncrementControl'));
    expect(prototype, contains('WellbeingRatingField'));
    expect(prototype, contains('not mapped to the production 1-5'));
    expect(prototype, contains('developer-only, disposable prototype'));
    expect(prototypeMatrix, contains('81 PASS / 0 FAIL / 0 NOT EXECUTED'));
    expect(prototypeMatrix, contains('| PASS |'));
    expect(prototypeMatrix, isNot(contains('| NOT EXECUTED |')));
    expect(registry, contains('Home / Today / Health Experience Prototype'));
    expect(registry, contains('81 / 0 / 0'));
  });

  test('active entry points do not reintroduce unqualified stale claims', () {
    final activeFiles = <String>[
      'README.md',
      baselinePath,
      releaseReadinessPath,
      docsIndexPath,
      manualRegistryPath,
      'server/README.md',
    ];
    final forbiddenClaims = <String>[
      'Only canonical Profile manual sync is connected',
      'Today, Journal, and Health are not product sync capabilities',
      'There is no public login UI',
      'current only sync Profile',
      'currently only syncs Profile',
    ];

    for (final path in activeFiles) {
      final text = File(path).readAsStringSync();
      for (final claim in forbiddenClaims) {
        expect(
          text.toLowerCase(),
          isNot(contains(claim.toLowerCase())),
          reason: '$path contains stale current-state claim: $claim',
        );
      }
    }

    for (final path in [
      'docs/00_AI_CONTEXT.md',
      'docs/01_PRD.md',
      'docs/02_ARCHITECTURE.md',
      'docs/03_DATABASE.md',
      'docs/04_AUTH_SYNC.md',
      'docs/06_CLOUD_DEPLOYMENT.md',
      'docs/15_ALPHA_GHCR_DEPLOYMENT.md',
      'docs/16_REBIRTH_CLOUD_ALPHA_CONTEXT.md',
    ]) {
      expect(
        File(path).readAsStringSync(),
        contains('CURRENT_BASELINE.md'),
        reason: '$path should point to the current authority',
      );
    }
  });

  test(
    'canonical documentation contains no credential material or public IP',
    () {
      final canonicalFiles = <String>[
        'README.md',
        baselinePath,
        releaseReadinessPath,
        docsIndexPath,
        manualRegistryPath,
      ];
      final privateKey = RegExp(r'-----BEGIN [A-Z ]*PRIVATE KEY-----');
      final githubToken = RegExp(r'\bgh[pousr]_[A-Za-z0-9_]{20,}\b');
      final jwt = RegExp(r'\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.');
      final authorizationHeader = RegExp(
        r'^\s*Authorization\s*:',
        caseSensitive: false,
        multiLine: true,
      );
      final ipv4 = RegExp(r'(?<![\d.])(?:\d{1,3}\.){3}\d{1,3}(?![\d.])');

      for (final path in canonicalFiles) {
        final text = File(path).readAsStringSync();
        expect(
          text,
          isNot(matches(privateKey)),
          reason: '$path has a key block',
        );
        expect(text, isNot(matches(githubToken)), reason: '$path has a token');
        expect(text, isNot(matches(jwt)), reason: '$path has a JWT-like value');
        expect(
          text,
          isNot(matches(authorizationHeader)),
          reason: '$path has an Authorization header',
        );

        for (final match in ipv4.allMatches(text)) {
          final address = match.group(0)!;
          expect(
            _isNonPublicIpv4(address),
            isTrue,
            reason: '$path contains public IPv4 address $address',
          );
        }
      }
    },
  );

  test('repository Markdown file links resolve locally', () {
    final files = <File>[
      File('README.md'),
      File('server/README.md'),
      ...Directory('docs')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.toLowerCase().endsWith('.md')),
    ]..sort((left, right) => left.path.compareTo(right.path));
    final markdownLink = RegExp(r'\[[^\]]+\]\(([^)]+)\)');

    for (final source in files) {
      final text = source.readAsStringSync();
      for (final match in markdownLink.allMatches(text)) {
        final target = match.group(1)!.trim().replaceAll(RegExp(r'^<|>$'), '');
        if (_isExternalOrAnchor(target)) {
          continue;
        }
        final pathOnly = Uri.decodeComponent(target.split('#').first);
        final resolvedFile = File('${source.parent.path}/$pathOnly');
        final resolvedDirectory = Directory('${source.parent.path}/$pathOnly');
        expect(
          resolvedFile.existsSync() || resolvedDirectory.existsSync(),
          isTrue,
          reason: '${source.path} links to missing file $target',
        );
      }
    }
  });

  test('production experience docs keep the new manual Gate honest', () {
    final baseline = File(baselinePath).readAsStringSync();
    final contract = File(productionExperiencePath).readAsStringSync();
    final matrix = File(productionExperienceMatrixPath).readAsStringSync();
    final registry = File(manualRegistryPath).readAsStringSync();

    expect(baseline, contains('17B Home / Today / Health'));
    expect(contract, contains('schema 12 to 13'));
    expect(contract, contains('oldScore * 2'));
    expect(contract, contains('API Version 1'));
    expect(contract, contains('Sync Protocol 2'));
    expect(matrix, contains('40 PASS / 0 FAIL / 11 NOT EXECUTED'));
    expect(
      RegExp(r'^\| [A-G]\d+ \|', multiLine: true).allMatches(matrix),
      hasLength(51),
    );
    expect(matrix, contains('| E1 | Cross-device'));
    expect(matrix, contains('| PASS | Passed after fixed API deployment'));
    expect(matrix, contains('Cross-device E1-E6 passed'));
    expect(matrix, contains('Gate: **OPEN**'));
    expect(registry, contains('Home / Today / Health Production Integration'));
    expect(registry, contains('40 / 0 / 11'));
  });
}

bool _isExternalOrAnchor(String target) {
  final lower = target.toLowerCase();
  return target.startsWith('#') ||
      lower.startsWith('http://') ||
      lower.startsWith('https://') ||
      lower.startsWith('mailto:');
}

bool _isNonPublicIpv4(String address) {
  final octets = address.split('.').map(int.parse).toList(growable: false);
  if (octets.any((octet) => octet < 0 || octet > 255)) {
    return true;
  }
  final first = octets[0];
  final second = octets[1];
  return first == 10 ||
      first == 127 ||
      (first == 169 && second == 254) ||
      (first == 172 && second >= 16 && second <= 31) ||
      (first == 192 && second == 168) ||
      (first == 192 && second == 0 && octets[2] == 2) ||
      (first == 198 && second == 51 && octets[2] == 100) ||
      (first == 203 && second == 0 && octets[2] == 113);
}
