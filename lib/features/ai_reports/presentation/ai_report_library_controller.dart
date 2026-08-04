import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/features/ai_coach/data/ai_coach_repository_providers.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_version.dart';

final aiReportLibraryControllerProvider =
    AsyncNotifierProvider<AiReportLibraryController, List<AiReport>>(
      AiReportLibraryController.new,
    );

final aiReportLibraryDetailProvider = FutureProvider.autoDispose
    .family<AiReportLibraryDetail?, String>((ref, reportId) async {
      if (reportId.trim().isEmpty) return null;
      final repository = ref.watch(aiReportRepositoryProvider);
      final report = await repository.getById(reportId);
      if (report == null) return null;
      final versions = await repository.listVersions(reportId);
      return AiReportLibraryDetail(report: report, versions: versions);
    });

final class AiReportLibraryController extends AsyncNotifier<List<AiReport>> {
  @override
  Future<List<AiReport>> build() => _load();

  Future<void> reload() async {
    state = const AsyncLoading<List<AiReport>>();
    state = await AsyncValue.guard(_load);
  }

  Future<List<AiReport>> _load() {
    return ref.read(aiReportRepositoryProvider).listRecent(limit: 100);
  }
}

final class AiReportLibraryDetail {
  const AiReportLibraryDetail({required this.report, required this.versions});

  final AiReport report;
  final List<AiReportVersion> versions;
}
