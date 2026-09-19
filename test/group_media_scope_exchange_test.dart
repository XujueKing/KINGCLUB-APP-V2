import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/group_file_device_scope.dart';
import 'package:kingclub/src/features/messaging/data/group_file_scope_exchange.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_frame.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_frame_link.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_secure_session.dart';

class _Channel implements NovoRudpSecureChannel {
  @override
  final sessionId = Uint8List(16);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Link implements NovoRudpFrameLink {
  @override
  final channel = _Channel();
  final incoming = StreamController<NovoRudpFrame>.broadcast();
  late _Link peer;
  @override
  Stream<NovoRudpFrame> get frames => incoming.stream;
  @override
  Future<void> send(NovoRudpFrame frame) async {
    peer.incoming.add(frame);
  }

  @override
  Future<void> close() => incoming.close();
}

void main() {
  const id = '11111111-1111-4111-8111-111111111111';
  GroupFileDeviceScope scope(String media) => GroupFileDeviceScope.parse(
    {
      'kind': 'group-file',
      'groupId': id,
      'messageId': id,
      'sender': 'a',
      'recipient': 'b',
      'senderMembershipVersion': 1,
      'recipientMembershipVersion': 2,
      'media': media,
    },
    messageId: id,
    groupId: id,
    account: 'a',
    peer: 'b',
    media: media,
  );
  for (final other in ['video', 'hevc']) {
    test('peer scope confirmation checks exact encoding $other', () async {
      final a = _Link(), b = _Link();
      a.peer = b;
      b.peer = a;
      try {
        final result = Future.wait([
          GroupFileScopeExchange.confirm(a, scope('video')),
          GroupFileScopeExchange.confirm(b, scope(other)),
        ]);
        if (other == 'video') {
          await result.timeout(const Duration(seconds: 2));
        } else {
          await expectLater(result, throwsA(isA<StateError>()));
        }
      } finally {
        await a.close();
        await b.close();
      }
    });
  }
}
