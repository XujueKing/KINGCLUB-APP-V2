import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/push_open_runtime.dart';
import 'package:kingclub/src/features/messaging/data/push_open_store.dart';

class FailingStore extends PushOpenStore {
  String? value;
  bool failWrite = false, failDelete = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> save(String raw) async {
    if (failWrite) throw StateError('write unavailable');
    value = raw;
  }

  @override
  Future<void> clear() async {
    if (failDelete) throw StateError('delete unavailable');
    value = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2026, 9, 27);
  const account = (account: 'recipient', sessionId: 'session');
  String payload() => jsonEncode({
    'version': 1,
    'eventId': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    'recipient': account.account,
    'target': 'sender',
    'scope': 'direct',
    'kind': 'message',
    'expiresAt': now.add(const Duration(minutes: 1)).millisecondsSinceEpoch,
    'unexpectedBody': 'must not persist',
  });
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'new runtime restores secure destination after bootstrap interruption',
    () async {
      final queue = [payload()];
      var opened = 0;
      final first = PushOpenRuntime(
        store: PushOpenStore(),
        now: () => now,
        takePending: () async => queue.isEmpty ? null : queue.removeAt(0),
        readySession: () async => null,
        open: (_, _) async {
          opened++;
          return true;
        },
      );
      await first.sync();
      expect(opened, 0);
      final saved = await PushOpenStore().read();
      expect(saved, isNotNull);
      expect(saved, isNot(contains('unexpectedBody')));
      first.close();
      final second = PushOpenRuntime(
        store: PushOpenStore(),
        now: () => now,
        takePending: () async => null,
        readySession: () async => account,
        open: (target, _) async {
          expect(target.target, 'sender');
          opened++;
          return true;
        },
      );
      addTearDown(second.close);
      await second.sync();
      expect(opened, 1);
      expect(await PushOpenStore().read(), isNull);
      await second.sync();
      expect(opened, 1);
    },
  );

  for (final scenario in ['expired', 'invalid', 'other-account']) {
    test(
      'restored $scenario destination is deleted without navigation',
      () async {
        await PushOpenStore().save(
          scenario == 'invalid' ? 'invalid' : payload(),
        );
        var opened = 0;
        final runtime = PushOpenRuntime(
          store: PushOpenStore(),
          now: () =>
              scenario == 'expired' ? now.add(const Duration(minutes: 2)) : now,
          takePending: () async => null,
          readySession: () async => (account: 'other', sessionId: 'other'),
          open: (_, _) async {
            opened++;
            return true;
          },
        );
        addTearDown(runtime.close);
        await runtime.sync();
        expect(opened, 0);
        expect(await PushOpenStore().read(), isNull);
      },
    );
  }

  test('failed save retries before navigating', () async {
    final store = FailingStore()..failWrite = true;
    final queue = [payload()];
    var opened = 0;
    final runtime = PushOpenRuntime(
      store: store,
      now: () => now,
      takePending: () async => queue.isEmpty ? null : queue.removeAt(0),
      readySession: () async => account,
      open: (_, _) async {
        expect(store.value, isNotNull);
        opened++;
        return true;
      },
    );
    addTearDown(runtime.close);
    await runtime.sync();
    expect(opened, 0);
    store.failWrite = false;
    await runtime.sync();
    expect(opened, 1);
    expect(store.value, isNull);
  });

  test(
    'account switch stays discarded when secure deletion initially fails',
    () async {
      final store = FailingStore()
        ..value = payload()
        ..failDelete = true;
      var ready = (account: 'other', sessionId: 'other');
      var opened = 0;
      final runtime = PushOpenRuntime(
        store: store,
        now: () => now,
        takePending: () async => null,
        readySession: () async => ready,
        open: (_, _) async {
          opened++;
          return true;
        },
      );
      addTearDown(runtime.close);
      await runtime.sync();
      ready = account;
      store.failDelete = false;
      await runtime.sync();
      expect(opened, 0);
      expect(store.value, isNull);
    },
  );
}
