import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_frame.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_ice_route.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_ice_signaling.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_relay_connection.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_relay_frame_link.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_secure_session.dart';

class _Carrier extends Fake implements NovoRudpRelayConnection {
  _Carrier(this.identity);
  @override
  final NovoRudpSecureSession identity;
  late _Carrier other;
  int sends = 0;
  final events = StreamController<Map<String, dynamic>>.broadcast();
  @override
  Stream<Map<String, dynamic>> get messages => events.stream;
  @override
  void sendEnvelope(Map<String, dynamic> envelope) {
    sends++;
    other.events.add({
      'kind': 'delivery',
      'body': {
        'source_peer_id': identity.peerId,
        'target_peer_id': other.identity.peerId,
        'envelope': envelope,
      },
    });
  }
}

class _Data extends RTCDataChannel {
  _Data(this.owner);
  final _Peer owner;
  int buffered = 0, sends = 0;
  bool closed = false, failSend = false;
  Uint8List? last;
  @override
  RTCDataChannelState get state => closed
      ? RTCDataChannelState.RTCDataChannelClosed
      : RTCDataChannelState.RTCDataChannelOpen;
  @override
  int get id => 0;
  @override
  String get label => 'novorudp-v1';
  @override
  int get bufferedAmount => buffered;
  @override
  Future<int> getBufferedAmount() async => buffered;
  @override
  Future<void> send(RTCDataChannelMessage value) async {
    if (failSend) throw StateError('native send failure');
    sends++;
    last = value.binary;
    owner.other.data.onMessage?.call(value);
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}

class _Peer extends Fake implements RTCPeerConnection {
  late _Peer other;
  late final data = _Data(this);
  int offers = 0, closed = 0, disposed = 0;
  RTCSessionDescription? description;
  @override
  Function(RTCPeerConnectionState)? onConnectionState;
  @override
  Function(RTCIceGatheringState)? onIceGatheringState;
  @override
  Function(RTCIceCandidate)? onIceCandidate;
  final candidates = <RTCIceCandidate>[];
  @override
  Future<void> addCandidate(RTCIceCandidate candidate) async {
    candidates.add(candidate);
  }

  @override
  RTCIceGatheringState get iceGatheringState =>
      RTCIceGatheringState.RTCIceGatheringStateComplete;
  @override
  Future<RTCDataChannel> createDataChannel(
    String label,
    RTCDataChannelInit init,
  ) async {
    expect(label, 'novorudp-v1');
    expect(init.negotiated, isTrue);
    expect(init.id, 0);
    return data;
  }

  @override
  Future<RTCSessionDescription> createOffer([
    Map<String, dynamic>? options,
  ]) async {
    offers++;
    return RTCSessionDescription(
      'v=0\r\nm=application 9 UDP/DTLS/SCTP webrtc-datachannel\r\na=x:${'a' * 3000}',
      'offer',
    );
  }

  @override
  Future<RTCSessionDescription> createAnswer([
    Map<String, dynamic>? options,
  ]) async => RTCSessionDescription(
    'v=0\r\nm=application 9 UDP/DTLS/SCTP webrtc-datachannel\r\n',
    'answer',
  );
  @override
  Future<void> setLocalDescription(RTCSessionDescription value) async {
    description = value;
  }

  @override
  Future<RTCSessionDescription?> getLocalDescription() async => description;
  @override
  Future<void> setRemoteDescription(RTCSessionDescription value) async {
    if (value.type == 'answer') {
      onConnectionState?.call(
        RTCPeerConnectionState.RTCPeerConnectionStateConnected,
      );
      other.onConnectionState?.call(
        RTCPeerConnectionState.RTCPeerConnectionStateConnected,
      );
    }
  }

  @override
  Future<List<StatsReport>> getStats([MediaStreamTrack? track]) async => [];
  @override
  Future<void> close() async {
    closed++;
  }

