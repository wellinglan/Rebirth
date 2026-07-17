import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/ai_coach/data/local_ai_generation_request_binding_store.dart';
import 'package:rebirth/features/ai_coach/domain/ai_generation_request_binding.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('v2 binding persists independently without request content', () async {
    final store = LocalAiGenerationRequestBindingStore();
    final binding = _binding('local-report');

    await store.save(binding);
    final restored = await LocalAiGenerationRequestBindingStore().read(
      binding.localReportId,
    );

    expect(restored?.requestId, binding.requestId);
    expect(restored?.normalizedEndpoint, 'http://127.0.0.1:8000');
    expect(restored?.cloudUserId, 'cloud-user-local-report');
    final preferences = await SharedPreferences.getInstance();
    final itemKeys = preferences
        .getKeys()
        .where(
          (key) =>
              key.startsWith(LocalAiGenerationRequestBindingStore.v2KeyPrefix),
        )
        .toList();
    expect(itemKeys, hasLength(1));
    final raw = preferences.getString(itemKeys.single)!;
    expect(raw, isNot(contains('canonical')));
    expect(raw, isNot(contains('journal')));
    expect(raw, isNot(contains('access_token')));
    expect(raw, isNot(contains('payload')));
  });

  test('v1 aggregate migrates once and migration is idempotent', () async {
    final one = _binding('one');
    final two = _binding('two');
    SharedPreferences.setMockInitialValues({
      LocalAiGenerationRequestBindingStore.legacyV1Key: jsonEncode({
        'one': _json(one),
        'two': _json(two),
      }),
    });

    final first = LocalAiGenerationRequestBindingStore();
    expect(await first.readAll(), hasLength(2));
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getBool(
        LocalAiGenerationRequestBindingStore.migrationMarkerKey,
      ),
      isTrue,
    );
    expect(
      preferences.containsKey(LocalAiGenerationRequestBindingStore.legacyV1Key),
      isFalse,
    );

    final second = LocalAiGenerationRequestBindingStore();
    expect(await second.readAll(), hasLength(2));
    expect(
      preferences.getKeys().where(
        (key) =>
            key.startsWith(LocalAiGenerationRequestBindingStore.v2KeyPrefix),
      ),
      hasLength(2),
    );
  });

  test('failed v1 migration never deletes legacy data', () async {
    SharedPreferences.setMockInitialValues({
      LocalAiGenerationRequestBindingStore.legacyV1Key: '{not-json',
    });
    final store = LocalAiGenerationRequestBindingStore();

    await expectLater(store.readAll(), throwsStateError);
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString(LocalAiGenerationRequestBindingStore.legacyV1Key),
      '{not-json',
    );
    expect(
      preferences.containsKey(
        LocalAiGenerationRequestBindingStore.migrationMarkerKey,
      ),
      isFalse,
    );
  });

  test('concurrent saves for different reports never overwrite', () async {
    final store = LocalAiGenerationRequestBindingStore();
    await Future.wait([
      store.save(_binding('one')),
      store.save(_binding('two')),
    ]);

    final all = await store.readAll();
    expect(all.map((binding) => binding.localReportId).toSet(), {'one', 'two'});
  });

  test('save and delete are serialized in invocation order', () async {
    final store = LocalAiGenerationRequestBindingStore();
    await Future.wait([store.save(_binding('same')), store.delete('same')]);
    expect(await store.read('same'), isNull);

    await Future.wait([store.delete('same'), store.save(_binding('same'))]);
    expect(await store.read('same'), isNotNull);
  });

  test('deleting a terminal binding preserves every other item', () async {
    final store = LocalAiGenerationRequestBindingStore();
    await Future.wait([
      store.save(_binding('one')),
      store.save(_binding('two')),
    ]);
    await store.delete('one');

    expect(await store.read('one'), isNull);
    expect((await store.read('two'))?.requestId, 'two-request');
  });

  test('corrupt v2 item does not affect valid bindings', () async {
    final store = LocalAiGenerationRequestBindingStore();
    await store.save(_binding('valid'));
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      '${LocalAiGenerationRequestBindingStore.v2KeyPrefix}corrupt',
      '{not-json',
    );

    final all = await store.readAll();
    expect(all, hasLength(1));
    expect(all.single.localReportId, 'valid');
  });

  test('different endpoints and accounts remain isolated', () async {
    final store = LocalAiGenerationRequestBindingStore();
    await Future.wait([
      store.save(_binding('one')),
      store.save(
        _binding(
          'two',
          endpoint: 'https://second.example.com/',
          userId: 'second-user',
        ),
      ),
    ]);

    final one = await store.read('one');
    final two = await store.read('two');
    expect(one?.normalizedEndpoint, 'http://127.0.0.1:8000');
    expect(one?.cloudUserId, 'cloud-user-one');
    expect(two?.normalizedEndpoint, 'https://second.example.com');
    expect(two?.cloudUserId, 'second-user');
  });
}

AiGenerationRequestBinding _binding(
  String id, {
  String endpoint = 'http://127.0.0.1:8000/',
  String? userId,
}) => AiGenerationRequestBinding(
  localReportId: id,
  requestId: '$id-request',
  normalizedEndpoint: endpoint,
  cloudUserId: userId ?? 'cloud-user-$id',
  inputHash: 'a' * 64,
  reportType: 'weekly_report',
  promptVersion: 'weekly-report-v1',
  createdAt: 1,
);

Map<String, Object?> _json(AiGenerationRequestBinding binding) => {
  'local_report_id': binding.localReportId,
  'request_id': binding.requestId,
  'normalized_endpoint': binding.normalizedEndpoint,
  'cloud_user_id': binding.cloudUserId,
  'input_hash': binding.inputHash,
  'report_type': binding.reportType,
  'prompt_version': binding.promptVersion,
  'created_at': binding.createdAt,
};
