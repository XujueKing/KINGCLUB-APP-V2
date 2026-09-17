import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/features/messaging/data/chat_read_outbox.dart';
import 'package:kingclub/src/features/messaging/data/chat_outbox_recovery.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

import 'direct_chat_controller_test.dart' show MemoryOutbox;

class ObservedOutbox extends MemoryOutbox {
  final accessed = Completer<void>();
  @override
  Future<List<Map<String, dynamic>>> read() async {
    if (!accessed.isCompleted) accessed.complete();
    return super.read();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'confirmed reads survive reopening without returning to retry queue',
    () async {
      final queue = ChatReadOutbox('me');
      await queue.put('peer', 8);
      await queue.acknowledge('peer', 8);
      final reopened = ChatReadOutbox('me');
      expect(await reopened.read(), isEmpty);
      expect(await reopened.displayWatermarks(), {'peer': 8});
      await reopened.put('peer', 3);
      await reopened.acknowledge('peer', 3);
      expect(await reopened.displayWatermarks(), {'peer': 8});
      expect(await ChatReadOutbox('other').displayWatermarks(), isEmpty);
      expect(
        await ChatReadOutbox('me', group: true).displayWatermarks(),
        isEmpty,
      );
      final repository = MessagingRepository(
        account: 'me',
        readOutbox: reopened,
        call: (_, _) async => {},
      );
      final projection = await repository.pendingReadProjection();
      final rows = projection.apply([
        {'peer': 'peer', 'lastSequence': 8, 'unreadCount': 3},
        {'peer': 'peer', 'lastSequence': 9, 'unreadCount': 1},
      ]);
      expect(rows[0]['unreadCount'], 0);
      expect(rows[1]['unreadCount'], 1);
    },
  );

  test('only successful read recovery notifies the matching account', () async {
    final matching = <String>[];
    final other = <String>[];
    final first = MessagingRepository.readChanges('me').listen(matching.add);
    final second = MessagingRepository.readChanges('other').listen(other.add);
    addTearDown(first.cancel);
    addTearDown(second.cancel);
    final queue = ChatReadOutbox('me');
    await queue.put('peer', 1);
    var offline = true;
    final repo = MessagingRepository(
      account: 'me',
      readOutbox: queue,
      call: (_, _) async {
        if (offline) throw const AuthFailure('NETWORK_ERROR', 'offline');
        return {'readSequence': 1};
      },
    );
    await repo.retryPendingReads(isActive: () => true);
    await Future<void>.delayed(Duration.zero);
    expect(matching, isEmpty);
    offline = false;
    await repo.retryPendingReads(isActive: () => true);
    await Future<void>.delayed(Duration.zero);
    expect(matching, ['me']);
    expect(other, isEmpty);
  });

  test('slow read receipt does not delay the pending-message drain', () async {
    final queue = ChatReadOutbox('me');
    await queue.put('peer', 1);
    final response = Completer<Map<String, dynamic>>();
    final called = Completer<void>();
    final messages = ObservedOutbox();
    final worker = ChatOutboxRecovery(
      MessagingRepository(
        account: 'me',
        readOutbox: queue,
        call: (_, _) {
          called.complete();
          return response.future;
        },
      ),
      messages,
    );
    final running = worker.notify();
    await called.future;
    await messages.accessed.future.timeout(const Duration(seconds: 2));
    expect(response.isCompleted, false);
    response.complete({'readSequence': 1});
    await running;
    worker.close();
  });

  test(
    'offline intent survives repository recreation and foreground recovery',
    () async {
      final repo = MessagingRepository(
        account: 'me',
        readOutbox: ChatReadOutbox('me'),
        call: (_, _) async =>
            throw const AuthFailure('NETWORK_ERROR', 'offline'),
      );
      await expectLater(repo.markRead('peer', 8), throwsA(isA<AuthFailure>()));
      final calls = <Map<String, dynamic>>[];
      final reopened = ChatReadOutbox('me');
      expect(await reopened.read(), {'peer': 8});
      final worker = ChatOutboxRecovery(
        MessagingRepository(
          account: 'me',
          readOutbox: reopened,
          call: (method, params) async {
            expect(method, 'K260913000605');
            calls.add(params);
            return {'readSequence': params['sequence']};
          },
        ),
        MemoryOutbox(),
      );
      await worker.notify();
      await worker.notify();
      expect(calls, [
        {'peer': 'peer', 'sequence': 8},
      ]);
      expect(await reopened.read(), isEmpty);
      worker.close();
    },
  );

  test('late acknowledgement cannot delete a newer concurrent read', () async {
    final queue = ChatReadOutbox('me');
    final response = Completer<Map<String, dynamic>>();
    final called = Completer<void>();
    final repo = MessagingRepository(
      account: 'me',
      readOutbox: queue,
      call: (_, _) {
        called.complete();
        return response.future;
      },
    );
    final sending = repo.markRead('peer', 5);
    await called.future;
    await ChatReadOutbox('me').put('peer', 10);
    response.complete({'readSequence': 5});
    await sending;
    expect(await queue.read(), {'peer': 10});
    await queue.put('peer', 3);
    expect(await queue.read(), {'peer': 10});
  });

  test(
    'accounts are isolated and invalid injected ownership is rejected',
    () async {
      final queue = ChatReadOutbox('a');
      await queue.put('peer', 3);
      expect(await ChatReadOutbox('b').read(), isEmpty);
      expect(
        () => MessagingRepository(
          account: 'b',
          readOutbox: queue,
          call: (_, _) async => {},
        ),
        throwsArgumentError,
      );
      await expectLater(queue.put('peer', 0), throwsArgumentError);
    },
  );

  test(
    'failed retry retains pending reads and stops network-error fanout',
    () async {
      final queue = ChatReadOutbox('me');
      await queue.put('peer', 1);
      await queue.put('other', 2);
      var calls = 0;
      final repo = MessagingRepository(
        account: 'me',
        readOutbox: queue,
        call: (_, _) async {
          calls++;
          throw const AuthFailure('NETWORK_ERROR', 'offline');
        },
      );
      await repo.retryPendingReads(isActive: () => true);
      expect(calls, 1);
      expect(await queue.read(), {'peer': 1, 'other': 2});
    },
  );

  test(
    'closing worker stops later peers and leaves in-flight intent recoverable',
    () async {
      final queue = ChatReadOutbox('me');
      await queue.put('peer', 1);
      await queue.put('other', 2);
      final response = Completer<Map<String, dynamic>>();
      final called = Completer<void>();
      var calls = 0;
      final worker = ChatOutboxRecovery(
        MessagingRepository(
          account: 'me',
          readOutbox: queue,
          call: (_, _) {
            calls++;
            called.complete();
            return response.future;
          },
        ),
        MemoryOutbox(),
      );
      final running = worker.notify();
      await called.future;
      worker.close();
      response.complete({'readSequence': 1});
      await running;
      expect(calls, 1);
      expect(await queue.read(), {'peer': 1, 'other': 2});
    },
  );
}
