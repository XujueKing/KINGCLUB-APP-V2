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

  for (final sending in [true, false]) {
    test('IPv6 loss preserves in-flight IPv4 sending=$sending', () async {
      final peer = await _Peer.open(globalIpv6: true);
      await peer.connect();
      final gate = _Gate();
      Future<bool>? sent;
      if (sending) {
        peer.channel.pauseSend = gate;
        sent = peer.route.trySend(peer.data([21]));
      } else {
        peer.channel.pauseReceive = gate;
        await peer.send(peer.data([22]));
      }
      await gate.entered.future.timeout(const Duration(seconds: 2));
      await peer.loseIpv6();
      gate.release.complete();
      if (sending) {
        expect(await sent, isTrue);
        await _until(() => peer.outbound.isNotEmpty);
        expect(peer.outbound.single.payload, [21]);
      } else {
        await _until(() => peer.inbound.isNotEmpty);
        expect(peer.inbound.single.payload, [22]);
      }
      expect(peer.route.ready, isTrue);
    }, skip: nativeUnavailable);
  }

  test('IPv6 loss preserves outstanding IPv4 return-path proof', () async {
    final peer = await _Peer.open(globalIpv6: true);
    await peer.advertise();
    await _until(() => peer.challenges.isNotEmpty);
    final nonce = peer.challenges.first;
    await peer.loseIpv6();
    await peer.send(peer.control({'op': 'pong', 'nonce': nonce}));
    await _until(() => peer.route.ready);
  }, skip: nativeUnavailable);

  test('peer withdrawing IPv6 keeps our in-flight IPv4 send', () async {
    final peer = await _Peer.open(globalIpv6: true);
    await peer.connect();
    await peer.advertise(ipv6: true);
    final gate = peer.channel.pauseSend = _Gate();
    final sending = peer.route.trySend(peer.data([28]));
    await gate.entered.future.timeout(const Duration(seconds: 2));
    await peer.advertise();
    gate.release.complete();
    expect(await sending, isTrue);
    expect(peer.route.ready, isTrue);
    await _until(() => peer.outbound.isNotEmpty);
    expect(peer.outbound.single.payload, [28]);
  }, skip: nativeUnavailable);

  test('IPv6 restoration keeps healthy IPv4 selected', () async {
    final peer = await _Peer.open(globalIpv6: true);
    await peer.connect();
    await peer.loseIpv6();
    await _until(
      () => peer.ipv6Sockets.length == 2,
      timeout: const Duration(seconds: 4),
    );
    await _until(() => peer.latestAdvertisement?['ipv6'] != null);
    expect(peer.route.ready, isTrue);
    expect(await peer.route.trySend(peer.data([23])), isTrue);
    await _until(() => peer.outbound.isNotEmpty);
    expect(peer.outbound.single.payload, [23]);
  }, skip: nativeUnavailable);

  test(
    'unattributed UDP error does not revoke healthy same-family route',
    () async {
      final peer = await _Peer.open();
      await peer.connect();
      peer.ipv4Socket.errors.addError(
        const SocketException('ICMP unreachable'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(peer.route.ready, isTrue);
      peer.ipv4Socket.failNextReceive = true;
      peer.ipv4Socket.errors.add(RawSocketEvent.read);
      await _until(() => !peer.ipv4Socket.failNextReceive);
      expect(peer.route.ready, isTrue);
      expect(await peer.route.trySend(peer.data([24])), isTrue);
      await _until(() => peer.outbound.isNotEmpty);
    },
    skip: nativeUnavailable,
  );

  test(
    'working heartbeat cannot reclaim stalled data path before cooldown',
    () async {
      var now = Duration.zero;
      final peer = await _Peer.open(clock: () => now);
      await peer.connect();
      final old = peer.challenges.first;
      peer.route.reprobeAfterStall();
      expect(peer.route.ready, isFalse);
      await peer.send(peer.control({'op': 'ping', 'nonce': 'b' * 32}));
      await _until(() => peer.pongs > 0);
      await peer.send(peer.control({'op': 'pong', 'nonce': old}));
      now = const Duration(milliseconds: 29999);
      await peer.advertise();
      expect(peer.route.ready, isFalse);
      expect(await peer.route.trySend(peer.data([25])), isFalse);
      expect(peer.challenges.toSet(), {old});

      now = const Duration(seconds: 30);
      await peer.advertise();
      await _until(() => peer.challenges.any((nonce) => nonce != old));
      expect(peer.route.ready, isFalse);
      await peer.send(
        peer.control({'op': 'pong', 'nonce': peer.challenges.last}),
      );
      await _until(() => peer.route.ready);
      expect(await peer.route.trySend(peer.data([26])), isTrue);
      await _until(() => peer.outbound.isNotEmpty);
      expect(peer.outbound.single.payload, [26]);
    },
    skip: nativeUnavailable,
  );

  test(
    'stalled endpoint cooldown does not prevent switching to an alternative',
    () async {
      final peer = await _Peer.open();
      await peer.connect(reflexive: true);
      peer.answerAlternate = true;
      peer.route.reprobeAfterStall();
      expect(peer.route.ready, isFalse);
      await _until(() => peer.route.ready);
      expect(await peer.route.trySend(peer.data([27])), isTrue);
      await _until(() => peer.alternateOutbound.isNotEmpty);
      expect(peer.alternateOutbound.single.payload, [27]);
      expect(peer.outbound, isEmpty);
    },
    skip: nativeUnavailable,
  );

  test(
    'late send failure cannot revoke a newly verified alternative',
    () async {
      final peer = await _Peer.open();
      await peer.connect();
      final gate = peer.channel.pauseSend = _Gate();
      final oldSend = peer.route.trySend(peer.data([29]));
      await gate.entered.future.timeout(const Duration(seconds: 2));
      peer.answerAlternate = true;
      await peer.advertise(reflexive: true);
      await _until(() => peer.route.ready);
      gate.release.complete();
      expect(await oldSend, isFalse);
      expect(peer.route.ready, isTrue);
      expect(await peer.route.trySend(peer.data([30])), isTrue);
      await _until(() => peer.alternateOutbound.isNotEmpty);
      expect(peer.alternateOutbound.single.payload, [30]);
      expect(peer.outbound, isEmpty);
    },
    skip: nativeUnavailable,
  );
}

Future<void> _until(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final watch = Stopwatch()..start();
  while (!condition() && watch.elapsed < timeout) {
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
  final alternateOutbound = <NovoRudpFrame>[];
  final ipv6Sockets = <RawDatagramSocket>[];
  late _ErrorInjectingSocket ipv4Socket;
  Map? latestAdvertisement;
  int pongs = 0;
  bool answerAlternate = false;

  static Future<_Peer> open({
    bool globalIpv6 = false,
    Duration Function()? clock,
  }) async {
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
    final discarded = advertised.listen((event) async {
      if (event == RawSocketEvent.read) {
        for (
          var packet = advertised.receive();
          packet != null;
          packet = advertised.receive()
        ) {
          if (!peer.answerAlternate || packet.address.isLoopback) continue;
          final frame = await peer.remote.open(
            NovoRudpSecurePacket.decode(packet.data),
          );
          if (frame.streamId == NovoRudpLanRoute.controlStream) {
            final body = jsonDecode(utf8.decode(frame.payload)) as Map;
            if (body['op'] == 'ping') {
              advertised.send(
                NovoRudpSecurePacket.encode(
                  await peer.remote.seal(
                    peer.control({
                      'op': 'pong',
                      'nonce': body['nonce'] as String,
                    }),
                  ),
                ),
                packet.address,
                packet.port,
              );
            }
          } else {
            peer.alternateOutbound.add(frame);
          }
        }
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
        if (body['op'] == 'pong') peer.pongs++;
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
        peer.latestAdvertisement = local;
      },
      deliver: (frame) async {
        peer.inbound.add(frame);
      },
      // Only a local dummy observer; no external STUN service is involved.
      observerHost: '127.0.0.1',
      observerPort: advertised.port,
      observerFallbacks: '',
      bindIpv4: () async => peer.ipv4Socket = _ErrorInjectingSocket(
        await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0),
      ),
      bindIpv6: () async {
        final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv6, 0);
        peer.ipv6Sockets.add(socket);
        return socket;
      },
      discoverIpv6: () async => globalIpv6 ? ['240e::5'] : [],
      discoveryClock: clock,
    ))!;
    addTearDown(peer.route.close);
    await peer.route.advertise();
    final addresses = local!['addresses'] as List;
    expect(addresses, isNotEmpty, reason: 'private IPv4 interface required');
    peer.address = InternetAddress(addresses.first as String);
    peer.port = local!['port'] as int;
    return peer;
  }

  Future<void> loseIpv6() async {
    ipv6Sockets.last.close();
    await _until(() => latestAdvertisement?['ipv6'] == null);
  }

  Future<void> advertise({
    bool extra = false,
    bool ipv6 = false,
    bool reflexive = false,
    bool withdraw = false,
  }) => route.acceptControl(
    control({
      'op': 'endpoint',
      'addresses': withdraw ? <String>[] : [address.address],
      'port': reflexive ? advertised.port : actual.port,
      if (ipv6)
        'ipv6': {
          'addresses': ['240e::6'],
          'port': 40001,
        },
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

// Real IPv4 UDP, with an independent asynchronous error source to represent
// ICMP errors that provide no destination information to the route.
class _ErrorInjectingSocket implements RawDatagramSocket {
  _ErrorInjectingSocket(this.inner) {
    subscription = inner.listen(
      errors.add,
      onError: errors.addError,
      onDone: () => unawaited(errors.close()),
    );
  }
  final RawDatagramSocket inner;
  final errors = StreamController<RawSocketEvent>();
  late final StreamSubscription<RawSocketEvent> subscription;
  bool failNextReceive = false;
  @override
  InternetAddress get address => inner.address;
  @override
  int get port => inner.port;
  @override
  set writeEventsEnabled(bool value) => inner.writeEventsEnabled = value;
  @override
  set readEventsEnabled(bool value) => inner.readEventsEnabled = value;
  @override
  Datagram? receive() {
    if (failNextReceive) {
      failNextReceive = false;
      throw const SocketException('ICMP unreachable during receive');
    }
    return inner.receive();
  }

  @override
  int send(List<int> buffer, InternetAddress address, int port) =>
      inner.send(buffer, address, port);
  @override
  StreamSubscription<RawSocketEvent> listen(
    void Function(RawSocketEvent)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => errors.stream.listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  void close() {
    inner.close();
    unawaited(subscription.cancel());
    unawaited(errors.close());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
