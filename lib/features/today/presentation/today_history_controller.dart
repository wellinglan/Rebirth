import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/features/today/data/today_repository_provider.dart';
import 'package:rebirth/features/today/domain/today_entry.dart';

final todayHistoryControllerProvider =
    AsyncNotifierProvider<TodayHistoryController, List<TodayEntry>>(
      TodayHistoryController.new,
    );

class TodayHistoryController extends AsyncNotifier<List<TodayEntry>> {
  int _days = 30;

  @override
  Future<List<TodayEntry>> build() {
    return ref.watch(todayRepositoryProvider).listRecentEntries(days: _days);
  }

  Future<void> reload() => loadRecent(days: _days);

  Future<void> loadRecent({int days = 30}) {
    _days = days;
    return _load(
      () => ref.read(todayRepositoryProvider).listRecentEntries(days: _days),
    );
  }

  Future<void> loadByDateRange({
    required String startDate,
    required String endDate,
    int? limit,
  }) {
    return _load(
      () => ref
          .read(todayRepositoryProvider)
          .listByDateRange(
            startDate: startDate,
            endDate: endDate,
            limit: limit,
          ),
    );
  }

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
