import 'package:drift/drift.dart';
import 'package:rebirth/core/database/app_database.dart' as db;
import 'package:rebirth/core/journal/journal_prompt_catalog.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/journal/domain/journal_entry.dart';
import 'package:rebirth/features/journal/domain/journal_entry_prompt_item.dart';
import 'package:rebirth/features/journal/domain/journal_prompt.dart';
import 'package:rebirth/features/journal/domain/journal_repository.dart';
import 'package:rebirth/features/journal/domain/journal_save_data.dart';
import 'package:uuid/uuid.dart';

import 'journal_local_data_source.dart';
import 'journal_prompt_repository_impl.dart';

final class JournalRepositoryImpl implements JournalRepository {
  JournalRepositoryImpl({
    required db.AppDatabase database,
    required this.dateTimeService,
    Uuid uuid = const Uuid(),
  }) : _database = database,
       _uuid = uuid,
       _localDataSource = JournalLocalDataSource(database),
       _promptRepository = JournalPromptRepositoryImpl(
         database: database,
         dateTimeService: dateTimeService,
         uuid: uuid,
       );

  final db.AppDatabase _database;
  final DateTimeService dateTimeService;
  final Uuid _uuid;
  final JournalLocalDataSource _localDataSource;
  final JournalPromptRepositoryImpl _promptRepository;

  @override
  Future<JournalEntry> createEntry(JournalSaveData data) async {
    _validateInputHasContent(data);
    final snapshot = dateTimeService.currentSnapshot();
    final bootstrap = await _database.bootstrapDao.bootstrap();
    return _database.transaction(() async {
      final items = await _resolveItems(
        data,
        timestamp: snapshot.utcMilliseconds,
      );
      return _insertEntry(
        userId: bootstrap.activeUserId,
        entryDate: snapshot.localDateString,
        timezoneOffsetMinutes: snapshot.timezoneOffsetMinutes,
        timestamp: snapshot.utcMilliseconds,
        originDeviceId: bootstrap.localInstallationId,
        items: items,
        status: data.status,
      );
    });
  }

  @override
  Future<JournalEntry?> getTodayEntry() async {
    final snapshot = dateTimeService.currentSnapshot();
    final bootstrap = await _database.bootstrapDao.bootstrap();
    final entries = await _localDataSource.selectByDate(
      userId: bootstrap.activeUserId,
      entryDate: snapshot.localDateString,
    );
    final mapped = await _mapEntries(entries);
    return mapped.isEmpty ? null : mapped.single;
  }

  @override
  Future<JournalEntry> saveTodayEntry(JournalSaveData data) async {
    _validateInputHasContent(data);
    final snapshot = dateTimeService.currentSnapshot();
    final bootstrap = await _database.bootstrapDao.bootstrap();
    return _database.transaction(() async {
      final entries = await _localDataSource.selectByDate(
        userId: bootstrap.activeUserId,
        entryDate: snapshot.localDateString,
      );
      final existingItems = entries.isEmpty
          ? null
          : await _selectItems(entries.single.id);
      final items = await _resolveItems(
        data,
        existingItems: existingItems,
        timestamp: snapshot.utcMilliseconds,
      );
      if (entries.isEmpty) {
        return _insertEntry(
          userId: bootstrap.activeUserId,
          entryDate: snapshot.localDateString,
          timezoneOffsetMinutes: snapshot.timezoneOffsetMinutes,
          timestamp: snapshot.utcMilliseconds,
          originDeviceId: bootstrap.localInstallationId,
          items: items,
          status: data.status,
        );
      }
      final updated = await _updateEntry(
        userId: bootstrap.activeUserId,
        id: entries.single.id,
        timestamp: snapshot.utcMilliseconds,
        originDeviceId: bootstrap.localInstallationId,
        items: items,
        status: data.status,
      );
      if (updated == null) {
        throw JournalEntryNotFoundException(entries.single.id);
      }
      return updated;
    });
  }

