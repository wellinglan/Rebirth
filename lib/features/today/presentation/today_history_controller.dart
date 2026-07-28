import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/today/data/today_repository_provider.dart';
import 'package:rebirth/features/today/domain/today_entry.dart';

final todayHistoryControllerProvider =
    AsyncNotifierProvider<TodayHistoryController, List<TodayEntry>>(
      TodayHistoryController.new,
    );

final todayHistoryEntryForDateProvider = FutureProvider.autoDispose
    .family<TodayEntry?, String>((ref, recordDate) {
      return ref.watch(todayRepositoryProvider).getByDate(recordDate);
    });

class TodayHistoryController extends AsyncNotifier<List<TodayEntry>> {
  int _days = 30;
  final Map<String, Future<void>> _deleteOperations = {};

  @override
  Future<List<TodayEntry>> build() async {
    final today = ref.watch(dateTimeServiceProvider).currentLocalDateString();
    final entries = await ref
        .watch(todayRepositoryProvider)
        .listRecentEntries(days: _days);
    return _withoutToday(entries, today);
  }

  Future<void> reload() => loadRecent(days: _days);

  Future<void> loadRecent({int days = 30}) {
    _days = days;
    return _load(() async {
      final entries = await ref
          .read(todayRepositoryProvider)
          .listRecentEntries(days: _days);
      return _withoutToday(entries, _today());
    });
  }

  Future<void> loadByDateRange({
    required String startDate,
    required String endDate,
    int? limit,
  }) {
    return _load(() async {
      final entries = await ref
          .read(todayRepositoryProvider)
          .listByDateRange(
            startDate: startDate,
            endDate: endDate,
            limit: limit,
          );
      return _withoutToday(entries, _today());
    });
  }

  Future<void> deleteByDate(String recordDate) {
    final active = _deleteOperations[recordDate];
    if (active != null) return active;
    final future = _deleteAndReload(recordDate);
    _deleteOperations[recordDate] = future;
    future.whenComplete(() => _deleteOperations.remove(recordDate));
    return future;
  }

  Future<void> _deleteAndReload(String recordDate) async {
    await ref.read(todayRepositoryProvider).deleteTodayByDate(recordDate);
    ref.invalidate(todayHistoryEntryForDateProvider(recordDate));
    await reload();
  }

  String _today() => ref.read(dateTimeServiceProvider).currentLocalDateString();

  List<TodayEntry> _withoutToday(List<TodayEntry> entries, String today) =>
      entries
          .where((entry) => entry.recordDate != today)
          .toList(growable: false);

  Future<void> _load(Future<List<TodayEntry>> Function() operation) async {
    state = const AsyncLoading<List<TodayEntry>>();
    try {
      state = AsyncData(await operation());
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}
