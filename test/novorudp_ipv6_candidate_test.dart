import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_frame.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_lan_route.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_secure_session.dart';

class _Channel implements NovoRudpSecureChannel {
  @override
  final sessionId = Uint8List(16);
  int probes = 0;
  @override
  Future<Map<String, dynamic>> seal(NovoRudpFrame frame) async {
    probes++;
    throw const SocketException('candidate test does not send network traffic');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ErrorSocket implements RawDatagramSocket {
  final events = StreamController<RawSocketEvent>();
  bool closed = false;
  @override
  int get port => 12001;
  @override
  set writeEventsEnabled(bool value) {}
  @override
  set readEventsEnabled(bool value) {}
  @override
  StreamSubscription<RawSocketEvent> listen(
    void Function(RawSocketEvent)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => events.stream.listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  void close() {
    closed = true;
    unawaited(events.close());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('closed IPv6 socket rebinds when global address is available', () async {
    final sockets = <RawDatagramSocket>[];
    final ads = <Map>[];
    final route = (await NovoRudpLanRoute.open(
      channel: _Channel(),
      bindIpv6: () async {
        final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv6, 0);
        sockets.add(socket);
        return socket;
      },
      discoverIpv6: () async => ['240e::5'],
      sendControl: (frame) async {
        ads.add(jsonDecode(utf8.decode(frame.payload)) as Map);
      },
      deliver: (_) async {},
    ))!;
    addTearDown(route.close);
    await route.advertise();
    sockets.first.close();
    final wait = Stopwatch()..start();
    while (sockets.length < 2 && wait.elapsed < const Duration(seconds: 4)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(sockets.length, 2);
    await route.advertise();
    expect((ads.last['ipv6'] as Map)['port'], sockets.last.port);
    expect(ads.last['port'], ads.first['port'], reason: 'IPv4 socket retained');
  });
  test('no local global IPv6 means no unreachable remote IPv6 probe', () async {
    final channel = _Channel();
    final route = (await NovoRudpLanRoute.open(
      channel: channel,
      bindIpv6: () async => _ErrorSocket(),
      discoverIpv6: () async => [],
      sendControl: (_) async {},
      deliver: (_) async {},
    ))!;
    addTearDown(route.close);
    await route.acceptControl(
      NovoRudpFrame(
        kind: NovoRudpFrameKind.data,
        sessionId: channel.sessionId,
        streamId: NovoRudpLanRoute.controlStream,
        objectId: BigInt.zero,
        sequence: BigInt.zero,
        ackEpoch: BigInt.zero,
        payload: utf8.encode(
          jsonEncode({
            'op': 'endpoint',
            'addresses': [],
            'port': 12000,
            'ipv6': {
              'addresses': ['240e::1234'],
              'port': 12000,
            },
          }),
        ),
      ),
    );
    expect(channel.probes, 0);
  });
  test('unreachable IPv6 candidate does not retire a usable socket', () async {
    final socket = _ErrorSocket();
    final channel = _Channel();
    final route = (await NovoRudpLanRoute.open(
      channel: channel,
      bindIpv6: () async => socket,
      discoverIpv6: () async => ['240e::5'],
      sendControl: (_) async {},
      deliver: (_) async {},
    ))!;
    addTearDown(route.close);
    socket.events.addError(const SocketException('network unreachable'));
    await Future<void>.delayed(Duration.zero);
    expect(socket.closed, isFalse);
    await route.acceptControl(
      NovoRudpFrame(
        kind: NovoRudpFrameKind.data,
        sessionId: channel.sessionId,
        streamId: NovoRudpLanRoute.controlStream,
        objectId: BigInt.zero,
        sequence: BigInt.zero,
        ackEpoch: BigInt.zero,
        payload: utf8.encode(
          jsonEncode({
            'op': 'endpoint',
            'addresses': [],
            'port': 12000,
            'ipv6': {
              'addresses': ['240e::1234'],
              'port': 12000,
            },
          }),
        ),
      ),
    );
    expect(
      channel.probes,
      1,
      reason: 'future IPv6 candidates still receive probes',
    );
  });
  for (final failure in ['bind', 'close']) {
    test('IPv6 $failure failure preserves IPv4 advertisements', () async {
      final socket = failure == 'close'
          ? await RawDatagramSocket.bind(InternetAddress.anyIPv6, 0)
          : null;
      final advertisements = <Map>[];
      final route = (await NovoRudpLanRoute.open(
        channel: _Channel(),
        bindIpv6: () async {
          if (socket == null) throw const SocketException('IPv6 unavailable');
          return socket;
        },
        sendControl: (frame) async {
          advertisements.add(jsonDecode(utf8.decode(frame.payload)) as Map);
        },
        deliver: (_) async {},
      ))!;
      addTearDown(route.close);
      await route.advertise();
      final port = advertisements.last['port'];
      if (socket != null) {
        socket.close();
        final wait = Stopwatch()..start();
        while (advertisements.length == 1 &&
            wait.elapsed < const Duration(seconds: 2)) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(
          advertisements.length,
          greaterThan(1),
          reason: 'closed IPv6 is withdrawn',
        );
      }
      final before = advertisements.length;
      await route.advertise();
      expect(advertisements.length, before + 1);
      expect(advertisements.last['port'], port);
      expect(advertisements.last.containsKey('ipv6'), isFalse);
    });
  }
  test('IPv6 excludes non-global and documentation addresses', () {
    for (final value in [
      '::',
      '::1',
      'fe80::1',
      'fc00::1',
      'fd00::1',
      'ff02::1',
      '::ffff:192.168.1.1',
      '2001:db8::1',
      '192.168.1.1',
    ]) {
      expect(
        NovoRudpLanRoute.isGlobalIpv6(InternetAddress(value)),
        isFalse,
        reason: value,
      );
    }
    expect(
      NovoRudpLanRoute.isGlobalIpv6(InternetAddress('240e::1234')),
      isTrue,
    );
    expect(
      NovoRudpLanRoute.isGlobalIpv6(InternetAddress('2001:4860::1234')),
      isTrue,
    );
  });
  test(
    'authenticated v6 candidates are bounded and need a return probe',
    () async {
      final channel = _Channel();
      final route = (await NovoRudpLanRoute.open(
        channel: channel,
        discoverIpv6: () async => ['240e::5'],
        sendControl: (_) async {},
        deliver: (_) async {},
      ))!;
      addTearDown(route.close);
      Future<void> advertise(List<String> hosts, int port) =>
          route.acceptControl(
            NovoRudpFrame(
              kind: NovoRudpFrameKind.data,
              sessionId: channel.sessionId,
              streamId: NovoRudpLanRoute.controlStream,
              objectId: BigInt.zero,
              sequence: BigInt.zero,
              ackEpoch: BigInt.zero,
              payload: utf8.encode(
                jsonEncode({
                  'op': 'endpoint',
                  'addresses': [],
                  'port': 10000,
                  'ipv6': {'addresses': hosts, 'port': port},
                }),
              ),
            ),
          );
      await advertise(['fe80::1', '::1'], 12000);
      expect(channel.probes, 0);
      await advertise(['240e::1234'], 0);
      expect(channel.probes, 0);
      await advertise(['240e::1', '240e::2', '240e::3'], 12000);
      expect(channel.probes, 0);
      await advertise(['240e::1234', '240e::1234'], 12000);
      expect(channel.probes, 1);
      expect(route.ready, isFalse);
      await advertise([], 12000);
      final before = channel.probes;
      await advertise([], 12000);
      expect(
        channel.probes,
        before,
        reason: 'removed candidates cannot keep probing',
      );
    },
  );
}
