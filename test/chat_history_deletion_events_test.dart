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
          final store = await ChatHistoryStore.openDatabaseWithKey(
            factory: databaseFactoryFfi,
            file: '${dir.path}/history.db',
            key: await AesGcm.with256bits().newSecretKey(),
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
