import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  for (final conversation in ['direct:friend', 'group:team']) {
    test(
      'local search paginates and respects deletion: $conversation',
      () async {
        final dir = await Directory.systemTemp.createTemp('local-search-');
        final key = await AesGcm.with256bits().newSecretKey();
        Future<ChatHistoryStore> open() => ChatHistoryStore.openDatabaseWithKey(
          factory: databaseFactoryFfi,
          file: '${dir.path}/history.db',
          key: key,
          account: 'me',
        );
        var store = await open();
        addTearDown(() async {
          await store.close();
          await dir.delete(recursive: true);
        });
        Map<String, dynamic> message(int n) => {
          'messageId': 'm$n',
          'clientMessageId': 'c$n',
          'sender': 'friend',
          'sequence': n,
          'text': n % 3 == 0 ? '测试 Needle 正文' : 'other',
          'messageType': 'text',
        };
        await store.commit(conversation, [
          for (var i = 1; i <= 125; i++) message(i),
        ], expectedEpoch: 0);
        await store.commit('direct:other', [message(999)], expectedEpoch: 0);
        final first = await store.search(
          conversation,
          query: 'needle',
          limit: 10,
        );
        expect((first['messages'] as List).map((m) => m['sequence']), [
          96,
          99,
          102,
          105,
          108,
          111,
          114,
          117,
          120,
          123,
        ]);
        expect(first['hasMore'], true);
        final second = await store.search(
          conversation,
          query: 'NEEDLE',
          before: 96,
          limit: 200,
        );
        expect((second['messages'] as List).length, 31);
        expect(second['hasMore'], false);
        await store.commit(conversation, [
          {
            ...message(126),
            'messageType': 'file',
            'fileName': '合同-Needle.PDF',
            'text': '[文件]',
          },
        ], expectedEpoch: 0);
        expect(
          (await store.search(conversation, query: '.pdf'))['messages'],
          hasLength(1),
        );
        expect(
          (await store.search(conversation, messageType: 'file'))['messages'],
          hasLength(1),
        );
        await store.clear(conversation, deletedMessageIds: {'m123'});
        await store.close();
        store = await open();
        final after = await store.search(
          conversation,
          query: 'needle',
          limit: 200,
        );
        expect(
          (after['messages'] as List).any((m) => m['messageId'] == 'm123'),
          false,
        );
        await store.clear(conversation, deleteMedia: false);
        expect(
          (await store.search(conversation, query: 'needle'))['messages'],
          isEmpty,
        );
      },
    );
  }
}
