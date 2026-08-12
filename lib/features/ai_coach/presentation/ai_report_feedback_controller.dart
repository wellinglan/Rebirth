import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/features/ai_coach/data/ai_coach_repository_providers.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_feedback.dart';

typedef AiReportFeedbackTarget = ({String reportId, int reportVersion});

final aiReportFeedbackProvider =
    FutureProvider.family<AiReportFeedback?, AiReportFeedbackTarget>((
      ref,
      target,
    ) {
      return ref
          .watch(aiReportFeedbackRepositoryProvider)
          .getForVersion(
            reportId: target.reportId,
            reportVersion: target.reportVersion,
          );
    });

final aiReportFeedbackControllerFamily =
    Provider.family<AiReportFeedbackController, AiReportFeedbackTarget>(
      (ref, target) => AiReportFeedbackController(ref, target),
    );

final class AiReportFeedbackController {
  const AiReportFeedbackController(this.ref, this.target);

  final Ref ref;
  final AiReportFeedbackTarget target;

  Future<void> save({
    required AiReportHelpfulness helpfulness,
    Iterable<AiReportFeedbackReason> reasons = const [],
  }) async {
    await ref
        .read(aiReportFeedbackRepositoryProvider)
        .save(
          reportId: target.reportId,
          reportVersion: target.reportVersion,
          helpfulness: helpfulness,
          reasons: reasons,
        );
    ref.invalidate(aiReportFeedbackProvider(target));
  }

  Future<void> clear() async {
    await ref
        .read(aiReportFeedbackRepositoryProvider)
        .clear(reportId: target.reportId, reportVersion: target.reportVersion);
    ref.invalidate(aiReportFeedbackProvider(target));
  }

  Future<void> adoptRemote(String id) async {
    await ref.read(aiReportFeedbackRepositoryProvider).adoptRemote(id);
    ref.invalidate(aiReportFeedbackProvider(target));
  }

  Future<void> keepLocal(String id) async {
    await ref.read(aiReportFeedbackRepositoryProvider).keepLocal(id);
    ref.invalidate(aiReportFeedbackProvider(target));
  }
}
