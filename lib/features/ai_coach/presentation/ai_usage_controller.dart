import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/features/ai_coach/data/ai_coach_repository_providers.dart';
import 'package:rebirth/features/ai_coach/domain/ai_usage_snapshot.dart';

final aiUsageControllerProvider =
    AsyncNotifierProvider.autoDispose<AiUsageController, AiUsageSnapshot>(
      AiUsageController.new,
    );

class AiUsageController extends AsyncNotifier<AiUsageSnapshot> {
  Future<AiUsageSnapshot>? _activeRefresh;

  @override
  Future<AiUsageSnapshot> build() => _load();

  Future<AiUsageSnapshot> refresh() {
    final active = _activeRefresh;
    if (active != null) return active;
    final future = _load();
    _activeRefresh = future;
    return future.whenComplete(() {
      _activeRefresh = null;
    });
  }

  Future<AiUsageSnapshot> _load() async {
    try {
      final usage = await ref.read(aiGenerationGatewayProvider).getUsage();
      if (ref.mounted) state = AsyncData(usage);
      return usage;
    } catch (_) {
      const usage = AiUsageSnapshot.unknown();
      if (ref.mounted) state = const AsyncData(usage);
      return usage;
    }
  }
}
