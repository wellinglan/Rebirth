import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/ai_coach/domain/ai_coach_exception.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_lifecycle.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_status.dart';

void main() {
  test('supports explicit report lifecycle and version regeneration', () {
    expect(
      AiReportLifecycle.canTransition(
        AiReportStatus.draft,
        AiReportStatus.generating,
      ),
      isTrue,
    );
    expect(
      AiReportLifecycle.canTransition(
        AiReportStatus.generating,
        AiReportStatus.completed,
      ),
      isTrue,
    );
    expect(
      AiReportLifecycle.canTransition(
        AiReportStatus.completed,
        AiReportStatus.generating,
      ),
      isTrue,
    );
    expect(
      AiReportLifecycle.canTransition(
        AiReportStatus.generating,
        AiReportStatus.failed,
      ),
      isTrue,
    );
    expect(
      AiReportLifecycle.canTransition(
        AiReportStatus.completed,
        AiReportStatus.completed,
      ),
      isFalse,
    );
  });

  test('archived report is terminal', () {
    for (final target in AiReportStatus.values) {
      expect(
        () => AiReportLifecycle.requireTransition(
          AiReportStatus.archived,
          target,
        ),
        throwsA(isA<InvalidAiReportTransitionException>()),
      );
    }
  });
}
