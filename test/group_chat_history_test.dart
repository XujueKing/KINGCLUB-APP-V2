import 'dart:io';
import 'dart:async';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_store.dart';
import 'package:kingclub/src/features/messaging/data/group_chat_controller.dart';
import 'package:kingclub/src/features/messaging/data/group_chat_repository.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';

import 'group_chat_controller_test.dart' show Queue, message, history;

void main() {
  sqfliteFfiInit();
  late Directory dir;
  late ChatHistoryStore store;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('group-history-');
    store = await ChatHistoryStore.openDatabaseWithKey(
      factory: databaseFactoryFfi,
      file: '${dir.path}/history.db',
      key: await AesGcm.with256bits().newSecretKey(),
      account: 'me',
    );
  });
  tearDown(() async {
    await store.close();
    await dir.delete(recursive: true);
  });
  Map<String, dynamic> row(int n) => {...message('c$n'), 'sequence': n};
  GroupChatController controller(ChatApiCall call) => GroupChatController(
    groupId: 'group',
    outbox: Queue(),
    openHistory: () async => store,
    repository: GroupChatRepository(
      MessagingRepository(account: 'me', call: call),
    ),
  );
  for (final revoked in [false, true]) {
    test(
      'cached older group page revalidates access: revoked=$revoked',
      () async {
        await store.commit(
          'group:group',
          List.generate(75, (i) => row(i + 1)),
          expectedEpoch: 0,
          cursor: 75,
          membershipVersion: 0,
        );
        final requested = Completer<void>();
        final pending = Completer<Map<String, dynamic>>();
        final chat = controller((id, params) async {
          if (id == 'K260913000619') {
            return {'groupName': 'Test', 'members': []};
          }
          if (params.containsKey('before')) {
            expect(params['before'], 26);
            requested.complete();
            return pending.future;
          }
          return {
            ...history([]),
            'membershipVersion': 0,
            'joinedSequence': 0,
            'settings': {'hiddenThrough': 0},
          };
        });
        await chat.initialize();
        final loading = chat.loadOlder();
        await requested.future.timeout(const Duration(seconds: 5));
        expect(chat.messages.length, 75);
        pending.completeError(
          AuthFailure(
            revoked ? 'CHAT_GROUP_ACCESS_DENIED' : 'NETWORK_ERROR',
            'fixture',
          ),
        );
        await loading;
        final saved = await store.read('group:group');
        if (revoked) {
          expect(chat.hasAccess, false);
          expect(chat.messages, isEmpty);
          expect(saved.messages, isEmpty);
        } else {
          expect(chat.messages.length, 75);
          expect(saved.cursor, 75);
          expect(saved.messages, isNotEmpty);
        }
        chat.dispose();
      },
    );
  }

  test('transient cache opening failure can recover on next sync', () async {
    var opens = 0;
    final queue = Queue();
    await queue.put({
      'clientMessageId': 'c1',
      'groupId': 'group',
      'sender': 'me',
      'text': 'message1',
      'status': 'queued',
      'membershipVersion': 0,
    });
    final chat = GroupChatController(
      groupId: 'group',
      outbox: queue,
      openHistory: () async {
        if (++opens == 1) throw StateError('temporary storage failure');
        return store;
      },
      repository: GroupChatRepository(
        MessagingRepository(
          account: 'me',
          call: (id, _) async {
            if (id == 'K260913000619') {
              return {'groupName': 'Test', 'members': <Map<String, dynamic>>[]};
            }
            return {
              ...history([row(1)]),
              'membershipVersion': 0,
              'joinedSequence': 0,
              'settings': {'hiddenThrough': 0},
            };
          },
        ),
      ),
    );
    await chat.initialize();
    expect(chat.error, isNotNull);
    expect(chat.messages.single['clientMessageId'], 'c1');
    await chat.synchronize();
    expect(opens, 2);
    expect(chat.error, isNull);
    expect(chat.messages.single['sequence'], 1);
    expect(await queue.read(), isEmpty);
    expect((await store.read('group:group')).messages.length, 1);
    chat.dispose();
  });
  test(
    'recall after offline cursor refresh removes old memory and disk payload',
    () async {
      var revision = 0;
      final requests = <Map<String, dynamic>>[];
      final chat = controller((id, params) async {
        if (id == 'K260913000619') {
          return {'groupName': 'Test', 'members': <Map<String, dynamic>>[]};
        }
        requests.add(Map<String, dynamic>.from(params));
        final rows = params.containsKey('after')
            ? <Map<String, dynamic>>[]
            : [
                {
                  ...row(1),
                  if (revision > 0) 'messageType': 'recalled',
                  if (revision > 0) 'text': '消息已撤回',
                },
              ];
        return {
          ...history(rows),
          'historyVersion': revision,
          'membershipVersion': 0,
          'joinedSequence': 0,
          'settings': {'hiddenThrough': 0},
        };
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
      final saved = await store.read('group:group');
      expect(saved.historyVersion, 1);
      expect(saved.messages.single['text'], '消息已撤回');
      chat.dispose();
      final offline = controller((_, _) async => throw StateError('offline'));
      await offline.initialize();
      expect(offline.messages.single['messageType'], 'recalled');
      offline.dispose();
    },
  );
  test('confirmed group and member names survive offline reopen and clear with access', () async {
    final chat = controller((id, _) async {
      if (id == 'K260913000619') {
        return {
          'groupName': 'Fixture group',
          'members': [
            {'account': 'me', 'nickname': 'Fixture name'},
          ],
        };
      }
      return {
        ...history([row(1)]),
        'membershipVersion': 0,
        'joinedSequence': 0,
        'settings': {'hiddenThrough': 0},
      };
    });
    await chat.initialize();
    expect(chat.messages.single['senderName'], 'Fixture name');
    chat.dispose();
    final offline = controller(
      (_, _) async => throw const AuthFailure('NETWORK_ERROR', 'offline'),
    );
    await offline.initialize();
    expect(offline.messages.single['senderName'], 'Fixture name');
    expect(offline.settings['groupName'], 'Fixture group');
    expect(offline.hasAccess, false);
    offline.dispose();
    final raw = String.fromCharCodes(
      await File('${dir.path}/history.db').readAsBytes(),
    );
    expect(raw.contains('Fixture name'), false);
    expect(raw.contains('Fixture group'), false);
    final removed = controller(
      (_, _) async =>
          throw const AuthFailure('CHAT_GROUP_ACCESS_DENIED', 'removed'),
    );
    await removed.initialize();
    expect(removed.settings['groupName'], null);
    expect((await store.read('group:group')).presentation, null);
    removed.dispose();
  });
  for (final denied in [false, true]) {
    test(
      'member lookup ${denied ? "denial revokes" : "network failure preserves"} cached access',
      () async {
        await store.commit(
          'group:group',
          [row(1)],
          expectedEpoch: 0,
          cursor: 1,
          membershipVersion: 0,
        );
        await store.saveGroupPresentation(
          'group:group',
          expectedEpoch: 0,
          membershipVersion: 0,
          groupName: 'Cached group',
          memberNames: {'me': 'Cached name'},
        );
        final chat = controller((id, _) async {
          if (id == 'K260913000619') {
            throw AuthFailure(
              denied ? 'CHAT_GROUP_ACCESS_DENIED' : 'NETWORK_ERROR',
              'fixture',
            );
          }
          return {
            ...history([]),
            'membershipVersion': 0,
            'joinedSequence': 0,
            'settings': {'hiddenThrough': 0},
          };
        });
        await chat.initialize();
        final disk = await store.read('group:group');
        if (denied) {
          expect(chat.hasAccess, false);
          expect(chat.messages, isEmpty);
          expect(chat.settings['groupName'], null);
          expect(disk.messages, isEmpty);
          expect(disk.presentation, null);
          await expectLater(chat.send('not allowed'), throwsStateError);
        } else {
          expect(chat.hasAccess, true);
          expect(chat.messages.single['senderName'], 'Cached name');
          expect(disk.presentation!['groupName'], 'Cached group');
        }
        chat.dispose();
      },
    );
  }
  test('old member-name snapshots cannot overwrite a new membership or clear epoch', () async {
    await store.commit(
      'group:group',
      [],
      expectedEpoch: 0,
      membershipVersion: 0,
    );
    expect(
      await store.saveGroupPresentation(
        'group:group',
        expectedEpoch: 0,
        membershipVersion: 0,
        groupName: 'Old',
        memberNames: {'me': 'Old name'},
      ),
      true,
    );
    await store.commit(
      'group:group',
      [],
      expectedEpoch: 0,
      membershipVersion: 1,
    );
    expect((await store.read('group:group')).presentation, null);
    expect(
      await store.saveGroupPresentation(
        'group:group',
        expectedEpoch: 0,
        membershipVersion: 0,
        groupName: 'Old',
        memberNames: {'me': 'Old name'},
      ),
      false,
    );
    await store.clear('group:group');
    expect(
      await store.saveGroupPresentation(
        'group:group',
        expectedEpoch: 0,
        membershipVersion: 1,
        groupName: 'Late',
        memberNames: {'me': 'Late name'},
      ),
      false,
    );
  });
  test(
    'offline group restores pages without granting current send permission',
    () async {
      await store.commit(
        'group:group',
        List.generate(60, (i) => row(i + 1)),
        expectedEpoch: 0,
        cursor: 60,
        membershipVersion: 0,
      );
      final chat = controller(
        (_, _) async => throw const AuthFailure('NETWORK_ERROR', 'offline'),
      );
      await chat.initialize();
      expect(chat.messages.length, 50);
      expect(chat.hasAccess, false);
      await chat.loadOlder();
      expect(chat.messages.length, 60);
      await expectLater(chat.send('must not send'), throwsStateError);
      chat.dispose();
    },
  );
  test('readmission atomically replaces visible boundary and rejects prior membership writes', () async {
    await store.commit(
      'group:group',
      [row(1)],
      expectedEpoch: 0,
      cursor: 1,
      membershipVersion: 0,
    );
    final chat = controller((id, _) async {
      if (id == 'K260913000619') return {'members': []};
      return {
        ...history([row(3)]),
        'membershipVersion': 1,
        'joinedSequence': 2,
        'settings': {'hiddenThrough': 0},
      };
    });
    await chat.initialize();
    expect(chat.messages.single['sequence'], 3);
    expect(chat.hasAccess, true);
    final saved = await store.read('group:group');
    expect(saved.membershipVersion, 1);
    expect(saved.hiddenThrough, 2);
    expect(
      await store.commit(
        'group:group',
        [row(4)],
        expectedEpoch: saved.epoch,
        membershipVersion: 0,
      ),
      false,
    );
    expect((await store.read('group:group')).messages.single['sequence'], 3);
    chat.dispose();
  });
  test(
    'queued sends never cross a member-version change automatically',
    () async {
      var version = 0, sends = 0;
      final chat = controller((id, _) async {
        if (id == 'K260913000619') return {'members': []};
        if (id == 'K260913000620') {
          sends++;
          throw const AuthFailure('NETWORK_ERROR', 'offline');
        }
        return {
          ...history([]),
          'membershipVersion': version,
          'joinedSequence': version,
          'settings': {'hiddenThrough': 0},
        };
      });
      await chat.initialize();
      await chat.send('old queued');
      expect(sends, 1);
      version = 1;
      await chat.synchronize();
      await chat.retryQueued();
      expect(sends, 1);
      expect(chat.messages.single['status'], 'failed');
      chat.dispose();
    },
  );
  test(
    'access denial clears persistent history before an offline reopen',
    () async {
      await store.commit(
        'group:group',
        [row(1)],
        expectedEpoch: 0,
        cursor: 1,
        membershipVersion: 0,
      );
      final chat = controller(
        (_, _) async =>
            throw const AuthFailure('CHAT_GROUP_ACCESS_DENIED', 'removed'),
      );
      await chat.initialize();
      expect(chat.messages, isEmpty);
      expect(chat.hasAccess, false);
      expect((await store.read('group:group')).messages, isEmpty);
      chat.dispose();
      final reopened = controller(
        (_, _) async => throw const AuthFailure('NETWORK_ERROR', 'offline'),
      );
      await reopened.initialize();
      expect(reopened.messages, isEmpty);
      reopened.dispose();
    },
  );
}
