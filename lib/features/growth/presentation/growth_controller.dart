import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/features/growth/data/growth_repository_provider.dart';
import 'package:rebirth/features/growth/domain/growth_period.dart';

import 'growth_view_state.dart';

final growthControllerProvider =
    AsyncNotifierProvider<GrowthController, GrowthViewState>(
      GrowthController.new,
    );

class GrowthController extends AsyncNotifier<GrowthViewState> {
  GrowthPeriod _selectedPeriod = GrowthPeriod.sevenDays;
  int _requestSequence = 0;

  @override
  Future<GrowthViewState> build() async {
    final snapshot = await ref
        .read(growthRepositoryProvider)
        .loadRecent(GrowthPeriod.sevenDays);
    return GrowthViewState(period: GrowthPeriod.sevenDays, snapshot: snapshot);
  }

  Future<void> selectPeriod(GrowthPeriod period) async {
    if (_selectedPeriod == period) {
      return;
    }

    _selectedPeriod = period;
    final current = state.asData?.value;
    if (current == null) {
      await _loadWithoutData();
      return;
    }

    await _refresh(period: period, current: current);
  }

  Future<void> reload() async {
    if (state.isLoading || state.asData?.value.isRefreshing == true) {
      return;
    }

    final current = state.asData?.value;
    if (current == null) {
      await _loadWithoutData();
      return;
    }

    _selectedPeriod = current.period;
    await _refresh(period: current.period, current: current);
  }

  Future<void> _loadWithoutData() async {
    final period = _selectedPeriod;
    final request = ++_requestSequence;
    state = const AsyncLoading<GrowthViewState>();

    try {
      final snapshot = await ref
          .read(growthRepositoryProvider)
          .loadRecent(period);
      if (!ref.mounted ||
          request != _requestSequence ||
          period != _selectedPeriod) {
        return;
      }
      state = AsyncData(GrowthViewState(period: period, snapshot: snapshot));
    } catch (error, stackTrace) {
      if (!ref.mounted ||
          request != _requestSequence ||
          period != _selectedPeriod) {
        return;
      }
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> _refresh({
    required GrowthPeriod period,
    required GrowthViewState current,
  }) async {
    final request = ++_requestSequence;
    final stablePeriod = current.snapshot.period;
    state = AsyncData(
      current.copyWith(
        period: period,
        isRefreshing: true,
        refreshFailed: false,
        clearRefreshDiagnostic: true,
      ),
    );

    try {
      final snapshot = await ref
          .read(growthRepositoryProvider)
          .loadRecent(period);
      if (!ref.mounted ||
          request != _requestSequence ||
          period != _selectedPeriod) {
        return;
      }
      state = AsyncData(GrowthViewState(period: period, snapshot: snapshot));
    } catch (error, stackTrace) {
      if (!ref.mounted ||
          request != _requestSequence ||
          period != _selectedPeriod) {
        return;
      }
      _selectedPeriod = stablePeriod;
      state = AsyncData(
        current.copyWith(
          period: stablePeriod,
          isRefreshing: false,
          refreshFailed: true,
          refreshError: error,
          refreshStackTrace: stackTrace,
        ),
      );
    }
  }
}
