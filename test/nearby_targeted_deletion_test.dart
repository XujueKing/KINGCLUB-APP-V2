import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  for (final mode in ['single', 'remote-floor', 'first-page-floor']) {
    test(
      '$mode deletion erases all bound nearby copies across restart',
      () async {
        final dir = await Directory.systemTemp.createTemp('nearby-delete-');
        final file = '${dir.path}/history.db';
        final key = await AesGcm.with256bits().newSecretKey();
        Future<ChatHistoryStore> open() => ChatHistoryStore.openDatabaseWithKey(
          factory: databaseFactoryFfi,
          file: file,
          key: key,
          account: 'me',
        );
        var store = await open();
        addTearDown(() async {
          await store.close();
          await dir.delete(recursive: true);
        });
        final peers = [
          'novovm-ed25519:${'a' * 64}',
          'novovm-ed25519:${'b' * 64}',
        ];
        const client = '00000000-0000-4000-8000-000000000001';
        for (final member in ['friend', 'other']) {
          for (final peer in peers) {
            await store.persistNearbyText(
              peerId: peer,
              peerAccount: member,
              id: client,
              text: 'private body',
              outgoing: member == 'friend',
            );
          }
          await store.commit(
            'direct:$member',
            [
              {
                'messageId': 'server-$member',
                'clientMessageId': client,
                'sequence': 1,
                'sender': member == 'friend' ? 'me' : member,
                'recipient': member == 'friend' ? member : 'me',
                'messageType': 'text',
                'text': 'private body',
              },
            ],
            expectedEpoch: 0,
            hiddenThrough: mode == 'first-page-floor' && member == 'friend'
                ? 1
                : 0,
          );
        }
        if (mode == 'single') {
          await store.clear(
            'direct:friend',
            deletedMessageIds: {'server-friend'},
          );
        } else if (mode == 'remote-floor') {
          await store.commit(
            'direct:friend',
            [],
            expectedEpoch: 0,
            hiddenThrough: 1,
          );
        }
        await store.close();
        final raw = await databaseFactoryFfi.openDatabase(file);
        try {
          final erased = await raw.query(
            'nearby_message',
            where: 'serverId=?',
            whereArgs: ['server-friend'],
          );
          expect(erased, hasLength(2));
          for (final row in erased) {
            expect(row['payload'], isEmpty);
            expect(row['hidden'], 1);
          }
        } finally {
          await raw.close();
        }
        store = await open();
        for (final peer in [...peers, 'novovm-ed25519:${'c' * 64}']) {
          await store.persistNearbyText(
            peerId: peer,
            peerAccount: 'friend',
            id: client,
            text: 'private body',
            outgoing: true,
          );
        }
        expect(await store.nearbyMemberMessages('friend'), isEmpty);
        expect((await store.read('direct:friend')).messages, isEmpty);
        for (final peer in peers) {
          final remaining = await store.nearbyMessages(peer);
          expect(remaining, hasLength(1));
          expect(remaining.single['text'], 'private body');
          expect(remaining.single['serverMessageId'], 'server-other');
        }
        expect((await store.read('direct:other')).messages, hasLength(1));
      },
    );
  }
}
