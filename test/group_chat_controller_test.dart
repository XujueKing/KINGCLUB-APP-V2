import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/features/messaging/data/chat_outbox.dart';
import 'package:kingclub/src/features/messaging/data/group_chat_controller.dart';
import 'package:kingclub/src/features/messaging/data/group_chat_repository.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

class Queue implements ChatOutbox {
  final rows = <String, Map<String, dynamic>>{};
  @override
  Future<List<Map<String, dynamic>>> read() async => rows.values.toList();
  @override
  Future<void> put(Map<String, dynamic> row) async {
    rows[row['clientMessageId'] as String] = {...row};
  }

  @override
  Future<void> remove(String id) async {
    rows.remove(id);
  }
}

Map<String, dynamic> history(List<Map<String, dynamic>> messages) => {
  'messages': messages,
  'hasMore': false,
  'lastSequence': messages.isEmpty ? 0 : messages.last['sequence'],
  'readSequence': 0,
};
Map<String, dynamic> message(String id) => {
  'messageId': 'server-$id',
  'groupId': 'group',
  'sequence': 1,
  'clientMessageId': id,
  'sender': 'me',
  'text': 'hello',
  'createdDate': '2026-09-13T01:00:00Z',
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});
  test(
    'silence keeps history and blocks queueing until authoritative unmute',
    () async {
      var muted = true;
      var sends = 0;
      final outbox = Queue();
      final controller = GroupChatController(
        groupId: 'group',
        outbox: outbox,
        repository: GroupChatRepository(
          MessagingRepository(
            account: 'me',
            call: (id, params) async {
              if (id == 'K260913000621') {
                return {
                  ...history([message('old')]),
                  'sendPermission': {'allowed': !muted},
                };
              }
              if (id == 'K260913000620') {
                sends++;
                return {
                  'message': {
                    ...message(params['clientMessageId'] as String),
                    'sequence': 2,
                  },
                };
              }
              return {};
            },
          ),
        ),
      );
      await controller.initialize();
      expect(controller.hasAccess, true);
      expect(controller.messages, hasLength(1));
      await expectLater(controller.send('hello'), throwsStateError);
      expect(outbox.rows, isEmpty);
      expect(sends, 0);
      muted = false;
      await controller.synchronize();
      expect(controller.sendMuted, false);
      await controller.send('hello');
      expect(sends, 1);
      expect(outbox.rows, isEmpty);
      controller.dispose();
    },
  );
  test('restored failed group text stays before newer group history', () async {
    final outbox = Queue();
    await outbox.put({
      'clientMessageId': 'old-failed',
      'groupId': 'group',
      'sender': 'me',
      'text': 'old failed draft',
      'status': 'failed',
      'createdDate': '2026-09-15T18:52:00+08:00',
    });
    final controller = GroupChatController(
      groupId: 'group',
      outbox: outbox,
      repository: GroupChatRepository(
        MessagingRepository(
          account: 'me',
          call: (method, _) async {
            if (method == 'K260913000619') {
              return {'groupName': 'Group', 'members': []};
            }
            expect(method, 'K260913000621');
            return history([
              {...message('newer'), 'createdDate': '2026-09-15T12:48:00Z'},
            ]);
          },
        ),
      ),
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    expect(controller.messages.map((row) => row['clientMessageId']), [
      'old-failed',
      'newer',
    ]);
    expect(outbox.rows['old-failed']!['status'], 'failed');
  });
  test(
    'group refresh keeps messages during rename but clears revoked access',
    () async {
      Completer<Map<String, dynamic>>? pending;
      var name = 'Before';
      final chat = GroupChatController(
        groupId: 'group',
        outbox: Queue(),
        repository: GroupChatRepository(
          MessagingRepository(
            account: 'me',
            call: (id, _) async {
              if (id == 'K260913000619') {
                return {'groupName': name, 'members': []};
              }
              return pending?.future ?? Future.value(history([message('one')]));
            },
          ),
        ),
      );
      await chat.synchronize();
      pending = Completer<Map<String, dynamic>>();
      name = 'After';
      final rename = chat.refreshGroup();
      await Future<void>.delayed(Duration.zero);
      expect(chat.messages.single['messageId'], 'server-one');
      expect(chat.hasAccess, isTrue);
      pending.complete(history([]));
      await rename;
      expect(chat.messages.single['messageId'], 'server-one');
      expect(chat.settings['groupName'], 'After');

      pending = Completer<Map<String, dynamic>>();
      final revoked = chat.refreshGroup();
      pending.completeError(
        const AuthFailure('CHAT_GROUP_ACCESS_DENIED', 'Access denied'),
      );
      await revoked;
      expect(chat.messages, isEmpty);
      expect(chat.hasAccess, isFalse);
      chat.dispose();
    },
  );

  test(
    'rejoining drops pre-admission messages and rejects an old member snapshot',
    () async {
      var version = 0, joined = 0;
      final chat = GroupChatController(
        groupId: 'group',
        outbox: Queue(),
        repository: GroupChatRepository(
          MessagingRepository(
            account: 'me',
            call: (id, _) async {
              if (id == 'K260913000619') return {'members': []};
              return {
                ...history([
                  {...message('old'), 'sequence': 1},
                  {...message('new'), 'sequence': 3},
                ]),
                'membershipVersion': version,
                'joinedSequence': joined,
                'settings': {'hiddenThrough': 0},
              };
            },
          ),
        ),
      );
      await chat.synchronize();
      expect(chat.messages.length, 2);
      version = 1;
      joined = 2;
      await chat.synchronize();
      expect(chat.messages.single['sequence'], 3);
      version = 0;
      joined = 0;
      await chat.synchronize();
      expect(chat.messages.single['sequence'], 3);
      expect(chat.error, isNotNull);
      chat.dispose();
    },
  );
  test(
    'reconnect rejects in-flight stale names while retaining messages',
    () async {
      final stale = Completer<Map<String, dynamic>>();
      var lookups = 0;
      final chat = GroupChatController(
        groupId: 'group',
        outbox: Queue(),
        repository: GroupChatRepository(
          MessagingRepository(
            account: 'me',
            call: (id, _) async {
              if (id == 'K260913000619') {
                lookups++;
                return lookups == 1
                    ? stale.future
                    : {
                        'members': [
                          {'account': 'friend', 'nickname': '当前昵称'},
                        ],
                      };
              }
              return history([
                {...message('one'), 'sender': 'friend'},
              ]);
            },
          ),
        ),
      );
      final sync = chat.synchronize();
      await Future<void>.delayed(Duration.zero);
      chat.invalidateMemberNames();
      chat.synchronize();
      stale.complete({
        'members': [
          {'account': 'friend', 'nickname': '旧昵称'},
        ],
      });
      await sync;
      expect(chat.messages.single['senderName'], '当前昵称');
      expect(chat.messages.single['messageId'], 'server-one');
      expect(lookups, 2);
      chat.dispose();
    },
  );

  test('member names map by sender and late member lookup cannot restore cleared data', () async {
    var name = '真实昵称';
    Completer<Map<String, dynamic>>? pending;
    final chat = GroupChatController(
      groupId: 'group',
      outbox: Queue(),
      repository: GroupChatRepository(
        MessagingRepository(
          account: 'me',
          call: (id, _) async {
            if (id == 'K260913000619') {
              if (pending != null) return pending.future;
              return {
                'members': [
                  {'account': 'friend', 'nickname': name},
                ],
              };
            }
            return history([
              {...message('one'), 'sender': 'friend'},
            ]);
          },
        ),
      ),
    );
    await chat.synchronize();
    expect(chat.messages.single['senderName'], '真实昵称');
    chat.invalidateMemberNames();
    expect(chat.messages.single['senderName'], 'friend');
    expect(chat.messages.single['messageId'], 'server-one');
    name = '新昵称';
    await chat.synchronize();
    expect(chat.messages.single['senderName'], '新昵称');
    chat.clearVisibleHistory();
    pending = Completer<Map<String, dynamic>>();
    final sync = chat.synchronize();
    await Future<void>.delayed(Duration.zero);
    chat.clearVisibleHistory();
    pending.complete({
      'members': [
        {'account': 'friend', 'nickname': '迟到昵称'},
      ],
    });
    await sync;
    expect(chat.messages, isEmpty);
    chat.dispose();
  });

  test('server hide cursor removes already loaded history', () async {
    var hidden = false;
    final chat = GroupChatController(
      groupId: 'group',
      outbox: Queue(),
      repository: GroupChatRepository(
        MessagingRepository(
          account: 'me',
          call: (_, _) async {
            return {
              ...history(hidden ? [] : [message('old')]),
              'settings': {'hiddenThrough': hidden ? 1 : 0, 'muted': true},
            };
          },
        ),
      ),
    );
    await chat.initialize();
    expect(chat.messages.length, 1);
    hidden = true;
    await chat.synchronize();
    expect(chat.messages, isEmpty);
    expect(chat.settings['muted'], true);
    chat.dispose();
  });

  test(
    'group creation retries with same identity and canonical member order',
    () async {
      final requests = <Map<String, dynamic>>[];
      final repo = GroupChatRepository(
        MessagingRepository(
          account: 'me',
          call: (id, params) async {
            expect(id, 'K260913000617');
            requests.add(params);
            if (requests.length == 1) {
              throw const AuthFailure('NETWORK_ERROR', 'lost acknowledgement');
            }
            return {'groupId': 'created'};
          },
        ),
      );
      await expectLater(
        repo.create(name: 'Friends', members: ['b', 'a']),
        throwsA(isA<AuthFailure>()),
      );
      await repo.create(name: 'Friends', members: ['a', 'b']);
      expect(requests[0]['requestId'], requests[1]['requestId']);
      expect(requests[1]['members'], ['a', 'b']);
      expect(requests[1].containsKey('ownerAccount'), false);
    },
  );
  test('lost group send acknowledgement is reconciled from history without duplicate or direct sends', () async {
    final queue = Queue();
    queue.rows['direct'] = {
      'clientMessageId': 'direct',
      'recipient': 'friend',
      'text': 'private direct',
    };
    Map<String, dynamic>? committed;
    var sends = 0;
    final repo = GroupChatRepository(
      MessagingRepository(
        account: 'me',
        call: (id, params) async {
          if (id == 'K260913000621') {
            return history(committed == null ? [] : [committed!]);
          }
          expect(id, 'K260913000620');
          sends++;
          expect(params['groupId'], 'group');
          expect(params.containsKey('recipient'), false);
          committed = message(params['clientMessageId'] as String);
          throw const AuthFailure('NETWORK_ERROR', 'lost acknowledgement');
        },
      ),
    );
    final first = GroupChatController(
      repository: repo,
      groupId: 'group',
      outbox: queue,
    );
    await first.initialize();
    const draftId = '22222222-2222-4222-8222-222222222222';
    await first.send('hello', clientMessageId: draftId);
    expect(committed!['clientMessageId'], draftId);
    expect(queue.rows.length, 2);
    first.dispose();
    final restored = GroupChatController(
      repository: repo,
      groupId: 'group',
      outbox: queue,
    );
    await restored.initialize();
    expect(restored.messages.length, 1);
    expect(restored.messages.single['status'], 'sent');
    expect(sends, 1);
    expect(queue.rows.keys, ['direct']);
    restored.dispose();
  });
  test(
    'group revocation clears confirmed history and disables new sends',
    () async {
      var revoked = false;
      final repo = GroupChatRepository(
        MessagingRepository(
          account: 'me',
          call: (id, params) async {
            expect(id, 'K260913000621');
            if (revoked) {
              throw const AuthFailure('CHAT_GROUP_ACCESS_DENIED', 'removed');
            }
            return history([message('old')]);
          },
        ),
      );
      final chat = GroupChatController(
        repository: repo,
        groupId: 'group',
        outbox: Queue(),
      );
      await chat.initialize();
      expect(chat.messages.length, 1);
      revoked = true;
      await chat.synchronize();
      expect(chat.messages, isEmpty);
      expect(chat.hasAccess, false);
      await expectLater(chat.send('new'), throwsStateError);
      chat.dispose();
    },
  );
  test('group notification during active sync triggers another read', () async {
    final old = Completer<Map<String, dynamic>>();
    var reads = 0;
    final repo = GroupChatRepository(
      MessagingRepository(
        account: 'me',
        call: (id, _) async {
          if (id == 'K260913000619') return {'members': []};
          reads++;
          return reads == 1 ? old.future : history([message('new')]);
        },
      ),
    );
    final chat = GroupChatController(
      repository: repo,
      groupId: 'group',
      outbox: Queue(),
    );
    final syncing = chat.synchronize();
    chat.synchronize();
    old.complete(history([]));
    await syncing;
    expect(reads, 2);
    expect(chat.messages.single['messageId'], 'server-new');
    chat.dispose();
  });
  test('clearing a group prevents late history from reappearing', () async {
    final old = Completer<Map<String, dynamic>>();
    final chat = GroupChatController(
      repository: GroupChatRepository(
        MessagingRepository(account: 'me', call: (_, _) => old.future),
      ),
      groupId: 'group',
      outbox: Queue(),
    );
    final syncing = chat.synchronize();
    chat.clearVisibleHistory();
    old.complete(history([message('old')]));
    await syncing;
    expect(chat.messages, isEmpty);
    expect(chat.hasAccess, false);
    chat.dispose();
  });
}
