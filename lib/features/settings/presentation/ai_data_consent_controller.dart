import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/features/ai_coach/data/ai_coach_repository_providers.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_authorization.dart';

final aiDataConsentControllerProvider =
    AsyncNotifierProvider<AiDataConsentController, AiDataConsentViewState>(
      AiDataConsentController.new,
    );

final class AiDataConsentViewState {
  const AiDataConsentViewState({
    required this.authorization,
    this.isSaving = false,
    this.errorMessage,
  });

  final AiDataAuthorization authorization;
  final bool isSaving;
  final String? errorMessage;

  AiDataConsentViewState copyWith({
    AiDataAuthorization? authorization,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AiDataConsentViewState(
      authorization: authorization ?? this.authorization,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class AiDataConsentController extends AsyncNotifier<AiDataConsentViewState> {
  @override
  Future<AiDataConsentViewState> build() async {
    final authorization = await ref.read(aiConsentRepositoryProvider).read();
    return AiDataConsentViewState(authorization: authorization);
  }

  Future<void> reload() async {
    state = const AsyncLoading<AiDataConsentViewState>();
    state = await AsyncValue.guard(build);
  }

  Future<bool> grant() => _mutate(grant: true);

  Future<bool> revoke() => _mutate(grant: false);

  Future<bool> _mutate({required bool grant}) async {
    final current = state.value;
    if (current == null || current.isSaving) return false;
    state = AsyncData(current.copyWith(isSaving: true, clearError: true));
    try {
      final repository = ref.read(aiConsentRepositoryProvider);
      final authorization = grant
          ? await repository.grant()
          : await repository.revoke();
      state = AsyncData(AiDataConsentViewState(authorization: authorization));
      return true;
    } catch (_) {
      state = AsyncData(
        current.copyWith(
          isSaving: false,
          errorMessage: grant ? '启用失败，请重试。' : '撤销失败，请重试。',
        ),
      );
      return false;
    }
  }
}
