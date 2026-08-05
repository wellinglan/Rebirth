import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/files/file_export_provider.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/account/presentation/app_auth_controller.dart';
import 'package:rebirth/features/ai_coach/data/ai_coach_repository_providers.dart';
import 'package:rebirth/features/ai_reports/domain/ai_report_export_service.dart';
import 'package:rebirth/features/ai_reports/domain/ai_report_file_export_adapter.dart';

import 'ai_report_export_service_impl.dart';
import 'platform_ai_report_export_adapter.dart';

final aiReportFileExportAdapterProvider = Provider<AiReportFileExportAdapter>(
  (ref) => PlatformAiReportExportAdapter(
    fileExportAdapter: ref.watch(fileExportAdapterProvider),
  ),
);

final aiReportExportServiceProvider = Provider<AiReportExportService>((ref) {
  return AiReportExportServiceImpl(
    repository: ref.watch(aiReportRepositoryProvider),
    fileExportAdapter: ref.watch(aiReportFileExportAdapterProvider),
    dateTimeService: ref.watch(dateTimeServiceProvider),
    activeUserId: () {
      final auth = ref.read(appAuthStateProvider).value;
      if (auth == null || !auth.canAccessBusiness) return null;
      return auth.localUserId;
    },
  );
});
