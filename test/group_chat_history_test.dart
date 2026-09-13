import 'dart:io';

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
