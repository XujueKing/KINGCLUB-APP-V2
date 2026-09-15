import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/networking/kingclub_realtime.dart';

class Socket extends Fake implements WebSocket {
  int closes = 0;
  bool failClose = false;
  @override
  Future<void> close([int? code, String? reason]) async {
    closes++;
    if (failClose) throw StateError('native close failed');
  }
}

void main() {
  final uri = Uri.parse('wss://fixture.invalid/ws');
  test('real delayed upgrade closes late connection on server', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final arrived = Completer<void>(), allowUpgrade = Completer<void>();
    final closed = Completer<void>();
    final subscription = server.listen((request) async {
      arrived.complete();
      await allowUpgrade.future;
      try {
        final socket = await WebSocketTransformer.upgrade(request);
        socket.listen(
          (_) {},
          onDone: () => closed.complete(),
          onError: (Object e, StackTrace st) => closed.completeError(e, st),
        );
      } catch (e, st) {
        closed.completeError(e, st);
      }
    });
    addTearDown(subscription.cancel);
    final pending = connectRealtimeSocket(
      Uri.parse('ws://127.0.0.1:${server.port}/ws'),
      timeout: const Duration(milliseconds: 200),
    );
    final timeout = expectLater(pending, throwsA(isA<TimeoutException>()));
    await arrived.future.timeout(const Duration(seconds: 2));
    await timeout;
    allowUpgrade.complete();
    await closed.future.timeout(const Duration(seconds: 3));
  });
  test('successful handshake stays open for the owner', () async {
    final socket = Socket();
    expect(
      await connectRealtimeSocket(uri, connect: (_) async => socket),
      same(socket),
    );
    expect(socket.closes, 0);
  });
  for (final failClose in [false, true]) {
    test(
      'timed out handshake closes late socket (close failure=$failClose)',
      () async {
        final pending = Completer<WebSocket>();
        final socket = Socket()..failClose = failClose;
        await expectLater(
          connectRealtimeSocket(
            uri,
            timeout: const Duration(milliseconds: 10),
            connect: (_) => pending.future,
          ),
          throwsA(isA<TimeoutException>()),
        );
        pending.complete(socket);
        await Future<void>.delayed(Duration.zero);
        expect(socket.closes, 1);
      },
    );
  }
  test('late handshake failure is consumed after timeout', () async {
    final pending = Completer<WebSocket>();
    await expectLater(
      connectRealtimeSocket(
        uri,
        timeout: const Duration(milliseconds: 10),
        connect: (_) => pending.future,
      ),
      throwsA(isA<TimeoutException>()),
    );
    pending.completeError(const SocketException('late failure'));
    await Future<void>.delayed(Duration.zero);
  });
  test('early handshake failure remains visible to reconnect policy', () async {
    await expectLater(
      connectRealtimeSocket(
        uri,
        connect: (_) async => throw const SocketException('connection refused'),
      ),
      throwsA(isA<SocketException>()),
    );
  });
}
