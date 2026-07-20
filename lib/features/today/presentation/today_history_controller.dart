import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/today/data/today_repository_provider.dart';
import 'package:rebirth/features/today/domain/today_entry.dart';

final todayHistoryControllerProvider =
    AsyncNotifierProvider<TodayHistoryController, List<TodayEntry>>(
      TodayHistoryController.new,
    );

final todayHistoryEntryForDateProvider =
    FutureProvider.autoDispose.family<TodayEntry?, String>((ref, recordDate) {
      return ref.watch(todayRepositoryProvider).getByDate(recordDate);
    });

class TodayHistoryController extends AsyncNotifier<List<TodayEntry>> {
  int _days = 30;

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
