import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/ai_coach/data/local_ai_generation_request_binding_store.dart';
import 'package:rebirth/features/ai_coach/domain/ai_generation_request_binding.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('binding persists across store instances without request content', () async {
    final store = LocalAiGenerationRequestBindingStore();
    const binding = AiGenerationRequestBinding(
      localReportId: 'local-report',
      requestId: '11111111-2222-4333-8444-555555555555',
      normalizedEndpoint: 'http://127.0.0.1:8000/',
      cloudUserId: 'cloud-user',
      inputHash:
          '12345678aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa87654321',
      reportType: 'weekly_report',
      promptVersion: 'weekly-report-v1',
      createdAt: 123,
    );

    await store.save(binding);
    final restored = await LocalAiGenerationRequestBindingStore().read(
      binding.localReportId,
    );

    expect(restored?.requestId, binding.requestId);
    expect(restored?.normalizedEndpoint, 'http://127.0.0.1:8000');
    expect(restored?.cloudUserId, 'cloud-user');
    final raw = (await SharedPreferences.getInstance()).getString(
      'rebirth.ai.generation_request_bindings.v1',
    );
    expect(raw, isNot(contains('canonical')));
    expect(raw, isNot(contains('journal')));
    expect(raw, isNot(contains('access_token')));
    expect(raw, isNot(contains('payload')));
  });

  test('bindings are isolated by local report id and can be deleted', () async {
    final store = LocalAiGenerationRequestBindingStore();
    for (final id in ['one', 'two']) {
      await store.save(
        AiGenerationRequestBinding(
          localReportId: id,
          requestId: '$id-request',
          normalizedEndpoint: 'https://example.com',
          cloudUserId: 'user',
          inputHash: 'a' * 64,
          reportType: 'weekly_report',
          promptVersion: 'weekly-report-v1',
          createdAt: 1,
        ),
      );
    }
    expect(await store.readAll(), hasLength(2));
    await store.delete('one');
    expect(await store.read('one'), isNull);
    expect((await store.read('two'))?.requestId, 'two-request');
  });
}
