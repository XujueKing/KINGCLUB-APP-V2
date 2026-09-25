import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/features/messaging/data/chat_outbox_recovery.dart';
import 'package:kingclub/src/features/messaging/data/direct_chat_controller.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

import 'direct_chat_controller_test.dart' as support;

void main() {
  for (final visible in [false, true]) {
    testWidgets(
      'reconnect wakes ${visible ? "visible" : "background"} queue without timer',
      (tester) async {
        final ready = StreamController<void>.broadcast();
        final queue = support.MemoryOutbox();
        var online = false, attempts = 0;
        final repository = MessagingRepository(
          account: 'me',
          call: (api, params) async {
            if (api == 'K260913000604') return support.history([]);
            if (api == 'K260913000601') {
              attempts++;
              if (!online) throw const AuthFailure('NETWORK_ERROR', 'offline');
              return {'message': support.ack(params)};
            }
            return {};
          },
        );
        await queue.put({
          'clientMessageId': 'queued',
          'sender': 'me',
          'recipient': 'peer',
          'text': 'hello',
          'status': 'queued',
        });
        final chat = visible
            ? DirectChatController(
                repository: repository,
                peer: 'peer',
                outbox: queue,
                transportReady: ready.stream,
              )
            : null;
        final worker = visible
            ? null
            : ChatOutboxRecovery(
                repository,
                queue,
                transportReady: ready.stream,
              );
        if (chat != null) {
          unawaited(chat.initialize());
        } else {
          worker!.start();
        }
        await tester.pump();
        expect(attempts, 1);
        expect(queue.items['queued']?['status'], 'queued');
        online = true;
        ready.add(null);
        ready.add(null);
        await tester.pump();
        expect(
          attempts,
          2,
          reason: 'duplicate wakeups must not duplicate sends',
        );
        expect(queue.items, isEmpty);
        chat?.dispose();
        worker?.close();
        ready.add(null);
        await tester.pump();
        expect(attempts, 2);
        expect(ready.hasListener, false);
        await ready.close();
      },
    );
  }
}
