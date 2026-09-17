import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_store.dart';
import 'package:kingclub/src/features/messaging/data/chat_media_deletion.dart';

void main() {
  sqfliteFfiInit();
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
