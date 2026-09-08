import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/database/database_provider.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/sync/domain/cloud_sync_preference_repository.dart';

import 'local_cloud_sync_preference_repository.dart';

final cloudSyncPreferenceRepositoryProvider =
    Provider<CloudSyncPreferenceRepository>((ref) {
      return LocalCloudSyncPreferenceRepository(
        database: ref.watch(appDatabaseProvider),
        dateTimeService: ref.watch(dateTimeServiceProvider),
      );
    });
