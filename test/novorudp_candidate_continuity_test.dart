import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_frame.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_lan_route.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_secure_packet.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_secure_session.dart';

void main() {
  final nativeUnavailable = !Platform.environment.containsKey(
    'NOVORUDP_NATIVE_LIBRARY',
  );

  test(
    'added candidate preserves an outstanding return-path challenge',
    () async {
      final peer = await _Peer.open();
      await peer.advertise();
      await _until(() => peer.challenges.isNotEmpty);
      final pending = peer.challenges.first;

      await peer.advertise(extra: true);
      await peer.send(peer.control({'op': 'pong', 'nonce': pending}));
      await _until(() => peer.route.ready);
      expect(peer.route.ready, isTrue);
    },
    skip: nativeUnavailable,
  );

  for (final reflexive in [false, true]) {
    test(
      'added candidate preserves selected route reflexive=$reflexive',
      () async {
        final peer = await _Peer.open();
        await peer.connect(reflexive: reflexive);
        await peer.advertise(extra: true, reflexive: reflexive);
        expect(peer.route.ready, isTrue);
        expect(await peer.route.trySend(peer.data([1, 2, 3])), isTrue);
        await _until(() => peer.outbound.isNotEmpty);
        expect(peer.outbound.single.payload, [1, 2, 3]);
        await peer.send(peer.data([4, 5, 6]));
        await _until(() => peer.inbound.isNotEmpty);
        expect(peer.inbound.single.payload, [4, 5, 6]);
      },
      skip: nativeUnavailable,
    );
  }

  test('added candidate does not interrupt in-flight encrypted send', () async {
    final peer = await _Peer.open();
    await peer.connect();
    final gate = peer.channel.pauseSend = _Gate();
    final sending = peer.route.trySend(peer.data([7, 8]));
    await gate.entered.future.timeout(const Duration(seconds: 2));
    await peer.advertise(extra: true);
    gate.release.complete();

    expect(await sending, isTrue);
    expect(peer.route.ready, isTrue);
    await _until(() => peer.outbound.isNotEmpty);
    expect(peer.outbound.single.payload, [7, 8]);
  }, skip: nativeUnavailable);

  test(
    'added candidate does not discard in-flight authenticated receive',
    () async {
      final peer = await _Peer.open();
      await peer.connect();
      final gate = peer.channel.pauseReceive = _Gate();
      await peer.send(peer.data([9, 10]));
      await gate.entered.future.timeout(const Duration(seconds: 2));
      await peer.advertise(extra: true);
      gate.release.complete();

      await _until(() => peer.inbound.isNotEmpty);
      expect(peer.inbound.single.payload, [9, 10]);
      expect(peer.route.ready, isTrue);
    },
    skip: nativeUnavailable,
  );

  test('withdrawal revokes selected route and aborts in-flight send', () async {
    final peer = await _Peer.open();
    await peer.connect();
    final gate = peer.channel.pauseSend = _Gate();
    final sending = peer.route.trySend(peer.data([11, 12]));
    await gate.entered.future.timeout(const Duration(seconds: 2));
    await peer.advertise(withdraw: true);
    expect(peer.route.ready, isFalse);
    gate.release.complete();
    expect(await sending, isFalse);
    expect(peer.outbound, isEmpty);
  }, skip: nativeUnavailable);

  test('withdrawal revokes authenticated observed NAT mapping', () async {
    final peer = await _Peer.open();
    await peer.connect(reflexive: true);
    await peer.advertise(withdraw: true, reflexive: true);
    expect(peer.route.ready, isFalse);
    expect(await peer.route.trySend(peer.data([13])), isFalse);
  }, skip: nativeUnavailable);
}

Future<void> _until(bool Function() condition) async {
  final watch = Stopwatch()..start();
  while (!condition() && watch.elapsed < const Duration(seconds: 2)) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(condition(), isTrue, reason: 'real UDP exchange did not complete');
}

class _Gate {
  final entered = Completer<void>();
  final release = Completer<void>();

  Future<void> wait() async {
    entered.complete();
    await release.future;
  }
}

// Pause only application frames at the real asynchronous crypto boundary.
// Control challenges continue using the native authenticated channel.
class _GatedChannel implements NovoRudpSecureChannel {
  _GatedChannel(this.inner);
  final NovoRudpSecureChannel inner;
  _Gate? pauseSend, pauseReceive;

  @override
  Uint8List get sessionId => inner.sessionId;

  @override
  Future<Map<String, dynamic>> seal(NovoRudpFrame frame) async {
    if (frame.streamId != NovoRudpLanRoute.controlStream && pauseSend != null) {
      final gate = pauseSend!;
      pauseSend = null;
      await gate.wait();
    }
    return inner.seal(frame);
  }

