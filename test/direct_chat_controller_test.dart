import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kingclub/src/features/messaging/data/chat_outbox.dart';
import 'package:kingclub/src/features/messaging/data/direct_chat_controller.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/direct_chat_page.dart';
import 'package:kingclub/src/features/messaging/presentation/conversations_page.dart';

class MemoryOutbox implements ChatOutbox {
  final items = <String, Map<String, dynamic>>{};
  bool failWrite = false;
  @override
  Future<List<Map<String, dynamic>>> read() async => items.values.toList();
  @override
  Future<void> put(Map<String, dynamic> message) async {
    if (failWrite) throw StateError('disk full');
    items[message['clientMessageId'] as String] = {...message};
  }

  @override
  Future<void> remove(String id) async {
    items.remove(id);
  }
}

Map<String, dynamic> ack(Map<String, dynamic> input, {int sequence = 1}) => {
  'messageId': 'message-$sequence',
  'conversationId': 'conversation',
  'clientMessageId': input['clientMessageId'],
  'sender': 'me',
  'recipient': 'peer',
  'sequence': sequence,
  'text': input['text'],
  'createdDate': '2026-09-13T01:00:00Z',
};
Map<String, dynamic> history(
  List<Map<String, dynamic>> messages, {
  bool more = false,
}) => {
  'conversationId': 'conversation',
  'messages': messages,
  'hasMore': more,
  'lastSequence': messages.isEmpty ? 0 : messages.last['sequence'],
  'peerReadSequence': 0,
  'settings': <String, dynamic>{},
  'sendPermission': {'allowed': true},
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('late older page cannot roll back a newer peer read receipt', () async {
    final older = Completer<Map<String, dynamic>>();
    final olderRequested = Completer<void>();
    var requests = 0;
    final controller = DirectChatController(
      peer: 'peer',
      outbox: MemoryOutbox(),
      repository: MessagingRepository(
        account: 'me',
        call: (_, params) async {
          if (params['before'] != null) {
            olderRequested.complete();
            return older.future;
          }
          requests++;
          return {
            ...history([
              ack({'clientMessageId': 'new', 'text': 'new'}, sequence: 2),
            ], more: requests == 1),
            'peerReadSequence': requests == 1 ? 0 : 2,
          };
        },
      ),
    );
    addTearDown(controller.dispose);
    await controller.synchronize();
    final loading = controller.loadOlder();
    await olderRequested.future;
    await controller.synchronize();
    expect(controller.peerReadSequence, 2);
    older.complete({
      ...history([
        ack({'clientMessageId': 'old', 'text': 'old'}),
      ]),
      'peerReadSequence': 0,
    });
    await loading;
    expect(controller.messages, hasLength(2));
    expect(
      controller.messages.every((message) => message['peerRead'] == true),
      isTrue,
    );
    expect(controller.peerReadSequence, 2);
  });
  testWidgets('only confirmed outgoing reads display a read receipt', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    for (final state in [(0, false), (0, true), (1, true)]) {
      final readSequence = state.$1;
      final repository = MessagingRepository(
        account: 'me',
        call: (id, params) async {
          if (id != 'K260913000604') return {};
          return {
            ...history([
              {
                ...ack({
                  'clientMessageId': 'receipt-out',
                  'text': 'Outgoing receipt test',
                }),
                'peerDelivered': state.$2,
              },
              {
                ...ack({
                  'clientMessageId': 'receipt-in',
                  'text': 'Incoming receipt test',
                }, sequence: 2),
                'sender': 'peer',
                'recipient': 'me',
                'peerRead': true,
              },
            ]),
            'peerReadSequence': readSequence,
          };
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: DirectChatPage(
            peerAccount: 'peer',
            peerName: 'Friend',
            repository: repository,
            chatOutbox: MemoryOutbox(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Outgoing receipt test'), findsOneWidget);
      expect(find.text('Incoming receipt test'), findsOneWidget);
      expect(
        find.text('已读'),
        readSequence == 1 ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('已送达'),
        readSequence == 0 && state.$2 ? findsOneWidget : findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
  test(
    'network failure uses same relay ID and keeps server reconciliation queued',
    () async {
      final outbox = MemoryOutbox();
      var offline = true;
      final relayIds = <String>[];
      final serviceIds = <String>[];
      final controller = DirectChatController(
        peer: 'peer',
        outbox: outbox,
        sendRelayText: (text, id) async {
          expect(text, 'hello');
          relayIds.add(id);
          return true;
        },
        repository: MessagingRepository(
          account: 'me',
          call: (_, params) async {
            serviceIds.add(params['clientMessageId'] as String);
            if (offline) throw const AuthFailure('NETWORK_ERROR', 'offline');
            return {'message': ack(params)};
          },
        ),
      );
      addTearDown(controller.dispose);
      await controller.send('hello');
      final id = relayIds.single;
      expect(serviceIds.single, id);
      expect(outbox.items[id]!['status'], 'queued');
      expect(outbox.items[id]!['peerDelivered'], true);
      expect(controller.messages.single['status'], 'sent');
      expect(controller.messages.single['sequence'], isNull);
      expect(controller.error, isNull);
      await controller.retryQueued();
      expect(relayIds, [id]);
      offline = false;
      await controller.retryQueued();
      expect(serviceIds, [id, id, id]);
      expect(outbox.items, isEmpty);
      expect(controller.messages.single['sequence'], 1);
    },
  );
  test('permission denial never falls back to peer transport', () async {
    var relayCalls = 0;
    final controller = DirectChatController(
      peer: 'peer',
      outbox: MemoryOutbox(),
      sendRelayText: (_, _) async {
        relayCalls++;
        return true;
      },
      repository: MessagingRepository(
        account: 'me',
        call: (_, _) async =>
            throw const AuthFailure('CHAT_BLOCKED', 'blocked'),
      ),
    );
    addTearDown(controller.dispose);
    await controller.send('blocked');
    expect(relayCalls, 0);
    expect(controller.messages.single['status'], 'failed');
  });
  test(
    'relay chronology interleaves without reordering server sequences',
    () async {
      final controller = DirectChatController(
        peer: 'peer',
        outbox: MemoryOutbox(),
        readRelayMessages: () async => [
          for (final time in [4000, 1000, 3000])
            {
              'id': 'local-$time',
              'text': 'local-$time',
              'created': time,
              'outgoing': false,
              'delivered': false,
            },
        ],
        repository: MessagingRepository(
          account: 'me',
          call: (_, params) async => history([
            {
              ...ack({'clientMessageId': 'server-a', 'text': 'server-a'}),
              'createdDate': '1970-01-01T00:00:02Z',
            },
            {
              ...ack({
                'clientMessageId': 'server-b',
                'text': 'server-b',
              }, sequence: 2),
              'createdDate': '1970-01-01T00:00:03.500Z',
            },
          ]),
        ),
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      await Future<void>.delayed(Duration.zero);
      expect(controller.messages.map((m) => m['text']), [
        'local-1000',
        'server-a',
        'local-3000',
        'server-b',
        'local-4000',
      ]);
      expect(
        controller.messages
            .where((m) => m['sequence'] != null)
            .map((m) => m['sequence']),
        [1, 2],
      );
    },
  );
  test('slow relay storage does not block normal service history', () async {
    final pending = Completer<List<Map<String, dynamic>>>();
    final controller = DirectChatController(
      peer: 'peer',
      outbox: MemoryOutbox(),
      readRelayMessages: () => pending.future,
      repository: MessagingRepository(
        account: 'me',
        call: (_, params) async => history([
          ack({'clientMessageId': 'normal', 'text': 'normal'}),
        ]),
      ),
    );
    addTearDown(controller.dispose);
    await controller.initialize().timeout(const Duration(seconds: 2));
    expect(controller.messages.single['text'], 'normal');
    pending.complete([]);
    await Future<void>.delayed(Duration.zero);
    expect(controller.messages.single['text'], 'normal');
  });
  test(
    'relay updates merge by sender and client ID without server sequences',
    () async {
      final changes = StreamController<String>.broadcast(sync: true);
      var confirmed = <Map<String, dynamic>>[];
      var reads = 0;
      final marked = <List<String>>[];
      var relay = <Map<String, dynamic>>[
        {
          'id': 'relay-1',
          'text': 'peer text',
          'outgoing': false,
          'delivered': false,
          'created': 1,
        },
      ];
      final controller = DirectChatController(
        peer: 'peer',
        outbox: MemoryOutbox(),
        relayChanges: changes.stream,
        markRelayRead: (ids) async {
          marked.add(ids);
          relay = relay.map((m) => {...m, 'read': true}).toList();
        },
        readRelayMessages: () async {
          reads++;
          return relay;
        },
        repository: MessagingRepository(
          account: 'me',
          call: (_, params) async => history(confirmed),
        ),
      );
      addTearDown(() async {
        controller.dispose();
        await changes.close();
      });
      await controller.initialize();
      expect(controller.messages.single['text'], 'peer text');
      expect(controller.messages.single['sequence'], isNull);
      expect(controller.messages.single['messageId'], isNull);
      expect(marked, isEmpty);
      await controller.markRelayVisibleRead();
      await controller.markRelayVisibleRead();
      expect(marked, [
        ['relay-1'],
      ]);
      final previousReads = reads;
      changes.add('someone-else');
      await Future<void>.delayed(Duration.zero);
      expect(reads, previousReads);
      relay = [
        {...relay.single, 'text': 'updated'},
      ];
      changes.add('peer');
      await Future<void>.delayed(Duration.zero);
      expect(controller.messages.single['text'], 'updated');
      confirmed = [
        {
          ...ack({'clientMessageId': 'relay-1', 'text': 'updated'}),
          'sender': 'peer',
          'recipient': 'me',
        },
      ];
      await controller.synchronize();
      expect(controller.messages, hasLength(1));
      expect(controller.messages.single['messageId'], 'message-1');
    },
  );

  test(
    'reset ignores a late relay read and disposal cancels event reads',
    () async {
      final changes = StreamController<String>.broadcast(sync: true);
      final pending = Completer<List<Map<String, dynamic>>>();
      var reads = 0;
      final controller = DirectChatController(
        peer: 'peer',
        outbox: MemoryOutbox(),
        relayChanges: changes.stream,
        readRelayMessages: () {
          reads++;
          return pending.future;
        },
        repository: MessagingRepository(
          account: 'me',
          call: (_, params) async => history([]),
        ),
      );
      changes.add('peer');
      await Future<void>.delayed(Duration.zero);
      controller.resetVisibleHistory();
      pending.complete([
        {
          'id': 'late',
          'text': 'stale',
          'outgoing': false,
          'delivered': false,
          'created': 1,
        },
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(controller.messages, isEmpty);
      controller.dispose();
      changes.add('peer');
      await Future<void>.delayed(Duration.zero);
      expect(reads, 1);
      await changes.close();
    },
  );
  test(
    'offline catch-up resumes after a failed middle page without duplicates',
    () async {
      final cursors = <Object?>[];
      var failMiddle = true;
      final controller = DirectChatController(
        peer: 'peer',
        outbox: MemoryOutbox(),
        repository: MessagingRepository(
          account: 'me',
          call: (_, params) async {
            final after = params['after'] as int?;
            cursors.add(after);
            if (after == null) {
              return history([
                ack({'clientMessageId': '1', 'text': 'initial'}),
              ]);
            }
            if (after == 51 && failMiddle) {
              failMiddle = false;
              throw const AuthFailure('NETWORK_ERROR', 'offline');
            }
            final end = (after + 50).clamp(0, 131);
            return history([
              for (var i = after + 1; i <= end; i++)
                ack({
                  'clientMessageId': '$i',
                  'text': 'message $i',
                }, sequence: i),
            ], more: end < 131);
          },
        ),
      );
      await controller.synchronize();
      await controller.synchronize();
      expect(cursors, [null, 1, 51]);
      expect(controller.messages.length, 51);
      expect(controller.permission['allowed'], isTrue);
      expect(controller.error, isNotNull);
      await controller.synchronize();
      expect(cursors, [null, 1, 51, 51, 101]);
      expect(
        controller.messages.map((m) => m['sequence']),
        List.generate(131, (i) => i + 1),
      );
      expect(controller.error, isNull);
      expect(controller.permission['allowed'], isTrue);
      controller.dispose();
    },
  );
  test(
    'notification during in-flight history triggers one more catch-up',
    () async {
      final first = Completer<Map<String, dynamic>>();
      final paramsSeen = <Map<String, dynamic>>[];
      final controller = DirectChatController(
        peer: 'peer',
        outbox: MemoryOutbox(),
        repository: MessagingRepository(
          account: 'me',
          call: (_, params) async {
            paramsSeen.add({...params});
            if (paramsSeen.length == 1) return first.future;
            return history([
              ack({'clientMessageId': 'two', 'text': 'second'}, sequence: 2),
            ]);
          },
        ),
      );
      final sync = controller.synchronize();
      final signals = List.generate(8, (_) => controller.synchronize());
      first.complete(
        history([
          ack({'clientMessageId': 'one', 'text': 'first'}),
        ]),
      );
      await Future.wait([sync, ...signals]);
      expect(paramsSeen.length, 2);
      expect(paramsSeen.last['after'], 1);
      expect(controller.messages.map((m) => m['sequence']), [1, 2]);
      controller.dispose();
    },
  );
  test(
    'disposed controller never starts a catch-up requested after disposal',
    () async {
      var calls = 0;
      final controller = DirectChatController(
        peer: 'peer',
        outbox: MemoryOutbox(),
        repository: MessagingRepository(
          account: 'me',
          call: (_, _) async {
            calls++;
            return history([]);
          },
        ),
      );
      controller.dispose();
      await controller.synchronize();
      expect(calls, 0);
    },
  );
  test(
    'clearing history rejects an old response without blocking fresh sync',
    () async {
      final oldResponse = Completer<Map<String, dynamic>>();
      final newResponse = Completer<Map<String, dynamic>>();
      var requests = 0;
      final controller = DirectChatController(
        peer: 'peer',
        outbox: MemoryOutbox(),
        repository: MessagingRepository(
          account: 'me',
          call: (id, params) {
            requests++;
            return requests == 1 ? oldResponse.future : newResponse.future;
          },
        ),
      );
      final oldSync = controller.synchronize();
      controller.resetVisibleHistory();
      final freshSync = controller.synchronize();
      expect(requests, 2);
      oldResponse.complete(
        history([
          ack({'clientMessageId': 'old', 'text': 'hidden'}),
        ]),
      );
      await oldSync;
      expect(controller.messages, isEmpty);
      expect(identical(controller.synchronize(), freshSync), isTrue);
      newResponse.complete(
        history([
          ack({'clientMessageId': 'new', 'text': 'new'}, sequence: 2),
        ]),
      );
      await freshSync;
      expect(controller.messages.single['text'], 'new');
      controller.dispose();
    },
  );
  test('clearing history rejects a pending older page', () async {
    final older = Completer<Map<String, dynamic>>();
    final controller = DirectChatController(
      peer: 'peer',
      outbox: MemoryOutbox(),
      repository: MessagingRepository(
        account: 'me',
        call: (id, params) async {
          if (params.containsKey('before')) return older.future;
          return history([
            ack({'clientMessageId': 'latest', 'text': 'latest'}, sequence: 5),
          ], more: true);
        },
      ),
    );
    await controller.synchronize();
    final loading = controller.loadOlder();
    controller.resetVisibleHistory();
    older.complete(
      history([
        ack({'clientMessageId': 'old', 'text': 'hidden'}),
      ], more: true),
    );
    await loading;
    expect(controller.messages, isEmpty);
    expect(controller.hasOlder, isFalse);
    controller.dispose();
  });
  testWidgets(
    'real conversation list opens the actual peer and removes demo rows',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      final repository = MessagingRepository(
        account: 'me',
        call: (id, params) async {
          if (id == 'K260913000607') {
            return {
              'items': [
                {
                  'peer': 'peer',
                  'nickname': '真实朋友',
                  'remark': '',
                  'preview': '真实预览',
                  'lastSequence': 1,
                  'unreadCount': 1,
                  'muted': false,
                  'pinned': false,
                  'messageDate': '2026-09-13T01:00:00Z',
                },
              ],
              'hasMore': false,
            };
          }
          expect(id, 'K260913000604');
          expect(params['peer'], 'peer');
          return history([]);
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConversationsPage(
              active: true,
              realData: true,
              repository: repository,
              systemUnreadCount: 3,
              initialFriendUnreadCount: 2,
              onFriendUnreadChanged: (_) {},
              onOpenContacts: () {},
              onAddFriend: () {},
              onOpenSystemNotifications: () {},
              onOpenDirectChat: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('卡座搭子'), findsNothing);
      expect(find.text('真实预览'), findsOneWidget);
      await tester.tap(find.text('真实预览'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<DirectChatPage>(find.byType(DirectChatPage)).peerAccount,
        'peer',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'real conversation shows no demo history and waits for server acknowledgement',
    (tester) async {
      final outbox = MemoryOutbox();
      final response = Completer<Map<String, dynamic>>();
      Map<String, dynamic>? request;
      final repository = MessagingRepository(
        account: 'me',
        call: (id, params) async {
          if (id == 'K260913000604') return history([]);
          if (id == 'K260913000605') {
            return {'readSequence': params['sequence']};
          }
          if (id != 'K260913000601') return <String, dynamic>{};
          request = params;
          return response.future;
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: DirectChatPage(
            peerName: '真实朋友',
            peerAccount: 'peer',
            repository: repository,
            chatOutbox: outbox,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('A6 卡座见'), findsNothing);
      expect(find.text('今天 21:08'), findsNothing);
      await tester.enterText(find.byType(TextField).first, '失败');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();
      expect(outbox.items, hasLength(1));
      expect(request!['text'], '失败');
      response.complete({'message': ack(request!), 'replayed': false});
      await tester.pumpAndSettle();
      expect(outbox.items, isEmpty);
      expect(find.text('失败'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  test('persists before sending and waits for real acknowledgement', () async {
    final outbox = MemoryOutbox(), reply = Completer<Map<String, dynamic>>();
    Map<String, dynamic>? sent;
    final controller = DirectChatController(
      peer: 'peer',
      outbox: outbox,
      repository: MessagingRepository(
        account: 'me',
        call: (id, params) {
          expect(outbox.items, hasLength(1));
          sent = params;
          return reply.future;
        },
      ),
    );
    var queued = false;
    final sending = controller.send('hello', onQueued: () => queued = true);
    await Future<void>.delayed(Duration.zero);
    expect(queued, true);
    expect(controller.messages.single['status'], 'sending');
    reply.complete({'message': ack(sent!), 'replayed': false});
    await sending;
    expect(controller.messages.single['status'], 'sent');
    expect(outbox.items, isEmpty);
    controller.dispose();
  });
  test(
    'failed local persistence retains draft and never calls server',
    () async {
      final outbox = MemoryOutbox()..failWrite = true;
      var queued = false, called = false;
      final controller = DirectChatController(
        peer: 'peer',
        outbox: outbox,
        repository: MessagingRepository(
          account: 'me',
          call: (id, params) async {
            called = true;
            return {};
          },
        ),
      );
      await expectLater(
        controller.send('hello', onQueued: () => queued = true),
        throwsStateError,
      );
      expect(queued, false);
      expect(called, false);
      expect(controller.messages, isEmpty);
      controller.dispose();
    },
  );
  test(
    'lost acknowledgement retries same id and startup history reconciles it',
    () async {
      final outbox = MemoryOutbox();
      Map<String, dynamic>? committed;
      final repository = MessagingRepository(
        account: 'me',
        call: (id, params) async {
          if (id == 'K260913000604') return history([ack(committed!)]);
          committed = params;
          throw const AuthFailure('NETWORK_ERROR', 'offline');
        },
      );
      final first = DirectChatController(
        peer: 'peer',
        outbox: outbox,
        repository: repository,
      );
      const draftId = '11111111-1111-4111-8111-111111111111';
      await first.send('hello', clientMessageId: draftId);
      expect(outbox.items, hasLength(1));
      final id = first.messages.single['clientMessageId'];
      expect(id, draftId);
      await first.retry(id as String);
      expect(committed!['clientMessageId'], id);
      first.dispose();
      final reopened = DirectChatController(
        peer: 'peer',
        outbox: outbox,
        repository: repository,
      );
      await reopened.initialize();
      expect(reopened.messages, hasLength(1));
      expect(reopened.messages.single['status'], 'sent');
      expect(outbox.items, isEmpty);
      reopened.dispose();
    },
  );
  test(
    'permission rejection stays failed and is not automatically retried',
    () async {
      var calls = 0;
      final outbox = MemoryOutbox();
      final controller = DirectChatController(
        peer: 'peer',
        outbox: outbox,
        repository: MessagingRepository(
          account: 'me',
          call: (id, params) async {
            calls++;
            throw const AuthFailure('CHAT_AWAITING_REPLY', '对方回复后才能继续发送');
          },
        ),
      );
      await controller.send('hello');
      await controller.retryQueued();
      expect(calls, 1);
      expect(controller.messages.single['status'], 'failed');
      expect(outbox.items, hasLength(1));
      controller.dispose();
    },
  );
  test('secure pending storage serializes multiple conversations and isolates accounts', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final a = SecureChatOutbox('a'),
        anotherA = SecureChatOutbox('a'),
        b = SecureChatOutbox('b');
    await Future.wait([
      a.put({'clientMessageId': 'one', 'recipient': 'x', 'text': 'one'}),
      anotherA.put({'clientMessageId': 'two', 'recipient': 'y', 'text': 'two'}),
    ]);
    expect(await a.read(), hasLength(2));
    expect(await b.read(), isEmpty);
    await b.put({
      'clientMessageId': 'one',
      'recipient': 'x',
      'text': 'private',
    });
    await a.remove('one');
    expect(await a.read(), hasLength(1));
    expect((await b.read()).single['text'], 'private');
  });
}
