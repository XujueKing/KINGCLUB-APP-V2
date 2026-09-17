import 'dart:async';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_store.dart';
import 'package:kingclub/src/features/messaging/data/direct_chat_controller.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';

import 'direct_chat_controller_test.dart' show MemoryOutbox, ack, history;

void main() {
  sqfliteFfiInit();
  late Directory dir;
  late ChatHistoryStore store;
  late SecretKey key;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('direct-history-');
    key = await AesGcm.with256bits().newSecretKey();
    store = await ChatHistoryStore.openDatabaseWithKey(
      factory: databaseFactoryFfi,
      file: '${dir.path}/history.db',
      key: key,
      account: 'me',
    );
  });
  tearDown(() async {
    await store.close();
    await dir.delete(recursive: true);
  });
  Map<String, dynamic> response(
    List<Map<String, dynamic>> rows, {
    int hidden = 0,
  }) => {
    ...history(rows),
    'settings': {'hiddenThrough': hidden},
  };
  Map<String, dynamic> message(int n) =>
      ack({'clientMessageId': 'c$n', 'text': 'message$n'}, sequence: n);
  DirectChatController controller(ChatApiCall call) => DirectChatController(
    peer: 'peer',
    outbox: MemoryOutbox(),
    openHistory: () async => store,
    repository: MessagingRepository(account: 'me', call: call),
  );

  test(
    'old tombstones outside loaded pages survive stale server pagination',
    () async {
      await store.commit(
        'direct:peer',
        [
          for (var n = 1; n <= 120; n++)
            {
              ...message(n),
              if (n <= 2) 'messageType': n == 1 ? 'recalled' : 'hidden',
              if (n <= 2) 'text': '',
            },
        ],
        expectedEpoch: 0,
        cursor: 120,
      );
      var online = false;
      final chat = controller((method, params) async {
        if (!online) throw const AuthFailure('NETWORK_ERROR', 'offline');
        return {
          ...history([for (var n = 1; n <= 70; n++) message(n)]),
          'settings': {'hiddenThrough': 0},
        };
      });
      addTearDown(chat.dispose);
      await chat.initialize();
      expect(chat.messages, hasLength(50));
      online = true;
      await chat.loadOlder();
      expect(chat.error, isNull);
      expect(
        chat.messages.where((m) => m['sequence'] == 1).single['messageType'],
        'recalled',
      );
      expect(chat.messages.any((m) => m['sequence'] == 2), false);
    },
  );

  for (final confirmed in [false, true]) {
    test(
      'cleared history settles only an explicit receipt confirmed=$confirmed',
      () async {
        final queue = MemoryOutbox();
        await queue.put({
          'clientMessageId': 'c1',
          'sender': 'me',
          'recipient': 'peer',
          'text': 'message1',
          'status': 'failed',
          'createdDate': '2026-09-17T00:00:00Z',
        });
        final chat = DirectChatController(
          peer: 'peer',
          outbox: queue,
          openHistory: () async => store,
          repository: MessagingRepository(
            account: 'me',
            call: (method, params) async {
              expect(method, 'K260913000604');
              return response(confirmed ? [message(1)] : [], hidden: 1);
            },
          ),
        );
        addTearDown(chat.dispose);
        await chat.initialize();
        expect(chat.error, isNull);
        expect(queue.items.length, confirmed ? 0 : 1);
        expect(chat.messages.length, confirmed ? 0 : 1);
        final saved = await store.read('direct:peer');
        expect(saved.hiddenThrough, 1);
        expect(saved.messages, isEmpty);
        await chat.synchronize();
        expect(queue.items.length, confirmed ? 0 : 1);
        expect(chat.messages.length, confirmed ? 0 : 1);
      },
    );
  }
  for (final cached in [false, true]) {
    for (final code in ['NETWORK_ERROR', 'SESSION_EXPIRED']) {
      test('initial refresh error cache=$cached code=$code', () async {
        if (cached) {
          await store.commit(
            'direct:peer',
            [message(1)],
            expectedEpoch: 0,
            cursor: 1,
          );
        }
        final chat = controller(
          (_, _) async => throw AuthFailure(code, 'fixture'),
        );
        addTearDown(chat.dispose);
        await chat.initialize();
        expect(chat.messages.length, cached ? 1 : 0);
        if (cached && code == 'NETWORK_ERROR') {
          expect(chat.error, isNull);
        } else {
          expect(chat.error, isNotNull);
        }
      });
    }
  }
  test(
    'server peer reads survive database reopen and offline history',
    () async {
      final online = controller(
        (_, _) async => {
          ...response([message(1), message(2)]),
          'peerReadSequence': 2,
        },
      );
      await online.initialize();
      expect(online.error, isNull);
      online.dispose();
      // A late older snapshot cannot roll back the durable receipt either.
      await store.commit(
        'direct:peer',
        [],
        expectedEpoch: 0,
        peerReadSequence: 0,
        serverConversationId: 'conversation',
      );
      await store.close();
      store = await ChatHistoryStore.openDatabaseWithKey(
        factory: databaseFactoryFfi,
        file: '${dir.path}/history.db',
        key: key,
        account: 'me',
      );
      final offline = controller((_, _) async => throw StateError('offline'));
      await offline.initialize();
      expect(offline.messages, hasLength(2));
      expect(offline.peerReadSequence, 2);
      expect(offline.messages.every((row) => row['peerRead'] == true), true);
      offline.dispose();
      expect((await store.read('direct:another-peer')).presentation, isNull);
      final epoch = await store.clear('direct:peer');
      expect((await store.read('direct:peer')).presentation, isNull);
      expect(
        await store.commit(
          'direct:peer',
          [],
          expectedEpoch: epoch - 1,
          peerReadSequence: 9,
          serverConversationId: 'conversation',
        ),
        false,
      );
      expect((await store.read('direct:peer')).presentation, isNull);
    },
  );

  test('cached call metadata refresh preserves cursor and runs once', () async {
    await store.commit(
      'direct:peer',
      [message(1)],
      expectedEpoch: 0,
      cursor: 1,
    );
    final metadata = {
      'callId': '00000000-0000-4000-8000-000000000001',
      'mediaKind': 'audio',
      'endReason': 'hangup',
      'durationMs': 15000,
    };
    var latestRequests = 0;
    final chat = controller((_, params) async {
      if (params.containsKey('after')) return response([]);
      latestRequests++;
      return response([
        {...message(1), 'call': metadata},
      ]);
    });
    await chat.initialize();
    expect(chat.error, isNull);
    expect(chat.messages.single['call'], metadata);
    final saved = await store.read('direct:peer');
    expect(saved.cursor, 1);
    expect(saved.messages.single['call'], metadata);
    await chat.synchronize();
    expect(latestRequests, 1);
    chat.dispose();
  });

  test(
    'older cached page is visible before its metadata refresh completes',
    () async {
      await store.commit(
        'direct:peer',
        List.generate(75, (i) => message(i + 1)),
        expectedEpoch: 0,
        cursor: 75,
      );
      final pending = Completer<Map<String, dynamic>>();
      final requested = Completer<void>();
      final metadata = {
        'callId': '00000000-0000-4000-8000-000000000001',
        'mediaKind': 'video',
        'endReason': 'hangup',
        'durationMs': 29000,
      };
      final chat = controller((_, params) async {
        if (params.containsKey('before')) {
          expect(params['before'], 26);
          requested.complete();
          return pending.future;
        }
        return response([]);
      });
      await chat.initialize();
      final loading = chat.loadOlder();
      await requested.future.timeout(const Duration(seconds: 5));
      expect(chat.messages.length, 75);
      expect(pending.isCompleted, false);
      pending.complete(
        response([
          {...message(1), 'call': metadata},
          ...List.generate(24, (i) => message(i + 2)),
        ]),
      );
      await loading;
      expect(chat.error, isNull);
      expect(chat.messages.first['call'], metadata);
      final saved = await store.read('direct:peer', before: 26);
      expect(saved.cursor, 75);
      expect(saved.messages.first['call'], metadata);
      chat.dispose();
    },
  );

  test('transient cache opening failure can recover on next sync', () async {
    var opens = 0, requests = 0;
    final queue = MemoryOutbox();
    await queue.put({
      'clientMessageId': 'c1',
      'recipient': 'peer',
      'sender': 'me',
      'text': 'message1',
      'status': 'queued',
    });
    final chat = DirectChatController(
      peer: 'peer',
      outbox: queue,
      openHistory: () async {
        if (++opens == 1) throw StateError('temporary storage failure');
        return store;
      },
      repository: MessagingRepository(
        account: 'me',
        call: (_, _) async {
          requests++;
          return response([message(1)]);
        },
      ),
    );
    await chat.initialize();
    expect(chat.error, isNotNull);
    expect(requests, 0);
    expect(chat.messages.single['clientMessageId'], 'c1');
    await chat.synchronize();
    expect(opens, 2);
    expect(chat.error, isNull);
    expect(chat.messages.single['sequence'], 1);
    expect(await queue.read(), isEmpty);
    expect((await store.read('direct:peer')).messages.length, 1);
    chat.dispose();
  });
  test(
    'recall after offline cursor refresh removes old memory and disk payload',
    () async {
      var revision = 0;
      final requests = <Map<String, dynamic>>[];
      final chat = controller((id, params) async {
        requests.add(Map<String, dynamic>.from(params));
        final rows = params.containsKey('after')
            ? <Map<String, dynamic>>[]
            : [
                {
                  ...message(1),
                  if (revision > 0) 'messageType': 'recalled',
                  if (revision > 0) 'text': '消息已撤回',
                },
              ];
        return {...response(rows), 'historyVersion': revision};
      });
      await chat.initialize();
      expect(chat.error, isNull);
      expect(chat.messages.single['messageType'], isNot('recalled'));
      revision = 1;
      requests.clear();
      await chat.synchronize();
      expect(chat.error, isNull);
      expect(requests.first['after'], 1);
      expect(requests.last.containsKey('after'), false);
      expect(chat.messages.single['messageType'], 'recalled');
      final saved = await store.read('direct:peer');
      expect(saved.historyVersion, 1);
      expect(saved.messages.single['text'], '消息已撤回');
      chat.dispose();
      final offline = controller((_, _) async => throw StateError('offline'));
      await offline.initialize();
      expect(offline.messages.single['messageType'], 'recalled');
      offline.dispose();
    },
  );
  test(
    'reopening offline restores messages and loads older pages from disk',
    () async {
      await store.commit(
        'direct:peer',
        List.generate(75, (i) => message(i + 1)),
        expectedEpoch: 0,
        cursor: 75,
      );
      var calls = 0;
      final chat = controller((_, _) async {
        calls++;
        throw StateError('offline');
      });
      await chat.initialize();
      expect(chat.messages.length, 50);
      expect(chat.messages.first['sequence'], 26);
      await chat.loadOlder();
      expect(chat.messages.length, 75);
      expect(calls, 2);
      chat.dispose();
    },
  );
  test(
    'catch-up starts at committed cursor and remote clear survives reopen',
    () async {
      await store.commit(
        'direct:peer',
        [message(1)],
        expectedEpoch: 0,
        cursor: 1,
      );
      final chat = controller((_, params) async {
        if (params.containsKey('after')) expect(params['after'], 1);
        return response([message(2)], hidden: 1);
      });
      await chat.initialize();
      expect(chat.error, isNull);
      expect(chat.messages.single['sequence'], 2);
      final saved = await store.read('direct:peer');
      expect(saved.cursor, 2);
      expect(saved.hiddenThrough, 1);
      expect(saved.messages.single['sequence'], 2);
      chat.dispose();
      final offline = controller((_, _) async => throw StateError('offline'));
      await offline.initialize();
      expect(offline.messages.single['sequence'], 2);
      offline.dispose();
    },
  );
  test(
    'clearing during an in-flight fetch rejects old disk and memory writes',
    () async {
      final late = Completer<Map<String, dynamic>>();
      var calls = 0;
      final chat = controller((_, _) async {
        calls++;
        if (calls == 1) return response([message(1)]);
        if (calls == 2) return late.future;
        return response([], hidden: 2);
      });
      await chat.initialize();
      final sync = chat.synchronize();
      await Future<void>.delayed(Duration.zero);
      chat.resetVisibleHistory();
      late.complete(response([message(2)]));
      await sync;
      // A fresh sync waits for the persistent clear barrier before reading.
      final fresh = controller((_, _) async => throw StateError('offline'));
      await chat.synchronize();
      await fresh.initialize();
      expect(fresh.messages, isEmpty);
      chat.dispose();
      fresh.dispose();
    },
  );
  test(
    'send acknowledgement persists without skipping unseen history',
    () async {
      final chat = controller((id, params) async {
        if (id == 'K260913000601') return {'message': ack(params, sequence: 5)};
        return response([]);
      });
      await chat.initialize();
      await chat.send('saved outbound');
      final page = await store.read('direct:peer');
      expect(page.messages.single['text'], 'saved outbound');
      expect(page.cursor, 0);
      chat.dispose();
      final offline = controller((_, _) async => throw StateError('offline'));
      await offline.initialize();
      expect(offline.messages.single['text'], 'saved outbound');
      offline.dispose();
    },
  );
  test(
    'a store bound to another account cannot restore into this conversation',
    () async {
      final bad = DirectChatController(
        peer: 'peer',
        outbox: MemoryOutbox(),
        openHistory: () async => store,
        repository: MessagingRepository(
          account: 'other',
          call: (_, _) async => throw StateError('must not call'),
        ),
      );
      await bad.initialize();
      expect(bad.messages, isEmpty);
      expect(bad.error, isNotNull);
      bad.dispose();
    },
  );
}
