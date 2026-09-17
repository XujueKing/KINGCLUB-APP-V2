import 'dart:async';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  test(
    'scans allow writes and reject deleted matches without stale results',
    () async {
      final dir = await Directory.systemTemp.createTemp('search-cancel-');
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
      Map<String, dynamic> row(int n) => {
        'messageId': 'm$n',
        'clientMessageId': 'c$n',
        'sequence': n,
        'sender': 'peer',
        'messageType': 'text',
        'text': 'saved history $n',
      };
      await store.commit('direct:peer', [
        for (var i = 1; i <= 2000; i++) row(i),
      ], expectedEpoch: 0);
      final scanning = Completer<void>();
      var active = true, checks = 0;
      final old = store.search(
        'direct:peer',
        query: 'absent',
        isActive: () {
          checks++;
          if (checks == 20) scanning.complete();
          return active;
        },
      );
      // Register the rejection before cancelling the in-flight transaction.
      final rejected = expectLater(old, throwsStateError);
      await scanning.future;
      final write = store.commit('direct:peer', [row(2001)], expectedEpoch: 0);
      active = false;
      await rejected;
      expect(await write, true);
      expect(
        checks,
        lessThan(30),
        reason: 'obsolete query must not scan all 2000 rows',
      );
      final fresh = await store.search('direct:peer', query: 'history 2001');
      expect((fresh['messages'] as List).single['messageId'], 'm2001');
      await expectLater(
        store.search('direct:peer', query: 'saved', isActive: () => false),
        throwsStateError,
      );

      final validScanStarted = Completer<void>();
      var validChecks = 0, finished = false;
      final validScan = store
          .search(
            'direct:peer',
            query: 'absent',
            isActive: () {
              if (++validChecks == 20) validScanStarted.complete();
              return true;
            },
          )
          .whenComplete(() => finished = true);
      await validScanStarted.future;
      expect(
        await store.commit('direct:peer', [row(2002)], expectedEpoch: 0),
        true,
      );
      expect(
        finished,
        false,
        reason: 'a live search must not block new message persistence',
      );
      expect((await validScan)['messages'], isEmpty);

      final deletionScanStarted = Completer<void>();
      var deletionChecks = 0;
      final deletedScan = store.search(
        'direct:peer',
        query: 'history 2002',
        isActive: () {
          if (++deletionChecks == 20) deletionScanStarted.complete();
          return true;
        },
      );
      final changed = expectLater(deletedScan, throwsStateError);
      await deletionScanStarted.future;
      await store.clear('direct:peer', deletedMessageIds: {'m2002'});
      await changed;
      expect(
        (await store.search('direct:peer', query: 'history 2002'))['messages'],
        isEmpty,
      );
    },
  );
}
