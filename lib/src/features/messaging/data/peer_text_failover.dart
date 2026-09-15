import 'dart:async';

import '../../../core/session/member_qr_memory.dart';
import '../../../core/session/secure_session_store.dart';
import 'chat_history_store.dart';
import 'nearby_text_channel.dart';

enum PeerTextRoute { direct, relay }

/// Switches authenticated lanes within one device journal. It does not merge
/// server history, discover devices, or grant permission to contact a peer.
class PeerTextFailover {
  PeerTextFailover({
    required this.history,
    required this.peerId,
    required this.canExchange,
    required this.connectRelay,
    NearbyTextChannel? direct,
    this.directReceiptTimeout = const Duration(seconds: 3),
    this.relayConnectTimeout = const Duration(seconds: 8),
  }) : _direct = direct {
    if (direct != null) _validate(direct);
    _session = SecureSessionStore.changes.stream.listen(
      (_) => unawaited(close()),
    );
  }
  final ChatHistoryStore history;
  final String peerId;
  final bool Function() canExchange;
  final Future<NearbyTextChannel> Function() connectRelay;
  final Duration directReceiptTimeout, relayConnectTimeout;
  NearbyTextChannel? _direct, _relay;
  final int _generation = MemberQrMemory.generation;
  late final StreamSubscription<void> _session;
  Future<void> _tail = Future.value();
  Future<void>? _closing;
  bool _closed = false;
  int _queued = 0, _opening = 0;
  void _check() {
    if (_closed || _generation != MemberQrMemory.generation || !canExchange()) {
      unawaited(close());
      throw StateError('Peer delivery unavailable');
    }
  }

  void _validate(NearbyTextChannel lane) {
    if (!identical(lane.history, history) || lane.peerId != peerId) {
      throw ArgumentError('Failover must share one peer and journal');
    }
  }

  Future<PeerTextRoute> sendText(String text, {required String messageId}) {
    _check();
    if (_queued >= 8) throw StateError('Peer delivery queue full');
    _queued++;
    final result = _tail.then((_) => _send(text, messageId));
    _tail = result
        .then<void>((_) {}, onError: (Object _, StackTrace _) {})
        .whenComplete(() {
          _queued--;
        });
    return result;
  }

  Future<PeerTextRoute> _send(String text, String id) async {
    _check();
    // Validate/persist before choosing a route; every retry keeps this ID.
    await history.persistNearbyText(
      peerId: peerId,
      id: id,
      text: text,
      outgoing: true,
    );
    _check();
    final direct = _direct;
    if (direct != null) {
      try {
        await direct
            .sendText(text, messageId: id)
            .timeout(directReceiptTimeout);
        _check();
        return PeerTextRoute.direct;
      } catch (_) {
        _direct = null;
        await direct.close();
        _check();
      }
    }
    try {
      var relay = _relay;
      if (relay == null) {
        final attempt = ++_opening;
        try {
          relay = await Future<NearbyTextChannel>.sync(connectRelay)
              .then((lane) async {
                try {
                  _check();
                  if (attempt != _opening) {
                    throw StateError('Expired relay attempt');
                  }
                  _validate(lane);
                  return lane;
                } catch (_) {
                  await lane.close();
                  rethrow;
                }
              })
              .timeout(relayConnectTimeout);
          _relay = relay;
        } catch (_) {
          _opening++;
          rethrow;
        }
      }
      _check();
      await relay.sendText(text, messageId: id);
      _check();
      return PeerTextRoute.relay;
    } catch (_) {
      final relay = _relay;
      _relay = null;
      await relay?.close();
      rethrow;
    }
  }

  Future<void> close() {
    _closed = true;
    _opening++;
    return _closing ??= _close();
  }

  Future<void> _close() async {
    await _session.cancel();
    await _direct?.close();
    await _relay?.close();
    _direct = null;
    _relay = null;
  }
}
