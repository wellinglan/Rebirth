import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/health/data/health_repository_provider.dart';
import 'package:rebirth/features/health/domain/health_entry.dart';
import 'package:rebirth/features/health/domain/health_save_data.dart';
import 'package:rebirth/features/health/domain/health_summary.dart';
import 'package:rebirth/shared/state/health_record_revision_provider.dart';

import 'health_view_state.dart';

final healthControllerProvider =
    AsyncNotifierProvider<HealthController, HealthViewState>(
      HealthController.new,
    );

class HealthController extends AsyncNotifier<HealthViewState> {
  int _recentDays = 30;

  @override
  Future<HealthViewState> build() {
    ref.watch(healthRecordRevisionProvider);
    return _loadState();
  }

  Future<void> reload() async {
    state = const AsyncLoading<HealthViewState>();
    state = await AsyncValue.guard(_loadState);
  }

  Future<void> loadRecent({int days = 30}) async {
    if (days <= 0) {
      throw ArgumentError.value(days, 'days', 'Days must be positive.');
    }
    _recentDays = days;
    final current = state.asData?.value;
    if (current == null) {
      await reload();
      return;
    }

    try {
      final entries = await ref
          .read(healthRepositoryProvider)
          .listRecent(days: days);
      state = AsyncData(
        current.copyWith(recentEntries: _withoutToday(entries)),
      );
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> saveToday(HealthSaveData data) => saveForDate(data);

  Future<void> saveForDate(HealthSaveData data) async {
    final current = state.asData?.value;
    if (current == null || current.isSaving) {
      return;
    }

    state = AsyncData(current.copyWith(isSaving: true));
    try {
      await ref.read(healthRepositoryProvider).saveForDate(data);
      state = AsyncData(await _loadState());
      ref.read(healthRecordRevisionProvider.notifier).bump();
    } catch (error, stackTrace) {
      state = AsyncData(current.copyWith(isSaving: false));
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<HealthViewState> _loadState() async {
    final repository = ref.read(healthRepositoryProvider);
    final today = await repository.getToday();
    final results = await Future.wait<Object>([
      repository.listRecent(days: _recentDays),
      repository.getSummary(days: 7),
    ]);
    return HealthViewState(
      today: today,
      recentEntries: _withoutToday(results[0] as List<HealthEntry>),
      summary: results[1] as HealthSummary,
    );
  }

  List<HealthEntry> _withoutToday(List<HealthEntry> entries) {
    final today = ref.read(dateTimeServiceProvider).currentLocalDateString();
    return entries
        .where((entry) => entry.recordDate != today)
        .toList(growable: false);
  }
}
