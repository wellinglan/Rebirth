import 'package:drift/drift.dart';
import 'package:rebirth/core/database/app_database.dart' as db;
import 'package:rebirth/core/journal/journal_prompt_catalog.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/journal/domain/journal_prompt.dart';
import 'package:rebirth/features/journal/domain/journal_prompt_repository.dart';
import 'package:uuid/uuid.dart';

final class JournalPromptRepositoryImpl implements JournalPromptRepository {
  JournalPromptRepositoryImpl({
    required this.database,
    required this.dateTimeService,
    this.uuid = const Uuid(),
  });

  final db.AppDatabase database;
  final DateTimeService dateTimeService;
  final Uuid uuid;

  @override
  Future<JournalPromptConfiguration> ensureInitialized() {
    return ensureInitializedAt(
      dateTimeService.currentSnapshot().utcMilliseconds,
    );
  }

  Future<JournalPromptConfiguration> ensureInitializedAt(int timestamp) {
    return database.transaction(() async {
      final bootstrap = await database.bootstrapDao.bootstrap();
      final existing = await _selectConfiguration(bootstrap.activeUserId);
      if (existing != null) {
        return _loadAggregate(existing);
      }

      final configurationId = uuid.v4();
      await database
          .into(database.journalPromptConfigurations)
          .insert(
            db.JournalPromptConfigurationsCompanion.insert(
              id: Value(configurationId),
              userId: bootstrap.activeUserId,
              configurationVersion: const Value(1),
              createdAt: Value(timestamp),
              updatedAt: Value(timestamp),
              syncStatus: const Value('local_only'),
              originDeviceId: Value(bootstrap.localInstallationId),
            ),
          );
      for (final prompt in JournalPromptCatalog.prompts) {
        await database
            .into(database.journalPromptDefinitions)
            .insert(
              db.JournalPromptDefinitionsCompanion.insert(
                id: Value(uuid.v4()),
                configurationId: configurationId,
                stableKey: Value(prompt.stableKey),
                promptSource: JournalPromptSource.system.wireName,
                questionText: prompt.questionText,
                helperText: Value(prompt.helperText),
                displayOrder: prompt.displayOrder,
                promptVersion: const Value(1),
                createdAt: Value(timestamp),
                updatedAt: Value(timestamp),
              ),
            );
      }
      return _loadAggregate(
        (await _selectConfiguration(bootstrap.activeUserId))!,
      );
    });
  }

  @override
  Future<JournalPromptConfiguration> getConfiguration() {
    return ensureInitialized();
  }

