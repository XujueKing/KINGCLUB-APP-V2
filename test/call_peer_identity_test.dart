import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/call_peer_identity.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

void main() {
  test(
    'caller uses viewer remark before nickname and strips control characters',
    () async {
      final repository = MessagingRepository(
        account: 'receiver',
        call: (method, params) async {
          expect(params['peer'], 'caller');
          return method == 'K260913000612'
              ? {'nickname': 'Nickname'}
              : {'remark': ' Friend\nName '};
        },
      );
      expect(await callPeerName(repository, 'caller'), 'Friend Name');
    },
  );
  test('failed settings read does not hide authorized nickname', () async {
    final repository = MessagingRepository(
      account: 'receiver',
      call: (method, params) async {
        if (method == 'K260913000612') return {'nickname': 'Friend'};
        throw StateError('offline');
      },
    );
    expect(await callPeerName(repository, 'caller'), 'Friend');
  });
  test('unavailable identity does not fabricate a caller', () async {
    final repository = MessagingRepository(
      account: 'receiver',
      call: (_, _) async => throw StateError('offline'),
    );
    expect(await callPeerName(repository, 'caller'), isNull);
  });
}
