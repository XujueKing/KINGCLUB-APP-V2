import 'dart:async';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kingclub/src/features/contacts/data/contact_groups_repository.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_store.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

void main() {
  sqfliteFfiInit();
  late Directory dir;
  late SecretKey key;
  late ChatHistoryStore store;
  Future<ChatHistoryStore> open() => ChatHistoryStore.openDatabaseWithKey(
    factory: databaseFactoryFfi,
    file: '${dir.path}/history.db',
    key: key,
    account: 'me',
  );
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('contact-groups-');
    key = await AesGcm.with256bits().newSecretKey();
    store = await open();
  });
  tearDown(() async {
    await store.close();
    await dir.delete(recursive: true);
  });
  Map<String, dynamic> snapshot(int version, String name) => {
    'version': version,
    'groups': [
      ContactGroup('g', name, 2, {'friend'}).toJson(),
    ],
  };
  test('confirmed groups survive reopen; offline snapshot does not authorize edits', () async {
    final repo = ContactGroupsRepository(
      MessagingRepository(
        account: 'me',
        call: (_, params) async => params.isEmpty
            ? snapshot(1, '好友')
            : {'version': 2, 'groups': params['groups']},
      ),
      openHistory: () async => store,
    );
    await repo.load();
    await repo.save([
      ContactGroup('g', '同学', 1, {'friend'}),
    ]);
    await store.close();
    store = await open();
    final cached = Completer<List<ContactGroup>>();
    final offline = ContactGroupsRepository(
      MessagingRepository(
        account: 'me',
        call: (_, _) async => throw StateError('offline'),
      ),
      openHistory: () async => store,
    );
    await expectLater(
      offline.load(onCached: cached.complete),
      throwsStateError,
    );
    final groups = await cached.future;
    expect(groups.single.name, '同学');
    expect(groups.single.icon, 1);
    expect(groups.single.members, {'friend'});
    await expectLater(offline.save([]), throwsStateError);
  });
  test(
    'late older repository cannot overwrite a newer saved snapshot',
    () async {
      await store.saveContactGroupSnapshot(snapshot(5, '新分组'));
      await store.saveContactGroupSnapshot(snapshot(3, '旧分组'));
      expect((await store.contactGroupSnapshot())!['version'], 5);
      await store.saveContactGroupSnapshot({'version': 6, 'groups': []});
      await store.close();
      store = await open();
      expect((await store.contactGroupSnapshot())!['groups'], isEmpty);
    },
  );
  test(
    'delayed local read cannot flash old groups after a network response',
    () async {
      await store.saveContactGroupSnapshot(snapshot(1, '旧分组'));
      final disk = Completer<ChatHistoryStore>();
      final network = Completer<Map<String, dynamic>>();
      final seen = <List<ContactGroup>>[];
      final repo = ContactGroupsRepository(
        MessagingRepository(account: 'me', call: (_, _) => network.future),
        openHistory: () => disk.future,
      );
      final load = repo.load(onCached: seen.add);
      network.complete(snapshot(2, '新分组'));
      await Future<void>.delayed(Duration.zero);
      disk.complete(store);
      expect((await load).single.name, '新分组');
      expect(seen, isEmpty);
    },
  );
}
