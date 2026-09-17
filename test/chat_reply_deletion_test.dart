import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_store.dart';

void main() {
  sqfliteFfiInit();
  for (final mode in ['delete', 'recall', 'clear-floor']) {
    test(
      'cached replies lose deleted source text across restart: $mode',
      () async {
        final dir = await Directory.systemTemp.createTemp('reply-delete-');
        final key = await AesGcm.with256bits().newSecretKey();
        Future<ChatHistoryStore> open() => ChatHistoryStore.openDatabaseWithKey(
          factory: databaseFactoryFfi,
          file: '${dir.path}/history.db',
          key: key,
          account: 'me',
        );
        var store = await open();
        const sourceId = '11111111-1111-4111-8111-111111111111';
        final source = <String, dynamic>{
          'messageId': sourceId,
          'clientMessageId': 'source',
          'sequence': 1,
          'sender': 'peer',
          'recipient': 'me',
          'text': 'private original',
          'createdDate': '2026-09-17T00:00:00Z',
        };
        final reply = {
          ...source,
          'messageId': 'reply',
          'clientMessageId': 'reply',
          'sequence': 2,
          'text': 'kept reply body',
          'reply': {
            'messageId': sourceId,
            'available': true,
            'sequence': 1,
            'text': 'private original',
          },
        };
        await store.commit('direct:peer', [source, reply], expectedEpoch: 0);
        await store.commit('direct:other', [source, reply], expectedEpoch: 0);
        if (mode == 'delete') {
          await store.clear('direct:peer', deletedMessageIds: {sourceId});
        } else {
          await store.commit(
            'direct:peer',
            mode == 'recall'
                ? [
                    {...source, 'messageType': 'recalled'},
                  ]
                : [],
            expectedEpoch: 0,
            hiddenThrough: mode == 'clear-floor' ? 1 : 0,
          );
        }
        await store.close();
        store = await open();
        final rows = (await store.read('direct:peer')).messages;
        final quoted = rows.singleWhere((r) => r['sequence'] == 2);
        expect(quoted['text'], 'kept reply body');
        expect(quoted['reply'], {'messageId': sourceId, 'available': false});
        expect(
          ((await store.read('direct:other')).messages.last['reply']
              as Map)['available'],
          true,
        );
        await store.close();
        await dir.delete(recursive: true);
      },
    );
  }
}
