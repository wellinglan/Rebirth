import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/sync/data/sync_cursor_store_impl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('cursor defaults to zero and persists after store recreation', () async {
    final store = LocalSyncCursorStore();
    expect(await _read(store), 0);

    await _write(store, 12);

    expect(await _read(LocalSyncCursorStore()), 12);
  });

  test('cursor is isolated by endpoint, cloud user, and scope', () async {
    final store = LocalSyncCursorStore();
    await _write(store, 8);

    expect(
      await store.read(
        endpoint: 'http://server-b:8000',
        cloudUserId: 'user-a',
        scope: 'user_profiles',
      ),
      0,
    );
    expect(
      await store.read(
        endpoint: 'http://server-a:8000',
        cloudUserId: 'user-b',
        scope: 'user_profiles',
      ),
      0,
    );
    expect(
      await store.read(
        endpoint: 'http://server-a:8000',
        cloudUserId: 'user-a',
        scope: 'today_records',
      ),
      0,
    );
  });

  test('clear can remove one scope without touching another', () async {
    final store = LocalSyncCursorStore();
    await _write(store, 8);
    await store.write(
      endpoint: 'http://server-a:8000',
      cloudUserId: 'user-a',
      scope: 'today_records',
      serverVersion: 4,
    );

    await store.clear(
      endpoint: 'http://server-a:8000',
      cloudUserId: 'user-a',
      scope: 'user_profiles',
    );

    expect(await _read(store), 0);
    expect(
      await store.read(
        endpoint: 'http://server-a:8000',
        cloudUserId: 'user-a',
        scope: 'today_records',
      ),
      4,
    );
  });
}

Future<int> _read(LocalSyncCursorStore store) {
  return store.read(
    endpoint: 'http://server-a:8000',
    cloudUserId: 'user-a',
    scope: 'user_profiles',
  );
}

Future<void> _write(LocalSyncCursorStore store, int version) {
  return store.write(
    endpoint: 'http://server-a:8000',
    cloudUserId: 'user-a',
    scope: 'user_profiles',
    serverVersion: version,
  );
}