  @override
  Future<JournalEntry> saveDraft(JournalSaveData data) {
    return saveTodayEntry(data.withStatus(JournalEntryStatus.draft));
  }

  @override
  Future<JournalEntry> complete(JournalSaveData data) {
    return saveTodayEntry(data.withStatus(JournalEntryStatus.completed));
  }

  @override
  Future<JournalEntry> reopen(String id) async {
    final snapshot = dateTimeService.currentSnapshot();
    final bootstrap = await _database.bootstrapDao.bootstrap();
    await _ensureNotConflicted(userId: bootstrap.activeUserId, id: id);
    final current = await _localDataSource.selectById(
      userId: bootstrap.activeUserId,
      id: id,
    );
    if (current == null) throw JournalEntryNotFoundException(id);
    if (current.entryStatus == JournalEntryStatus.draft.name) {
      return (await _mapEntries([current])).single;
    }
    final updated = await _localDataSource.updateById(
      userId: bootstrap.activeUserId,
      id: id,
      changes: db.JournalEntriesCompanion(
        entryStatus: Value(JournalEntryStatus.draft.name),
        updatedAt: Value(snapshot.utcMilliseconds),
        syncStatus: const Value('pending'),
        originDeviceId: Value(bootstrap.localInstallationId),
      ),
    );
    if (updated == null) throw JournalEntryNotFoundException(id);
    return (await _mapEntries([updated])).single;
  }

  Future<JournalEntry> applyLatestPrompts(String id) async {
    final snapshot = dateTimeService.currentSnapshot();
    final bootstrap = await _database.bootstrapDao.bootstrap();
    return _database.transaction(() async {
      await _ensureNotConflicted(userId: bootstrap.activeUserId, id: id);
      final row = await _localDataSource.selectById(
        userId: bootstrap.activeUserId,
        id: id,
      );
      if (row == null) throw JournalEntryNotFoundException(id);
      if (row.entryStatus != JournalEntryStatus.draft.name) {
        throw const JournalPromptOperationException();
      }
      final existing = await _selectItems(id);
      final configuration = await _promptRepository.ensureInitializedAt(
        snapshot.utcMilliseconds,
      );
        final byIdentity = {
          for (final item in existing)
            if (item.sourcePromptId != null)
              '${item.sourcePromptId}:${item.sourcePromptVersion}': item,
        };
        final byStableKey = {
          for (final item in existing)
            if (item.sourcePromptStableKey != null)
              item.sourcePromptStableKey!: item,
        };
        final usedItemIds = <String>{};
        final merged = <JournalEntryPromptItem>[];
        var order = 0;
        for (final prompt in configuration.activePrompts) {
          final identity = '${prompt.id}:${prompt.promptVersion}';
          final matched =
              byIdentity[identity] ??
              (prompt.stableKey == null ? null : byStableKey[prompt.stableKey]);
          if (matched != null) usedItemIds.add(matched.id);
          merged.add(
            _itemFromPrompt(
              prompt,
              id: matched?.id ?? _uuid.v4(),
              displayOrder: order,
              timestamp: snapshot.utcMilliseconds,
              answerText: matched?.answerText,
            ),
          );
          order += 1;
        }
        for (final item in existing) {
          if (!usedItemIds.contains(item.id) && item.hasAnswer) {
            merged.add(item.copyWith(displayOrder: order));
            order += 1;
          }
        }
      final normalized = _normalizeItems(merged);
      final updated = await _updateEntry(
        userId: bootstrap.activeUserId,
        id: id,
        timestamp: snapshot.utcMilliseconds,
        originDeviceId: bootstrap.localInstallationId,
        items: normalized,
        status: JournalEntryStatus.draft,
      );
      if (updated == null) throw JournalEntryNotFoundException(id);
      return updated;
    });
  }

