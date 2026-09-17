import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_store.dart';
import 'package:kingclub/src/features/messaging/data/chat_media_deletion.dart';

void main() {
  sqfliteFfiInit();
  test(
    'large replay preserves terminal content across query batches',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'history-replay-batch-',
      );
      final store = await ChatHistoryStore.openDatabaseWithKey(
        factory: databaseFactoryFfi,
        file: '${dir.path}/history.db',
        key: await AesGcm.with256bits().newSecretKey(),
        account: 'me',
      );
      addTearDown(() async {
        await store.close();
        await dir.delete(recursive: true);
      });
      final messages = <Map<String, dynamic>>[
        for (var n = 1; n <= 450; n++)
          {
            'messageId': 'message-$n',
            'clientMessageId': 'client-$n',
            'sender': 'peer',
            'sequence': n,
            'messageType': 'text',
            'text': 'original $n',
          },
      ];
      await store.commit('direct:peer', [
        for (final row in messages)
          {...row, 'messageType': 'recalled', 'text': ''},
      ], expectedEpoch: 0);
      await store.commit('direct:peer', messages, expectedEpoch: 0);
      var seen = 0;
      int? before;
      while (true) {
        final page = await store.read(
          'direct:peer',
          before: before,
          limit: 200,
        );
        if (page.messages.isEmpty) break;
        expect(
          page.messages.every((row) => row['messageType'] == 'recalled'),
          true,
        );
        seen += page.messages.length;
        before = page.messages.first['sequence'] as int;
      }
      expect(seen, 450);
    },
  );
  for (final group in [false, true]) {
    for (final cached in [false, true]) {
      test(
        'remote text deletion notifies open consumers group=$group cached=$cached',
        () async {
          final dir = await Directory.systemTemp.createTemp('deletion-events-');
          final key = await AesGcm.with256bits().newSecretKey();
          var store = await ChatHistoryStore.openDatabaseWithKey(
            factory: databaseFactoryFfi,
            file: '${dir.path}/history.db',
            key: key,
            account: 'me',
          );
          final conversation = group ? 'group:peer' : 'direct:peer';
          final source = <String, dynamic>{
            'messageId': 'source',
            'clientMessageId': 'client',
            'sequence': 1,
            'sender': 'peer',
            'messageType': 'text',
            'text': 'quote',
          };
          if (cached) {
            await store.commit(conversation, [source], expectedEpoch: 0);
          }
          final events = <ChatMediaDeletion>[];
          final stop = ChatMediaDeletion.listen(events.add);
          try {
            final tombstone = {
              ...source,
              'messageType': 'recalled',
              'text': '',
            };
            expect(
              await store.commit(conversation, [tombstone], expectedEpoch: 0),
              true,
            );
            expect(events, hasLength(1));
            expect(events.single.account, 'me');
            expect(events.single.group, group);
            expect(events.single.messageId, 'source');
            await store.commit(conversation, [tombstone], expectedEpoch: 0);
            expect(
              events,
              hasLength(1),
              reason: 'replayed tombstone does not re-notify',
            );
            await store.close();
            store = await ChatHistoryStore.openDatabaseWithKey(
              factory: databaseFactoryFfi,
              file: '${dir.path}/history.db',
              key: key,
              account: 'me',
            );
            await store.commit(conversation, [source], expectedEpoch: 0);
            expect(
              (await store.read(conversation)).messages.single['messageType'],
              'recalled',
            );
            await store.commit(conversation, [
              {...source, 'messageId': 'second', 'sequence': 2},
            ], expectedEpoch: 0);
            await store.commit(
              conversation,
              [],
              expectedEpoch: 0,
              hiddenThrough: 2,
            );
            expect(events.map((e) => e.messageId), ['source', 'second']);
            final third = {...source, 'messageId': 'third', 'sequence': 3};
            await store.commit(conversation, [
              {...third, 'messageType': 'hidden'},
            ], expectedEpoch: 0);
            await store.commit(conversation, [third], expectedEpoch: 0);
            expect(
              (await store.read(conversation)).messages.single['messageType'],
              'hidden',
            );
          } finally {
            stop();
            await store.close();
            await dir.delete(recursive: true);
          }
        },
      );
    }
  }
}
