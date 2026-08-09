import 'package:rebirth/features/ai_coach/domain/ai_report_status.dart';

final class AiCoachTaskCardModel {
  const AiCoachTaskCardModel({
    required this.id,
    required this.title,
    required this.periodLabel,
    required this.message,
    required this.actionLabel,
    required this.iconName,
    required this.actionEnabled,
    this.reportId,
    this.reportStatus,
  });

  final String id;
  final String title;
  final String periodLabel;
  final String message;
  final String actionLabel;
  final String iconName;
  final bool actionEnabled;
  final String? reportId;
  final AiReportStatus? reportStatus;

  bool get opensReport => reportId != null;
}
