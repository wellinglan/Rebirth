import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/ai_coach/data/ai_coach_repository_providers.dart';
import 'package:rebirth/features/ai_coach/domain/ai_usage_snapshot.dart';
import 'package:rebirth/features/ai_coach/presentation/ai_usage_controller.dart';

import '../ai_coach_test_support.dart';

void main() {
  test('loads and explicitly refreshes the current user usage', () async {
    final gateway = FakeAiGenerationGateway();
    final container = ProviderContainer(
      overrides: [aiGenerationGatewayProvider.overrideWithValue(gateway)],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      aiUsageControllerProvider,
      (previous, next) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    final initial = await container.read(aiUsageControllerProvider.future);
    expect(initial.used, 2);
    expect(gateway.usageCalls, 1);

    gateway.usage = const AiUsageSnapshot(
      availability: AiUsageAvailability.limitReached,
      enabled: true,
      dailyLimit: 10,
      used: 10,
      remaining: 0,
      resetsAtUtcMilliseconds: 1785628800000,
    );
    final refreshed = await container
        .read(aiUsageControllerProvider.notifier)
        .refresh();

    expect(refreshed.availability, AiUsageAvailability.limitReached);
    expect(container.read(aiUsageControllerProvider).value?.remaining, 0);
    expect(gateway.usageCalls, 2);
  });

  test('degrades a usage query failure to unknown', () async {
    final gateway = FakeAiGenerationGateway()
      ..usageError = StateError('network unavailable');
    final container = ProviderContainer(
      overrides: [aiGenerationGatewayProvider.overrideWithValue(gateway)],
    );
    addTearDown(container.dispose);

    final result = await container.read(aiUsageControllerProvider.future);

    expect(result.availability, AiUsageAvailability.unknown);
    expect(result.preventsGeneration, isFalse);
    expect(gateway.usageCalls, 1);
  });
}
