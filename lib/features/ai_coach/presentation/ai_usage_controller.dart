import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/features/ai_coach/data/ai_coach_repository_providers.dart';
import 'package:rebirth/features/ai_coach/domain/ai_usage_snapshot.dart';

final aiUsageControllerFamily = AsyncNotifierProvider.autoDispose
    .family<AiUsageController, AiUsageSnapshot, AiUsageScope>(
      AiUsageController.new,
    );

final aiUsageControllerProvider = aiUsageControllerFamily(AiUsageScope.reports);
final aiChatUsageControllerProvider = aiUsageControllerFamily(
  AiUsageScope.chat,
);

class AiUsageController extends AsyncNotifier<AiUsageSnapshot> {
  AiUsageController(this.scope);

  final AiUsageScope scope;
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
      final usage = await ref
          .read(aiGenerationGatewayProvider)
          .getUsage(scope: scope);
      if (ref.mounted) state = AsyncData(usage);
      return usage;
    } catch (_) {
      const usage = AiUsageSnapshot.unknown();
      if (ref.mounted) state = const AsyncData(usage);
      return usage;
    }
  }
}
