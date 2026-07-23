import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/features/ai_coach/data/ai_coach_repository_providers.dart';
import 'package:rebirth/features/ai_coach/domain/daily_report_freshness.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_type.dart';

final aiDailyReportFreshnessProvider = FutureProvider.autoDispose
    .family<DailyReportFreshnessResult?, String>((ref, reportId) async {
      if (reportId.trim().isEmpty) return null;
      final repository = ref.read(aiReportRepositoryProvider);
      final freshnessService = ref.read(dailyReportFreshnessServiceProvider);
      final report = await repository.getById(reportId);
      if (report == null || report.reportType != AiReportType.dailyInsight) {
        return null;
      }
      return freshnessService.evaluate(report);
    });
