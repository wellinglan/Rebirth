import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/database/database_provider.dart';
import 'package:rebirth/features/account/domain/app_auth_state.dart';
import 'package:rebirth/features/account/presentation/app_auth_controller.dart';
import 'package:rebirth/features/personal_data/application/personal_data_providers.dart';

void main() {
  test('authenticated composition root registers all five providers', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final userId = (await database.bootstrapDao.bootstrap(
      createUnboundProfile: true,
    )).activeUserId;
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        appAuthStateProvider.overrideWithValue(
          AsyncData(
            AppAuthState(
              status: AppAuthStatus.authenticatedOffline,
              localUserId: userId,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final registry = container.read(personalDataProviderRegistryProvider);

    expect(
      registry.providers.map((entry) => entry.descriptor.providerId.value),
      [
        'rebirth.profile',
        'rebirth.plan',
        'rebirth.today',
        'rebirth.journal',
        'rebirth.health',
      ],
    );
  });

  test('signed-out composition root exposes no account-scoped providers', () {
    final container = ProviderContainer(
      overrides: [
        appAuthStateProvider.overrideWithValue(
          const AsyncData(AppAuthState.signedOut()),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(personalDataProviderRegistryProvider).providers,
      isEmpty,
    );
  });
}
