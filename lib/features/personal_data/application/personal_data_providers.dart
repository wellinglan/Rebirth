import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/database/database_provider.dart';
import 'package:rebirth/features/account/presentation/app_auth_controller.dart';

import '../data/providers/health_personal_data_provider.dart';
import '../data/providers/journal_personal_data_provider.dart';
import '../data/providers/plan_personal_data_provider.dart';
import '../data/providers/profile_personal_data_provider.dart';
import '../data/providers/today_personal_data_provider.dart';
import 'personal_data_aggregation_engine.dart';
import 'personal_data_provider_registry.dart';

final personalDataProviderRegistryProvider =
    Provider<PersonalDataProviderRegistry>((ref) {
      final auth = ref.watch(appAuthStateProvider).value;
      final localUserId = auth?.localUserId;
      if (auth?.canAccessBusiness != true || localUserId == null) {
        return PersonalDataProviderRegistry(const []);
      }
      final database = ref.watch(appDatabaseProvider);
      return PersonalDataProviderRegistry([
        ProfilePersonalDataProvider(
          database: database,
          localUserId: localUserId,
        ),
        PlanPersonalDataProvider(database: database, localUserId: localUserId),
        TodayPersonalDataProvider(database: database, localUserId: localUserId),
        JournalPersonalDataProvider(
          database: database,
          localUserId: localUserId,
        ),
        HealthPersonalDataProvider(
          database: database,
          localUserId: localUserId,
        ),
      ]);
    });

final personalDataAggregationEngineProvider =
    Provider<PersonalDataAggregationEngine>((ref) {
      return PersonalDataAggregationEngine(
        ref.watch(personalDataProviderRegistryProvider),
      );
    });