  @override
  Future<JournalEntry?> getById(String id) async {
    final bootstrap = await _database.bootstrapDao.bootstrap();
    final entry = await _localDataSource.selectById(
      userId: bootstrap.activeUserId,
      id: id,
    );
    if (entry == null) return null;
    return (await _mapEntries([entry])).single;
  }

  @override
  Future<List<JournalEntry>> listRecent({int limit = 20}) async {
    _validateLimit(limit);
    final bootstrap = await _database.bootstrapDao.bootstrap();
    return _mapEntries(
      await _localDataSource.selectRecent(
        userId: bootstrap.activeUserId,
        limit: limit,
      ),
    );
  }

  @override
  Future<List<JournalEntry>> listByDate(String entryDate) async {
    _validateDate(entryDate, 'entryDate');
    final bootstrap = await _database.bootstrapDao.bootstrap();
    return _mapEntries(
      await _localDataSource.selectByDate(
        userId: bootstrap.activeUserId,
        entryDate: entryDate,
      ),
    );
  }

  @override
  Future<List<JournalEntry>> listByDateRange({
    required String startDate,
    required String endDate,
    int? limit,
  }) async {
    _validateDate(startDate, 'startDate');
    _validateDate(endDate, 'endDate');
    if (startDate.compareTo(endDate) > 0) {
      throw ArgumentError('startDate must not be after endDate.');
    }
    if (limit != null) _validateLimit(limit);
    final bootstrap = await _database.bootstrapDao.bootstrap();
    return _mapEntries(
      await _localDataSource.selectByDateRange(
        userId: bootstrap.activeUserId,
        startDate: startDate,
        endDate: endDate,
        limit: limit,
      ),
    );
  }

  @override
  Future<JournalEntry> updateEntry({
    required String id,
    required JournalSaveData data,
  }) async {
    _validateInputHasContent(data);
    final snapshot = dateTimeService.currentSnapshot();
    final bootstrap = await _database.bootstrapDao.bootstrap();
    return _database.transaction(() async {
      final existing = await _selectItems(id);
      final items = await _resolveItems(
        data,
        existingItems: existing,
        timestamp: snapshot.utcMilliseconds,
      );
      final entry = await _updateEntry(
        userId: bootstrap.activeUserId,
        id: id,
        timestamp: snapshot.utcMilliseconds,
        originDeviceId: bootstrap.localInstallationId,
        items: items,
        status: data.status,
      );
      if (entry == null) throw JournalEntryNotFoundException(id);
      return entry;
    });
  }

  @override
  Future<void> softDelete(String id) async {
    final snapshot = dateTimeService.currentSnapshot();
    final bootstrap = await _database.bootstrapDao.bootstrap();
    await _ensureNotConflicted(userId: bootstrap.activeUserId, id: id);
    final deleted = await _localDataSource.softDeleteById(
      userId: bootstrap.activeUserId,
      id: id,
      timestamp: snapshot.utcMilliseconds,
      originDeviceId: bootstrap.localInstallationId,
    );
    if (!deleted) throw JournalEntryNotFoundException(id);
  }

  Future<JournalEntry> _insertEntry({
    required String userId,
    required String entryDate,
    required int timezoneOffsetMinutes,
    required int timestamp,
    required String originDeviceId,
    required List<JournalEntryPromptItem> items,
    required JournalEntryStatus status,
  }) async {
    final id = _uuid.v4();
    await _ensureItemOwnership(items, journalEntryId: null);
    final todayRecordId = await _findTodayRecordId(
      userId: userId,
      entryDate: entryDate,
    );
    final legacy = _legacyMirror(items);
    await _database
        .into(_database.journalEntries)
        .insert(
          db.JournalEntriesCompanion.insert(
            id: Value(id),
            userId: userId,
            todayRecordId: Value(todayRecordId),
            entryDate: entryDate,
            timezoneOffsetMinutes: timezoneOffsetMinutes,
            mostImportantAccomplishment: Value(legacy.accomplishment),
            mostDrainingEvent: Value(legacy.drainingEvent),
            emotionSource: Value(legacy.emotionSource),
            learning: Value(legacy.learning),
            tomorrowAdjustment: Value(legacy.tomorrowAdjustment),
            entryStatus: Value(status.name),
            createdAt: Value(timestamp),
            updatedAt: Value(timestamp),
            syncStatus: const Value('pending'),
            originDeviceId: Value(originDeviceId),
          ),
        );
    await _replaceItems(id, items, timestamp);
    return (await _mapEntries([
      (await _localDataSource.selectById(userId: userId, id: id))!,
    ])).single;
  }

