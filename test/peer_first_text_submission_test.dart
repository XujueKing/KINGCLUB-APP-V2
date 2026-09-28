import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/peer_first_text_submission.dart';

void main() {
  testWidgets('slow peer does not delay service acceptance or submit twice', (
    tester,
  ) async {
    final peer = Completer<bool>();
    var calls = 0;
    String? result;
    unawaited(
      peerFirstTextSubmission(
        sendPeer: () => peer.future,
        sendService: () async {
          calls++;
          return 'accepted';
        },
        isCurrent: () => true,
      ).then((value) async {
        result = await value.service;
      }),
    );
    await tester.pump(const Duration(milliseconds: 199));
    expect(calls, 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(result, 'accepted');
    peer.complete(true);
    await tester.pump();
    expect(calls, 1);
  });

  test('fast peer keeps its receipt and starts service only once', () async {
    var calls = 0;
    final result = await peerFirstTextSubmission(
      sendPeer: () async => true,
      sendService: () async {
        calls++;
        return 'accepted';
      },
      isCurrent: () => true,
    );
    expect(result.peerDelivered, true);
    expect(await result.service, 'accepted');
    expect(calls, 1);
  });

  testWidgets('service failure waits for peer and retains the receipt', (
    tester,
  ) async {
    final peer = Completer<bool>();
    bool? delivered;
    Object? error;
    unawaited(
      peerFirstTextSubmission(
        sendPeer: () => peer.future,
        sendService: () async => throw StateError('offline'),
        isCurrent: () => true,
      ).then((value) async {
        delivered = value.peerDelivered;
        try {
          await value.service;
        } catch (e) {
          error = e;
        }
      }),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(delivered, null);
    peer.complete(true);
    await tester.pump();
    expect(delivered, true);
    expect(error, isA<StateError>());
  });

  testWidgets('cancelled context cannot start a delayed service request', (
    tester,
  ) async {
    final peer = Completer<bool>();
    var active = true, called = false;
    Object? error;
    unawaited(
      peerFirstTextSubmission(
        sendPeer: () => peer.future,
        sendService: () async {
          called = true;
          return 'wrong';
        },
        isCurrent: () => active,
      ).then((value) async {
        try {
          await value.service;
        } catch (e) {
          error = e;
        }
      }),
    );
    active = false;
    await tester.pump(const Duration(milliseconds: 200));
    peer.complete(false);
    await tester.pump();
    expect(called, false);
    expect(error, isA<StateError>());
  });
}
