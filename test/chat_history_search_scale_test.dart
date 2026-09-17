import 'dart:async';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  test('10000 encrypted messages search old matches and page without blocking writes', () async {
    final root = await Directory.systemTemp.createTemp('chat-search-scale-');
    final key = await AesGcm.with256bits().newSecretKey();
    final store = await ChatHistoryStore.openDatabaseWithKey(
      factory: databaseFactoryFfi,
      file: '${root.path}/history.db',
      key: key,
      account: 'me',
    );
    addTearDown(() async {
      await store.close();
      await root.delete(recursive: true);
    });
    Map<String, dynamic> row(int n) => {
      'messageId': 'message-$n',
      'clientMessageId': 'client-$n',
      'sender': 'peer',
      'sequence': n,
      'messageType': 'text',
      'text': n <= 65 ? 'archived needle $n' : 'ordinary history $n',
    };
    for (var start = 1; start <= 10000; start += 250) {
      expect(
        await store.commit('direct:peer', [
          for (var n = start; n < start + 250; n++) row(n),
        ], expectedEpoch: 0),
        true,
      );
    }
    final clock = Stopwatch()..start();
    final scanStarted = Completer<void>();
    var checks = 0, finished = false;
    final searching = store
        .search(
          'direct:peer',
          query: 'archived needle',
          limit: 30,
          isActive: () {
            if (++checks == 60) scanStarted.complete();
            return true;
          },
        )
        .whenComplete(() => finished = true);
    await scanStarted.future;
    final writeClock = Stopwatch()..start();
    expect(
      await store.commit('direct:peer', [row(10001)], expectedEpoch: 0),
      true,
    );
    writeClock.stop();
    expect(
      finished,
      false,
      reason: 'new messages must persist while old history is searched',
    );
    final first = await searching;
    clock.stop();
    expect((first['messages'] as List).map((r) => r['sequence']), [
      for (var n = 36; n <= 65; n++) n,
    ]);
    expect(first['hasMore'], true);
    final second = await store.search(
      'direct:peer',
      query: 'archived needle',
      before: 36,
      limit: 30,
    );
    expect((second['messages'] as List).map((r) => r['sequence']), [
      for (var n = 6; n <= 35; n++) n,
    ]);
    expect(second['hasMore'], true);
    final last = await store.search(
      'direct:peer',
      query: 'archived needle',
      before: 6,
      limit: 30,
    );
    expect((last['messages'] as List).map((r) => r['sequence']), [
      1,
      2,
      3,
      4,
      5,
    ]);
    expect(last['hasMore'], false);
    var recentChecks = 0;
    final recent = await store.search(
      'direct:peer',
      query: 'ordinary history',
      limit: 30,
      isActive: () {
        recentChecks++;
        return true;
      },
    );
    expect((recent['messages'] as List), hasLength(30));
    expect(
      recentChecks,
      lessThan(50),
      reason: 'a full recent page must not scan all stored messages',
    );
    // Timing is evidence for this desktop only, not a brittle device-independent gate.
    // ignore: avoid_print
    print(
      'CHAT_SEARCH_10000 scanMs=${clock.elapsedMilliseconds} concurrentWriteMs=${writeClock.elapsedMilliseconds} checks=$checks recentChecks=$recentChecks',
    );
  }, timeout: const Timeout(Duration(minutes: 2)));
}