  @override
  Future<void> dispose() async {
    disposed++;
  }
}

Future<void> _until(bool Function() condition) async {
  final watch = Stopwatch()..start();
  while (!condition() && watch.elapsed < const Duration(seconds: 12)) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(condition(), isTrue);
}

void main() {
  testWidgets(
    'closing during native creation disposes late peer without sending SDP',
    (tester) async {
      final pending = Completer<RTCPeerConnection>();
      var creations = 0;
      final channel = _SessionOnly();
      final route = NovoRudpIceRoute(
        channel: channel,
        offerer: true,
        sendControl: (_) async {},
        deliver: (_, _) async {},
        stunUrls: [],
        peerFactory: (_) {
          creations++;
          return pending.future;
        },
      );
      await route.acceptControl(
        NovoRudpFrame(
          kind: NovoRudpFrameKind.endpoint,
          sessionId: channel.sessionId,
          streamId: NovoRudpIceRoute.controlStream,
          objectId: BigInt.zero,
          sequence: BigInt.zero,
          ackEpoch: BigInt.zero,
          payload: NovoRudpIceSignaling.encode({'op': 'hello'}).single,
        ),
      );
      route.start();
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 20));
      expect(creations, 1);
      await route.close();
      final late = _Peer();
      pending.complete(late);
      await tester.pump();
      expect(late.closed, 1);
      expect(late.disposed, 1);
      expect(late.offers, 0);
    },
  );
  test('encrypted relay negotiates data ICE; saturation/failure falls back without duplicates', () async {
    final library = DynamicLibrary.open(
      Platform.environment['NOVORUDP_NATIVE_LIBRARY']!,
    );
    final a = NovoRudpSecureSession.fromSeed(
      library: library,
      seed: Uint8List(32),
    );
    final b = NovoRudpSecureSession.fromSeed(
      library: library,
      seed: Uint8List.fromList(List.filled(32, 41)),
    );
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    final offer = a.start(b.peerId);
    final response = b.respond(offer.offer, expectedPeer: a.peerId);
    final ca = _Carrier(a), cb = _Carrier(b);
    ca.other = cb;
    cb.other = ca;
    final pa = _Peer(), pb = _Peer();
    pa.other = pb;
    pb.other = pa;
    final left = NovoRudpRelayFrameLink(
      relay: ca,
      channel: a.complete(offer, response.response),
      expectedPeer: b.peerId,
      enableIce: true,
      icePeerFactory: (_) async => pa,
    );
    final right = NovoRudpRelayFrameLink(
      relay: cb,
      channel: response.channel,
      expectedPeer: a.peerId,
      enableIce: true,
      icePeerFactory: (_) async => pb,
    );
    addTearDown(() async {
      await left.close();
      await right.close();
      await ca.events.close();
      await cb.events.close();
    });
    final received = <NovoRudpFrame>[];
    final sub = right.frames.listen(received.add);
    addTearDown(sub.cancel);
    NovoRudpFrame frame(int value) => NovoRudpFrame(
      kind: NovoRudpFrameKind.data,
      sessionId: left.channel.sessionId,
      streamId: BigInt.one,
      objectId: BigInt.one,
      sequence: BigInt.from(value),
      ackEpoch: BigInt.zero,
      payload: List.filled(500, value),
    );
    await left.send(
      frame(1),
    ); // Old fallback is immediately usable while ICE gathers.
    await _until(() => received.length == 1);
    await _until(() => left.iceReady && right.iceReady);
    expect(
      pa.offers + pb.offers,
      1,
      reason: 'deterministic offerer prevents glare',
    );
    pa.onIceCandidate!(
      RTCIceCandidate('candidate:1 1 udp 1 192.168.1.3 12345 typ host', '0', 0),
    );
    await _until(() => pb.candidates.length == 1);
    final relayed = ca.sends;
    await left.send(frame(2));
    await _until(() => received.length == 2);
    expect(pa.data.sends, 1);
    expect(ca.sends, relayed);
    pb.data.onMessage!(RTCDataChannelMessage.fromBinary(pa.data.last!));
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(
      received.length,
      2,
      reason: 'native replay defense is shared across carriers',
    );
    pa.data.buffered = 65537;
    await left.send(frame(3));
    await _until(() => received.length == 3);
    expect(ca.sends, greaterThan(relayed));
    pa.data.buffered = 0;
    pa.data.failSend = true;
    await left.send(frame(4));
    await _until(() => received.length == 4);
    expect(left.iceReady, isFalse);
    expect(received.map((f) => f.payload.first), [1, 2, 3, 4]);
    await left.close();
    expect(pa.closed, greaterThan(0));
    expect(pa.disposed, greaterThan(0));
  }, skip: !Platform.environment.containsKey('NOVORUDP_NATIVE_LIBRARY'));
}

class _SessionOnly extends Fake implements NovoRudpSecureChannel {
  @override
  final sessionId = Uint8List(16);
}
