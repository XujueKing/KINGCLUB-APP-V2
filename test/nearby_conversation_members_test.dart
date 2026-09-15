import 'dart:io';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_store.dart';

void main() {
  sqfliteFfiInit();
  test('encrypted member catalogue survives restart and respects delivery and hiding', () async {
    final dir = await Directory.systemTemp.createTemp('nearby-catalogue-');
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
    final device = 'novovm-ed25519:${'a' * 64}';
    String id(int n) =>
        '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
    Future<void> put(String? member, int n, {bool outgoing = false}) =>
        store.persistNearbyText(
          peerId: device,
          peerAccount: member,
          id: id(n),
          text: 'hello',
          outgoing: outgoing,
        );
    await put('friend_alpha', 1);
    await put('friend_beta', 2);
    await put('pending_only', 3, outgoing: true);
    await put(null, 4);
    expect(
      await store.nearbyConversationMembers(),
      unorderedEquals(['friend_alpha', 'friend_beta']),
    );
    final first = await store.nearbyConversationMembers(limit: 1);
    final second = await store.nearbyConversationMembers(
      afterMember: first.single,
      limit: 1,
    );
    expect({...first, ...second}, {'friend_alpha', 'friend_beta'});
    expect(
      await store.nearbyConversationMembers(afterMember: second.single),
      isEmpty,
    );
    await store.confirmNearbyReceipt(peerId: device, id: id(3));
    expect(await store.nearbyConversationMembers(), contains('pending_only'));
    await store.confirmNearbyServerPresence('friend_alpha', [id(1)]);
    await store.clear('direct:friend_beta', hideNearby: true);
    expect(await store.nearbyConversationMembers(), ['pending_only']);
    await store.close();
    final raw = await databaseFactoryFfi.openDatabase(file);
    final rows = await raw.query('nearby_member');
    expect(rows, hasLength(3));
    expect(jsonEncode(rows), isNot(contains('friend_alpha')));
    // Re-create the prior version without a catalogue: migration keeps journals,
    // and a later authenticated replay safely restores the missing mapping.
    await raw.execute('DROP TABLE nearby_member');
    await raw.execute('DROP TABLE conversation_list_cache');
    await raw.setVersion(11);
    await raw.close();
    store = await open();
    expect(await store.nearbyConversationMembers(), isEmpty);
    expect(await store.nearbyMemberMessages('pending_only'), hasLength(1));
    await put('pending_only', 3, outgoing: true);
    expect(await store.nearbyConversationMembers(), ['pending_only']);
    await expectLater(put('wrong_member', 3, outgoing: true), throwsStateError);
    expect(await store.nearbyConversationMembers(), ['pending_only']);
    await store.close();
    store = await open();
    expect(await store.nearbyConversationMembers(), ['pending_only']);
  });
}