  Future<JournalEntry?> _updateEntry({
    required String userId,
    required String id,
    required int timestamp,
    required String originDeviceId,
    required List<JournalEntryPromptItem> items,
    required JournalEntryStatus status,
  }) async {
    await _ensureNotConflicted(userId: userId, id: id);
    await _ensureItemOwnership(items, journalEntryId: id);
    final legacy = _legacyMirror(items);
    final entry = await _localDataSource.updateById(
      userId: userId,
      id: id,
      changes: db.JournalEntriesCompanion(
        mostImportantAccomplishment: Value(legacy.accomplishment),
        mostDrainingEvent: Value(legacy.drainingEvent),
        emotionSource: Value(legacy.emotionSource),
        learning: Value(legacy.learning),
        tomorrowAdjustment: Value(legacy.tomorrowAdjustment),
        entryStatus: Value(status.name),
        updatedAt: Value(timestamp),
        syncStatus: const Value('pending'),
        originDeviceId: Value(originDeviceId),
      ),
    );
    if (entry == null) return null;
    await _replaceItems(id, items, timestamp);
    return (await _mapEntries([entry])).single;
  }

  Future<List<JournalEntryPromptItem>> _resolveItems(
    JournalSaveData data, {
    List<JournalEntryPromptItem>? existingItems,
    required int timestamp,
  }) async {
    final supplied = data.promptItems;
    if (supplied != null) return _normalizeItems(supplied);

    final legacyAnswers = <String, String?>{
      JournalPromptCatalog.accomplishmentKey: data.mostImportantAccomplishment,
      JournalPromptCatalog.drainingEventKey: data.mostDrainingEvent,
      JournalPromptCatalog.emotionSourceKey: data.emotionSource,
      JournalPromptCatalog.learningKey: data.learning,
      JournalPromptCatalog.tomorrowAdjustmentKey: data.tomorrowAdjustment,
    };
    if (existingItems != null && existingItems.isNotEmpty) {
      return _normalizeItems([
        for (final item in existingItems)
          legacyAnswers.containsKey(item.sourcePromptStableKey)
              ? item.copyWith(
                  answerText: legacyAnswers[item.sourcePromptStableKey],
                  clearAnswer:
                      _trimToNull(legacyAnswers[item.sourcePromptStableKey]) ==
                      null,
                )
              : item,
      ]);
    }

    final configuration = await _promptRepository.ensureInitializedAt(
      timestamp,
    );
    return _normalizeItems([
      for (final prompt in configuration.activePrompts)
        _itemFromPrompt(
          prompt,
          id: _uuid.v4(),
          displayOrder: prompt.displayOrder,
          timestamp: timestamp,
          answerText: legacyAnswers[prompt.stableKey],
        ),
    ]);
  }

  List<JournalEntryPromptItem> _normalizeItems(
    List<JournalEntryPromptItem> items,
  ) {
    final normalized =
        [
          for (final item in items)
            JournalEntryPromptItem(
              id: item.id,
              sourcePromptId: item.sourcePromptId,
              sourcePromptStableKey: item.sourcePromptStableKey,
              sourcePromptVersion: item.sourcePromptVersion,
              promptSource: item.promptSource,
              questionTextSnapshot: item.questionTextSnapshot.trim(),
              helperTextSnapshot: _trimToNull(item.helperTextSnapshot),
              responseKind: item.responseKind,
              displayOrder: item.displayOrder,
              answerText: _trimToNull(item.answerText),
              createdAt: item.createdAt,
              updatedAt: item.updatedAt,
            ),
        ]..sort((left, right) {
          final order = left.displayOrder.compareTo(right.displayOrder);
          return order != 0 ? order : left.id.compareTo(right.id);
        });
    validateJournalPromptItems(normalized);
    return normalized;
  }

