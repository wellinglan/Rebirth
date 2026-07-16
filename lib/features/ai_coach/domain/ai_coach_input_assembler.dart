import 'ai_coach_input_bundle.dart';
import 'ai_data_selection.dart';
import 'ai_report_type.dart';

abstract interface class AiCoachInputAssembler {
  Future<AiCoachInputBundle> build({
    required AiReportType reportType,
    required AiDataSelection selection,
  });

  Future<AiCoachInputBundle> buildWeeklyReport({
    required AiDataSelection selection,
  });
}
