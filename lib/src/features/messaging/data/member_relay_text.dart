import 'dart:async';

import '../../../core/session/member_qr_memory.dart';
import 'chat_history_store.dart';
import 'member_relay_runtime.dart';
import 'nearby_text_channel.dart';
import 'novorudp_relay_frame_link.dart';

/// Binds authenticated relay members to durable text journals. The owner must
/// subscribe to changes and read history before enabling this route in the UI.
/// Does not own the account history store or replace the service outbox.
class MemberRelayText {
  MemberRelayText({required this.runtime, required this.history}) {
    if (history.account != runtime.binding.messaging.account) {
      throw ArgumentError('Relay history belongs to another account');
    }
    _incoming = runtime.incomingChannels.listen((arrival) {
      try {
        _attach(arrival.peer, arrival.link);
      } catch (_) {
        unawaited(arrival.link.close());
      }
    });
    _connections = runtime.connections.listen((connection) {
      if (connection == null) _clearChannels();
    }, onDone: () => unawaited(close()));
  }
  final MemberRelayRuntime runtime;
  final ChatHistoryStore history;
  final int _generation = MemberQrMemory.generation;
  final _channels = <String, NearbyTextChannel>{};
  final _subscriptions = <String, StreamSubscription<String>>{};
  final _changes = StreamController<String>.broadcast();
  Stream<String> get changes => _changes.stream;

  /// Local history remains readable offline, but never across account changes.
  Future<List<Map<String, dynamic>>> messages(
    String peer, {
    int limit = 100,
  }) async {
    if (_closed || _generation != MemberQrMemory.generation) {
      throw StateError('Relay text account changed');
    }
    final rows = await history.nearbyMemberMessages(peer, limit: limit);
    if (_closed || _generation != MemberQrMemory.generation) {
      throw StateError('Relay text account changed');
    }
    return rows;
  }

  late final StreamSubscription<MemberRelayArrival> _incoming;
  late final StreamSubscription _connections;
  bool _closed = false;
  Future<void>? _closing;

  bool get _active =>
      !_closed &&
      _generation == MemberQrMemory.generation &&
      runtime.connection != null;

  NearbyTextChannel _attach(String peer, NovoRudpRelayFrameLink link) {
    if (!_active) throw StateError('Relay text inactive');
    final previous = _channels[link.expectedPeer];
    if (previous != null && identical(previous.link, link)) return previous;
    if (previous != null) unawaited(previous.close());
    unawaited(_subscriptions.remove(link.expectedPeer)?.cancel());
    final channel = NearbyTextChannel(
      link: link,
      history: history,
      peerId: link.expectedPeer,
      peerAccount: peer,
      canExchange: () => _active,
    );
    _channels[link.expectedPeer] = channel;
    _subscriptions[link.expectedPeer] = channel.changes.listen(
      (_) {
        if (_active && identical(_channels[link.expectedPeer], channel)) {
          _changes.add(peer);
        }
      },
      onDone: () {
        if (identical(_channels[link.expectedPeer], channel)) {
          _channels.remove(link.expectedPeer);
          _subscriptions.remove(link.expectedPeer);
        }
      },
    );
    return channel;
  }

  Future<void> sendText({
    required String peer,
    required String bindingId,
    required String text,
    required String messageId,
    bool Function()? stillActive,
  }) async {
    if (!_active || stillActive?.call() == false) {
      throw StateError('Relay text inactive');
    }
    final link = await runtime.connectPeer(peer, bindingId);
    if (!_active || stillActive?.call() == false) {
      throw StateError('Relay text inactive');
    }
    await _attach(
      peer,
      link,
    ).sendText(text, messageId: messageId, stillActive: stillActive);
  }

  void _clearChannels() {
    for (final channel in _channels.values) {
      unawaited(channel.close());
    }
    _channels.clear();
    for (final subscription in _subscriptions.values) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
  }

  Future<void> flushReadReceipts(String peer) async {
    if (!_active) return;
    await Future.wait(
      _channels.values
          .where((channel) => channel.peerAccount == peer)
          .map((channel) => channel.flushReadReceipts()),
    );
  }

  Future<void> close() {
    _closed = true;
    return _closing ??= _close();
  }

  Future<void> _close() async {
    _clearChannels();
    await _incoming.cancel();
    await _connections.cancel();
    await _changes.close();
  }
}
