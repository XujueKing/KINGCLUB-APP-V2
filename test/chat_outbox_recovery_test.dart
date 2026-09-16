import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/features/messaging/data/chat_outbox_recovery.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

import 'direct_chat_controller_test.dart' as direct;
import 'group_chat_controller_test.dart' as group;

void main() {
  test(
    'reconnect during an active retry drains the queue again immediately',
    () async {
      final queue = direct.MemoryOutbox();
      await queue.put({
        'clientMessageId': 'q',
        'status': 'queued',
        'recipient': 'peer',
        'sender': 'me',
        'text': 'hello',
      });
      final entered = Completer<void>();
      final first = Completer<Map<String, dynamic>>();
      var sends = 0;
      final worker = ChatOutboxRecovery(
        MessagingRepository(
          account: 'me',
          call: (id, p) async {
            if (id == 'K260913000604') return direct.history([]);
            sends++;
            if (sends == 1) {
              entered.complete();
              return first.future;
            }
            return {'message': direct.ack(p)};
          },
        ),
        queue,
      );
      addTearDown(worker.close);
      final running = worker.notify();
      await entered.future;
      final reconnect = worker.notify();
      first.completeError(
        const AuthFailure('NETWORK_ERROR', 'old connection failed'),
      );
      await Future.wait([running, reconnect]);
      expect(sends, 2);
      expect(queue.items, isEmpty);
    },
  );
  test(
    'foreground recovery retains peer receipt across worker restart',
    () async {
      final queue = direct.MemoryOutbox();
      await queue.put({
        'clientMessageId': 'queued',
        'status': 'queued',
        'recipient': 'peer',
        'sender': 'me',
        'text': 'hello',
      });
      var offline = true;
      var relays = 0;
      final ids = <String>[];
      ChatOutboxRecovery worker() => ChatOutboxRecovery(
        MessagingRepository(
          account: 'me',
          call: (method, params) async {
            if (method == 'K260913000604') return direct.history([]);
            ids.add(params['clientMessageId'] as String);
            if (offline) throw const AuthFailure('NETWORK_ERROR', 'offline');
            return {'message': direct.ack(params)};
          },
        ),
        queue,
        relaySenderFor: (peer) => (text, id) async {
          expect(peer, 'peer');
          expect(text, 'hello');
          expect(id, 'queued');
          relays++;
          return true;
        },
      );
      var current = worker();
      await current.notify();
      expect(queue.items['queued']!['peerDelivered'], true);
      expect(queue.items['queued']!['status'], 'queued');
      current.close();
      current = worker();
      await current.notify();
      expect(relays, 1);
      offline = false;
      await current.notify();
      expect(ids, ['queued', 'queued', 'queued']);
      expect(queue.items, isEmpty);
      current.close();
    },
  );
  for (final isGroup in [false, true]) {
    test(
      'recovers ${isGroup ? "group" : "direct"} without a visible page',
      () async {
        final queue = direct.MemoryOutbox();
        await queue.put({
          'clientMessageId': 'queued',
          'status': 'queued',
          'text': 'hello',
          if (isGroup) 'groupId': 'group' else 'recipient': 'peer',
        });
        final sends = <String>[];
        final worker = ChatOutboxRecovery(
          MessagingRepository(
            account: 'me',
            call: (id, params) async {
              if (id == 'K260913000619') return {'members': []};
              if (id == 'K260913000621') return group.history([]);
              if (id == 'K260913000604') return direct.history([]);
              expect(id, isGroup ? 'K260913000620' : 'K260913000601');
              sends.add(params['clientMessageId'] as String);
              return {
                'message': isGroup
                    ? group.message('queued')
                    : direct.ack(params),
              };
            },
          ),
          queue,
        );
        worker.start();
        await Future.wait([worker.notify(), worker.notify()]);
        await worker.notify();
        expect(sends, ['queued']);
        expect(queue.items, isEmpty);
        worker.close();
      },
    );
  }

  test('visible conversation owns retry until released', () async {
    final queue = direct.MemoryOutbox();
    await queue.put({
      'clientMessageId': 'q',
      'status': 'queued',
      'recipient': 'peer',
      'text': 'hello',
    });
    var sends = 0;
    final worker = ChatOutboxRecovery(
      MessagingRepository(
        account: 'me',
        call: (id, p) async {
          if (id == 'K260913000604') return direct.history([]);
          sends++;
          return {'message': direct.ack(p)};
        },
      ),
      queue,
    );
    final release = ChatOutboxRecovery.hold('me', 'peer', false);
    await worker.notify();
    expect(sends, 0);
    release();
    await worker.notify();
    expect(sends, 1);
    worker.close();
  });

  test(
    'closing during history prevents send and preserves durable queue',
    () async {
      final queue = direct.MemoryOutbox();
      await queue.put({
        'clientMessageId': 'q',
        'status': 'queued',
        'recipient': 'peer',
        'text': 'hello',
      });
      final entered = Completer<void>();
      final reply = Completer<Map<String, dynamic>>();
      final worker = ChatOutboxRecovery(
        MessagingRepository(
          account: 'me',
          call: (id, p) async {
            expect(id, 'K260913000604');
            entered.complete();
            return reply.future;
          },
        ),
        queue,
      );
      final pending = worker.notify();
      await entered.future;
      worker.close();
      reply.complete(direct.history([]));
      await pending;
      expect(queue.items.keys, ['q']);
    },
  );

  test('revoked group access and failed messages are not sent', () async {
    final queue = direct.MemoryOutbox();
    await queue.put({
      'clientMessageId': 'q',
      'status': 'queued',
      'groupId': 'group',
      'text': 'hello',
    });
    await queue.put({
      'clientMessageId': 'f',
      'status': 'failed',
      'recipient': 'peer',
      'text': 'hello',
    });
    final worker = ChatOutboxRecovery(
      MessagingRepository(
        account: 'me',
        call: (id, p) async {
          expect(id, 'K260913000621');
          throw const AuthFailure('CHAT_GROUP_ACCESS_DENIED', 'removed');
        },
      ),
      queue,
    );
    await worker.notify();
    expect(queue.items.length, 2);
    worker.close();
  });
}
