import 'dart:async';
import 'dart:convert';

import 'group_file_device_scope.dart';
import 'novorudp_frame.dart';
import 'novorudp_frame_link.dart';

/// Confirm scope inside the peer-authenticated encrypted channel before use.
/// The outer relay offer is only a discovery hint, never trusted authorization.
class GroupFileScopeExchange {
  static final stream = BigInt.from(0x4b434753);

  static Future<void> confirm(
    NovoRudpFrameLink link,
    GroupFileDeviceScope scope,
  ) async {
    final encoded = jsonEncode([
      'kingclub-group-file-v1',
      scope.groupId,
      scope.messageId,
      scope.sender,
      scope.recipient,
      scope.senderVersion,
      scope.recipientVersion,
      if (scope.media != null) scope.media,
    ]);
    final result = Completer<void>();
    Timer? retry, deadline;
    var stopped = false, sending = false;
    late StreamSubscription<NovoRudpFrame> subscription;
    void stop() {
      if (stopped) return;
      stopped = true;
      retry?.cancel();
      deadline?.cancel();
      unawaited(subscription.cancel());
    }

    void fail(Object error) {
      if (!result.isCompleted) result.completeError(error);
      stop();
    }

    subscription = link.frames.listen(
      (frame) {
        if (frame.streamId != stream) return;
        if (frame.kind != NovoRudpFrameKind.endpoint ||
            frame.payload.length > 1024 ||
            utf8.decode(frame.payload, allowMalformed: true) != encoded) {
          fail(StateError('Encrypted group file scope mismatch'));
        } else if (!result.isCompleted) {
          result.complete();
        }
      },
      onError: fail,
      onDone: () => fail(StateError('Group file lane closed')),
    );
    Future<void> send() async {
      if (stopped || sending) return;
      sending = true;
      try {
        await link
            .send(
              NovoRudpFrame(
                kind: NovoRudpFrameKind.endpoint,
                sessionId: link.channel.sessionId,
                streamId: stream,
                objectId: BigInt.zero,
                sequence: BigInt.zero,
                ackEpoch: BigInt.zero,
                payload: utf8.encode(encoded),
              ),
            )
            .timeout(const Duration(seconds: 1));
      } catch (error) {
        fail(error);
      } finally {
        sending = false;
      }
    }

    // Keep confirming briefly after our own receipt so a late peer subscriber
    // can finish too. This does not delay successful callers or carry file data.
    retry = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => unawaited(send()),
    );
    deadline = Timer(const Duration(seconds: 2), () {
      if (!result.isCompleted) {
        result.completeError(
          TimeoutException('Group scope confirmation timed out'),
        );
      }
      stop();
    });
    unawaited(send());
    await result.future;
  }
}
