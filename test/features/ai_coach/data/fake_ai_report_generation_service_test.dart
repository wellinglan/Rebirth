import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/ai_coach/data/fake_ai_report_generation_service.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_generation_service.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_status.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_type.dart';

import '../ai_coach_test_support.dart';

void main() {
  test(
    'fake generation creates a local completed version without provider',
    () async {
      final repository = FakeAiReportRepository();
      final service = FakeAiReportGenerationService(repository: repository);

      final report = await service.generate(
        const AiReportGenerationRequest(
          reportType: AiReportType.weeklyReport,
          title: 'Fake 周报',
          periodStartDate: '2026-07-24',
          periodEndDate: '2026-07-30',
        ),
      );

      expect(report.status, AiReportStatus.completed);
      expect(report.versions, hasLength(1));
      expect(report.versions.single.generationSource, 'fake');
      expect(report.versions.single.content, contains('本地 Fake 报告'));
    },
  );
}
