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
    'real UDP discovery advertises translated port on the same data socket',
    () async {
      final server = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      server.writeEventsEnabled = false;
      final advertisement = Completer<Map>();
      var observedPort = 0;
      final subscription = server.listen((event) {
        if (event != RawSocketEvent.read) return;
        final packet = server.receive();
        if (packet == null) return;
        observedPort = packet.port;
        expect(packet.data.length, 20);
        final response = Uint8List(32)..setRange(0, 20, packet.data);
        final data = ByteData.sublistView(response);
        data.setUint16(0, 0x0101);
        data.setUint16(2, 12);
        data.setUint16(20, 0x0020);
        data.setUint16(22, 8);
        response[25] = 1;
        data.setUint16(26, 45678 ^ 0x2112);
        data.setUint32(28, 0x08080808 ^ 0x2112a442);
        server.send(response, packet.address, packet.port);
      });
      final route = await NovoRudpLanRoute.open(
        channel: _Channel(),
        observerHost: '127.0.0.1',
        observerPort: server.port,
        sendControl: (frame) async {
          final body = jsonDecode(utf8.decode(frame.payload)) as Map;
          if (body['public'] != null && !advertisement.isCompleted) {
            advertisement.complete(body);
          }
        },
        deliver: (_) async =>
            fail('Discovery must not deliver application data'),
      );
      try {
        final body = await advertisement.future.timeout(
          const Duration(seconds: 3),
        );
        expect(body['port'], observedPort);
        expect(body['public'], {'address': '8.8.8.8', 'port': 45678});
        expect(route!.ready, false);
      } finally {
        await route?.close();
        await subscription.cancel();
        server.close();
      }
    },
  );
}
