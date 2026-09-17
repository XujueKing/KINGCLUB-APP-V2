import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_store.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/contacts/data/contacts_controller.dart';

void main() {
  sqfliteFfiInit();
  late Directory dir;
  late SecretKey key;
  late ChatHistoryStore store;
  Future<ChatHistoryStore> open([String account = 'me']) =>
      ChatHistoryStore.openDatabaseWithKey(
        factory: databaseFactoryFfi,
        file: '${dir.path}/contacts.db',
        key: key,
        account: account,
      );
  const row = {
    'peer': 'friend',
    'nickname': 'PrivateContactNickname',
    'remark': 'PrivateRemark',
    'bio': 'hello',
  };
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('contact-snapshot-');
    key = await AesGcm.with256bits().newSecretKey();
    store = await open();
  });
  tearDown(() async {
    await store.close();
    await dir.delete(recursive: true);
  });

  test('version 14 upgrades without replacing existing chat tables', () async {
    await store.close();
    final db = await databaseFactoryFfi.openDatabase('${dir.path}/contacts.db');
    await db.execute('DROP TABLE contact_snapshot');
    await db.execute(
      "INSERT INTO conversation(id,cursor) VALUES('existing-chat',7)",
    );
    await db.execute('DROP TABLE contact_group_snapshot');
    await db.execute('ALTER TABLE message DROP COLUMN stale');
    await db.setVersion(14);
    await db.close();
    store = await open();
    expect(await store.contactSnapshot(), null);
    await store.saveContactSnapshot([row], 1);
    expect(await store.contactSnapshot(), [row]);
    await store.close();
    final checked = await databaseFactoryFfi.openDatabase(
      '${dir.path}/contacts.db',
    );
    expect(await checked.getVersion(), 20);
    expect((await checked.query('conversation')).single['cursor'], 7);
    await checked.close();
    store = await open();
  });

  test(
    'real disk reopen, encrypted content, old writes and account binding',
    () async {
      await store.saveContactSnapshot([
        {...row, 'token': 'not-stored'},
      ], 2);
      await store.saveContactSnapshot([], 1);
      await store.close();
      final bytes = await File('${dir.path}/contacts.db').readAsBytes();
      expect(latin1.decode(bytes), isNot(contains('PrivateContactNickname')));
      expect(latin1.decode(bytes), isNot(contains('PrivateRemark')));
      store = await open();
      expect(await store.contactSnapshot(), [row]);
      await store.close();
      store = await open('other');
      await expectLater(
        store.contactSnapshot(),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    },
  );

  test(
    'offline restart restores contacts; confirmed removal replaces snapshot',
    () async {
      await store.saveContactSnapshot([row], 1);
      var offline = true;
      final controller = ContactsController(
        MessagingRepository(
          account: 'me',
          call: (_, _) async {
            if (offline) throw StateError('offline');
            return {'items': [], 'hasMore': false};
          },
        ),
        historyStore: () async => store,
      );
      final restored = Completer<void>();
      controller.addListener(() {
        if (controller.hasSnapshot && !restored.isCompleted) {
          restored.complete();
        }
      });
      await controller.refresh();
      await restored.future.timeout(const Duration(seconds: 2));
      expect(controller.contacts.single.displayName, 'PrivateRemark');
      expect(controller.error, isNotNull);
      offline = false;
      await controller.refresh();
      expect(controller.contacts, isEmpty);
      expect(controller.error, isNull);
      // The UI is updated before the background encrypted write finishes.
      final deadline = DateTime.now().add(const Duration(seconds: 2));
      while ((await store.contactSnapshot())!.isNotEmpty &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(await store.contactSnapshot(), isEmpty);
      controller.dispose();
    },
  );

  test(
    'slow cache read cannot repopulate contacts after account invalidation',
    () async {
      await store.saveContactSnapshot([row], 1);
      final opening = Completer<ChatHistoryStore>();
      final controller = ContactsController(
        MessagingRepository(
          account: 'me',
          call: (_, _) async => throw StateError('offline'),
        ),
        historyStore: () => opening.future,
      );
      await controller.refresh();
      controller.invalidate();
      opening.complete(store);
      await store.contactSnapshot();
      await Future<void>.delayed(Duration.zero);
      expect(controller.contacts, isEmpty);
      expect(controller.hasSnapshot, false);
      controller.dispose();
    },
  );
}
