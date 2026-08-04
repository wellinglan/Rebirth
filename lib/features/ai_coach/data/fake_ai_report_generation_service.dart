import 'package:rebirth/features/ai_coach/domain/ai_report.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_generation_service.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_repository.dart';

final class FakeAiReportGenerationService implements AiReportGenerationService {
  FakeAiReportGenerationService({required this.repository});

  final AiReportRepository repository;

  @override
  Future<AiReport> generate(AiReportGenerationRequest request) async {
    final draft = await repository.createDraft(
      reportType: request.reportType,
      title: request.title,
      periodStartDate: request.periodStartDate,
      periodEndDate: request.periodEndDate,
      generationSource: 'fake',
    );
    await repository.beginGeneration(draft.id);
    return repository.completeVersion(
      reportId: draft.id,
      content: '# ${request.title}\n\n这是用于持久化基础测试的本地 Fake 报告。',
      generationSource: 'fake',
    );
  }
}
