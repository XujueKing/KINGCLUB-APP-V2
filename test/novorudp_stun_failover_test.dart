import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_frame.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_lan_route.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_secure_session.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_stun_binding.dart';

class _Channel implements NovoRudpSecureChannel {
  @override
  final sessionId = Uint8List(16);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Uint8List reply(Uint8List request, int port) {
  final bytes = Uint8List(32)..setRange(0, 20, request);
  final data = ByteData.sublistView(bytes);
  data.setUint16(0, 0x0101);
  data.setUint16(2, 12);
  data.setUint16(20, 0x0020);
  data.setUint16(22, 8);
  bytes[25] = 1;
  data.setUint16(26, port ^ 0x2112);
  data.setUint32(28, 0xcb007109 ^ NovoRudpStunBinding.cookie);
  return bytes;
}

void main() {
  test('deployment endpoint list is bounded and rejects credential URLs', () {
    expect(
      NovoRudpLanRoute.parseObservers(
        'A.example',
        3478,
        'a.example:3478,b.example:443',
      ),
      [(host: 'a.example', port: 3478), (host: 'b.example', port: 443)],
    );
    for (final value in [
      'https://a:443',
      'user@host:443',
      'a:0',
      'a:65536',
      'a:443,b:443,c:443,d:443',
      'a:443?x=1',
    ]) {
      expect(
        () => NovoRudpLanRoute.parseObservers('a', 3478, value),
        throwsFormatException,
      );
    }
  });

  test('silent primary rotates port and ignores its late response', () async {
    final silent = await RawDatagramSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final backup = await RawDatagramSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    silent.writeEventsEnabled = backup.writeEventsEnabled = false;
    Datagram? first;
    var primaryRequests = 0, backupRequests = 0;
    final primarySub = silent.listen((event) {
      if (event != RawSocketEvent.read) return;
      Datagram? packet;
      while ((packet = silent.receive()) != null) {
        first = packet;
        primaryRequests++;
      }
    });
    final backupSub = backup.listen((event) {
      if (event != RawSocketEvent.read) return;
      Datagram? packet;
      while ((packet = backup.receive()) != null) {
        backupRequests++;
        backup.send(reply(packet!.data, 45678), packet.address, packet.port);
      }
    });
    final mapped = Completer<void>();
    final ports = <int>[];
    final route = await NovoRudpLanRoute.open(
      channel: _Channel(),
      observerHost: '127.0.0.1',
      observerPort: silent.port,
      observerFallbacks: '127.0.0.1:${backup.port}',
      sendControl: (NovoRudpFrame frame) async {
        final body = jsonDecode(utf8.decode(frame.payload)) as Map;
        final public = body['public'];
        if (public is Map) {
          ports.add(public['port'] as int);
          if (!mapped.isCompleted) mapped.complete();
        }
      },
      deliver: (_) async {},
    );
    try {
      await mapped.future.timeout(const Duration(seconds: 10));
      expect(primaryRequests, greaterThan(0));
      expect(backupRequests, 1);
      expect(ports, everyElement(45678));
      silent.send(reply(first!.data, 49999), first!.address, first!.port);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await route!.advertise();
      expect(ports, everyElement(45678));
      expect(
        route.ready,
        isFalse,
        reason: 'STUN observation never authenticates a peer route',
      );
    } finally {
      await route?.close();
      await primarySub.cancel();
      await backupSub.cancel();
      silent.close();
      backup.close();
    }
  });
}
