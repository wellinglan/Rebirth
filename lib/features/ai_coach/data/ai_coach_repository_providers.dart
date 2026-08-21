import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/database/database_provider.dart';
import 'package:rebirth/core/config/server_endpoint_provider.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/core/network/api_client_provider.dart';
import 'package:rebirth/features/account/data/account_repository_provider.dart';
import 'package:rebirth/features/ai_coach/domain/ai_coach_input_assembler.dart';
import 'package:rebirth/features/ai_coach/domain/ai_consent_repository.dart';
import 'package:rebirth/features/ai_coach/domain/ai_chat_repository.dart';
import 'package:rebirth/features/ai_coach/domain/ai_chat_input_assembler.dart';
import 'package:rebirth/features/ai_coach/domain/ai_chat_gateway.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_repository.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_feedback_repository.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_feedback_remote_data_source.dart';
import 'package:rebirth/features/ai_coach/domain/daily_report_freshness_service.dart';
import 'package:rebirth/features/ai_coach/domain/canonical_json_encoder.dart';
import 'package:rebirth/features/ai_coach/domain/input_hash_service.dart';
import 'package:rebirth/features/ai_coach/domain/ai_generation_gateway.dart';
import 'package:rebirth/features/growth/data/growth_repository_provider.dart';
import 'package:rebirth/features/health/data/health_repository_provider.dart';
import 'package:rebirth/features/journal/data/journal_repository_provider.dart';
import 'package:rebirth/features/today/data/today_repository_provider.dart';

import 'ai_coach_input_assembler_impl.dart';
import 'ai_chat_input_assembler_impl.dart';
import 'canonical_json_encoder_impl.dart';
import 'local_ai_consent_repository.dart';
import 'local_ai_chat_repository.dart';
import 'local_ai_report_repository.dart';
import 'local_ai_report_feedback_repository.dart';
import 'remote_ai_report_feedback_data_source.dart';
import 'ai_report_feedback_sync_service_impl.dart';
import 'sha256_input_hash_service.dart';
import 'remote_ai_generation_gateway.dart';
import 'remote_ai_chat_gateway.dart';
import 'local_ai_generation_request_binding_store.dart';
import '../domain/ai_generation_request_binding.dart';

final aiGenerationGatewayProvider = Provider<AiGenerationGateway>((ref) {
  return RemoteAiGenerationGateway(
    apiClient: ref.watch(apiClientProvider),
    sessionManager: ref.watch(authSessionManagerProvider),
  );
});

final aiGenerationRequestBindingStoreProvider =
    Provider<AiGenerationRequestBindingStore>((ref) {
      return LocalAiGenerationRequestBindingStore(
        endpointValidator: ref.watch(serverEndpointValidatorProvider),
      );
    });

final canonicalJsonEncoderProvider = Provider<CanonicalJsonEncoder>((ref) {
  return const CanonicalJsonEncoderImpl();
});

final inputHashServiceProvider = Provider<InputHashService>((ref) {
  return const Sha256InputHashService();
});

final aiConsentRepositoryProvider = Provider<AiConsentRepository>((ref) {
  return LocalAiConsentRepository(
    database: ref.watch(appDatabaseProvider),
    dateTimeService: ref.watch(dateTimeServiceProvider),
  );
});

final aiChatRepositoryProvider = Provider<AiChatRepository>((ref) {
  return LocalAiChatRepository(
    database: ref.watch(appDatabaseProvider),
    dateTimeService: ref.watch(dateTimeServiceProvider),
  );
});

final aiChatGatewayProvider = Provider<AiChatGateway>((ref) {
  return RemoteAiChatGateway(
    apiClient: ref.watch(apiClientProvider),
    sessionManager: ref.watch(authSessionManagerProvider),
  );
});

final aiChatInputAssemblerProvider = Provider<AiChatInputAssembler>((ref) {
  return AiChatInputAssemblerImpl(
    consentRepository: ref.watch(aiConsentRepositoryProvider),
    growthRepository: ref.watch(growthRepositoryProvider),
    todayRepository: ref.watch(todayRepositoryProvider),
    healthRepository: ref.watch(healthRepositoryProvider),
    journalRepository: ref.watch(journalRepositoryProvider),
    dateTimeService: ref.watch(dateTimeServiceProvider),
    canonicalJsonEncoder: ref.watch(canonicalJsonEncoderProvider),
    inputHashService: ref.watch(inputHashServiceProvider),
  );
});

final aiCoachInputAssemblerProvider = Provider<AiCoachInputAssembler>((ref) {
  return AiCoachInputAssemblerImpl(
    consentRepository: ref.watch(aiConsentRepositoryProvider),
    growthRepository: ref.watch(growthRepositoryProvider),
    todayRepository: ref.watch(todayRepositoryProvider),
    healthRepository: ref.watch(healthRepositoryProvider),
    journalRepository: ref.watch(journalRepositoryProvider),
    dateTimeService: ref.watch(dateTimeServiceProvider),
    canonicalJsonEncoder: ref.watch(canonicalJsonEncoderProvider),
    inputHashService: ref.watch(inputHashServiceProvider),
  );
});

final dailyReportFreshnessServiceProvider =
    Provider<DailyReportFreshnessService>((ref) {
      return DailyReportFreshnessService(
        inputAssembler: ref.watch(aiCoachInputAssemblerProvider),
      );
    });

final aiReportRepositoryProvider = Provider<AiReportRepository>((ref) {
  return LocalAiReportRepository(
    database: ref.watch(appDatabaseProvider),
    dateTimeService: ref.watch(dateTimeServiceProvider),
    consentRepository: ref.watch(aiConsentRepositoryProvider),
    canonicalJsonEncoder: ref.watch(canonicalJsonEncoderProvider),
  );
});

final aiReportFeedbackRepositoryProvider = Provider<AiReportFeedbackRepository>(
  (ref) {
    return LocalAiReportFeedbackRepository(
      database: ref.watch(appDatabaseProvider),
      dateTimeService: ref.watch(dateTimeServiceProvider),
    );
  },
);

final aiReportFeedbackRemoteDataSourceProvider =
    Provider<AiReportFeedbackRemoteDataSource>((ref) {
      return RemoteAiReportFeedbackDataSource(
        apiClient: ref.watch(apiClientProvider),
        sessionManager: ref.watch(authSessionManagerProvider),
      );
    });

final aiReportFeedbackSyncServiceProvider =
    Provider<AiReportFeedbackSyncService>((ref) {
      return AiReportFeedbackSyncServiceImpl(
        repository: ref.watch(aiReportFeedbackRepositoryProvider),
        remoteDataSource: ref.watch(aiReportFeedbackRemoteDataSourceProvider),
      );
    });
