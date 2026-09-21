import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_lan_route.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_secure_session.dart';

class _Channel implements NovoRudpSecureChannel {
  @override
  final sessionId = Uint8List(16);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'real UDP discovery keeps distinct mappings from the same data socket',
    () async {
      final primary = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final secondary = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final duplicate = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      primary.writeEventsEnabled = secondary.writeEventsEnabled =
          duplicate.writeEventsEnabled = false;
      final advertisement = Completer<Map>();
      final observedPorts = <int>[];
      final visitedObservers = <int>{};
      StreamSubscription<RawSocketEvent> respond(
        RawDatagramSocket server, {
        required int mappedPort,
        required int mappedAddress,
      }) => server.listen((event) {
        if (event != RawSocketEvent.read) return;
        Datagram? packet;
        while ((packet = server.receive()) != null) {
          observedPorts.add(packet!.port);
          visitedObservers.add(server.port);
          expect(packet.data.length, 20);
          final response = Uint8List(32)..setRange(0, 20, packet.data);
          final data = ByteData.sublistView(response);
          data.setUint16(0, 0x0101);
          data.setUint16(2, 12);
          data.setUint16(20, 0x0020);
          data.setUint16(22, 8);
          response[25] = 1;
          data.setUint16(26, mappedPort ^ 0x2112);
          data.setUint32(28, mappedAddress ^ 0x2112a442);
          server.send(response, packet.address, packet.port);
        }
      });
      final primarySub = respond(
        primary,
        mappedPort: 45678,
        mappedAddress: 0x08080808,
      );
      final secondarySub = respond(
        secondary,
        mappedPort: 45679,
        mappedAddress: 0x01010101,
      );
      final duplicateSub = respond(
        duplicate,
        mappedPort: 45679,
        mappedAddress: 0x01010101,
      );
      final route = await NovoRudpLanRoute.open(
        channel: _Channel(),
        observerHost: '127.0.0.1',
        observerPort: primary.port,
        observerFallbacks:
            '127.0.0.1:${secondary.port},127.0.0.1:${duplicate.port}',
        sendControl: (frame) async {
          final body = jsonDecode(utf8.decode(frame.payload)) as Map;
          final candidates = body['publicCandidates'];
          if (candidates is List &&
              candidates.length == 2 &&
              visitedObservers.length == 3 &&
              !advertisement.isCompleted) {
            advertisement.complete(body);
          }
        },
        deliver: (_) async =>
            fail('Discovery must not deliver application data'),
      );
      try {
        final body = await advertisement.future.timeout(
          const Duration(seconds: 8),
        );
        expect(visitedObservers, hasLength(3));
        expect(observedPorts, hasLength(greaterThanOrEqualTo(3)));
        expect(observedPorts.toSet(), hasLength(1));
        expect(body['port'], observedPorts.first);
        expect(body['public'], {'address': '8.8.8.8', 'port': 45678});
        expect(body['publicCandidates'], [
          {'address': '8.8.8.8', 'port': 45678},
          {'address': '1.1.1.1', 'port': 45679},
        ]);
        expect(route!.ready, false);
      } finally {
        await route?.close();
        await primarySub.cancel();
        await secondarySub.cancel();
        await duplicateSub.cancel();
        primary.close();
        secondary.close();
        duplicate.close();
      }
    },
  );
}
