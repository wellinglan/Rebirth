import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/database/database_provider.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/core/network/api_client_provider.dart';
import 'package:rebirth/features/account/data/account_repository_provider.dart';
import 'package:rebirth/features/ai_coach/domain/ai_coach_input_assembler.dart';
import 'package:rebirth/features/ai_coach/domain/ai_consent_repository.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_repository.dart';
import 'package:rebirth/features/ai_coach/domain/canonical_json_encoder.dart';
import 'package:rebirth/features/ai_coach/domain/input_hash_service.dart';
import 'package:rebirth/features/ai_coach/domain/ai_generation_gateway.dart';
import 'package:rebirth/features/growth/data/growth_repository_provider.dart';
import 'package:rebirth/features/health/data/health_repository_provider.dart';
import 'package:rebirth/features/journal/data/journal_repository_provider.dart';
import 'package:rebirth/features/today/data/today_repository_provider.dart';

import 'ai_coach_input_assembler_impl.dart';
import 'canonical_json_encoder_impl.dart';
import 'local_ai_consent_repository.dart';
import 'local_ai_report_repository.dart';
import 'sha256_input_hash_service.dart';
import 'remote_ai_generation_gateway.dart';

final aiGenerationGatewayProvider = Provider<AiGenerationGateway>((ref) {
  return RemoteAiGenerationGateway(
    apiClient: ref.watch(apiClientProvider),
    sessionStore: ref.watch(authSessionStoreProvider),
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

final aiReportRepositoryProvider = Provider<AiReportRepository>((ref) {
  return LocalAiReportRepository(
    database: ref.watch(appDatabaseProvider),
    dateTimeService: ref.watch(dateTimeServiceProvider),
    consentRepository: ref.watch(aiConsentRepositoryProvider),
    canonicalJsonEncoder: ref.watch(canonicalJsonEncoderProvider),
  );
});