  JournalEntryPromptItem _itemFromPrompt(
    JournalPromptDefinition prompt, {
    required String id,
    required int displayOrder,
    required int timestamp,
    String? answerText,
  }) {
    return JournalEntryPromptItem(
      id: id,
      sourcePromptId: prompt.id,
      sourcePromptStableKey: prompt.stableKey,
      sourcePromptVersion: prompt.promptVersion,
      promptSource: prompt.source,
      questionTextSnapshot: prompt.questionText,
      helperTextSnapshot: prompt.helperText,
      responseKind: prompt.responseKind,
      displayOrder: displayOrder,
      answerText: answerText,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  Future<void> _replaceItems(
    String journalEntryId,
    List<JournalEntryPromptItem> items,
    int timestamp,
  ) async {
    await (_database.delete(
      _database.journalEntryPromptItems,
    )..where((row) => row.journalEntryId.equals(journalEntryId))).go();
    for (final item in items) {
      await _database
          .into(_database.journalEntryPromptItems)
          .insert(
            db.JournalEntryPromptItemsCompanion.insert(
              id: Value(item.id),
              journalEntryId: journalEntryId,
              sourcePromptId: Value(item.sourcePromptId),
              sourcePromptStableKey: Value(item.sourcePromptStableKey),
              sourcePromptVersion: item.sourcePromptVersion,
              promptSource: item.promptSource.wireName,
              questionTextSnapshot: item.questionTextSnapshot,
              helperTextSnapshot: Value(item.helperTextSnapshot),
              responseKind: Value(item.responseKind.wireName),
              displayOrder: item.displayOrder,
              answerText: Value(item.answerText),
              createdAt: Value(
                item.createdAt == 0 ? timestamp : item.createdAt,
              ),
              updatedAt: Value(timestamp),
            ),
          );
    }
  }

  Future<void> _ensureItemOwnership(
    List<JournalEntryPromptItem> items, {
    required String? journalEntryId,
  }) async {
    final ids = items.map((item) => item.id).toList(growable: false);
    if (ids.isEmpty) return;
    final existing = await (_database.select(
      _database.journalEntryPromptItems,
    )..where((row) => row.id.isIn(ids))).get();
    if (existing.any((row) => row.journalEntryId != journalEntryId)) {
      throw const JournalPromptItemValidationException();
    }
  }

  Future<List<JournalEntryPromptItem>> _selectItems(
    String journalEntryId,
  ) async {
    final rows =
        await (_database.select(_database.journalEntryPromptItems)
              ..where((row) => row.journalEntryId.equals(journalEntryId))
              ..orderBy([
                (row) => OrderingTerm.asc(row.displayOrder),
                (row) => OrderingTerm.asc(row.id),
              ]))
            .get();
    return rows.map(_toDomainItem).toList(growable: false);
  }

  Future<List<JournalEntry>> _mapEntries(List<db.JournalEntry> entries) async {
    if (entries.isEmpty) return const [];
    final entryIds = entries.map((entry) => entry.id).toList(growable: false);
    final rows =
        await (_database.select(_database.journalEntryPromptItems)
              ..where((row) => row.journalEntryId.isIn(entryIds))
              ..orderBy([
                (row) => OrderingTerm.asc(row.displayOrder),
                (row) => OrderingTerm.asc(row.id),
              ]))
            .get();
    final itemsByEntry = <String, List<JournalEntryPromptItem>>{};
    for (final row in rows) {
      itemsByEntry
          .putIfAbsent(row.journalEntryId, () => [])
          .add(_toDomainItem(row));
    }
    return [
      for (final entry in entries)
        JournalEntry(
          id: entry.id,
          userId: entry.userId,
          todayRecordId: entry.todayRecordId,
          entryDate: entry.entryDate,
          timezoneOffsetMinutes: entry.timezoneOffsetMinutes,
          promptItems: itemsByEntry[entry.id] ?? const [],
          status: switch (entry.entryStatus) {
            'draft' => JournalEntryStatus.draft,
            'completed' => JournalEntryStatus.completed,
            final value => throw StateError(
              'Unknown journal entry status: $value',
            ),
          },
          createdAt: entry.createdAt,
          updatedAt: entry.updatedAt,
        ),
    ];
  }

  JournalEntryPromptItem _toDomainItem(db.JournalEntryPromptItemRow row) {
    return JournalEntryPromptItem(
      id: row.id,
      sourcePromptId: row.sourcePromptId,
      sourcePromptStableKey: row.sourcePromptStableKey,
      sourcePromptVersion: row.sourcePromptVersion,
      promptSource: JournalPromptSource.fromWireName(row.promptSource),
      questionTextSnapshot: row.questionTextSnapshot,
      helperTextSnapshot: row.helperTextSnapshot,
      responseKind: JournalResponseKind.fromWireName(row.responseKind),
      displayOrder: row.displayOrder,
      answerText: row.answerText,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  _LegacyMirror _legacyMirror(List<JournalEntryPromptItem> items) {
    String? answer(String key) {
      for (final item in items) {
        if (item.sourcePromptStableKey == key) return item.answerText;
      }
      return null;
    }

    return _LegacyMirror(
      accomplishment: answer(JournalPromptCatalog.accomplishmentKey),
      drainingEvent: answer(JournalPromptCatalog.drainingEventKey),
      emotionSource: answer(JournalPromptCatalog.emotionSourceKey),
      learning: answer(JournalPromptCatalog.learningKey),
      tomorrowAdjustment: answer(JournalPromptCatalog.tomorrowAdjustmentKey),
    );
  }

  Future<void> _ensureNotConflicted({
    required String userId,
    required String id,
  }) async {
    final current = await _localDataSource.selectByIdIncludingDeleted(
      userId: userId,
      id: id,
    );
    if (current?.syncStatus == 'conflict') {
      throw JournalConflictPendingException(id);
    }
  }

  Future<String?> _findTodayRecordId({
    required String userId,
    required String entryDate,
  }) async {
    final today =
        await (_database.select(_database.todayRecords)..where(
              (row) =>
                  row.userId.equals(userId) &
                  row.recordDate.equals(entryDate) &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    return today?.id;
  }

  String? _trimToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  void _validateInputHasContent(JournalSaveData data) {
    final supplied = data.promptItems;
    if (supplied != null) {
      if (supplied.any((item) => _trimToNull(item.answerText) != null)) return;
      throw const EmptyJournalContentException();
    }
    if ([
      data.mostImportantAccomplishment,
      data.mostDrainingEvent,
      data.emotionSource,
      data.learning,
      data.tomorrowAdjustment,
    ].any((value) => _trimToNull(value) != null)) {
      return;
    }
    throw const EmptyJournalContentException();
  }

  void _validateDate(String date, String name) {
    if (!dateTimeService.isValidLocalDateString(date)) {
      throw ArgumentError.value(
        date,
        name,
        'Expected a valid date in YYYY-MM-DD format.',
      );
    }
  }

  void _validateLimit(int limit) {
    if (limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'Limit must be positive.');
    }
  }
}

final class _LegacyMirror {
  const _LegacyMirror({
    required this.accomplishment,
    required this.drainingEvent,
    required this.emotionSource,
    required this.learning,
    required this.tomorrowAdjustment,
  });

  final String? accomplishment;
  final String? drainingEvent;
  final String? emotionSource;
  final String? learning;
  final String? tomorrowAdjustment;
}
