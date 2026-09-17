import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_access.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_store.dart';

void main() {
  sqfliteFfiInit();
  for (final code in [
    'CHAT_GROUP_ACCESS_DENIED',
    'NETWORK_ERROR',
    'CHAT_GROUP_MUTED',
    'FORBIDDEN',
  ]) {
    test(
      'group search denial persists only for definitive access loss: $code',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'group-search-access-',
        );
        final key = await AesGcm.with256bits().newSecretKey();
        Future<ChatHistoryStore> open() => ChatHistoryStore.openDatabaseWithKey(
          factory: databaseFactoryFfi,
          file: '${root.path}/history.db',
          key: key,
          account: 'me',
        );
        var store = await open();
        addTearDown(() async {
          await store.close();
          await root.delete(recursive: true);
        });
        for (final target in [
          'group:revoked',
          'group:other',
          'direct:friend',
        ]) {
          await store.commit(target, [
            {
              'sequence': 1,
              'messageId': 'm1',
              'clientMessageId': 'c1',
              'sender': 'peer',
              'text': 'saved content',
            },
          ], expectedEpoch: 0);
        }
        await clearDeniedGroupHistory(
          AuthFailure(code, 'test'),
          account: 'me',
          groupId: 'revoked',
          openHistory: () async => store,
        );
        await store.close();
        store = await open();
        expect(
          (await store.read('group:revoked')).messages.length,
          code == 'CHAT_GROUP_ACCESS_DENIED' ? 0 : 1,
        );
        expect((await store.read('group:other')).messages.length, 1);
        expect((await store.read('direct:friend')).messages.length, 1);
      },
    );
  }
  test('direct conversation does not open or clear group storage', () async {
    await clearDeniedGroupHistory(
      const AuthFailure('CHAT_GROUP_ACCESS_DENIED', 'test'),
      account: 'me',
      groupId: null,
      openHistory: () async => throw StateError('must not open'),
    );
  });
}