  @override
  Future<NovoRudpFrame> open(Map<String, dynamic> envelope) async {
    final frame = await inner.open(envelope);
    if (frame.streamId != NovoRudpLanRoute.controlStream &&
        pauseReceive != null) {
      final gate = pauseReceive!;
      pauseReceive = null;
      await gate.wait();
    }
    return frame;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Peer {
  _Peer(this.channel, this.remote, this.actual, this.advertised);
  final _GatedChannel channel;
  final NovoRudpSecureChannel remote;
  final RawDatagramSocket actual, advertised;
  late final NovoRudpLanRoute route;
  late final InternetAddress address;
  late final int port;
  final challenges = <String>[];
  final inbound = <NovoRudpFrame>[], outbound = <NovoRudpFrame>[];

  static Future<_Peer> open() async {
    final library = DynamicLibrary.open(
      Platform.environment['NOVORUDP_NATIVE_LIBRARY']!,
    );
    final a = NovoRudpSecureSession.fromSeed(
      library: library,
      seed: Uint8List(32),
    );
    final b = NovoRudpSecureSession.fromSeed(
      library: library,
      seed: Uint8List.fromList(List.filled(32, 61)),
    );
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    final offer = a.start(b.peerId);
    final answer = b.respond(offer.offer, expectedPeer: a.peerId);
    final secure = a.complete(offer, answer.response);
    addTearDown(secure.close);
    addTearDown(answer.channel.close);
    final actual = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    final advertised = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    final peer = _Peer(
      _GatedChannel(secure),
      answer.channel,
      actual,
      advertised,
    );
    actual.writeEventsEnabled = false;
    advertised.writeEventsEnabled = false;
    final discarded = advertised.listen((event) {
      if (event == RawSocketEvent.read) {
        while (advertised.receive() != null) {}
      }
    });
    final incoming = actual.listen((event) async {
      if (event != RawSocketEvent.read) return;
      final packet = actual.receive();
      if (packet == null) return;
      final frame = await peer.remote.open(
        NovoRudpSecurePacket.decode(packet.data),
      );
      if (frame.streamId == NovoRudpLanRoute.controlStream) {
        final body = jsonDecode(utf8.decode(frame.payload)) as Map;
        if (body['op'] == 'ping') peer.challenges.add(body['nonce'] as String);
      } else {
        peer.outbound.add(frame);
      }
    });
    addTearDown(() async {
      await incoming.cancel();
      await discarded.cancel();
      actual.close();
      advertised.close();
    });
    Map? local;
    peer.route = (await NovoRudpLanRoute.open(
      channel: peer.channel,
      sendControl: (frame) async {
        local = jsonDecode(utf8.decode(frame.payload)) as Map;
      },
      deliver: (frame) async {
        peer.inbound.add(frame);
      },
      // Only a local dummy observer; no external STUN service is involved.
      observerHost: '127.0.0.1',
      observerPort: advertised.port,
      observerFallbacks: '',
      discoverIpv6: () async => [],
    ))!;
    addTearDown(peer.route.close);
    await peer.route.advertise();
    final addresses = local!['addresses'] as List;
    expect(addresses, isNotEmpty, reason: 'private IPv4 interface required');
    peer.address = InternetAddress(addresses.first as String);
    peer.port = local!['port'] as int;
    return peer;
  }

  Future<void> advertise({
    bool extra = false,
    bool reflexive = false,
    bool withdraw = false,
  }) => route.acceptControl(
    control({
      'op': 'endpoint',
      'addresses': withdraw ? <String>[] : [address.address],
      'port': reflexive ? advertised.port : actual.port,
      if (extra)
        'publicCandidates': [
          {'address': '198.51.100.77', 'port': 40000},
        ],
    }),
  );

  Future<void> connect({bool reflexive = false}) async {
    await advertise(reflexive: reflexive);
    if (reflexive) {
      await send(control({'op': 'ping', 'nonce': 'a' * 32}));
    }
    await _until(() => challenges.isNotEmpty);
    await send(control({'op': 'pong', 'nonce': challenges.first}));
    await _until(() => route.ready);
  }

  Future<void> send(NovoRudpFrame frame) async {
    actual.send(
      NovoRudpSecurePacket.encode(await remote.seal(frame)),
      address,
      port,
    );
  }

  NovoRudpFrame control(Map<String, Object> body) =>
      _frame(NovoRudpLanRoute.controlStream, utf8.encode(jsonEncode(body)));
  NovoRudpFrame data(List<int> bytes) => _frame(BigInt.one, bytes);
  NovoRudpFrame _frame(BigInt streamId, List<int> payload) => NovoRudpFrame(
    kind: NovoRudpFrameKind.data,
    sessionId: channel.sessionId,
    streamId: streamId,
    objectId: BigInt.one,
    sequence: BigInt.zero,
    ackEpoch: BigInt.zero,
    payload: payload,
  );
}
