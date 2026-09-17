import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/chat_queue_completion.dart';

void main() {
  test(
    'durable ownership releases composer while network is pending',
    () async {
      final disk = Completer<void>(), network = Completer<void>();
      var finished = false;
      final result = waitForChatQueue((queued) async {
        await disk.future;
        queued();
        await network.future;
      }).then((_) => finished = true);
      await Future<void>.delayed(Duration.zero);
      expect(finished, false);
      disk.complete();
      await result;
      expect(finished, true);
      expect(network.isCompleted, false);
      network.completeError(StateError('late network failure'));
      await Future<void>.delayed(Duration.zero);
    },
  );
  test(
    'queue failures and completion without ownership keep composer open',
    () async {
      await expectLater(
        waitForChatQueue((_) async => throw StateError('disk full')),
        throwsStateError,
      );
      await expectLater(waitForChatQueue((_) async {}), throwsStateError);
      await expectLater(
        waitForChatQueue((_) => throw StateError('sync failure')),
        throwsStateError,
      );
    },
  );
  test('repeated ownership callback cannot complete twice', () async {
    await waitForChatQueue((queued) async {
      queued();
      queued();
    });
  });
}
