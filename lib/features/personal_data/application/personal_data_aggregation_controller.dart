import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/account/presentation/app_auth_controller.dart';

import '../domain/personal_data_query.dart';
import '../presentation/personal_data_overview_state.dart';
import 'personal_data_providers.dart';

final personalDataAggregationControllerProvider =
    AsyncNotifierProvider<
      PersonalDataAggregationController,
      PersonalDataOverviewState
    >(PersonalDataAggregationController.new);

class PersonalDataAggregationController
    extends AsyncNotifier<PersonalDataOverviewState> {
  int _requestVersion = 0;
  String? _inFlightDate;

  @override
  Future<PersonalDataOverviewState> build() async {
    final auth = ref.watch(appAuthStateProvider).value;
    if (auth?.canAccessBusiness != true || auth?.localUserId == null) {
      throw StateError('Personal data requires an active local account.');
    }
    final snapshot = ref.watch(dateTimeServiceProvider).currentSnapshot();
    final selectedDate = snapshot.localDateString;
    ref.onDispose(() => _requestVersion++);
    return _collect(
      selectedDate: selectedDate,
      todayDate: selectedDate,
      requestedAtUtc: _snapshotUtc(snapshot),
    );
  }

  Future<void> previousDay() => _selectRelativeDay(-1);

  Future<void> nextDay() => _selectRelativeDay(1);

  Future<void> goToToday() async {
    final snapshot = ref.read(dateTimeServiceProvider).currentSnapshot();
    await _load(
      snapshot.localDateString,
      todayDate: snapshot.localDateString,
      preserveResult: false,
    );
  }

  Future<void> refresh() async {
    final current = state.value;
    if (current == null) return;
    final snapshot = ref.read(dateTimeServiceProvider).currentSnapshot();
    final selectedDate =
        current.isToday && current.todayDate != snapshot.localDateString
        ? snapshot.localDateString
        : current.selectedDate;
    await _load(
      selectedDate,
      todayDate: snapshot.localDateString,
      preserveResult: selectedDate == current.selectedDate,
    );
  }

  Future<void> selectDate(String localDate) async {
    if (!_isValidDate(localDate)) {
      throw ArgumentError.value(localDate, 'localDate', 'Invalid date.');
    }
    final snapshot = ref.read(dateTimeServiceProvider).currentSnapshot();
    await _load(
      localDate,
      todayDate: snapshot.localDateString,
      preserveResult: false,
    );
  }

  Future<void> _selectRelativeDay(int offset) async {
    final current = state.value;
    if (current == null) return;
    final parts = current.selectedDate.split('-').map(int.parse).toList();
    final target = DateTime.utc(parts[0], parts[1], parts[2] + offset);
    await _load(
      _formatUtcDate(target),
      todayDate: current.todayDate,
      preserveResult: false,
    );
  }

  Future<void> _load(
    String selectedDate, {
    required String todayDate,
    required bool preserveResult,
  }) async {
    if (_inFlightDate == selectedDate) return;
    final current = state.value;
    final requestVersion = ++_requestVersion;
    _inFlightDate = selectedDate;
    state = AsyncData(
      PersonalDataOverviewState(
        selectedDate: selectedDate,
        todayDate: todayDate,
        result: preserveResult ? current?.result : null,
        isRefreshing: true,
      ),
    );
    try {
      final snapshot = ref.read(dateTimeServiceProvider).currentSnapshot();
      final result = await _collect(
        selectedDate: selectedDate,
        todayDate: todayDate,
        requestedAtUtc: _snapshotUtc(snapshot),
      );
      if (!ref.mounted || requestVersion != _requestVersion) return;
      state = AsyncData(result);
    } catch (_) {
      if (!ref.mounted || requestVersion != _requestVersion) return;
      state = AsyncData(
        PersonalDataOverviewState(
          selectedDate: selectedDate,
          todayDate: todayDate,
          result: preserveResult ? current?.result : null,
          isRefreshing: false,
          errorMessage: '本地数据暂时无法汇总，请重试。',
        ),
      );
    } finally {
      if (requestVersion == _requestVersion) {
        _inFlightDate = null;
      }
    }
  }

  Future<PersonalDataOverviewState> _collect({
    required String selectedDate,
    required String todayDate,
    required DateTime requestedAtUtc,
  }) async {
    final result = await ref
        .read(personalDataAggregationEngineProvider)
        .aggregate(
          PersonalDataQuery.daily(
            localDate: selectedDate,
            requestedAtUtc: requestedAtUtc,
          ),
        );
    return PersonalDataOverviewState(
      selectedDate: selectedDate,
      todayDate: todayDate,
      result: result,
      isRefreshing: false,
    );
  }

  bool _isValidDate(String value) {
    return ref.read(dateTimeServiceProvider).isValidLocalDateString(value);
  }

  DateTime _snapshotUtc(DateTimeSnapshot snapshot) {
    return DateTime.fromMillisecondsSinceEpoch(
      snapshot.utcMilliseconds,
      isUtc: true,
    );
  }

  String _formatUtcDate(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }
}