  @override
  Future<JournalPromptConfiguration> createUserPrompt(
    JournalPromptInput input,
  ) {
    return _mutate((configuration, prompts, now) async {
      _requireCapacity(prompts);
      final normalized = _normalizeInput(input);
      final order = prompts
          .where((prompt) => !prompt.isDeleted && prompt.isEnabled)
          .fold<int>(
            -1,
            (highest, prompt) =>
                prompt.displayOrder > highest ? prompt.displayOrder : highest,
          );
      await database
          .into(database.journalPromptDefinitions)
          .insert(
            db.JournalPromptDefinitionsCompanion.insert(
              id: Value(uuid.v4()),
              configurationId: configuration.id,
              promptSource: JournalPromptSource.user.wireName,
              questionText: normalized.questionText,
              helperText: Value(normalized.helperText),
              displayOrder: order + 1,
              promptVersion: const Value(1),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      return true;
    });
  }

  @override
  Future<JournalPromptConfiguration> updateUserPrompt(
    String promptId,
    JournalPromptInput input,
  ) {
    return _mutate((configuration, prompts, now) async {
      final prompt = _requirePrompt(prompts, promptId);
      if (!prompt.isUser || prompt.isDeleted) {
        throw const JournalPromptOperationException();
      }
      final normalized = _normalizeInput(input);
      await (database.update(database.journalPromptDefinitions)..where(
            (row) =>
                row.configurationId.equals(configuration.id) &
                row.id.equals(prompt.id) &
                row.deletedAt.isNull(),
          ))
          .write(
            db.JournalPromptDefinitionsCompanion(
              questionText: Value(normalized.questionText),
              helperText: Value(normalized.helperText),
              promptVersion: Value(prompt.promptVersion + 1),
              updatedAt: Value(now),
            ),
          );
      return true;
    });
  }

  @override
  Future<JournalPromptConfiguration> duplicateAsUserPrompt(String promptId) {
    return _mutate((configuration, prompts, now) async {
      final prompt = _requirePrompt(prompts, promptId);
      if (!prompt.isSystem || prompt.isDeleted) {
        throw const JournalPromptOperationException();
      }
      _requireCapacity(prompts, enabledCountDelta: prompt.isEnabled ? 0 : 1);
      await (database.update(database.journalPromptDefinitions)..where(
            (row) =>
                row.configurationId.equals(configuration.id) &
                row.id.equals(prompt.id) &
                row.deletedAt.isNull(),
          ))
          .write(
            db.JournalPromptDefinitionsCompanion(
              isEnabled: const Value(false),
              updatedAt: Value(now),
            ),
          );
      await database
          .into(database.journalPromptDefinitions)
          .insert(
            db.JournalPromptDefinitionsCompanion.insert(
              id: Value(uuid.v4()),
              configurationId: configuration.id,
              promptSource: JournalPromptSource.user.wireName,
              questionText: prompt.questionText,
              helperText: Value(prompt.helperText),
              displayOrder: prompt.displayOrder,
              promptVersion: const Value(1),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      return true;
    });
  }

  @override
  Future<JournalPromptConfiguration> setPromptEnabled(
    String promptId,
    bool isEnabled,
  ) {
    return _mutate((configuration, prompts, now) async {
      final prompt = _requirePrompt(prompts, promptId);
      if (prompt.isDeleted) throw const JournalPromptOperationException();
      if (prompt.isEnabled == isEnabled) return false;
      final enabledCount = prompts
          .where((item) => !item.isDeleted && item.isEnabled)
          .length;
      if ((!isEnabled && enabledCount <= 1) ||
          (isEnabled &&
              enabledCount >= JournalPromptLimits.enabledPromptCount)) {
        throw const JournalPromptLimitException();
      }
      await (database.update(database.journalPromptDefinitions)..where(
            (row) =>
                row.configurationId.equals(configuration.id) &
                row.id.equals(prompt.id) &
                row.deletedAt.isNull(),
          ))
          .write(
            db.JournalPromptDefinitionsCompanion(
              isEnabled: Value(isEnabled),
              updatedAt: Value(now),
            ),
          );
      return true;
    });
  }

  @override
  Future<JournalPromptConfiguration> reorderPrompts(
    List<String> enabledPromptIds,
  ) {
    return _mutate((configuration, prompts, now) async {
      final active = prompts
          .where((prompt) => !prompt.isDeleted && prompt.isEnabled)
          .toList(growable: false);
      if (enabledPromptIds.length != active.length ||
          enabledPromptIds.toSet().length != enabledPromptIds.length ||
          !enabledPromptIds.toSet().containsAll(
            active.map((prompt) => prompt.id),
          )) {
        throw const JournalPromptOperationException();
      }
      for (var index = 0; index < enabledPromptIds.length; index += 1) {
        await (database.update(database.journalPromptDefinitions)..where(
              (row) =>
                  row.configurationId.equals(configuration.id) &
                  row.id.equals(enabledPromptIds[index]) &
                  row.deletedAt.isNull(),
            ))
            .write(
              db.JournalPromptDefinitionsCompanion(
                displayOrder: Value(index),
                updatedAt: Value(now),
              ),
            );
      }
      return true;
    });
  }

  @override
  Future<JournalPromptConfiguration> deleteUserPrompt(String promptId) {
    return _mutate((configuration, prompts, now) async {
      final prompt = _requirePrompt(prompts, promptId);
      if (!prompt.isUser || prompt.isDeleted) {
        throw const JournalPromptOperationException();
      }
      final enabledCount = prompts
          .where((item) => !item.isDeleted && item.isEnabled)
          .length;
      if (prompt.isEnabled && enabledCount <= 1) {
        throw const JournalPromptLimitException();
      }
      await (database.update(database.journalPromptDefinitions)..where(
            (row) =>
                row.configurationId.equals(configuration.id) &
                row.id.equals(prompt.id) &
                row.deletedAt.isNull(),
          ))
          .write(
            db.JournalPromptDefinitionsCompanion(
              isEnabled: const Value(false),
              deletedAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      return true;
    });
  }

  Future<JournalPromptConfiguration> _mutate(
    Future<bool> Function(
      JournalPromptConfiguration configuration,
      List<JournalPromptDefinition> prompts,
      int now,
    )
    operation,
  ) {
    return ensureInitialized().then(
      (_) => database.transaction(() async {
        final bootstrap = await database.bootstrapDao.bootstrap();
        final row = await _selectConfiguration(bootstrap.activeUserId);
        if (row == null) throw const JournalPromptOperationException();
        final configuration = await _loadAggregate(row);
        if (configuration.userId != bootstrap.activeUserId) {
          throw const JournalPromptOperationException();
        }
        final now = dateTimeService.currentSnapshot().utcMilliseconds;
        final changed = await operation(
          configuration,
          configuration.prompts,
          now,
        );
        if (!changed) return configuration;
        final affected =
            await (database.update(database.journalPromptConfigurations)..where(
                  (row) =>
                      row.id.equals(configuration.id) &
                      row.userId.equals(bootstrap.activeUserId) &
                      row.deletedAt.isNull(),
                ))
                .write(
                  db.JournalPromptConfigurationsCompanion(
                    configurationVersion: Value(
                      configuration.configurationVersion + 1,
                    ),
                    updatedAt: Value(now),
                    syncStatus: const Value('pending'),
                    originDeviceId: Value(bootstrap.localInstallationId),
                  ),
                );
        if (affected != 1) throw const JournalPromptOperationException();
        return _loadAggregate(
          (await _selectConfiguration(bootstrap.activeUserId))!,
        );
      }),
    );
  }

  Future<db.JournalPromptConfigurationRow?> _selectConfiguration(
    String userId,
  ) {
    return (database.select(database.journalPromptConfigurations)..where(
          (row) =>
              row.userId.equals(userId) &
              row.logicalKey.equals('default') &
              row.deletedAt.isNull(),
        ))
        .getSingleOrNull();
  }

  Future<JournalPromptConfiguration> _loadAggregate(
    db.JournalPromptConfigurationRow configuration,
  ) async {
    final rows =
        await (database.select(database.journalPromptDefinitions)
              ..where((row) => row.configurationId.equals(configuration.id))
              ..orderBy([
                (row) => OrderingTerm.desc(row.isEnabled),
                (row) => OrderingTerm.asc(row.displayOrder),
                (row) => OrderingTerm.asc(row.id),
              ]))
            .get();
    return JournalPromptConfiguration(
      id: configuration.id,
      userId: configuration.userId,
      logicalKey: configuration.logicalKey,
      configurationVersion: configuration.configurationVersion,
      createdAt: configuration.createdAt,
      updatedAt: configuration.updatedAt,
      syncStatus: configuration.syncStatus,
      serverVersion: configuration.serverVersion,
      lastSyncedAt: configuration.lastSyncedAt,
      originDeviceId: configuration.originDeviceId,
      deletedAt: configuration.deletedAt,
      prompts: rows.map(_toDomainPrompt).toList(growable: false),
    );
  }

  JournalPromptDefinition _toDomainPrompt(db.JournalPromptDefinitionRow row) {
    return JournalPromptDefinition(
      id: row.id,
      configurationId: row.configurationId,
      stableKey: row.stableKey,
      source: JournalPromptSource.fromWireName(row.promptSource),
      questionText: row.questionText,
      helperText: row.helperText,
      responseKind: JournalResponseKind.fromWireName(row.responseKind),
      displayOrder: row.displayOrder,
      isEnabled: row.isEnabled,
      promptVersion: row.promptVersion,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
    );
  }

  JournalPromptDefinition _requirePrompt(
    List<JournalPromptDefinition> prompts,
    String promptId,
  ) {
    for (final prompt in prompts) {
      if (prompt.id == promptId) return prompt;
    }
    throw const JournalPromptOperationException();
  }

  JournalPromptInput _normalizeInput(JournalPromptInput input) {
    return JournalPromptInput(
      questionText: normalizePromptText(
        input.questionText,
        maxLength: JournalPromptLimits.questionTextLength,
      ),
      helperText: normalizeOptionalPromptText(
        input.helperText,
        maxLength: JournalPromptLimits.helperTextLength,
      ),
    );
  }

  void _requireCapacity(
    List<JournalPromptDefinition> prompts, {
    int enabledCountDelta = 1,
  }) {
    final active = prompts.where((prompt) => !prompt.isDeleted).toList();
    final enabled = active.where((prompt) => prompt.isEnabled).length;
    if (active.length >= JournalPromptLimits.totalPromptCount ||
        enabled + enabledCountDelta > JournalPromptLimits.enabledPromptCount) {
      throw const JournalPromptLimitException();
    }
  }
}
