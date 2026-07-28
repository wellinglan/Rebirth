import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/features/sync/data/sync_providers.dart';
import 'package:rebirth/features/sync/domain/profile_sync_repository.dart';
import 'package:rebirth/shared/state/profile_revision_provider.dart';

import 'profile_sync_repository_impl.dart';

final profileSyncRepositoryProvider = Provider<ProfileSyncRepository>((ref) {
  return ProfileSyncRepositoryImpl(
    coordinator: ref.watch(syncCoordinatorProvider),
    adapter: ref.watch(profileSyncAdapterProvider),
  );
});

final profileSyncConflictProvider = FutureProvider.autoDispose<bool>((ref) {
  ref.watch(profileRevisionProvider);
  return ref.watch(profileSyncRepositoryProvider).hasConflict();
});
