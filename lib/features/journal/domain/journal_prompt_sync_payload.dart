import 'package:rebirth/features/sync/domain/sync_models.dart';

import 'journal_prompt.dart';

final class JournalPromptConfigurationSyncPayload implements SyncEntityPayload {
  JournalPromptConfigurationSyncPayload({
    required this.logicalKey,
    required this.configurationVersion,
    required this.createdAt,
    required List<JournalPromptDefinition> prompts,
  }) : prompts = List.unmodifiable(prompts);

  static const payloadSchemaVersion = 1;

  final String logicalKey;
  final int configurationVersion;
  final int createdAt;
  final List<JournalPromptDefinition> prompts;
}
