import 'dart:async';

/// Give peer delivery a head start without serializing service delivery behind
/// a handshake timeout. Both callbacks must use the same stable message ID.
Future<({bool peerDelivered, Future<T> service})> peerFirstTextSubmission<T>({
  required Future<bool> Function() sendPeer,
  required Future<T> Function() sendService,
  required bool Function() isCurrent,
  Duration headStart = const Duration(milliseconds: 200),
}) async {
  final service = Completer<T>();
  final accepted = Completer<void>();
  var started = false;
  void startService() {
    if (started) return;
    started = true;
    service.complete(
      Future<T>.sync(() {
        if (!isCurrent()) throw StateError('Text submission cancelled');
        return sendService();
      }),
    );
  }

  // Observe errors immediately, even while waiting for the peer receipt. The
  // original future still propagates the failure to the durable outbox owner.
  unawaited(
    service.future.then<void>(
      (_) => accepted.complete(),
      onError: (Object _, StackTrace _) {},
    ),
  );
  var peerDelivered = false;
  final peer = Future<bool>.sync(sendPeer)
      .then<void>(
        (value) => peerDelivered = value,
        onError: (Object _, StackTrace _) {},
      )
      .whenComplete(startService);
  final timer = Timer(headStart, startService);
  try {
    await Future.any<void>([peer, accepted.future]);
    return (peerDelivered: peerDelivered, service: service.future);
  } finally {
    timer.cancel();
  }
}
