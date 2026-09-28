import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_store.dart';
import 'package:kingclub/src/features/messaging/data/device_history_receipts.dart';

import 'direct_chat_controller_test.dart' show ack;

void main() {
  sqfliteFfiInit();
  const id = '11111111-1111-4111-8111-111111111111';
  late Directory directory;
  late ChatHistoryStore store;
  late SecretKey key;
  var number = 0;
  Future<ChatHistoryStore> open(String account) =>
      ChatHistoryStore.openDatabaseWithKey(
        factory: databaseFactoryFfi,
        file: '${directory.path}/history.db',
        key: key,
        account: account,
      );
  Map<String, dynamic> message() => {
    ...ack({'clientMessageId': 'c1', 'text': 'saved message'}, sequence: 1),
    'messageId': id,
  };
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('device-history-');
    key = await AesGcm.with256bits().newSecretKey();
    store = await open('receipt-${++number}');
  });
  tearDown(() async {
    await store.close();
    await directory.delete(recursive: true);
  });
  test(
    'failed epoch write cannot enqueue a receipt, successful write does',
    () async {
      expect(
        await store.commit('direct:peer', [message()], expectedEpoch: 999),
        false,
      );
      expect(await store.pendingDeviceReceipts(), isEmpty);
      expect(
        await store.commit('direct:peer', [message()], expectedEpoch: 0),
        true,
      );
      expect(await store.pendingDeviceReceipts(), {
        'direct:peer': [id],
      });
      expect(
        (await store.read('direct:peer')).messages.single['text'],
        'saved message',
      );
    },
  );
  test('receipt survives offline failure and database reopen without deleting the message', () async {
    await store.commit('direct:peer', [message()], expectedEpoch: 0);
    await flushDeviceHistoryReceipts(
      store.account,
      (_, _) async => throw StateError('offline'),
      store: store,
    );
    final account = store.account;
    await store.close();
    store = await open(account);
    expect(await store.pendingDeviceReceipts(), {
      'direct:peer': [id],
    });
    expect((await store.read('direct:peer')).messages, hasLength(1));
  });
  test(
    'confirmed receipt is not requeued by repeated history refresh',
    () async {
      await store.commit('direct:peer', [message()], expectedEpoch: 0);
      var calls = 0;
      await flushDeviceHistoryReceipts(store.account, (method, params) async {
        calls++;
        expect(method, 'K260913000604');
        expect(params, {
          'peer': 'peer',
          'acknowledgeOnly': true,
          'savedMessageIds': [id],
        });
        return {
          'deviceHistory': true,
          'confirmed': [id],
          'conflicts': [],
          'unavailable': [],
        };
      }, store: store);
      expect(calls, 1);
      expect(await store.pendingDeviceReceipts(), isEmpty);
      await store.commit('direct:peer', [message()], expectedEpoch: 0);
      expect(await store.pendingDeviceReceipts(), isEmpty);
    },
  );
  test(
    'malformed or disabled server receipt leaves durable intent pending',
    () async {
      await store.commit('direct:peer', [message()], expectedEpoch: 0);
      await flushDeviceHistoryReceipts(
        store.account,
        (_, _) async => {
          'deviceHistory': true,
          'confirmed': [],
          'conflicts': [],
          'unavailable': [],
        },
        store: store,
      );
      expect(await store.pendingDeviceReceipts(), {
        'direct:peer': [id],
      });
    },
  );
}
