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
