import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/data/peer_file_authority.dart';

void main() {
  const message = '00000000-0000-4000-8000-000000000001';
  const asset = '00000000-0000-4000-8000-000000000002';
  Map<String, dynamic> manifest() => {
    'messageId': message,
    'sender': 'me',
    'recipient': 'peer',
    'assetId': asset,
    'fileName': 'file.bin',
    'size': 3,
    'sha256': 'a' * 64,
    'expiresAt': DateTime.now()
        .toUtc()
        .add(const Duration(seconds: 15))
        .toIso8601String(),
  };
  Future<PeerFileAuthority> read(Map<String, dynamic> data) =>
      PeerFileAuthority.read(
        MessagingRepository(account: 'me', call: (_, _) async => data),
        'peer',
        message,
        sending: true,
      );
  test(
    'authority binds full immutable manifest and current direction',
    () async {
      final first = await read(manifest()), second = await read(manifest());
      expect(first.sameFile(second), isTrue);
      expect(first.valid, isTrue);
      expect(
        first.sameFile(await read({...manifest(), 'sha256': 'b' * 64})),
        isFalse,
      );
    },
  );
  for (final groupId in [asset, null, '../group']) {
    test(
      'group discovery requires an explicit valid group: $groupId',
      () async {
        final repository = MessagingRepository(
          account: 'me',
          call: (_, params) async {
            expect(params['group'], true);
            return {
              ...manifest(),
              if (groupId != null) 'groupId': groupId,
              'senderMembershipVersion': 1,
              'recipientMembershipVersion': 2,
            };
          },
        );
        final result = PeerFileAuthority.read(
          repository,
          'peer',
          message,
          sending: true,
          group: true,
        );
        if (groupId == asset) {
          expect((await result).groupId, asset);
        } else {
          await expectLater(result, throwsFormatException);
        }
      },
    );
  }
  for (final invalid in <Map<String, dynamic>>[
    {'sender': 'outsider'},
    {'recipient': 'outsider'},
    {'messageId': asset},
    {'assetId': '../file'},
    {'size': -1},
    {'size': 3.0},
    {'size': 268435457},
    {'sha256': 'bad'},
    {'fileName': ''},
    {'expiresAt': 'invalid'},
    {
      'expiresAt': DateTime.now()
          .subtract(const Duration(minutes: 1))
          .toIso8601String(),
    },
    {
      'expiresAt': DateTime.now()
          .add(const Duration(days: 1))
          .toIso8601String(),
    },
  ]) {
    test('rejects invalid authority $invalid', () async {
      await expectLater(
        read({...manifest(), ...invalid}),
        throwsFormatException,
      );
    });
  }
}
