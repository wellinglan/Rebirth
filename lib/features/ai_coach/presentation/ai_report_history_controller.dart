import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/features/ai_coach/data/ai_coach_repository_providers.dart';

import 'ai_report_history_view_state.dart';
import 'ai_report_presentation_mapper.dart';
import 'models/ai_report_presentation_models.dart';

final aiReportPresentationMapperProvider = Provider<AiReportPresentationMapper>(
  (ref) => const AiReportPresentationMapper(),
);

final aiReportHistoryControllerProvider =
    AsyncNotifierProvider.autoDispose<
      AiReportHistoryController,
      AiReportHistoryViewState
    >(AiReportHistoryController.new);

final aiReportDetailProvider = FutureProvider.autoDispose
    .family<AiReportDetailModel?, String>((ref, reportId) {
      if (reportId.trim().isEmpty) return null;
      return ref
          .watch(aiReportHistoryControllerProvider.notifier)
          .getById(reportId);
    });

class AiReportHistoryController
    extends AsyncNotifier<AiReportHistoryViewState> {
  @override
  Future<AiReportHistoryViewState> build() async {
    return AiReportHistoryViewState(reports: await _loadReports());
  }

  Future<void> reload() async {
    final current = state.asData?.value;
    if (current == null) {
      state = const AsyncLoading<AiReportHistoryViewState>();
      state = await AsyncValue.guard(build);
      return;
    }
    if (current.isRefreshing) return;
    state = AsyncData(
      current.copyWith(isRefreshing: true, clearOperationError: true),
    );
    try {
      final reports = await _loadReports();
      if (!ref.mounted) return;
      state = AsyncData(AiReportHistoryViewState(reports: reports));
    } catch (_) {
      if (!ref.mounted) return;
      state = AsyncData(
        current.copyWith(
          isRefreshing: false,
          operationError: '本地报告暂时无法刷新，请重试。',
        ),
      );
    }
  }

  Future<AiReportDetailModel?> getById(String reportId) async {
    if (reportId.trim().isEmpty) return null;
    final report = await ref.read(aiReportRepositoryProvider).getById(reportId);
    return report == null
        ? null
        : ref.read(aiReportPresentationMapperProvider).toDetail(report);
  }

  Future<bool> deleteReport(String reportId) async {
    final current = state.asData?.value;
    if (current == null || current.deletingReportIds.contains(reportId)) {
      return false;
    }
    final deleting = {...current.deletingReportIds, reportId};
    state = AsyncData(
      current.copyWith(deletingReportIds: deleting, clearOperationError: true),
    );
    try {
      await ref.read(aiReportRepositoryProvider).softDelete(reportId);
      final reports = await _loadReports();
      if (!ref.mounted) return false;
      state = AsyncData(AiReportHistoryViewState(reports: reports));
      return true;
    } catch (_) {
      if (!ref.mounted) return false;
      final latest = state.asData?.value ?? current;
      final remaining = {...latest.deletingReportIds}..remove(reportId);
      state = AsyncData(
        latest.copyWith(
          deletingReportIds: remaining,
          operationError: '本地报告删除失败，请重试。',
        ),
      );
      return false;
    }
  }

  Future<List<AiReportListItemModel>> _loadReports() async {
    final reports = [
      ...await ref.read(aiReportRepositoryProvider).listRecent(),
    ];
    reports.sort(
      (left, right) => right.requestedAt.compareTo(left.requestedAt),
    );
    final mapper = ref.read(aiReportPresentationMapperProvider);
    return reports.map(mapper.toListItem).toList(growable: false);
  }
}
