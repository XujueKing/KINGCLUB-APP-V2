import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/session/member_qr_memory.dart';
import 'package:kingclub/src/features/messaging/data/nearby_peer_identity_store.dart';

import 'novorudp_device_identity_store_test.dart' show Storage;

void main() {
  test(
    'historical identities are scoped, replaced and reject late session reads',
    () async {
      final storage = Storage();
      final own = 'novovm-ed25519:${List.filled(64, '1').join()}';
      final other = 'novovm-ed25519:${List.filled(64, '2').join()}';
      NearbyPeerIdentityStore create(String account, String key) =>
          NearbyPeerIdentityStore(
            account: account,
            ownPeerId: key,
            storage: storage,
          );
      final store = create('member-a', own);
      await store.save('member-b', [other]);
      final restored = await create('member-a', own).read('member-b');
      expect(restored!.peerIds, [other]);
      expect(() => restored.peerIds.clear(), throwsUnsupportedError);
      expect(await create('member-c', own).read('member-b'), isNull);
      expect(await create('member-a', other).read('member-b'), isNull);
      expect(await store.read('member-c'), isNull);
      await expectLater(
        store.save('member-b', [other, other]),
        throwsArgumentError,
      );
      await store.save('member-b', []);
      expect((await store.read('member-b'))!.peerIds, isEmpty);
      storage.reading = Completer<void>();
      final pending = store.read('member-b');
      final assertion = expectLater(pending, throwsStateError);
      await Future<void>.delayed(Duration.zero);
      MemberQrMemory.clear();
      storage.reading!.complete();
      await assertion;
    },
  );
}
